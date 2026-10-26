class_name GameHud
extends CanvasLayer
## Container for the prototype RPG UI. Pure presentation: reads the Character
## through the PlayerProgressionBridge and calls its public methods.

var bridge: PlayerProgressionBridge
var toasts: ToastFeed
var mastery_panel: MasteryPanel

var _root: Control


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -156
	right.offset_right = -4
	right.offset_top = 4
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	mastery_panel = MasteryPanel.new()
	right.add_child(mastery_panel)

	toasts = ToastFeed.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toasts.offset_left = -160
	toasts.offset_right = 160
	toasts.offset_top = -110
	toasts.offset_bottom = -50
	_root.add_child(toasts)


func setup(progression_bridge: PlayerProgressionBridge) -> void:
	bridge = progression_bridge
	mastery_panel.bridge = bridge
	if not bridge.message.is_connected(toasts.push):
		bridge.message.connect(toasts.push.bind(UiTheme.COLOR_ACCENT))


func notify(text: String) -> void:
	toasts.push(text)
