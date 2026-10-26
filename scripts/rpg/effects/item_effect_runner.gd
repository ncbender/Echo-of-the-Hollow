class_name ItemEffectRunner
extends RefCounted
## Runtime host for special item and set effects of ONE character.
##  * rebuild() collects the effects of the active loadout + reached set bonuses
##    (always from scratch: nothing stays active after unequipping)
##  * exactly one connection to CombatComponent.hit_landed (made by the bridge)
##    dispatches each accepted player hit once to every active event effect
##  * per-source runtime state (cooldowns, dedupe) lives here, never in the
##    shared ItemEffect resources
##  * re-entrancy guard: effects never trigger effects (no recursive chains)

## One active effect: {"effect": ItemEffect, "key": String}.
var active: Array[Dictionary] = []
var attack_modifiers: Array[AttackModifier] = []
## Free-form per-source state (effects read/write their own key only).
var state: Dictionary = {}
var time: float = 0.0
var player: Player

var _dispatching: bool = false


func rebuild(character: Character) -> void:
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


func on_hit_landed(hit: HitData) -> void:
	if _dispatching:
		return   # an effect caused this hit: never chain effects
	_dispatching = true
	for entry in active:
		entry.effect.on_hit_landed(hit, self, entry.key)
	_dispatching = false


func source_state(key: String) -> Dictionary:
	if not state.has(key):
		state[key] = {}
	return state[key]


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
