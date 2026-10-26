class_name ClassEmblem
extends Control
## Provisional class icon: a framed diamond in the class resource colour with the
## class initial (procedural like ItemIcon; replaceable by a sprite via `texture`).
## Locked classes are drawn dimmed.

var definition: ClassDefinition
var locked: bool = false
## Optional real icon; drawn instead of the procedural emblem.
var texture: Texture2D


func setup(target: ClassDefinition, is_locked: bool, edge: float = 48.0) -> ClassEmblem:
	definition = target
	locked = is_locked
	custom_minimum_size = Vector2.ONE * edge
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _draw() -> void:
	if definition == null or size.x < 4.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	if texture != null:
		draw_texture_rect(texture, rect, false, Color(1, 1, 1, 0.45 if locked else 1.0))
		return
	var tint := definition.resource.color if definition.resource != null else UiTheme.BRONZE_DIM
	if locked:
		tint = Color(UiTheme.TEXT_MUTED, 0.7)
	draw_rect(rect, UiTheme.PANEL_INSET)
	draw_rect(rect.grow(-1.0), UiTheme.BRONZE if not locked else UiTheme.BRONZE_DARK, false, 2.0)
	var center := rect.get_center()
	var radius := size.x * 0.34
	var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(diamond, Color(tint, 0.28))
	diamond.append(diamond[0])
	draw_polyline(diamond, tint, 2.0)
	var font := UiTheme.display_font()
	var font_size := int(size.y * 0.42)
	var initial := definition.display_name.left(1).to_upper()
	var text_size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			UiTheme.PARCHMENT if not locked else UiTheme.TEXT_MUTED)
