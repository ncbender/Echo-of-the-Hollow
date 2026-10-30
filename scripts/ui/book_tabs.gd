class_name BookTabs
extends VBoxContainer
## Vertical page registers of a window ("bookmarks" sticking out of the left
## edge of an old book): dark leather, muted bronze, the active one in
## desaturated parchment and sticking out a little further. Same API as UiTabs
## (buttons "Tab<Id>", `tab_selected`), so a window can switch between them.
## The owning UiWindow places it outside its left edge (UiWindow.side_tabs).
## Menu UX Polish 1.1: shared by the class station and Professions. The registers sit behind the window
## (z -1), tucked under its frame without a gap; the selected one is drawn in front of the frame and reaches to
## the page (`bridge`), so it joins the page it opens. Selection = gold, keyboard focus = cyan, as before.

signal tab_selected(id: String)

## Width of an inactive register; the active one sticks out by ACTIVE_EXTRA.
const WIDTH := 112.0
const HEIGHT := 46.0
const ACTIVE_EXTRA := 10.0
## How far the registers reach under the window frame.
const OVERLAP := 6.0

var current: String = ""
## Menu UX Polish 1.1: how far every register reaches into the window (UiWindow sets it: up to its page). The
## inactive ones end there hidden behind the frame; the selected one is drawn over the frame up to the page.
var bridge: float = OVERLAP:
	set(value):
		bridge = value
		select(current)

var _group := ButtonGroup.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1   # behind the window: its frame covers the inner end of every register
	# fixed width (room for the protruding active register): the column never
	# changes size, so no register moves when another one becomes active
	custom_minimum_size.x = _width(true)


func add_tab(id: String, text: String, tooltip: String = "") -> Button:
	var button := BookTabButton.new()
	button.name = "Tab%s" % id.validate_node_name()
	button.text = text
	button.toggle_mode = true
	button.button_group = _group
	button.tooltip_text = tooltip
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.custom_minimum_size = Vector2(_width(false), HEIGHT)
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
			button.custom_minimum_size.x = _width(active)
			button.z_index = 2 if active else 0   # the selected register in front of the frame (absolute z 1)
	custom_minimum_size.x = _width(true)
	if emit:
		tab_selected.emit(id)


func tab_button(id: String) -> Button:
	return get_node_or_null("Tab%s" % id.validate_node_name()) as Button


## Total width the window has to keep free on its left side.
func reserved_width() -> float:
	return WIDTH + ACTIVE_EXTRA - OVERLAP


## Width of a register: the part outside the window (WIDTH - OVERLAP, the selected one ACTIVE_EXTRA more) plus the
## part inside it (`bridge`) - the same for every inactive register.
func _width(active: bool) -> float:
	return WIDTH - OVERLAP + bridge + (ACTIVE_EXTRA if active else 0.0)


func _on_pressed(id: String) -> void:
	select(id)
	tab_selected.emit(id)


## One register: a body open towards the page with stitches and a rivet left of the text.
## BookTabs Visual Integration 1.0: the body is the booktab/* art when present (UiSkin, the flat styles
## below stay the fallback): normal dark slate, hover lighter with a steel rim, selected = old-gold rim
## (and 10 px further out); disabled (unused so far) = the normal art dimmed. Keyboard focus is a
## separate square cyan outline just outside the body, so a selected register can show both.
class BookTabButton:
	extends Button

	const LEATHER := Color("2b2520")
	const LEATHER_HOVER := Color("3a3128")
	const PARCHMENT_DARK := Color("4d4334")
	## Decoration colours from the art palette (steel dark / steel / old gold).
	const STITCH := Color("50555c")
	const STITCH_ACTIVE := Color("b39a70")
	const RIVET := Color("777c83")
	const FONT_SIZE := 16

	func _init() -> void:
		theme_type_variation = &"BookTab"
		# every label fits an inactive register (WIDTH, minus the part under the frame): "Gathering" too -
		# a wider register stuck out further than the selected one (BookTabs Visual Integration 1.0)
		add_theme_font_size_override(&"font_size", FONT_SIZE)
		focus_mode = Control.FOCUS_ALL
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override(&"normal", UiSkin.stylebox(&"booktab/normal", _body(LEATHER, UiTheme.BRONZE_DIM, 1)))
		add_theme_stylebox_override(&"hover", UiSkin.stylebox(&"booktab/hover", _body(LEATHER_HOVER, UiTheme.BRONZE, 1)))
		add_theme_stylebox_override(&"pressed", UiSkin.stylebox(&"booktab/selected", _body(PARCHMENT_DARK, UiTheme.BRONZE, 2)))
		add_theme_stylebox_override(&"hover_pressed", UiSkin.stylebox(&"booktab/selected", _body(PARCHMENT_DARK, UiTheme.BRONZE, 2)))
		var disabled := UiSkin.stylebox(&"booktab/normal", _body(LEATHER, UiTheme.BRONZE_DARK, 1))
		if disabled is StyleBoxTexture:
			disabled = disabled.duplicate()
			(disabled as StyleBoxTexture).modulate_color = UiTheme.CARD_DISABLED_TINT
		add_theme_stylebox_override(&"disabled", disabled)
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = UiTheme.COLOR_FOCUS
		focus.set_border_width_all(2)
		if UiSkin.has(&"booktab/normal"):   # square pixel outline just outside the art (gold rim stays visible)
			focus.expand_margin_left = 3
			focus.expand_margin_top = 3
			focus.expand_margin_bottom = 3
			focus.border_width_right = 0   # open towards the page like the body (never over the window frame)
		else:
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
		box.content_margin_left = 18   # rim, stitches and rivet end at 16
		box.content_margin_right = 6
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		return box

	## Decoration left of the text only (stitches, rivet) - never over the label. With the art: whole
	## pixels inside its 4 px rim, palette colours (gold on the selected register).
	func _draw() -> void:
		if UiSkin.has(&"booktab/normal"):
			var stitch := STITCH_ACTIVE if button_pressed else STITCH
			for y in range(8, int(size.y) - 8, 6):
				draw_rect(Rect2(7, y, 2, 3), stitch)
			var rivet := Vector2(14, floorf(size.y * 0.5))
			draw_rect(Rect2(rivet - Vector2(2, 2), Vector2(4, 4)), STITCH_ACTIVE if button_pressed else RIVET)
			draw_rect(Rect2(rivet - Vector2(2, 2), Vector2(2, 2)), Color(UiTheme.PARCHMENT, 0.5) if button_pressed else Color(1, 1, 1, 0.15))
			return
		var edge := UiTheme.BRONZE if button_pressed else UiTheme.BRONZE_DIM
		for y in range(8, int(size.y) - 8, 6):
			draw_line(Vector2(6, y), Vector2(6, y + 2), Color(edge, 0.6), 1.0)
		var rivet := Vector2(12, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([rivet + Vector2(0, -3), rivet + Vector2(3, 0), rivet + Vector2(0, 3), rivet + Vector2(-3, 0)]), edge)
