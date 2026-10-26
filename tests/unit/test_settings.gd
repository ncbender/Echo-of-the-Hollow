extends TestCase
## UserSettings: allowed UI scales, persistence independent of save games,
## invalid files, reset, application to the window and the camera compensation.

const PATH := "user://test_saves/settings_test.cfg"

var _previous_factor: float


func before_each() -> void:
	_previous_factor = get_tree().root.content_scale_factor
	_remove()


func after_each() -> void:
	get_tree().root.content_scale_factor = _previous_factor
	_remove()


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_defaults() -> void:
	var settings := UserSettings.new()
	check_eq(settings.ui_scale, 1.0, "100 % by default")
	check_eq(settings.window_mode, UserSettings.WindowMode.WINDOWED, "windowed by default")
	check_eq(UserSettings.UI_SCALES, [0.75, 1.0, 1.25, 1.5] as Array[float], "offered scales (UI Scaling Standard 1.1)")


func test_only_offered_scales_are_accepted() -> void:
	var settings := UserSettings.new()
	var changes := [0]
	settings.changed.connect(func() -> void: changes[0] += 1)
	for value in UserSettings.UI_SCALES:
		check(settings.set_ui_scale(value), "%.2f accepted" % value)
		check_eq(settings.ui_scale, value, "%.2f stored" % value)
	check(not settings.set_ui_scale(3.0), "300 % refused")
	check(not settings.set_ui_scale(0.5), "50 % refused")
	check(not settings.set_ui_scale(2.0), "200 % is no longer offered")
	check_eq(settings.ui_scale, 1.5, "refused values change nothing")
	check_eq(changes[0], UserSettings.UI_SCALES.size(), "one change per new value (1.0 -> 0.75 -> 1.0 -> ...), none for refused ones")
	settings.set_ui_scale(1.5)
	check_eq(changes[0], UserSettings.UI_SCALES.size(), "same value again: no change")


func test_save_and_load_roundtrip() -> void:
	var settings := UserSettings.load_from(PATH)
	check_eq(settings.ui_scale, 1.0, "missing file -> defaults")
	settings.set_ui_scale(1.5)
	settings.set_window_mode(UserSettings.WindowMode.FULLSCREEN)
	check_eq(settings.save(), OK, "saved")
	var loaded := UserSettings.load_from(PATH)
	check_eq(loaded.ui_scale, 1.5, "UI scale persisted")
	check_eq(loaded.window_mode, UserSettings.WindowMode.FULLSCREEN, "window mode persisted")
	check_eq(loaded.path, PATH, "keeps its path")


func test_settings_are_not_part_of_save_games() -> void:
	var character := CharacterFactory.create_new(GameDatabase.get_default())
	var text := JSON.stringify(character.to_dict())
	check(not "ui_scale" in text and not "window_mode" in text, "character save has no display settings")


func test_invalid_file_values_fall_back_to_defaults() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var config := ConfigFile.new()
	config.set_value(UserSettings.SECTION, "ui_scale", 7.0)
	config.set_value(UserSettings.SECTION, "window_mode", "huge")
	config.save(PATH)
	var loaded := UserSettings.load_from(PATH)
	check_eq(loaded.ui_scale, 1.5, "a too large saved scale is limited to 150 %")
	check_eq(loaded.window_mode, UserSettings.WindowMode.WINDOWED, "invalid mode ignored")
	var garbage := FileAccess.open(PATH, FileAccess.WRITE)
	garbage.store_string("not a config file [[[")
	garbage.close()
	check_eq(UserSettings.load_from(PATH).ui_scale, 1.0, "corrupt file -> defaults")


func test_reset_to_defaults() -> void:
	var settings := UserSettings.new()
	settings.set_ui_scale(1.5)
	settings.set_window_mode(UserSettings.WindowMode.FULLSCREEN)
	var changes := [0]
	settings.changed.connect(func() -> void: changes[0] += 1)
	settings.reset_to_defaults()
	check_eq(settings.ui_scale, 1.0, "scale reset")
	check_eq(settings.window_mode, UserSettings.WindowMode.WINDOWED, "mode reset")
	check_eq(changes[0], 1, "one change notification")


func test_in_memory_settings_never_write() -> void:
	var settings := UserSettings.new()
	check_eq(settings.save(), ERR_UNCONFIGURED, "no path -> nothing written")


func test_scripted_session_uses_in_memory_settings() -> void:
	var session := SessionState.find(get_tree())
	check(session.settings != null, "session has settings")
	check_eq(session.settings.path, "", "tests never touch the player's settings file")


func test_apply_sets_content_scale_and_camera_keeps_world_view() -> void:
	var root := get_tree().root
	var camera: CameraShake = CameraShake.new()
	add_child(camera)
	var visible_world := {}
	for value in UserSettings.UI_SCALES:
		var settings := UserSettings.new()
		settings.set_ui_scale(value)
		settings.apply_to(root)
		check_near(root.content_scale_factor, value, 0.0001, "factor %.2f applied" % value)
		camera._process(0.0)
		visible_world[value] = root.get_visible_rect().size.x / camera.zoom.x
		check_near(visible_world[value], 512.0, 0.01, "visible world width at %.2f" % value)
	camera.free()


func test_old_saved_scales_are_mapped_into_the_new_range() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	for entry: Array in [[2.0, 1.5], [1.75, 1.5], [0.8, 0.75], [1.25, 1.25], [0.5, 0.75]]:
		var config := ConfigFile.new()
		config.set_value(UserSettings.SECTION, "ui_scale", entry[0])
		config.save(PATH)
		check_eq(UserSettings.load_from(PATH).ui_scale, entry[1], "saved %.2f -> %.2f" % [entry[0], entry[1]])
	check(UserSettings.UI_SCALES.max() <= UserSettings.MAX_UI_SCALE, "no offered scale above the maximum")
