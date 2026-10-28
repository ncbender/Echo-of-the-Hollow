class_name PlayerProgressionBridge
extends Node
## The single connection point between the combat layer (Player scene) and the
## RPG layer (Character). Added as child of the Player by SessionState.bind_player().
## Responsibilities:
##  * XP from combat events (CombatRewardTracker)
##  * mastery techniques -> combo tree unlocks
##  * resolved character stats -> player (max health, armor, outgoing hit modifier)
##  * class runtime: resource (rage, mana, focus), skills on Q/E/R/F, buffs
##  * talents: stat sources (Character) and combat effects (ItemEffectRunner)
## All connections to the long-lived Character are tracked and removed in
## unbind(), so reloading a scene never leaves duplicate registrations behind.

signal message(text: String)
## An item went into the character's inventory from the world (loot feed).
signal item_received(item_id: StringName, quantity: int)

var player: Player
var character: Character
var rewards: CombatRewardTracker
var stat_modifier := CharacterStatModifier.new()
## Combat-time state of the active class (resource, skills, cooldowns, buffs).
var class_runtime := ClassRuntime.new()
## Runtime pool of the active class.s resource (null if the class has none).
var resource_pool: ClassResourcePool:
	get: return class_runtime.pool
## Special item and set effects of the active loadout.
var effects := ItemEffectRunner.new()
## Rolls status chances of weapon hits (Bleed / Chill Chance stats); tests may seed it.
var rng := RandomNumberGenerator.new()
## Weapon family waiting to be applied (combat must be idle to switch).
var _pending_weapon: WeaponFamily

var _connections: Array[Array] = []   # [Signal, Callable]
var _installed_modifiers: Array[AttackModifier] = []
var _base_poise: float = -1.0
## Armor XP from defense: attack instances already rewarded, XP per enemy so far.
var _defended: Dictionary = {}
var _defense_xp: Dictionary = {}


func bind(target_player: Player, target_character: Character) -> void:
	unbind()
	_base_poise = -1.0
	_defended.clear()
	_defense_xp.clear()
	player = target_player
	character = target_character
	rewards = CombatRewardTracker.new(character, character.database.rules)
	rewards.attach(player.combat)
	if not player.combat.modifiers.has(stat_modifier):
		player.combat.modifiers.append(stat_modifier)
	_track(character.mastery.leveled_up, _on_mastery_leveled_up)
	_track(character.mastery.unlocked, _on_mastery_unlocked)
	_track(character.mastery.path_unlocked, _on_path_unlocked)
	_track(character.stats_changed, apply_stats)
	_track(character.classes.active_class_changed, _on_active_class_changed)
	_track(character.classes.leveled_up, _on_class_leveled_up)
	_track(character.classes.class_unlocked, _on_class_unlocked)
	_track(player.combat.hit_landed, _on_player_hit_landed)
	_track(player.hurtbox.hit_received, class_runtime.on_hit_taken)
	_track(character.builds.changed, _on_build_changed)
	_track(character.equipment.changed, sync_weapon)
	_track(character.equipment.changed, rebuild_effects)
	_track(player.combat.hit_landed, effects.on_hit_landed)
	_track(effects.hit_dispatched, _on_hit_dispatched)
	_track(effects.hit_dispatched, class_runtime.on_hit_dispatched)
	_track(class_runtime.cast_failed, _on_cast_failed)
	_track(class_runtime.status_consumed, _on_status_consumed)
	_track(class_runtime.skill_cast, _on_skill_cast)
	_track(character.prologue.trial_finished, _on_trial_finished)
	_track(player.health.died, _on_player_died)
	_track(player.defense.blocked, _on_defended)
	_track(player.defense.parried, _on_defended)
	effects.resource_gainer = class_runtime.gain
	effects.status_applier = apply_status
	effects.cooldown_reducer = class_runtime.reduce_cooldown
	effects.player = player
	player.ability_handler = class_runtime.try_cast
	player.consumable_handler = try_use
	class_runtime.setup(character, player, effects, apply_status)
	refresh_unlocks()
	apply_stats()
	sync_weapon()
	rebuild_effects()


func unbind() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
	if rewards != null:
		rewards.detach()
		rewards = null
	if character != null:
		class_runtime.clear_buffs()
	if player != null and is_instance_valid(player):
		player.combat.modifiers.erase(stat_modifier)
		player.ability_handler = Callable()
		player.consumable_handler = Callable()
		player.cancel_use()
		_uninstall_modifiers()


func is_bound() -> bool:
	return character != null and player != null


