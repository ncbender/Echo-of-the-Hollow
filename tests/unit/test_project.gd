extends TestCase
## Project configuration smoke tests (input map, main scene).

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
	&"attack_light", &"attack_heavy", &"dash", &"defensive",
	&"ability_1", &"ability_2", &"ability_3", &"ability_4",
]


func test_required_input_actions_exist() -> void:
	for action in REQUIRED_ACTIONS:
		if check(InputMap.has_action(action), "missing input action %s" % action):
			check(not InputMap.action_get_events(action).is_empty(), "action %s has no events" % action)


func test_bindings_match_design() -> void:
	var expected := {
		&"move_up": KEY_W, &"move_left": KEY_A, &"move_down": KEY_S, &"move_right": KEY_D,
		&"dash": KEY_SPACE, &"defensive": KEY_SHIFT,
		&"ability_1": KEY_Q, &"ability_2": KEY_E, &"ability_3": KEY_R, &"ability_4": KEY_F,
	}
	for action: StringName in expected:
		var event := InputMap.action_get_events(action)[0] as InputEventKey
		check_eq(event.physical_keycode, expected[action], "binding of %s" % action)
	var light := InputMap.action_get_events(&"attack_light")[0] as InputEventMouseButton
	var heavy := InputMap.action_get_events(&"attack_heavy")[0] as InputEventMouseButton
	check_eq(light.button_index, MOUSE_BUTTON_LEFT, "light attack binding")
	check_eq(heavy.button_index, MOUSE_BUTTON_RIGHT, "heavy attack binding")


func test_main_scene_instantiates() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var packed: PackedScene = load(path)
	if check(packed != null, "main scene loads"):
		var arena := packed.instantiate()
		add_child(arena)
		await wait_physics(2)
		check(arena.is_inside_tree(), "arena in tree")
		arena.queue_free()
