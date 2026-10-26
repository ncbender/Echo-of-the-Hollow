class_name GameHud
extends CanvasLayer
## Container for the prototype RPG UI. Pure presentation: reads the Character
## through the PlayerProgressionBridge and calls its public methods.

var bridge: PlayerProgressionBridge
var toasts: ToastFeed
var mastery_panel: MasteryPanel
var class_info: ClassInfoPanel
var class_panel: ClassStationPanel
var inventory_panel: InventoryPanel
var build_panel: BuildPanel
var options_panel: OptionsPanel
var crafting_panel: CraftingPanel
var skill_bar: SkillBar
var objectives: ObjectivePanel
var class_choice_panel: ClassChoicePanel
var pause_menu: PauseMenu
var save_indicator: SaveIndicator
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
	objectives = ObjectivePanel.new()
	right.add_child(objectives)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -UiTheme.FEED_WIDTH * 0.5
	bottom.offset_right = UiTheme.FEED_WIDTH * 0.5
	bottom.offset_bottom = -UiTheme.SCREEN_MARGIN * 6
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	skill_bar = SkillBar.new()
	bottom.add_child(skill_bar)
	_prompt = UiTheme.label("", UiTheme.COLOR_PROMPT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", UiTheme.FONT_HEADING)
	_prompt.add_theme_constant_override(&"outline_size", 6)
	bottom.add_child(_prompt)
	toasts = ToastFeed.new()
	bottom.add_child(toasts)

	class_panel = _add_window(ClassStationPanel.new()) as ClassStationPanel
	inventory_panel = _add_window(InventoryPanel.new()) as InventoryPanel
	build_panel = _add_window(BuildPanel.new()) as BuildPanel
	options_panel = _add_window(OptionsPanel.new()) as OptionsPanel
	crafting_panel = _add_window(CraftingPanel.new()) as CraftingPanel
	class_choice_panel = _add_window(ClassChoicePanel.new()) as ClassChoicePanel
	pause_menu = _add_window(PauseMenu.new()) as PauseMenu
	pause_menu.options_requested.connect(_open_options_from_pause)
	options_panel.process_mode = Node.PROCESS_MODE_ALWAYS   # reachable from the pause menu
	save_indicator = SaveIndicator.new()
	save_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	save_indicator.offset_left = -260
	save_indicator.offset_top = -64
	save_indicator.offset_right = -UiTheme.SCREEN_MARGIN
	save_indicator.offset_bottom = -UiTheme.SCREEN_MARGIN
	save_indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(save_indicator)
	crafting_panel.recipes_requested.connect(open_build_panel)
	var session := SessionState.find(get_tree())
	if session != null:
		settings = session.settings
	if settings != null:
		settings.changed.connect(_refit_windows)


func setup(progression_bridge: PlayerProgressionBridge) -> void:
	bridge = progression_bridge
	mastery_panel.bridge = bridge
	class_info.bridge = bridge
	skill_bar.bridge = bridge
	objectives.bridge = bridge
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
	class_panel.open(bridge.character, station, "Classes")


## One-time prologue class choice (Altar of Choice).
func open_class_choice(station: ClassChoiceStation) -> void:
	if bridge == null:
		return
	close_windows()
	class_choice_panel.open(bridge.character, station)


func open_build_panel(plot: BuildPlot) -> void:
	if bridge == null:
		return
	close_windows()
	build_panel.open(bridge.character, plot)


## C: class, talents and skills away from a class station (learning talents only).
func toggle_character() -> void:
	if bridge == null:
		return
	if class_panel.visible:
		class_panel.hide()
	else:
		close_windows()
		class_panel.open(bridge.character, null, "Talents")


func toggle_inventory() -> void:
	if bridge == null:
		return
	if inventory_panel.visible:
		inventory_panel.hide()
	else:
		close_windows()
		inventory_panel.open(bridge.character)


## Resonance Forge at a crafting station (smithy).
func open_crafting_panel(plot: BuildPlot) -> void:
	if bridge == null:
		return
	close_windows()
	crafting_panel.open(bridge.character, plot)


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
	if event.is_action_pressed(&"ui_character"):
		toggle_character()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_options"):
		toggle_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if is_window_open():
			close_windows()
		else:
			open_pause_menu()
		get_viewport().set_input_as_handled()


## Esc with no other window: pause menu (save, load, options, title).
func open_pause_menu() -> void:
	var session := SessionState.find(get_tree())
	if session == null:
		return
	close_windows()
	pause_menu.open(session)


func _open_options_from_pause() -> void:
	pause_menu.hide()
	if settings != null:
		options_panel.open(settings)