## Mastery level of the wielded family -> Combat Flow path gates (after load,
## level-up, weapon change). Legacy requirement unlocks are re-applied too.
func refresh_unlocks() -> void:
	player.combat.combo.unlocks.clear()
	for requirement in character.mastery.unlocked_requirements():
		player.combat.set_unlocked(requirement, true)
	var family := player.combat.weapon
	player.combat.mastery_level = character.mastery.get_level(family.id) if family != null else 1


## Pushes freshly resolved stats into the scene (never additive).
func apply_stats() -> void:
	var stats := character.get_stats()
	stat_modifier.stats = stats
	effects.stats = stats
	player.health.set_max_health(stats.get(Stats.MAX_HEALTH, 100.0))
	var armor := maxf(0.0, stats.get(Stats.ARMOR, 0.0))
	player.incoming_damage_multiplier = Stats.ARMOR_CONSTANT / (Stats.ARMOR_CONSTANT + armor)
	player.incoming_damage_multiplier *= 1.0 - clampf(stats.get(Stats.DAMAGE_REDUCTION, 0.0), 0.0, 75.0) / 100.0
	# walking only, never the dash: Movement Speed % and the armour burden (after Iron Discipline)
	player.move_speed_multiplier = maxf(0.1, (1.0 + stats.get(Stats.MOVE_SPEED, 0.0) / 100.0) * (1.0 - ArmorMasteryService.move_penalty(character) / 100.0))
	player.combat.recovery_multiplier = (1.0 + ArmorMasteryService.recovery_penalty(character) / 100.0) \
		/ (1.0 + maxf(0.0, stats.get(Stats.ATTACK_RECOVERY_SPEED, 0.0)) / 100.0)
	player.physical_damage_multiplier = 1.0 - clampf(stats.get(Stats.PHYSICAL_RESISTANCE, 0.0), 0.0, 75.0) / 100.0
	player.magic_damage_multiplier = 1.0 - clampf(stats.get(Stats.MAGIC_RESISTANCE, 0.0), 0.0, 75.0) / 100.0
	player.defense.block_efficiency = clampf(stats.get(Stats.BLOCK_EFFICIENCY, 0.0), 0.0, 90.0) / 100.0
	if _base_poise < 0.0:
		_base_poise = player.health.max_poise
	player.health.max_poise = _base_poise * (1.0 + maxf(0.0, stats.get(Stats.POISE, 0.0)) / 100.0)
	var statuses := StatusComponent.of(player)
	if statuses != null:
		statuses.general_resistance = clampf(stats.get(Stats.STATUS_RESISTANCE, 0.0), 0.0, 100.0) / 100.0
	var rules := character.database.rules
	player.combat.attack_speed = clampf(1.0 + stats.get(Stats.ATTACK_SPEED, 0.0) / 100.0,
			rules.attack_speed_min, rules.attack_speed_max)
	if class_runtime.character != null:
		class_runtime.refresh_stats()
	_refresh_weapon_damage()


## Re-collects item/set effects from the active loadout and swaps the combo
## modifiers on the player (never adds twice, never leaves stale ones).
func rebuild_effects() -> void:
	_uninstall_modifiers()
	effects.rebuild(character, TalentService.effect_entries(character, character.classes.active_class_id))
	for modifier in effects.attack_modifiers:
		player.combat.modifiers.append(modifier)
		_installed_modifiers.append(modifier)


func _uninstall_modifiers() -> void:
	for modifier in _installed_modifiers:
		player.combat.modifiers.erase(modifier)
	_installed_modifiers.clear()


## The combat weapon follows the active main-hand item (fallback: rules).
func sync_weapon() -> void:
	var off_hand := character.equipment.get_item(EquipSlot.Slot.OFF_HAND)
	var off_def := character.database.get_item(off_hand.definition_id) if off_hand != null else null
	player.defense.shield_profile = off_def.defense_profile if off_def != null else null
	var family_id := character.equipment.main_hand_family()
	if family_id == &"":
		family_id = character.database.rules.fallback_weapon_family
	_pending_weapon = character.database.weapons.get(family_id)
	_apply_pending_weapon()


func current_family_id() -> StringName:
	return player.combat.weapon.id if player.combat.weapon != null else &""


func debug_add_mastery_xp(amount: int) -> void:
	character.mastery.add_xp(current_family_id(), amount)


func _physics_process(delta: float) -> void:
	effects.step(delta)
	if _pending_weapon != null:
		_apply_pending_weapon()
	class_runtime.step(delta)
	ConsumableService.step(character, delta)   # potion buff and cooldown run in game time
	var pool := class_runtime.pool
	if pool != null and character.classes.in_trial():
		PrologueService.record(character, TrialObjective.Kind.RESOURCE_AT_LEAST, pool.definition.id, pool.value)


func _apply_pending_weapon() -> void:
	if _pending_weapon == null:
		return
	if player.combat.weapon == _pending_weapon or player.set_weapon_family(_pending_weapon):
		_pending_weapon = null
		refresh_unlocks()
		_refresh_weapon_damage()


