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

var _root: Control
var _prompt: Label
var _windows: Array[Control] = []


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -176
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -4
	right.offset_top = 4
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	class_info = ClassInfoPanel.new()
	right.add_child(class_info)
	mastery_panel = MasteryPanel.new()
	right.add_child(mastery_panel)

	toasts = ToastFeed.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toasts.offset_left = -160
	toasts.offset_right = 160
	toasts.offset_top = -110
	toasts.offset_bottom = -50
	_root.add_child(toasts)

	_prompt = UiTheme.label("", Color(1.0, 0.95, 0.7))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -120
	_prompt.offset_right = 120
	_prompt.offset_top = -48
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override(&"outline_size", 3)
	_root.add_child(_prompt)

	class_panel = _add_window(ClassPanel.new()) as ClassPanel
	inventory_panel = _add_window(InventoryPanel.new()) as InventoryPanel
	build_panel = _add_window(BuildPanel.new()) as BuildPanel


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


func _add_window(window: Control) -> Control:
	window.set_anchors_preset(Control.PRESET_CENTER)
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	window.hide()
	_root.add_child(window)
	_windows.append(window)
	return window


func _process(_delta: float) -> void:
	var target := Interactable.find_active(get_tree())
	_prompt.text = "[G] %s" % target.prompt if target != null and not is_window_open() else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") and is_window_open():
		close_windows()
		get_viewport().set_input_as_handled()
