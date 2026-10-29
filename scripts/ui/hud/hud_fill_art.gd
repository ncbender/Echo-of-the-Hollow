class_name HudFillArt
extends RefCounted
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): draws a frame asset over its tint mask, 1:1 in design px -
## the empty well in a dark tone, the fill from the bottom up to a share in whole texture rows (a lit surface
## row on top), then the frame. Used by the health / resource vessels (hud/vessel_*) and the quick-use bottles
## (hud/flask, hud/potion). Without the art the caller draws its procedural fallback (`available` is false).

## Dark tone of the empty inside (scaled like UiTheme.fill_box: the mask body is 0.847).
const WELL := Color("101114")
## The surface row of the fill is this much lighter.
const SURFACE_LIGHTEN := 0.35

static var _extents := {}   # mask -> Vector2i(first opaque row, last opaque row)


static func available(frame_id: StringName, mask_id: StringName) -> bool:
	return UiSkin.has(frame_id) and UiSkin.has(mask_id)


## First and last opaque row of `mask` (cached per texture).
static func extent(mask: Texture2D) -> Vector2i:
	if not _extents.has(mask):
		var image := mask.get_image()
		if image.is_compressed():
			image.decompress()
		var rows := Vector2i(image.get_height(), -1)
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					rows = Vector2i(mini(rows.x, y), maxi(rows.y, y))
					break
		_extents[mask] = rows
	return _extents[mask]


## Filled rows for `ratio` (0..1): 0 only for an empty share; any share above 0 shows at least `min_rows`.
static func fill_rows(mask: Texture2D, ratio: float, min_rows: int = 1) -> int:
	var rows := extent(mask)
	var total := rows.y - rows.x + 1
	if ratio <= 0.0 or total <= 0:
		return 0
	return clampi(roundi(ratio * total), mini(min_rows, total), total)


## Draws well, fill (`ratio` of the inside in `color`) and frame at `at` (top left, 1:1). `dim` darkens the
## frame (an unusable bottle, a class without resource).
static func draw(canvas: CanvasItem, at: Vector2, frame_id: StringName, mask_id: StringName, ratio: float,
		color: Color, min_rows: int = 1, dim: bool = false) -> void:
	var frame := UiSkin.texture(frame_id)
	var mask := UiSkin.texture(mask_id)
	if frame == null or mask == null:
		return
	var size := Vector2(mask.get_size())
	var body := UiTheme.BAR_FILL_BODY
	canvas.draw_texture_rect(mask, Rect2(at, size), false, Color(WELL.r / body, WELL.g / body, WELL.b / body))
	var rows := fill_rows(mask, ratio, min_rows)
	if rows > 0:
		var bottom := extent(mask).y + 1
		var tint := Color(color.r / body, color.g / body, color.b / body, color.a)
		var source := Rect2(0, bottom - rows, size.x, rows)
		canvas.draw_texture_rect_region(mask, Rect2(at + source.position, source.size), source, tint)
		var surface := Rect2(0, bottom - rows, size.x, 1)
		var lit := color.lightened(SURFACE_LIGHTEN)
		canvas.draw_texture_rect_region(mask, Rect2(at + surface.position, surface.size), surface, Color(lit.r / body, lit.g / body, lit.b / body))
	canvas.draw_texture_rect(frame, Rect2(at, Vector2(frame.get_size())), false, Color(0.55, 0.55, 0.55) if dim else Color.WHITE)


## A short number centred at `centre` (IBM Plex Mono, dark outline) - the vessels' value.
static func draw_number(canvas: CanvasItem, centre: Vector2, text: String, font_size: int, color: Color = UiTheme.PARCHMENT) -> void:
	var font := UiTheme.body_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := centre + Vector2(-roundf(width * 0.5), roundf((font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5))
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.92))
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