## D_weapon of the main-hand item -> combat (Weapon Base Damage 1.0), recomputed from
## the instance after every equipment, quality or crafting change (never additive).
## 0 = the family reference (no weapon item, or a weapon not on the model yet).
## While a family switch waits, the running family keeps its value.
func _refresh_weapon_damage() -> void:
	if _pending_weapon != null:
		return
	var item := character.equipment.get_item(EquipSlot.Slot.MAIN_HAND)
	var definition := character.database.get_item(item.definition_id) if item != null else null
	var family := player.combat.weapon
	var wielded := definition != null and family != null and definition.weapon_family_id == family.id
	player.combat.weapon_base_damage = WeaponDamage.of(item, definition, character.database) if wielded else 0.0


func _track(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
		_connections.append([sig, callable])


func _on_player_hit_landed(hit: HitData) -> void:
	var stats := character.get_stats()
	var life: float = stats.get(Stats.LIFE_ON_HIT, 0.0)
	if life > 0.0:
		player.health.heal(life)
	_roll_status(hit, Stats.BLEED_CHANCE, character.database.rules.bleed_status_id,
			1.0 + stats.get(Stats.BLEED_DAMAGE, 0.0) / 100.0)
	_roll_status(hit, Stats.CHILL_CHANCE, character.database.rules.chill_status_id, 1.0)
	_grant_item_xp(hit)


## Evolving main-hand items learn from real fights (separate from weapon mastery).
func _grant_item_xp(hit: HitData) -> void:
	if PrologueService.rewards_blocked(character):
		return   # no evolution XP inside a trial (Class Trials 2.0 M3)
	var item := character.equipment.get_item(EquipSlot.Slot.MAIN_HAND)
	if item == null:
		return
	var definition := character.database.get_item(item.definition_id)
	var was_ready := ItemEvolution.is_ready(item, definition, character.database)
	if ItemEvolution.grant_hit_xp(character, hit) > 0 and not was_ready \
			and ItemEvolution.is_ready(item, definition, character.database):
		message.emit("%s is ready to evolve (Resonance Forge)" % definition.display_name)


func _on_mastery_leveled_up(family_id: StringName, level: int) -> void:
	refresh_unlocks()
	message.emit("%s mastery reached level %d" % [_family_name(family_id), level])


func _on_mastery_unlocked(family_id: StringName, unlock: MasteryUnlock) -> void:
	refresh_unlocks()
	var kind := "Technique" if unlock.is_technique() else "Milestone"
	message.emit("%s unlocked: %s (%s)" % [kind, unlock.display_name, _family_name(family_id)])


## A mastery level unlocked a real combo path (Weapon Mastery 1.4).
func _on_path_unlocked(family_id: StringName, path: ComboPathDefinition) -> void:
	refresh_unlocks()
	message.emit("Combo unlocked: %s (%s, %s)" % [path.display_name, path.input_label(), _family_name(family_id)])


func _on_active_class_changed(class_id: StringName) -> void:
	player.combat.cancel(&"class_change")   # a class change ends the running combo and its buffer
	class_runtime.rebuild()
	message.emit("Class changed: %s" % _class_name(class_id))


func _on_class_leveled_up(class_id: StringName, level: int) -> void:
	message.emit("%s reached level %d" % [_class_name(class_id), level])


func _on_class_unlocked(class_id: StringName) -> void:
	message.emit("Class unlocked: %s" % _class_name(class_id))


func _family_name(family_id: StringName) -> String:
	var family: WeaponFamily = character.database.weapons.get(family_id)
	return family.display_name if family != null else String(family_id)


func _class_name(class_id: StringName) -> String:
	var definition := character.database.get_class_def(class_id)
	return definition.display_name if definition != null else String(class_id)


func _exit_tree() -> void:
	unbind()


## Applies status `status_id` to `target`, credited to the player: damage ticks
## are dispatched like any other hit of the character (source STATUS).
func apply_status(target: Node, status_id: StringName, power: float = 1.0, stacks: int = 1) -> bool:
	var definition: StatusEffectDefinition = character.database.statuses.get(status_id)
	var component := StatusComponent.of(target)
	if definition == null or component == null:
		return false
	if not component.apply(definition, power, player, effects.dispatch_hit, stacks):
		return false
	PrologueService.record(character, TrialObjective.Kind.STATUS_APPLIED, status_id, 1.0)
	return true


func _roll_status(hit: HitData, chance_stat: StringName, status_id: StringName, power: float) -> void:
	var chance: float = character.get_stat(chance_stat)
	if chance > 0.0 and status_id != &"" and rng.randf() * 100.0 < chance:
		apply_status(hit.target, status_id, power)


## Every hit the character caused (weapon, skill, status tick, triggered).
## Weapon kills are rewarded by CombatRewardTracker; kills by skills and
## statuses are credited here, once per target.
func _on_hit_dispatched(hit: HitData) -> void:
	if not hit.is_direct() and hit.killed and rewards != null:
		rewards.reward_kill(hit)
	if hit.source == HitData.Source.SKILL:
		PrologueService.record(character, TrialObjective.Kind.SKILL_HITS, hit.skill_id, 1.0)
	if hit.killed and hit.target != null and is_instance_valid(hit.target) and not hit.target.is_in_group(&"training_target"):
		var variant: StringName = (hit.target as Enemy).config.id if hit.target is Enemy else &""
		PrologueService.record(character, TrialObjective.Kind.KILLS, variant, 1.0)   # variant id: trial bosses (M3)
	if hit.broke_poise and hit.target is Enemy and is_instance_valid(hit.target):
		PrologueService.record(character, TrialObjective.Kind.POISE_BREAKS, (hit.target as Enemy).config.id, 1.0)
	for tag in hit.tags:
		if String(tag).begins_with("rupture_"):
			PrologueService.record(character, TrialObjective.Kind.STATUS_CONSUMED, StringName(String(tag).trim_prefix("rupture_")), 1.0)


func _on_status_consumed(status_id: StringName, stacks: int) -> void:
	PrologueService.record(character, TrialObjective.Kind.STATUS_CONSUMED, status_id, float(stacks))


func _on_skill_cast(skill_id: StringName, _slot: int) -> void:
	PrologueService.record(character, TrialObjective.Kind.SKILL_CASTS, skill_id, 1.0)


## Falling in a trial ends it without a trace; it can be restarted right away.
func _on_player_died() -> void:
	ConsumableService.end_buff(character)   # death ends the potion buff
	if character.classes.in_trial():
		PrologueService.end_trial(character, false)


func _on_trial_finished(trial_id: StringName, completed: bool) -> void:
	var trial: TrialDefinition = character.database.trials.get(trial_id)
	var name := trial.display_name if trial != null else String(trial_id)
	message.emit("%s walked. The echo fades; you are a Basic Adventurer again." % name if completed else "%s fades. You can walk it again at any time." % name)


## Talents, slots or mods changed: talent effects may differ (stats re-resolve
## through Character.stats_changed on their own).
func _on_build_changed(class_id: StringName) -> void:
	if class_id == character.classes.active_class_id:
		rebuild_effects()


func _on_cast_failed(_skill_id: StringName, reason: String) -> void:
	message.emit(reason)


# --- quick use: Hearth Flask (1) and the slotted potion (2) ------------------------

## Player.consumable_handler: starts the drink when the rules allow it (refusals
## are shown as a message). The effect lands only when the drink completes.
func try_use(kind: int) -> bool:
	var rules := character.database.rules
	var error := ConsumableService.flask_error(character) if kind == 0 else ConsumableService.potion_error(character)
	if error != "":
		message.emit(error)
		return false
	if kind == 0:
		player.begin_use(rules.flask_drink_time, rules.drink_move_multiplier, _on_flask_done)
	else:
		player.begin_use(rules.potion_drink_time, rules.drink_move_multiplier, _on_potion_done)
	return true


func _on_flask_done() -> void:
	var share := ConsumableService.complete_flask(character)
	if share > 0.0 and not player.health.is_dead():
		player.health.heal(player.health.max_health * share)


func _on_potion_done() -> void:
	var error := ConsumableService.complete_potion(character)
	if error != "":
		message.emit(error)


# --- Armor Mastery XP ---------------------------------------------------------------

## A blocked or parried enemy attack is a valid combat event (never a hit taken):
## once per attack instance, capped per enemy so one weak enemy cannot be farmed.
func _on_defended(hit: HitData) -> void:
	var attacker := hit.attacker
	if attacker == null or not is_instance_valid(attacker) or attacker.is_in_group(&"training_target") or attacker.is_in_group(&"player") \
			or PrologueService.rewards_blocked(character):   # no trial farming (Class Trials 2.0 M3)
		return
	var key := "%d:%d" % [attacker.get_instance_id(), hit.attack_instance_id]
	if _defended.has(key):
		return
	_defended[key] = true
	var armor_rules := ArmorMasteryService.rules(character)
	var given: float = _defense_xp.get(attacker.get_instance_id(), 0.0)
	var amount := minf(armor_rules.xp_per_defense, armor_rules.defense_xp_cap_per_enemy - given)
	if amount <= 0.0:
		return
	_defense_xp[attacker.get_instance_id()] = given + amount
	ArmorMasteryService.add_xp(character, amount)
