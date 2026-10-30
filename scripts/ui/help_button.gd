class_name HelpButton
extends Button
## Menu UX Polish 1.1: a compact "?" that holds a page's longer explanations (legends, threshold tables, how XP
## is earned) instead of permanent text. Its help panel opens on mouse hover AND on keyboard focus (a Godot
## tooltip would only follow the mouse) and closes when both leave; it never takes mouse input, so nothing under
## it is blocked. The text is plain lines; a line starting with "# " is a small bronze heading.

const SIZE := Vector2(26, 26)
const WIDTH := 380.0
const GAP := 8.0

var help_text: String = ""
var _panel: PanelContainer
var _box: VBoxContainer
var _hovered: bool = false


static func make(text: String, node_name: String = "Help") -> HelpButton:
	var help := HelpButton.new()
	help.name = node_name
	help.help_text = text
	return help


func _init() -> void:
	text = "?"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_HELP
	add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	add_theme_constant_override(&"h_separation", 0)
	_panel = PanelContainer.new()
	_panel.name = "HelpPanel"
	_panel.theme_type_variation = &"TooltipPanel"
	_panel.top_level = true
	_panel.z_index = 100
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_box)
	add_child(_panel)
	mouse_entered.connect(func() -> void:
		_hovered = true
		open_help())
	mouse_exited.connect(func() -> void:
		_hovered = false
		if not has_focus():
			close_help())
	focus_entered.connect(open_help)
	focus_exited.connect(func() -> void:
		if not _hovered:
			close_help())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			close_help())


func is_open() -> bool:
	return _panel.visible


func open_help() -> void:
	if not is_inside_tree() or help_text == "":
		return
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	for line: String in help_text.split("\n"):
		if line.begins_with("# "):
			var head := UiTheme.styled(line.trim_prefix("# ").to_upper(), &"CaptionLabel")
			head.add_theme_color_override(&"font_color", UiTheme.BRONZE)
			_box.add_child(head)
		else:
			var label := UiTheme.wrapped(line, UiTheme.TEXT_PRIMARY, WIDTH - 32.0)
			label.theme_type_variation = &"MenuMetaLabel"
			_box.add_child(label)
	_panel.show()
	_panel.reset_size()
	_place()
	_place.call_deferred()   # wrapped lines know their height after one pass


func close_help() -> void:
	_panel.hide()


## Below the "?" if it fits, else above; clamped into the visible canvas.
func _place() -> void:
	if not _panel.visible or not is_inside_tree():
		return
	_panel.reset_size()
	var want := _panel.get_combined_minimum_size()
	var anchor := get_global_rect()
	var view := get_viewport_rect().size
	var margin := float(UiTheme.SCREEN_MARGIN) * 0.5
	var x := clampf(anchor.position.x, margin, maxf(margin, view.x - margin - want.x))
	var y := anchor.end.y + GAP
	if y + want.y > view.y - margin:
		y = anchor.position.y - GAP - want.y
	y = clampf(y, margin, maxf(margin, view.y - margin - want.y))
	_panel.size = want
	_panel.global_position = Vector2(x, y).floor()
