class_name InputBuffer
extends RefCounted
## Single-slot input buffer: remembers the most recent action for `window` seconds.
## A newer push replaces the older entry (the latest intent wins).

var window: float
var _action: StringName = &""
var _age: float = 0.0


func _init(buffer_window: float = 0.12) -> void:
	window = buffer_window


func push(action: StringName) -> void:
	_action = action
	_age = 0.0


## Ages the buffered entry; call once per tick before pushing that tick's inputs.
func step(delta: float) -> void:
	if _action == &"":
		return
	_age += delta
	if _age > window + 0.0001:
		clear()


func peek() -> StringName:
	return _action


func has(action: StringName) -> bool:
	return _action == action


func clear() -> void:
	_action = &""
	_age = 0.0
