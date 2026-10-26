class_name WorldText
extends RefCounted
## Crisp text inside the zoomed game world (damage numbers, labels on plots,
## stations, dummies). Fonts are rasterized for the viewport's stretch scale only;
## text drawn at 8 px under a 3.75x camera zoom would be magnified and blocky.
## This draws the glyphs at their final on-screen size under a counter-scaled
## transform, so `size` keeps meaning "world pixels" while staying sharp at any
## resolution and UI scale (docs/DISPLAY_AND_UI_STANDARD.md).


## Draws `text` with its baseline-left at `at` (local coordinates of `canvas`).
## Leaves the canvas draw transform reset to identity.
static func draw(canvas: CanvasItem, at: Vector2, text: String, size: float, color: Color,
		outline_size: float = 0.0, outline_color: Color = Color.BLACK) -> void:
	var scale := _world_to_canvas_scale(canvas)
	var font := ThemeDB.fallback_font
	var font_px := maxi(1, roundi(size * scale))
	canvas.draw_set_transform(at, 0.0, Vector2.ONE / scale)
	if outline_size > 0.0:
		canvas.draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px,
				maxi(1, roundi(outline_size * scale)), outline_color)
	canvas.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, color)
	canvas.draw_set_transform(Vector2.ZERO)


## Width of `text` in world pixels at `size`.
static func width(text: String, size: float) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(size))).x


static func _world_to_canvas_scale(canvas: CanvasItem) -> float:
	var scale := absf(canvas.get_global_transform_with_canvas().get_scale().x)
	return scale if scale > 0.001 else 1.0
