class_name UiTheme
extends RefCounted
## Central UI theme and layout constants (docs/DISPLAY_AND_UI_STANDARD.md).
##
## All sizes are design pixels of the 1920x1080 reference canvas. The canvas_items
## stretch maps them to any window (4K = 2x) and the player's UI scale is
## Window.content_scale_factor - so nothing here is ever multiplied by a scale,
## and text is always rasterized at its final size (crisp, never magnified).
## Font: Godot's built-in dynamic default font (a readable sans, not a pixel font).

# --- Font sizes (design px) --------------------------------------------------
const FONT_SMALL := 15
const FONT_BODY := 18
const FONT_HEADING := 22
const FONT_TITLE := 26

# --- Layout constants (design px) --------------------------------------------
## Distance of HUD elements and windows from the canvas edge.
const SCREEN_MARGIN := 16
## Inner padding of panels and windows.
const PANEL_PADDING := 12
## Gap between elements in containers.
const GAP := 8
const BORDER := 2
const CORNER := 4
## Right HUD column (class info, mastery).
const HUD_COLUMN_WIDTH := 360
## Width for wrapped text blocks in windows.
const TEXT_WIDTH := 520
## Width of the toast feed / interaction prompt at the bottom.
const FEED_WIDTH := 900
const BAR_HEIGHT := 8
const BAR_HEIGHT_SMALL := 6
const SLOT_SIZE := Vector2(150, 40)
const SLOT_GAP := 4
const TOOLTIP_MAX_WIDTH := 420
## Windows never get smaller than this (unless the canvas itself is smaller).
const WINDOW_MIN_SIZE := Vector2(320, 160)

# --- Colors ------------------------------------------------------------------
const COLOR_TEXT := Color(0.93, 0.92, 0.86)
const COLOR_DIM := Color(0.65, 0.63, 0.6)
const COLOR_ACCENT := Color(0.56, 0.83, 1.0)
const COLOR_WARN := Color(1.0, 0.85, 0.5)
const COLOR_ERROR := Color(1.0, 0.55, 0.45)
const COLOR_PROMPT := Color(1.0, 0.95, 0.7)
const COLOR_PANEL := Color(0.07, 0.06, 0.1, 0.92)
## Modal windows: nearly opaque so HUD/debug text never shows through.
const COLOR_WINDOW := Color(0.07, 0.06, 0.1, 0.985)
const COLOR_BORDER := Color(0.36, 0.33, 0.47)
const COLOR_BUTTON := Color(0.16, 0.14, 0.22)
const COLOR_BUTTON_HOVER := Color(0.26, 0.23, 0.36)
const COLOR_BUTTON_PRESSED := Color(0.32, 0.45, 0.6)
const COLOR_BUTTON_DISABLED := Color(0.1, 0.1, 0.12)
const COLOR_FOCUS := Color(0.56, 0.83, 1.0, 0.9)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	var panel := _box(COLOR_PANEL, COLOR_BORDER, PANEL_PADDING)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"Panel", panel)
	theme.set_type_variation(&"WindowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"WindowPanel", _box(COLOR_WINDOW, COLOR_BORDER, PANEL_PADDING))

	theme.set_color(&"font_color", &"Label", COLOR_TEXT)
	theme.set_color(&"font_outline_color", &"Label", Color.BLACK)
	theme.set_constant(&"line_spacing", &"Label", 0)
	theme.set_type_variation(&"HeaderLabel", &"Label")
	theme.set_font_size(&"font_size", &"HeaderLabel", FONT_HEADING)
	theme.set_color(&"font_color", &"HeaderLabel", COLOR_ACCENT)
	theme.set_type_variation(&"SmallLabel", &"Label")
	theme.set_font_size(&"font_size", &"SmallLabel", FONT_SMALL)
	theme.set_color(&"font_color", &"SmallLabel", COLOR_DIM)

	for type: StringName in [&"VBoxContainer", &"HBoxContainer"]:
		theme.set_constant(&"separation", type, GAP)
	theme.set_constant(&"h_separation", &"GridContainer", SLOT_GAP)
	theme.set_constant(&"v_separation", &"GridContainer", SLOT_GAP)
	theme.set_constant(&"h_separation", &"HFlowContainer", GAP * 2)
	theme.set_constant(&"v_separation", &"HFlowContainer", GAP * 2)

	_button_styles(theme, &"Button", 10, 6)
	theme.set_color(&"font_color", &"Button", COLOR_TEXT)
	theme.set_color(&"font_hover_color", &"Button", Color.WHITE)
	theme.set_color(&"font_focus_color", &"Button", Color.WHITE)
	theme.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	theme.set_color(&"font_disabled_color", &"Button", Color(0.45, 0.45, 0.45))
	# Inventory / equipment slots: same states, compact padding, own look.
	theme.set_type_variation(&"InventorySlot", &"Button")
	_button_styles(theme, &"InventorySlot", 8, 4)
	theme.set_font_size(&"font_size", &"InventorySlot", FONT_SMALL)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_ACCENT
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)

	var tooltip := _box(Color(0.04, 0.035, 0.06, 0.96), COLOR_ACCENT.darkened(0.3), 10)
	theme.set_stylebox(&"panel", &"TooltipPanel", tooltip)
	theme.set_color(&"font_color", &"TooltipLabel", COLOR_TEXT)
	theme.set_font_size(&"font_size", &"TooltipLabel", FONT_BODY)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = COLOR_BORDER
	grabber.set_corner_radius_all(CORNER)
	grabber.set_content_margin_all(5)
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0, 0, 0, 0.35)
	scroll_bg.set_content_margin_all(5)
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", type, scroll_bg)
		theme.set_stylebox(&"grabber", type, grabber)
		var highlight := grabber.duplicate() as StyleBoxFlat
		highlight.bg_color = COLOR_BUTTON_PRESSED
		theme.set_stylebox(&"grabber_highlight", type, highlight)
		theme.set_stylebox(&"grabber_pressed", type, highlight)
	return theme


