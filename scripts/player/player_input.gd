class_name PlayerInput
extends Node
## Captures device input. Clicks are collected from input events so every
## physical press counts exactly once, independent of frame timing.

## Cursor closer to the character than this (px) gives no aim; the character keeps
## its last valid facing (attacks and dash).
const AIM_DEADZONE := 4.0

var _pending := InputFrame.new()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"attack_light"):
		_pending.light_pressed = true
	elif event.is_action_pressed(&"attack_heavy"):
		_pending.heavy_pressed = true
	elif event.is_action_released(&"attack_heavy"):
		_pending.heavy_released = true
	elif event.is_action_pressed(&"dash"):
		_pending.dash_pressed = true
	elif event.is_action_pressed(&"weapon_slot_1"):
		_pending.weapon_slot = 0
	elif event.is_action_pressed(&"weapon_slot_2"):
		_pending.weapon_slot = 1


## Returns this tick's intent for a character at `origin`, aiming at the mouse.
func poll(character: Node2D) -> InputFrame:
	var frame := InputFrame.new()
	frame.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var to_mouse := character.get_global_mouse_position() - character.global_position
	frame.aim_direction = to_mouse.normalized() if to_mouse.length() > AIM_DEADZONE else Vector2.ZERO
	frame.heavy_held = Input.is_action_pressed(&"attack_heavy")
	frame.light_pressed = _pending.light_pressed
	frame.heavy_pressed = _pending.heavy_pressed
	frame.heavy_released = _pending.heavy_released
	frame.dash_pressed = _pending.dash_pressed
	frame.weapon_slot = _pending.weapon_slot
	_pending.clear_edges()
	return frame
