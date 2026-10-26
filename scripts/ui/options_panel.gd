class_name OptionsPanel
extends UiWindow
## Options (O): Display · Audio · Gameplay · Accessibility · Controls.
## Edits the session's UserSettings (installation-wide, never part of a save);
## SessionState applies and stores them. Controls lists the real key bindings
## from the InputMap (read-only - rebinding is not available yet).

const PAGES := ["Display", "Audio", "Gameplay", "Accessibility", "Controls"]
const WIDTH := 640
## Action -> label, in the order shown on the Controls page.
const CONTROLS := [
	[&"move_up", "Move up"], [&"move_down", "Move down"], [&"move_left", "Move left"], [&"move_right", "Move right"],
	[&"attack_light", "Light attack"], [&"attack_heavy", "Heavy attack (hold to charge)"], [&"dash", "Dash (movement direction; standing still: towards the cursor)"],
	[&"defensive", "Block / parry"], [&"ability_1", "Skill 1"], [&"ability_2", "Skill 2"], [&"ability_3", "Skill 3"],
	[&"ability_4", "Skill 4"], [&"weapon_slot_1", "Weapon 1"], [&"weapon_slot_2", "Weapon 2"], [&"interact", "Interact / talk / continue"],
	[&"ui_inventory", "Inventory"], [&"ui_character", "Character, talents and skills"], [&"ui_journal", "Journal"],
	[&"ui_map", "Map"], [&"ui_professions", "Professions"], [&"ui_options", "Options"], [&"ui_cancel", "Pause menu / close"], [&"toggle_fullscreen", "Fullscreen"],
]

var settings: UserSettings
var page: String = "Display"

var _tabs: UiTabs
var _pages: Dictionary = {}   # page -> VBoxContainer
var _scale_buttons: Dictionary = {}   # float -> Button
var _windowed: Button
var _fullscreen: Button
var _info: Label
var _volume: HSlider
var _volume_label: Label
var _autosave: CheckButton
var _indicator: CheckButton
var _motion: CheckButton


func _ready() -> void:
	set_title("Options")
	set_close_text("Close [O / Esc]")
	_tabs = UiTabs.new()
	for id in PAGES:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(show_page)
	body.add_child(_tabs)
	for id in PAGES:
		var box := VBoxContainer.new()
		box.name = "Page%s" % id
		box.custom_minimum_size = Vector2(WIDTH, 0)
		box.add_theme_constant_override(&"separation", UiTheme.GAP)
		body.add_child(box)
		_pages[id] = box
	_build_display(_pages["Display"])
	_build_audio(_pages["Audio"])
	_build_gameplay(_pages["Gameplay"])
	_build_accessibility(_pages["Accessibility"])
	_build_controls(_pages["Controls"])
	var reset := UiTheme.button("Reset to defaults", &"DangerButton", _on_reset)
	reset.name = "Reset"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(reset)
	show_page("Display")


func show_page(id: String) -> void:
	page = id
	_tabs.select(id)
	for key: String in _pages:
		(_pages[key] as Control).visible = key == id
	queue_fit()


func _build_display(box: VBoxContainer) -> void:
	box.add_child(UiTheme.section("UI scale"))
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
	box.add_child(scales)
	box.add_child(UiTheme.section("Window"))
	var modes := HBoxContainer.new()
	var mode_group := ButtonGroup.new()
	_windowed = _mode_button("Windowed", mode_group, UserSettings.WindowMode.WINDOWED)
	_fullscreen = _mode_button("Fullscreen [F11]", mode_group, UserSettings.WindowMode.FULLSCREEN)
	modes.add_child(_windowed)
	modes.add_child(_fullscreen)
	box.add_child(modes)
	_info = UiTheme.wrapped("", UiTheme.TEXT_MUTED, WIDTH)
	_info.theme_type_variation = &"SmallLabel"
	box.add_child(_info)


func _build_audio(box: VBoxContainer) -> void:
	box.add_child(UiTheme.section("Effects volume"))
	var volume_row := HBoxContainer.new()
	_volume = HSlider.new()
	_volume.name = "EffectsVolume"
	_volume.min_value = 0.0
	_volume.max_value = 100.0
	_volume.step = 5.0
	_volume.custom_minimum_size = Vector2(360, 24)
	_volume.value_changed.connect(func(value: float) -> void: settings.set_sfx_volume(value / 100.0))
	volume_row.add_child(_volume)
	_volume_label = UiTheme.label("", UiTheme.TEXT_SECONDARY)
	volume_row.add_child(_volume_label)
	box.add_child(volume_row)
	box.add_child(_small("Music and ambience will get their own sliders once they exist."))


func _build_gameplay(box: VBoxContainer) -> void:
	box.add_child(UiTheme.section("Saving"))
	_autosave = CheckButton.new()
	_autosave.name = "PeriodicAutosave"
	_autosave.text = "Periodic Autosave"
	_autosave.toggled.connect(func(on: bool) -> void: settings.set_periodic_autosave(on))
	box.add_child(_autosave)
	box.add_child(_small("Automatically saves every 5 minutes. Important progression milestones are always saved."))
	_indicator = CheckButton.new()
	_indicator.name = "ShowSaveIndicator"
	_indicator.text = "Show Save Indicator"
	_indicator.toggled.connect(func(on: bool) -> void: settings.set_show_save_indicator(on))
	box.add_child(_indicator)
	box.add_child(_small("A failed save is always shown."))


func _build_accessibility(box: VBoxContainer) -> void:
	box.add_child(UiTheme.section("Motion"))
	_motion = CheckButton.new()
	_motion.name = "ReduceMotion"
	_motion.text = "Reduce Motion"
	_motion.tooltip_text = "Windows and panels appear instantly instead of fading in."
	_motion.toggled.connect(func(on: bool) -> void: settings.set_reduce_motion(on))
	box.add_child(_motion)
	box.add_child(_small("Windows and panels appear instantly instead of fading in."))
	box.add_child(UiTheme.section("Readability"))
	box.add_child(_small("Text size follows the UI scale on the Display page (up to 200 %). Rarity, states and warnings are always written out, never shown by colour alone."))


func _build_controls(box: VBoxContainer) -> void:
	box.add_child(_small("Mouse and keyboard. Rebinding keys is not available yet."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTheme.GAP * 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	for entry: Array in CONTROLS:
		if not InputMap.has_action(entry[0]):
			continue
		var label := UiTheme.label(entry[1], UiTheme.TEXT_SECONDARY)
		label.custom_minimum_size = Vector2(300, 0)
		grid.add_child(label)
		grid.add_child(UiTheme.key_chip(binding_text(entry[0])))
	box.add_child(grid)


## Human-readable keys of an action ("W", "LMB", "Shift", "Esc").
static func binding_text(action: StringName) -> String:
	var parts: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		var mouse := event as InputEventMouseButton
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
			parts.append({KEY_ESCAPE: "Esc", KEY_SHIFT: "Shift", KEY_SPACE: "Space"}.get(code, OS.get_keycode_string(code)))
		elif mouse != null:
			parts.append({MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB"}.get(mouse.button_index, "Mouse %d" % mouse.button_index))
	return " / ".join(parts) if not parts.is_empty() else "-"


func _small(text: String) -> Label:
	var label := UiTheme.wrapped(text, UiTheme.TEXT_MUTED, WIDTH)
	label.theme_type_variation = &"SmallLabel"
	return label


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
	_autosave.set_pressed_no_signal(settings.periodic_autosave)
	_indicator.set_pressed_no_signal(settings.show_save_indicator)
	_motion.set_pressed_no_signal(settings.reduce_motion)
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
