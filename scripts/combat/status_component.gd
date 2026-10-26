class_name StatusComponent
extends Node2D
## Active statuses of one combat entity (enemy, training dummy). Generic:
## behaviour comes from StatusEffectDefinition data.
##  * application rules (refresh / stack) and resistances live here, once
##  * damage over time is delivered as HitData (source STATUS, depth 1) through
##    the entity's own Hurtbox - same damage numbers, health and death handling
##    as every other hit; the applier is credited through `on_damage`
##  * slows only affect the owner's locomotion (move_multiplier), capped by
##    `max_slow_cap` (bosses); nothing touches global time or dash timings
## Draws small status pips above the entity (purely visual).

signal status_applied(status_id: StringName, stacks: int)
signal status_removed(status_id: StringName)

## Status id -> resistance 0..1 (1 = immune): shortens duration and weakens power.
var resistances: Dictionary = {}
## Largest total slow this entity accepts (EnemyConfig.max_slow, bosses lower).
var max_slow_cap: float = 0.9

var _active: Dictionary = {}   # status id -> Entry


class Entry:
	extends RefCounted
	var definition: StatusEffectDefinition
	var stacks: int = 0
	var remaining: float = 0.0
	var power: float = 0.0
	var tick_left: float = 0.0
	var source: WeakRef
	## Called with every damage tick (HitData) - credits the applier.
	var on_damage: Callable


## Finds the entity's StatusComponent, creating one when `create` is set.
static func of(entity: Node, create: bool = false) -> StatusComponent:
	if entity == null or not is_instance_valid(entity):
		return null
	var existing := entity.get_node_or_null("StatusComponent") as StatusComponent
	if existing == null and create:
		existing = StatusComponent.new()
		existing.name = "StatusComponent"
		entity.add_child(existing)
	return existing


func _ready() -> void:
	z_index = 30


## Applies `definition`. Returns false when the entity is immune or dead.
func apply(definition: StatusEffectDefinition, power: float = 1.0, source: Node = null,
		on_damage: Callable = Callable(), stacks: int = 1) -> bool:
	if definition == null or _is_dead():
		return false
	var resistance := clampf(float(resistances.get(definition.id, 0.0)), 0.0, 1.0)
	if resistance >= 1.0:
		return false
	var factor := 1.0 - resistance
	var entry: Entry = _active.get(definition.id)
	if entry == null:
		entry = Entry.new()
		entry.definition = definition
		entry.tick_left = definition.tick_interval
		_active[definition.id] = entry
	if definition.stack_rule == StatusEffectDefinition.StackRule.STACK:
		entry.stacks = mini(definition.max_stacks, entry.stacks + maxi(1, stacks))
	else:
		entry.stacks = 1
	entry.power = maxf(entry.power, power * factor)
	entry.remaining = definition.duration * factor
	if source != null:
		entry.source = weakref(source)
	if on_damage.is_valid():
		entry.on_damage = on_damage
	status_applied.emit(definition.id, entry.stacks)
	return true


func has(status_id: StringName) -> bool:
	return _active.has(status_id)


func stacks(status_id: StringName) -> int:
	var entry: Entry = _active.get(status_id)
	return entry.stacks if entry != null else 0


func remaining(status_id: StringName) -> float:
	var entry: Entry = _active.get(status_id)
	return entry.remaining if entry != null else 0.0


func power(status_id: StringName) -> float:
	var entry: Entry = _active.get(status_id)
	return entry.power if entry != null else 0.0


## Removes the status and returns how many stacks it had (0 = was not active).
func consume(status_id: StringName) -> int:
	var count := stacks(status_id)
	if _active.erase(status_id):
		status_removed.emit(status_id)
	return count


func clear() -> void:
	for status_id: StringName in _active.keys():
		consume(status_id)


func active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_active.keys())
	return result


## Locomotion factor from all slowing statuses (1 = normal speed).
func move_multiplier() -> float:
	var slow := 0.0
	for entry: Entry in _active.values():
		slow += minf(entry.definition.max_slow, entry.definition.slow_per_stack * entry.stacks)
	return 1.0 - clampf(slow, 0.0, clampf(max_slow_cap, 0.0, 0.9))


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _active.is_empty():
		return
	if _is_dead():
		clear()
		return
	for status_id: StringName in _active.keys():
		var entry: Entry = _active.get(status_id)
		if entry == null:
			continue
		var definition := entry.definition
		entry.remaining -= delta
		if definition.damage_per_second > 0.0:
			entry.tick_left -= delta
			while entry.tick_left <= 0.00001 and _active.has(status_id):
				entry.tick_left += definition.tick_interval
				_tick(entry)
		if entry.remaining <= 0.00001 and _active.has(status_id):
			consume(status_id)


func _tick(entry: Entry) -> void:
	var hurtbox := get_parent().get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox == null:
		return
	var definition := entry.definition
	var hit := HitData.new()
	hit.attacker = entry.source.get_ref() if entry.source != null else null
	hit.damage = definition.damage_per_second * definition.tick_interval * entry.stacks * entry.power
	hit.damage_type = definition.damage_type
	hit.position = hurtbox.global_position
	hit.source = HitData.Source.STATUS
	hit.depth = 1
	hit.tags.append_array([&"status", definition.id])
	if hurtbox.receive_hit(hit) and entry.on_damage.is_valid():
		entry.on_damage.call(hit)


func _is_dead() -> bool:
	var health := get_parent().get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.is_dead()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _active.is_empty():
		return
	var x := -float(_active.size() - 1) * 3.5
	for entry: Entry in _active.values():
		var center := Vector2(x, -27)
		draw_circle(center, 2.4, Color.BLACK)
		draw_circle(center, 1.8, entry.definition.color)
		for i in mini(entry.stacks - 1, 4):
			draw_rect(Rect2(center + Vector2(-2.5 + i * 1.4, -4.6), Vector2(0.9, 1.2)), entry.definition.color)
		x += 7.0
	if move_multiplier() < 0.999:
		draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, Color(0.65, 0.9, 1.0, 0.7), 1.5)
		draw_set_transform(Vector2.ZERO)
