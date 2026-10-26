class_name OptionsPanel
extends UiWindow
## Options (key O): UI scale, window mode, effects volume, reset to defaults.
## Edits the session's UserSettings; SessionState applies and saves them.

var settings: UserSettings

var _scale_buttons: Dictionary = {}   # float -> Button
var _windowed: Button
var _fullscreen: Button
var _info: Label
var _volume: HSlider
var _volume_label: Label


func _ready() -> void:
	set_title("Options")
	set_close_text("Close [O / Esc]")
	body.add_child(UiTheme.label("UI scale"))
	var scales := HFlowContainer.new()
	var group := ButtonGroup.new()
	for value in UserSettings.UI_SCALES:
		var button := Button.new()
		button.text = "%d %%" % roundi(value * 100.0)
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(96, 0)
		button.pressed.connect(_on_scale.bind(value))
		scales.add_child(button)
		_scale_buttons[value] = button
	body.add_child(scales)
	body.add_child(UiTheme.label("Window"))
	var modes := HBoxContainer.new()
	var mode_group := ButtonGroup.new()
	_windowed = _mode_button("Windowed", mode_group, UserSettings.WindowMode.WINDOWED)
	_fullscreen = _mode_button("Fullscreen [F11]", mode_group, UserSettings.WindowMode.FULLSCREEN)
	modes.add_child(_windowed)
	modes.add_child(_fullscreen)
	body.add_child(modes)
	body.add_child(UiTheme.label("Effects volume"))
	var volume_row := HBoxContainer.new()
	_volume = HSlider.new()
	_volume.name = "EffectsVolume"
	_volume.min_value = 0.0
	_volume.max_value = 100.0
	_volume.step = 5.0
	_volume.custom_minimum_size = Vector2(320, 24)
	_volume.value_changed.connect(func(value: float) -> void: settings.set_sfx_volume(value / 100.0))
	volume_row.add_child(_volume)
	_volume_label = UiTheme.label("", UiTheme.COLOR_DIM)
	volume_row.add_child(_volume_label)
	body.add_child(volume_row)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(_on_reset)
	body.add_child(reset)
	_info = UiTheme.wrapped("", UiTheme.COLOR_DIM)
	_info.theme_type_variation = &"SmallLabel"
	body.add_child(_info)


func open(target_settings: UserSettings) -> void:
	if settings != target_settings:
		if settings != null and settings.changed.is_connected(refresh):
			settings.changed.disconnect(refresh)
		settings = target_settings
		settings.changed.connect(refresh)
	show()
	refresh()


func refresh() -> void:
	if settings == null:
		return
	for value: float in _scale_buttons:
		(_scale_buttons[value] as Button).set_pressed_no_signal(is_equal_approx(value, settings.ui_scale))
	_windowed.set_pressed_no_signal(settings.window_mode == UserSettings.WindowMode.WINDOWED)
	_fullscreen.set_pressed_no_signal(settings.window_mode == UserSettings.WindowMode.FULLSCREEN)
	_volume.set_value_no_signal(settings.sfx_volume * 100.0)
	_volume_label.text = "%d %%" % roundi(settings.sfx_volume * 100.0)
	var window := get_window()
	_info.text = "Window %d x %d px  -  UI canvas %d x %d  -  design 1920 x 1080\nSettings are stored per installation (%s), not in save games." % [
		window.size.x, window.size.y, get_viewport_rect().size.x, get_viewport_rect().size.y,
		settings.path if settings.path != "" else "not persisted in this run"]


func _mode_button(text: String, group: ButtonGroup, mode: UserSettings.WindowMode) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(func() -> void: settings.set_window_mode(mode))
	return button


func _on_scale(value: float) -> void:
	settings.set_ui_scale(value)


func _on_reset() -> void:
	settings.reset_to_defaults()
	refresh()


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(refresh):
		settings.changed.disconnect(refresh)


func _process(_delta: float) -> void:
	if visible:
		refresh()   # window size changes asynchronously after a mode switch
