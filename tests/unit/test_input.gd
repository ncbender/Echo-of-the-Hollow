extends TestCase
## Device input layer: each physical click produces exactly one edge flag.


func _mouse(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _key(keycode: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	return event


func _setup() -> Array:
	var character := Node2D.new()
	var input := PlayerInput.new()
	character.add_child(input)
	add_child(character)
	return [character, input]


func test_click_is_one_edge() -> void:
	var nodes := _setup()
	var character: Node2D = nodes[0]
	var input: PlayerInput = nodes[1]
	input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, true))
	check(input.poll(character).light_pressed, "click produces light edge")
	check(not input.poll(character).light_pressed, "edge consumed after one tick (holding adds nothing)")
	input._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	check(not input.poll(character).light_pressed, "release produces no attack")


func test_heavy_press_and_release_edges() -> void:
	var nodes := _setup()
	var character: Node2D = nodes[0]
	var input: PlayerInput = nodes[1]
	input._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, true))
	var pressed := input.poll(character)
	check(pressed.heavy_pressed and not pressed.heavy_released, "RMB down -> heavy_pressed")
	input._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT, false))
	var released := input.poll(character)
	check(released.heavy_released and not released.heavy_pressed, "RMB up -> heavy_released")


func test_dash_ignores_key_repeat() -> void:
	var nodes := _setup()
	var character: Node2D = nodes[0]
	var input: PlayerInput = nodes[1]
	input._unhandled_input(_key(KEY_SPACE, true))
	check(input.poll(character).dash_pressed, "space -> dash edge")
	input._unhandled_input(_key(KEY_SPACE, true, true))
	check(not input.poll(character).dash_pressed, "OS key repeat is ignored")


## Consumables 1.0: key 1 drinks the Hearth Flask, key 2 the slotted potion;
## the weapon slot actions no longer listen to those keys.
func test_quick_use_keys() -> void:
	var nodes := _setup()
	var character: Node2D = nodes[0]
	var input: PlayerInput = nodes[1]
	input._unhandled_input(_key(KEY_1, true))
	var first := input.poll(character)
	check(first.flask_pressed and not first.potion_pressed and not "weapon_slot" in first, "key 1 -> flask; there is no weapon switch input")
	check(not input.poll(character).flask_pressed, "flask edge consumed")
	input._unhandled_input(_key(KEY_2, true))
	var second := input.poll(character)
	check(second.potion_pressed, "key 2 -> potion")
