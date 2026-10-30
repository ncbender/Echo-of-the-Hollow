class_name BarText
extends Control
## UI Usability & Haven Crafting 1.0: the one text placement for numbers inside bars (PlayerFrame
## health / resource, HudXpBar). A Label cannot shrink below its line height (font ascent + descent +
## line spacing, 18-23 px for 13-14 px text), so inside a 12-18 px bar it grew out of the bar and
## sat off-centre; the line box also centres the empty descender room, so digits sat too high.
## This control has no minimum size and draws the text itself: horizontally centred on its advance,
## vertically on the real ink of a digit (glyph box of "0"), whole pixels; too big for the bar
## (height with the outline, or width) - the size steps down until it fits.

var text: String = "":
	set(value):
		if value != text:
			text = value
			queue_redraw()
var font_size: int = 13:
	set(value):
		font_size = value
		queue_redraw()
var color: Color = UiTheme.PARCHMENT:
	set(value):
		color = value
		queue_redraw()
var outline_size: int = 4
var outline_color: Color = Color.BLACK
## Smallest size the fit may step down to.
var min_font_size: int = 9

static var _ink_cache: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## [top, height] of a digit's ink relative to the baseline (top negative) at `size`.
static func digit_ink(font: Font, size: int) -> Vector2:
	var key := [font.get_instance_id(), size]
	if _ink_cache.has(key):
		return _ink_cache[key]
	var ink := Vector2(-font.get_ascent(size) * 0.72, font.get_ascent(size) * 0.72)   # fallback: cap-height share
	var file := font as FontFile
	if file != null and not file.get_rids().is_empty():
		var server := TextServerManager.get_primary_interface()
		var rid: RID = file.get_rids()[0]
		var glyph := server.font_get_glyph_index(rid, size, "0".unicode_at(0), 0)
		var offset: Vector2 = server.font_get_glyph_offset(rid, Vector2i(size, 0), glyph)
		var box: Vector2 = server.font_get_glyph_size(rid, Vector2i(size, 0), glyph)
		if box.y > 0.0:
			ink = Vector2(offset.y, box.y)
	_ink_cache[key] = ink
	return ink


## The size that fits `box` (outline included), `wanted` at most.
static func fitting_size(font: Font, value: String, wanted: int, box: Vector2, outline: int, smallest: int) -> int:
	var size := wanted
	while size > smallest:
		var ink := digit_ink(font, size)
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if ink.y + outline <= box.y and width + outline <= box.x:
			break
		size -= 1
	return size


## Baseline-left position that centres `value` in `box` (whole pixels).
static func centred_origin(font: Font, value: String, size: int, box: Vector2) -> Vector2:
	var ink := digit_ink(font, size)
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := roundf((box.x - width) * 0.5)
	var y := roundf(box.y * 0.5 - (ink.x + ink.y * 0.5))
	return Vector2(x, y)


func used_font_size() -> int:
	return fitting_size(UiTheme.body_font(), text, font_size, size, outline_size, min_font_size)


func _draw() -> void:
	if text == "":
		return
	var font := UiTheme.body_font()
	var used := used_font_size()
	var at := centred_origin(font, text, used, size)
	if outline_size > 0:
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, used, outline_size, outline_color)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, used, color)
