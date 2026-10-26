class_name ClassResourcePool
extends RefCounted
## Runtime value of a class resource (rage, mana ...). Generic: behaviour comes
## from ClassResourceDefinition. Not saved; recreated on class change.

signal changed(value: float, max_value: float)

var definition: ClassResourceDefinition
var value: float = 0.0
## Flat bonus on the maximum (Max Class Resource stat).
var max_bonus: float = 0.0
## While false, decay (negative regen) is paused (e.g. a berserk state).
var decay_enabled: bool = true
var _since_gain: float = 0.0


func _init(resource_definition: ClassResourceDefinition) -> void:
	definition = resource_definition
	value = clampf(definition.start_value, 0.0, definition.max_value)


func max_value() -> float:
	return maxf(1.0, definition.max_value + max_bonus)


func set_max_bonus(bonus: float) -> void:
	max_bonus = bonus
	_set_value(value)


func gain(amount: float) -> void:
	if amount <= 0.0:
		return
	_since_gain = 0.0
	_set_value(value + amount)


## Spends `amount` if available. Returns true on success.
func spend(amount: float) -> bool:
	if amount < 0.0 or value + 0.0001 < amount:
		return false
	_set_value(value - amount)
	return true


func step(delta: float) -> void:
	_since_gain += delta
	var rate := definition.regen_per_second
	if rate < 0.0 and not decay_enabled:
		return
	if rate != 0.0 and _since_gain >= definition.regen_delay:
		_set_value(value + rate * delta)


func ratio() -> float:
	return value / max_value()


func _set_value(new_value: float) -> void:
	var clamped := clampf(new_value, 0.0, max_value())
	if not is_equal_approx(clamped, value):
		value = clamped
		changed.emit(value, max_value())
