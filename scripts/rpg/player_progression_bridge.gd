class_name PlayerProgressionBridge
extends Node
## The single connection point between the combat layer (Player scene) and the
## RPG layer (Character). Added as child of the Player by SessionState.bind_player().
## Responsibilities:
##  * XP from combat events (CombatRewardTracker)
##  * mastery techniques -> combo tree unlocks
##  * resolved character stats -> player (max health, armor, outgoing hit modifier)
##  * runtime class resource (rage ...)
## All connections to the long-lived Character are tracked and removed in
## unbind(), so reloading a scene never leaves duplicate registrations behind.

signal message(text: String)

var player: Player
var character: Character
var rewards: CombatRewardTracker
var stat_modifier := CharacterStatModifier.new()
## Runtime pool of the active class's resource (null if the class has none).
var resource_pool: ClassResourcePool

var _connections: Array[Array] = []   # [Signal, Callable]


func bind(target_player: Player, target_character: Character) -> void:
	unbind()
	player = target_player
	character = target_character
	rewards = CombatRewardTracker.new(character, character.database.rules)
	rewards.attach(player.combat)
	if not player.combat.modifiers.has(stat_modifier):
		player.combat.modifiers.append(stat_modifier)
	_track(character.mastery.leveled_up, _on_mastery_leveled_up)
	_track(character.mastery.unlocked, _on_mastery_unlocked)
	_track(character.stats_changed, apply_stats)
	_track(character.classes.active_class_changed, _on_active_class_changed)
	_track(character.classes.leveled_up, _on_class_leveled_up)
	_track(character.classes.class_unlocked, _on_class_unlocked)
	_track(player.combat.hit_landed, _on_player_hit_landed)
	_track(player.hurtbox.hit_received, _on_player_hit_taken)
	refresh_unlocks()
	apply_stats()
	_rebuild_resource_pool()


func unbind() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
	if rewards != null:
		rewards.detach()
		rewards = null
	if player != null and is_instance_valid(player):
		player.combat.modifiers.erase(stat_modifier)


func is_bound() -> bool:
	return character != null and player != null


## Re-applies all mastery techniques to the combo tree (after load, level-up ...).
func refresh_unlocks() -> void:
	player.combat.combo.unlocks.clear()
	for requirement in character.mastery.unlocked_requirements():
		player.combat.set_unlocked(requirement, true)


## Pushes freshly resolved stats into the scene (never additive).
func apply_stats() -> void:
	var stats := character.get_stats()
	stat_modifier.stats = stats
	player.health.set_max_health(stats.get(Stats.MAX_HEALTH, 100.0))
	var armor := maxf(0.0, stats.get(Stats.ARMOR, 0.0))
	player.incoming_damage_multiplier = Stats.ARMOR_CONSTANT / (Stats.ARMOR_CONSTANT + armor)


func current_family_id() -> StringName:
	return player.combat.weapon.id if player.combat.weapon != null else &""


func debug_add_mastery_xp(amount: int) -> void:
	character.mastery.add_xp(current_family_id(), amount)


func _physics_process(delta: float) -> void:
	if resource_pool != null:
		resource_pool.step(delta)


func _rebuild_resource_pool() -> void:
	var definition := character.classes.get_active_definition()
	resource_pool = ClassResourcePool.new(definition.resource) if definition != null and definition.resource != null else null


func _track(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
		_connections.append([sig, callable])


func _on_player_hit_landed(_hit: HitData) -> void:
	if resource_pool != null:
		resource_pool.gain(resource_pool.definition.gain_per_hit_dealt)


func _on_player_hit_taken(_hit: HitData) -> void:
	if resource_pool != null:
		resource_pool.gain(resource_pool.definition.gain_per_hit_taken)


func _on_mastery_leveled_up(family_id: StringName, level: int) -> void:
	message.emit("%s mastery reached level %d" % [_family_name(family_id), level])


func _on_mastery_unlocked(family_id: StringName, unlock: MasteryUnlock) -> void:
	refresh_unlocks()
	var kind := "Technique" if unlock.is_technique() else "Milestone"
	message.emit("%s unlocked: %s (%s)" % [kind, unlock.display_name, _family_name(family_id)])


func _on_active_class_changed(class_id: StringName) -> void:
	_rebuild_resource_pool()
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
