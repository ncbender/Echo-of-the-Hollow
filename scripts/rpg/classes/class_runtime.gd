class_name ClassRuntime
extends RefCounted
## Combat-time state of the ACTIVE class (not saved, rebuilt on bind/class
## change): class resource pool, skill cooldowns, timed buffs, empowered
## follow-ups and Combat Pressure. Created and driven by the
## PlayerProgressionBridge (the only Combat<->RPG link):
##  * try_cast(slot) is the Player's ability_handler (Q/E/R/F)
##  * on_hit_dispatched receives every hit of the character (ItemEffectRunner)
##  * writes `class_state` for talent effects (resource ratio, recent casts)
## Generic: no class or skill is special-cased here; behaviour is data.

signal skill_cast(skill_id: StringName, slot: int)
signal cast_failed(skill_id: StringName, reason: String)
## A skill consumed a status on a target (mark detonation, execution ...).
signal status_consumed(status_id: StringName, stacks: int)

var character: Character
var player: Player
var effects: ItemEffectRunner
## Applies statuses credited to the character (bridge.apply_status).
var status_applier: Callable
var pool: ClassResourcePool
var rng := RandomNumberGenerator.new()
var time: float = 0.0
## skill id -> runner time when ready again
var cooldowns: Dictionary = {}
## buff key -> expiry time; stat modifiers live on Character runtime sources
var buffs: Dictionary = {}
## tag -> damage multiplier for the next cast with that tag (Rune Sigil ...)
var empowered: Dictionary = {}
var pressure: int = 0
var _pressure_left: float = 0.0
var _casts: int = 0
## Casts whose movement is still running (kept alive until they arrive).
var _held_casts: Array[SkillCast] = []
var _class_id: StringName


func setup(target_character: Character, target_player: Player, runner: ItemEffectRunner, applier: Callable) -> void:
	character = target_character
	player = target_player
	effects = runner
	status_applier = applier
	rebuild()


## Recreates the pool for the active class. Cooldowns and buffs reset on a class change.
func rebuild() -> void:
	var class_id := character.classes.active_class_id
	if class_id != _class_id:
		clear_buffs()
		cooldowns.clear()
		empowered.clear()
		pressure = 0
		_class_id = class_id
		var definition := character.classes.get_active_definition()
		pool = ClassResourcePool.new(definition.resource) if definition != null and definition.resource != null else null
	refresh_stats()


## Stats that shape the runtime (max resource bonus).
func refresh_stats() -> void:
	if pool != null:
		pool.set_max_bonus(character.get_stat(Stats.MAX_RESOURCE))
	_write_state()


func clear_buffs() -> void:
	for key: StringName in buffs.keys():
		character.clear_runtime_modifiers(key)
	buffs.clear()
	if pool != null:
		pool.decay_enabled = true


func step(delta: float) -> void:
	time += delta
	# Regeneration/decay is time based (delta) and runs in and out of combat, but
	# not while the player is dead (respawn delay); a paused tree runs no ticks.
	if pool != null and not (player != null and is_instance_valid(player) and player.health.is_dead()):
		pool.step(delta)
	for key: StringName in buffs.keys():
		if time >= buffs[key]:
			buffs.erase(key)
			character.clear_runtime_modifiers(key)
			if key == &"buff:no_decay" and pool != null:
				pool.decay_enabled = true
	if pressure > 0:
		_pressure_left -= delta
		if _pressure_left <= 0.0:
			pressure = 0
	_write_state()


# --- Skills -------------------------------------------------------------------

func skill_in_slot(slot: int) -> SkillDefinition:
	var build := character.builds.get_build()
	if slot < 0 or slot >= build.slots.size():
		return null
	return character.database.skills.get(build.slots[slot])


func params_for(skill: SkillDefinition) -> SkillParams:
	var cost_factor := 1.0 - clampf(character.get_stat(Stats.RESOURCE_EFFICIENCY), 0.0, 50.0) / 100.0
	var cooldown_factor := 1.0 - clampf(character.get_stat(Stats.COOLDOWN_REDUCTION), 0.0, 50.0) / 100.0
	return SkillParams.resolve(skill, SkillBook.cast_mods(character, character.classes.active_class_id, skill.id),
			cost_factor, cooldown_factor)


func cooldown_left(skill_id: StringName) -> float:
	return maxf(0.0, cooldowns.get(skill_id, 0.0) - time)


## "" if the skill in `slot` can be cast right now, otherwise the reason.
func cast_error(slot: int) -> String:
	var skill := skill_in_slot(slot)
	if skill == null:
		return "No skill in this slot."
	if not SkillBook.is_skill_available(character, character.classes.active_class_id, skill.id):
		return "%s is not unlocked." % skill.display_name
	if cooldown_left(skill.id) > 0.0:
		return "%s is on cooldown." % skill.display_name
	var params := params_for(skill)
	if params.cost > 0.0 and (pool == null or pool.value + 0.0001 < params.cost):
		return "Not enough %s." % (pool.definition.display_name if pool != null else "resource")
	if player == null or not player.can_start_skill():
		return "Busy."
	for action in params.actions:
		var action_error := action.cast_error(self, params)
		if action_error != "":
			return action_error   # e.g. no target: nothing is spent
	return ""