static func _box(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(padding)
	return box


static func _button_styles(theme: Theme, type: StringName, pad_x: int, pad_y: int) -> void:
	var normal := _box(COLOR_BUTTON, COLOR_BUTTON, 0)
	normal.content_margin_left = pad_x
	normal.content_margin_right = pad_x
	normal.content_margin_top = pad_y
	normal.content_margin_bottom = pad_y
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_BUTTON_HOVER
	hover.border_color = COLOR_BUTTON_HOVER.lightened(0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = COLOR_BUTTON_PRESSED
	pressed.border_color = COLOR_ACCENT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = COLOR_BUTTON_DISABLED
	disabled.border_color = COLOR_BUTTON_DISABLED
	# Focus is drawn on top of the current state: a clear outline for keyboard/gamepad.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = COLOR_FOCUS
	focus.set_border_width_all(BORDER)
	focus.set_corner_radius_all(CORNER)
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, pressed)
	theme.set_stylebox(&"disabled", type, disabled)
	theme.set_stylebox(&"focus", type, focus)


static func label(text: String = "", color: Color = COLOR_TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override(&"font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func heading(text: String = "") -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"HeaderLabel"
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Label that wraps at `width` design px.
static func wrapped(text: String, color: Color = COLOR_TEXT, width: float = TEXT_WIDTH) -> Label:
	var result := label(text, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(width, 0)
	return result


static func bar(height: float = BAR_HEIGHT) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size = Vector2(0, height)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Wrapping tooltip content (Control._make_custom_tooltip). Width-limited, so long
## item texts never run off the screen; Godot keeps the popup inside the viewport.
static func tooltip(text: String) -> Control:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"TooltipLabel"
	var font_size := get_theme().get_font_size(&"font_size", &"TooltipLabel")
	var natural := ThemeDB.fallback_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(minf(natural + 2.0, TOOLTIP_MAX_WIDTH), 0)
	return result
