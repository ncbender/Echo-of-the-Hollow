class_name UiTheme
extends RefCounted
## Shared placeholder theme for all prototype UI (small font, dark panels).

const FONT_SIZE := 8
const COLOR_TEXT := Color(0.93, 0.92, 0.86)
const COLOR_DIM := Color(0.65, 0.63, 0.6)
const COLOR_ACCENT := Color(0.56, 0.83, 1.0)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.06, 0.1, 0.88)
	panel.border_color = Color(0.36, 0.33, 0.47)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(5)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_color(&"font_color", &"Label", COLOR_TEXT)
	theme.set_constant(&"line_spacing", &"Label", -2)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_ACCENT
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(0.16, 0.14, 0.22)
	button.set_content_margin_all(2)
	var button_hover := button.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.26, 0.23, 0.36)
	var button_pressed := button.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.32, 0.45, 0.6)
	var button_disabled := button.duplicate() as StyleBoxFlat
	button_disabled.bg_color = Color(0.1, 0.1, 0.12)
	theme.set_stylebox(&"normal", &"Button", button)
	theme.set_stylebox(&"hover", &"Button", button_hover)
	theme.set_stylebox(&"pressed", &"Button", button_pressed)
	theme.set_stylebox(&"focus", &"Button", button_hover)
	theme.set_stylebox(&"disabled", &"Button", button_disabled)
	theme.set_color(&"font_color", &"Button", COLOR_TEXT)
	theme.set_color(&"font_disabled_color", &"Button", Color(0.45, 0.45, 0.45))
	return theme


static func label(text: String = "", color: Color = COLOR_TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override(&"font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func bar(height: float = 4.0) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size = Vector2(0, height)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
