class_name GameHud
extends CanvasLayer
## Container for the prototype RPG UI. Pure presentation: reads the Character
## through the PlayerProgressionBridge and calls its public methods.

var bridge: PlayerProgressionBridge
var toasts: ToastFeed
var mastery_panel: MasteryPanel
var class_info: ClassInfoPanel
var class_panel: ClassPanel
var inventory_panel: InventoryPanel
var build_panel: BuildPanel
var options_panel: OptionsPanel
## Player display preferences (from GameSession); null when running without one.
var settings: UserSettings

var _root: Control
var _prompt: Label
var _windows: Array[UiWindow] = []


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	# Anchored layout in design px (UiTheme): adapts to every window size and UI scale.
	var margin := UiTheme.SCREEN_MARGIN
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -UiTheme.HUD_COLUMN_WIDTH - margin
	right.offset_right = -margin
	right.offset_top = margin
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	class_info = ClassInfoPanel.new()
	right.add_child(class_info)
	mastery_panel = MasteryPanel.new()
	right.add_child(mastery_panel)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -UiTheme.FEED_WIDTH * 0.5
	bottom.offset_right = UiTheme.FEED_WIDTH * 0.5
	bottom.offset_bottom = -UiTheme.SCREEN_MARGIN * 6
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_prompt = UiTheme.label("", UiTheme.COLOR_PROMPT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", UiTheme.FONT_HEADING)
	_prompt.add_theme_constant_override(&"outline_size", 6)
	bottom.add_child(_prompt)
	toasts = ToastFeed.new()
	bottom.add_child(toasts)

	class_panel = _add_window(ClassPanel.new()) as ClassPanel
	inventory_panel = _add_window(InventoryPanel.new()) as InventoryPanel
	build_panel = _add_window(BuildPanel.new()) as BuildPanel
	options_panel = _add_window(OptionsPanel.new()) as OptionsPanel
	var session := SessionState.find(get_tree())
	if session != null:
		settings = session.settings
	if settings != null:
		settings.changed.connect(_refit_windows)


func setup(progression_bridge: PlayerProgressionBridge) -> void:
	bridge = progression_bridge
	mastery_panel.bridge = bridge
	class_info.bridge = bridge
	bridge.message.connect(toasts.push.bind(UiTheme.COLOR_ACCENT))


func notify(text: String) -> void:
	toasts.push(text)


func is_window_open() -> bool:
	for window in _windows:
		if window.visible:
			return true
	return false


func close_windows() -> void:
	for window in _windows:
		window.hide()


func open_class_panel(station: ClassStation) -> void:
	if bridge == null:
		return
	close_windows()
	class_panel.open(bridge.character, station)


func open_build_panel(plot: BuildPlot) -> void:
	if bridge == null:
		return
	close_windows()
	build_panel.open(bridge.character, plot)


func toggle_inventory() -> void:
	if bridge == null:
		return
	if inventory_panel.visible:
		inventory_panel.hide()
	else:
		close_windows()
		inventory_panel.open(bridge.character)


func toggle_options() -> void:
	if settings == null:
		return
	if options_panel.visible:
		options_panel.hide()
	else:
		close_windows()
		options_panel.open(settings)


## UiWindows size and center themselves (see UiWindow).
func _add_window(window: UiWindow) -> UiWindow:
	window.hide()
	_root.add_child(window)
	_windows.append(window)
	return window


## The visible canvas changes with the UI scale / window mode: re-fit open windows.
func _refit_windows() -> void:
	for window: UiWindow in _windows:
		window.queue_fit()


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(_refit_windows):
		settings.changed.disconnect(_refit_windows)


func _process(_delta: float) -> void:
	var target := Interactable.find_active(get_tree())
	_prompt.text = "[G] %s" % target.prompt if target != null and not is_window_open() else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_options"):
		toggle_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and is_window_open():
		close_windows()
		get_viewport().set_input_as_handled()
