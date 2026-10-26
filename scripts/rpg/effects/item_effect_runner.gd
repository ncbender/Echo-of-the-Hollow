class_name ItemEffectRunner
extends RefCounted
## Runtime host for special item and set effects of ONE character.
##  * rebuild() collects the effects of the active loadout + reached set bonuses
##    (always from scratch: nothing stays active after unequipping)
##  * exactly one connection to CombatComponent.hit_landed (made by the bridge)
##    dispatches each accepted player hit once to every active event effect
##  * per-source runtime state (cooldowns, dedupe) lives here, never in the
##    shared ItemEffect resources
##  * every hit source goes through dispatch_hit(): weapon hits (hit_landed),
##    skill hits, status ticks and opt-in triggered hits. Hits are queued, so an
##    effect never runs inside another effect, and hits deeper than
##    MAX_TRIGGER_DEPTH are never dispatched (no endless trigger chains)
##  * hit_dispatched: the one event stream class mechanics, talents, trials and
##    rewards listen to (direct vs. triggered via HitData.source)

signal hit_dispatched(hit: HitData)

## Hits deeper than this are never dispatched (0 = player action, 1 = caused by a hit).
const MAX_TRIGGER_DEPTH := 1

## One active effect: {"effect": ItemEffect, "key": String}.
var active: Array[Dictionary] = []
var attack_modifiers: Array[AttackModifier] = []
## Free-form per-source state (effects read/write their own key only).
var state: Dictionary = {}
var time: float = 0.0
var player: Player
## Resolved character stats (set by the bridge; e.g. shock damage for discharges).
var stats: Dictionary = {}
## Short-lived combat marks: mark id -> {target instance id: expires at (runner time)}.
var marks: Dictionary = {}

## Class hooks for talent effects (set by the bridge; no-ops when unset).
var resource_gainer: Callable
var status_applier: Callable
var cooldown_reducer: Callable
var rng := RandomNumberGenerator.new()

var _dispatching: bool = false
var _queue: Array[HitData] = []
var _seen: Dictionary = {}   # hits of the running dispatch cycle


## `extra`: further effect sources of the character (talents, class mechanics):
## [{"effect": ItemEffect, "key": String, "power": float}].
func rebuild(character: Character, extra: Array = []) -> void:
	active.clear()
	attack_modifiers.clear()
	for item in character.equipment.equipped_items():
		var definition := character.database.get_item(item.definition_id)
		if definition == null:
			continue
		# definition effects + essences, resonances, runes, evolution (ItemStats)
		for entry in ItemStats.effects(item, definition, character.database):
			_add(entry.effect, entry.key, entry.power)
	var counts := character.equipped_set_counts()
	for set_id: StringName in counts:
		var set_def: SetDefinition = character.database.sets.get(set_id)
		if set_def == null:
			continue
		for bonus in set_def.active_bonuses(counts[set_id]):
			for index in bonus.effects.size():
				_add(bonus.effects[index], "set:%s:%d:%d" % [set_id, bonus.pieces_required, index])
	for entry: Dictionary in extra:
		_add(entry.effect, entry.key, entry.get("power", 1.0))
	# Drop state of sources that are no longer active.
	var keys := {}
	for entry in active:
		keys[entry.key] = true
	for key: String in state.keys():
		if not keys.has(key):
			state.erase(key)


func has_effect(effect_id: StringName) -> bool:
	for entry in active:
		if entry.effect.effect_id == effect_id:
			return true
	return false


func step(delta: float) -> void:
	time += delta


## Weapon hits of the player (CombatComponent.hit_landed).
func on_hit_landed(hit: HitData) -> void:
	dispatch_hit(hit)


## Single entry point for every accepted hit the character caused. Queued:
## hits produced while effects run are handled after them (never nested).
func dispatch_hit(hit: HitData) -> void:
	if hit == null or hit.depth > MAX_TRIGGER_DEPTH or _seen.has(hit):
		return   # too deep, or this very hit was already dispatched (re-entry)
	hit.snapshot_target()
	_queue.append(hit)
	_seen[hit] = true
	if _dispatching:
		return
	_dispatching = true
	while not _queue.is_empty():
		var current: HitData = _queue.pop_front()
		var bit := 1 << current.source
		for entry in active.duplicate():
			if entry.effect.hit_sources & bit:
				entry.effect.on_hit_landed(current, self, entry.key)
		hit_dispatched.emit(current)
	_dispatching = false
	_seen.clear()


func source_state(key: String) -> Dictionary:
	if not state.has(key):
		state[key] = {}
	return state[key]


## State shared by all sources of one effect id (e.g. two items with the same
## essence still trigger once per swing).
func shared_state(effect_id: StringName) -> Dictionary:
	return source_state("shared:%s" % effect_id)


## Marks `target` with `mark_id` for `duration` seconds (refreshes, never stacks).
func mark(target: Node, mark_id: StringName, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not marks.has(mark_id):
		marks[mark_id] = {}
	marks[mark_id][target.get_instance_id()] = time + duration


func has_mark(target: Node, mark_id: StringName) -> bool:
	if target == null or not is_instance_valid(target) or not marks.has(mark_id):
		return false
	return marks[mark_id].get(target.get_instance_id(), -1.0) > time


## Removes the mark and returns whether it was active (one use per mark).
func consume_mark(target: Node, mark_id: StringName) -> bool:
	var active := has_mark(target, mark_id)
	if marks.has(mark_id) and target != null and is_instance_valid(target):
		marks[mark_id].erase(target.get_instance_id())
	return active


## Strength of a source (1.0, or more for essences attuned to the item material).
func power(key: String) -> float:
	return float(source_state(key).get("power", 1.0))


## Hurtboxes of other teams within `radius` of `position` (for area effects).
func query_hurtboxes(position: Vector2, radius: float) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	if player == null or not player.is_inside_tree():
		return result
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, position)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for found in player.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := found.collider as Hurtbox
		if hurtbox != null and hurtbox.team != player.hurtbox.team:
			result.append(hurtbox)
	return result


## Adds a purely visual node to the world at `position`.
func spawn_fx(node: Node2D, position: Vector2) -> void:
	if player == null or player.get_parent() == null:
		node.free()
		return
	node.position = position
	player.get_parent().add_child(node)


func _add(effect: ItemEffect, key: String, power: float = 1.0) -> void:
	if effect == null:
		return
	active.append({"effect": effect, "key": key})
	source_state(key)["power"] = power
	attack_modifiers.append_array(effect.get_attack_modifiers_for(self, key))


## Class resource for talent effects (rage on kill ...).
func gain_resource(amount: float) -> void:
	if resource_gainer.is_valid() and amount > 0.0:
		resource_gainer.call(amount)


## Applies a status credited to the character (damage ticks come back here).
func apply_status(target: Node, status_id: StringName, power: float = 1.0, stacks: int = 1) -> bool:
	return status_applier.is_valid() and status_applier.call(target, status_id, power, stacks)


## Lowers skill cooldowns (&"" = all skills).
func reduce_cooldown(skill_id: StringName, seconds: float) -> void:
	if cooldown_reducer.is_valid():
		cooldown_reducer.call(skill_id, seconds)