## Player.ability_handler: casts the skill in `slot`. Returns true when the input
## was handled (cast, or refused with a message); false keeps it buffered (busy).
func try_cast(slot: int) -> bool:
	var error := cast_error(slot)
	var skill := skill_in_slot(slot)
	if error == "Busy.":
		return false
	if error != "":
		cast_failed.emit(skill.id if skill != null else &"", error)
		return true
	var params := params_for(skill)
	if params.cost > 0.0 and not pool.spend(params.cost):
		return false
	_casts += 1
	cooldowns[skill.id] = time + params.cooldown
	player.begin_skill(skill.cast_lock, skill.cast_move_multiplier)
	var cast := SkillCast.new()
	cast.runtime = self
	cast.skill = skill
	cast.params = params
	cast.cast_id = _casts
	cast.origin = player.global_position
	cast.direction = player.aim_direction
	for tag: StringName in empowered.keys():
		if params.has_tag(tag):
			cast.damage_scale *= empowered[tag]
			empowered.erase(tag)
	var fx := skill.fx
	if fx != null and fx.cast_style >= 0:
		CombatFx.spawn(CombatFx.world_of(player), player.global_position + player.aim_direction * 6.0, fx.cast_style,
				fx.cast_color, fx.cast_radius, 0.35, player.aim_direction)
	cast.run_actions(params.actions)
	var recent: Dictionary = effects.shared_state(&"class").get("recent_casts", {})
	for tag in params.tags:
		recent[tag] = time
	recent[skill.id] = time
	effects.shared_state(&"class")["recent_casts"] = recent
	skill_cast.emit(skill.id, slot)
	return true


## Lowers the remaining cooldown of one skill (&"" = all skills).
func reduce_cooldown(skill_id: StringName, seconds: float) -> void:
	for id: StringName in cooldowns.keys():
		if skill_id == &"" or id == skill_id:
			cooldowns[id] = maxf(time, cooldowns[id] - seconds)


# --- Buffs, resource, statuses -----------------------------------------------

## Timed stat buff (re-applying refreshes, never stacks: one source per key).
func add_buff(key: StringName, duration: float, modifiers: Array[StatModifier]) -> void:
	character.set_runtime_modifiers(key, modifiers)
	buffs[key] = time + duration


func buff_left(key: StringName) -> float:
	return maxf(0.0, buffs.get(key, 0.0) - time)


## Pauses resource decay for `duration` seconds (berserk states).
func pause_decay(duration: float) -> void:
	if pool == null:
		return
	pool.decay_enabled = false
	var empty: Array[StatModifier] = []
	add_buff(&"buff:no_decay", duration, empty)


func empower_next(tag: StringName, multiplier: float) -> void:
	empowered[tag] = maxf(empowered.get(tag, 1.0), multiplier)


func gain(amount: float) -> void:
	if pool != null and amount > 0.0:
		var pressure_factor := 1.0 + pressure * pool.definition.pressure_gain_bonus
		pool.gain(amount * pressure_factor * (1.0 + character.get_stat(Stats.RESOURCE_GAIN) / 100.0))


func apply_status(target: Node, status_id: StringName, power: float = 1.0, stacks: int = 1) -> bool:
	return status_applier.is_valid() and status_applier.call(target, status_id, power, stacks)


func note_consumed(status_id: StringName, stacks: int, _target: Node) -> void:
	status_consumed.emit(status_id, stacks)


## Every hit the character caused (ItemEffectRunner.hit_dispatched).
func on_hit_dispatched(hit: HitData) -> void:
	if pool == null:
		return
	var definition := pool.definition
	if hit.is_direct():
		var amount := definition.gain_per_hit_dealt
		for tag: StringName in definition.gain_per_tag:
			if tag in hit.tags:
				amount += definition.gain_per_tag[tag]
		gain(amount)   # pressure of the previous hits speeds this gain up
		if definition.pressure_max_stacks > 0:
			pressure = mini(definition.pressure_max_stacks, pressure + 1)
			_pressure_left = definition.pressure_window
	if hit.broke_poise:
		gain(definition.gain_per_poise_break)
	if hit.killed:
		gain(definition.gain_per_kill)


func on_hit_taken(hit: HitData) -> void:
	if &"parried" in hit.tags:
		return   # a parried hit is no hit taken (no pressure loss, no rage)
	pressure = 0
	if pool != null:
		gain(pool.definition.gain_per_hit_taken)


## Shared state for talent effects (HitCondition): resource ratio, pressure.
func _write_state() -> void:
	if effects == null:
		return
	var state := effects.shared_state(&"class")
	state["resource_ratio"] = pool.ratio() if pool != null else 0.0
	state["pressure"] = pressure
	state["time"] = time


func hold_cast(cast: SkillCast) -> void:
	if not cast in _held_casts:
		_held_casts.append(cast)


func release_cast(cast: SkillCast) -> void:
	_held_casts.erase(cast)
