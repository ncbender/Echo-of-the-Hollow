class_name BookTabs
extends VBoxContainer
## Vertical page registers of a window ("bookmarks" sticking out of the left
## edge of an old book): dark leather, muted bronze, the active one in
## desaturated parchment and sticking out a little further. Same API as UiTabs
## (buttons "Tab<Id>", `tab_selected`), so a window can switch between them.
## The owning UiWindow places it outside its left edge (UiWindow.side_tabs).

signal tab_selected(id: String)

## Width of an inactive register; the active one sticks out by ACTIVE_EXTRA.
const WIDTH := 112.0
const HEIGHT := 46.0
const ACTIVE_EXTRA := 10.0
## How far the registers reach under the window frame.
const OVERLAP := 6.0

var current: String = ""

var _group := ButtonGroup.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# fixed width (room for the protruding active register): the column never
	# changes size, so no register moves when another one becomes active
	custom_minimum_size.x = WIDTH + ACTIVE_EXTRA


func add_tab(id: String, text: String, tooltip: String = "") -> Button:
	var button := BookTabButton.new()
	button.name = "Tab%s" % id.validate_node_name()
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.tooltip_text = tooltip
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	button.pressed.connect(_on_pressed.bind(id))
	add_child(button)
	return button


func select(id: String, emit: bool = false) -> void:
	current = id
	for child in get_children():
		var button := child as Button
		if button != null:
			var active := button.name == "Tab%s" % id.validate_node_name()
			button.set_pressed_no_signal(active)
			button.custom_minimum_size.x = WIDTH + (ACTIVE_EXTRA if active else 0.0)
	if emit:
		tab_selected.emit(id)


func tab_button(id: String) -> Button:
	return get_node_or_null("Tab%s" % id.validate_node_name()) as Button


## Total width the window has to keep free on its left side.
func reserved_width() -> float:
	return WIDTH + ACTIVE_EXTRA - OVERLAP


func _on_pressed(id: String) -> void:
	select(id)
	tab_selected.emit(id)


## One register: leather body (StyleBoxes, open towards the page), bronze edge,
## stitches and a rivet left of the text; active = desaturated parchment.
class BookTabButton:
	extends Button

	const LEATHER := Color("2b2520")
	const LEATHER_HOVER := Color("3a3128")
	const PARCHMENT_DARK := Color("4d4334")

	func _init() -> void:
		theme_type_variation = &"BookTab"
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override(&"normal", _body(LEATHER, UiTheme.BRONZE_DIM, 1))
		add_theme_stylebox_override(&"hover", _body(LEATHER_HOVER, UiTheme.BRONZE, 1))
		add_theme_stylebox_override(&"pressed", _body(PARCHMENT_DARK, UiTheme.BRONZE, 2))
		add_theme_stylebox_override(&"hover_pressed", _body(PARCHMENT_DARK, UiTheme.BRONZE, 2))
		add_theme_stylebox_override(&"disabled", _body(LEATHER, UiTheme.BRONZE_DARK, 1))
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = UiTheme.COLOR_FOCUS
		focus.set_border_width_all(2)
		focus.corner_radius_top_left = 6
		focus.corner_radius_bottom_left = 6
		add_theme_stylebox_override(&"focus", focus)
		add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
		add_theme_color_override(&"font_hover_color", UiTheme.TEXT_PRIMARY)
		add_theme_color_override(&"font_pressed_color", UiTheme.PARCHMENT)
		add_theme_color_override(&"font_hover_pressed_color", UiTheme.PARCHMENT)
		add_theme_color_override(&"font_focus_color", UiTheme.TEXT_PRIMARY)
		toggled.connect(func(_on: bool) -> void: queue_redraw())

	static func _body(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = edge
		box.border_width_left = width
		box.border_width_top = width
		box.border_width_bottom = width
		box.corner_radius_top_left = 6
		box.corner_radius_bottom_left = 6
		box.content_margin_left = 24
		box.content_margin_right = 8
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		return box

	## Decoration left of the text only (stitches, rivet) - never over the label.
	func _draw() -> void:
		var edge := UiTheme.BRONZE if button_pressed else UiTheme.BRONZE_DIM
		for y in range(8, int(size.y) - 8, 6):
			draw_line(Vector2(6, y), Vector2(6, y + 2), Color(edge, 0.6), 1.0)
		var rivet := Vector2(14, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([rivet + Vector2(0, -3), rivet + Vector2(3, 0), rivet + Vector2(0, 3), rivet + Vector2(-3, 0)]), edge)
