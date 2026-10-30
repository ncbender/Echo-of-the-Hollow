class_name SplitBarText
extends Control
## HUD Resource Text Readability 1.0: the resource bar's value, readable on every fill colour. Over the
## filled part of a bright fill (Mana, Focus, Resolve, Soul Energy - parchment reaches < 3:1 there) the
## text is dark; over the empty groove (and on dark fills such as Rage) it stays light with its outline.
## Two BarTexts with the same text, size and position, each clipped to its side of the fill edge - so a
## glyph that crosses the edge changes colour at the exact pixel, and both halves stay readable.

## Below this contrast of light text on the fill, the filled part gets dark text (WCAG large-text minimum).
const MIN_CONTRAST := 3.0
const DARK := Color("0e0f12")   # ink of the UI art

var text: String = "":
	set(value):
		text = value
		_light.text = value
		_dark.text = value
var font_size: int = 13:
	set(value):
		font_size = value
		_light.font_size = value
		_dark.font_size = value

var _light: BarText
var _dark: BarText
var _light_clip: Control
var _dark_clip: Control
var _split: float = 0.0
var _dark_on_fill: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark_clip = _clip()
	_light_clip = _clip()
	_dark = BarText.new()
	_dark.color = DARK
	_dark.outline_size = 2   # the same fit as the light text (no outline is drawn, see _process)
	_dark_clip.add_child(_dark)
	_light = BarText.new()
	_light.outline_size = 2
	_light_clip.add_child(_light)
	resized.connect(_layout)


func _clip() -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	return clip


## `edge`: the x (local px) where the visible fill ends; `fill`: the fill colour.
func set_fill(edge: float, fill: Color) -> void:
	var dark := contrast(UiTheme.PARCHMENT, fill) < MIN_CONTRAST
	edge = clampf(roundf(edge), 0.0, size.x)
	if is_equal_approx(edge, _split) and dark == _dark_on_fill:
		return
	_split = edge
	_dark_on_fill = dark
	_layout()


func _layout() -> void:
	var split := _split if _dark_on_fill else 0.0
	_dark_clip.position = Vector2.ZERO
	_dark_clip.size = Vector2(split, size.y)
	_light_clip.position = Vector2(split, 0)
	_light_clip.size = Vector2(size.x - split, size.y)
	for label: BarText in [_dark, _light]:   # both span the whole bar: same size, same place
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.size = size
	_dark.position = Vector2.ZERO
	_light.position = Vector2(-split, 0)
	_dark.outline_color = Color(0, 0, 0, 0)   # dark text needs no halo on a bright fill
	_dark_clip.visible = split > 0.0


## The font size both halves use (BarText's fit).
func used_font_size() -> int:
	return _light.used_font_size()


## WCAG contrast ratio of two colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var channel := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channel.call(c.r) + 0.7152 * channel.call(c.g) + 0.0722 * channel.call(c.b)
