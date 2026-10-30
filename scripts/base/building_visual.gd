@tool
extends Node2D
## Placeholder building art: walls, roof, label and a small detail motif.

enum Detail { NONE, ANVIL, CRATES, FENCE }

@export var size: Vector2 = Vector2(56, 36)
@export var wall_color: Color = Color("6b5a4a")
@export var roof_color: Color = Color("8a4a3a")
@export var label: String = ""
@export var detail: Detail = Detail.NONE
## FENCE: only a fenced yard without a house.
@export var yard_only: bool = false


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	if yard_only:
		_draw_fence(rect)
	else:
		draw_rect(Rect2(rect.position + Vector2(2, 4), rect.size), Color(0, 0, 0, 0.3))
		draw_rect(rect, wall_color)
		var roof := PackedVector2Array([
			rect.position + Vector2(-4, 6), rect.position + Vector2(size.x * 0.5, -10),
			rect.position + Vector2(size.x + 4, 6)])
		draw_colored_polygon(roof, roof_color)
		draw_rect(Rect2(Vector2(-5, size.y * 0.5 - 12), Vector2(10, 12)), Color(0.18, 0.13, 0.1))
	match detail:
		Detail.ANVIL:
			var at := Vector2(size.x * 0.5 + 8, size.y * 0.5 - 6)
			draw_rect(Rect2(at + Vector2(-6, -3), Vector2(12, 4)), Color(0.35, 0.35, 0.4))
			draw_rect(Rect2(at + Vector2(-2, 1), Vector2(4, 5)), Color(0.28, 0.28, 0.32))
		Detail.CRATES:
			for i in 3:
				var at := Vector2(size.x * 0.5 + 4 + (i % 2) * 9, size.y * 0.5 - 8 - (i / 2) * 8)
				draw_rect(Rect2(at, Vector2(8, 8)), Color(0.55, 0.42, 0.26))
				draw_rect(Rect2(at, Vector2(8, 8)), Color(0.3, 0.22, 0.12), false, 1.0)
	if label != "":
		var font := UiTheme.body_font()
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var at := Vector2(-width * 0.5, -size.y * 0.5 - 14)
		WorldText.draw(self, at, label, 7, Color(1.0, 0.92, 0.75), 2, Color.BLACK)


func _draw_fence(rect: Rect2) -> void:
	draw_rect(rect, Color(0.3, 0.26, 0.18, 0.35))
	var post := Color(0.5, 0.38, 0.24)
	draw_rect(rect, post, false, 2.0)
	var x := rect.position.x
	while x <= rect.end.x:
		draw_rect(Rect2(Vector2(x - 1.5, rect.position.y - 3), Vector2(3, 5)), post)
		draw_rect(Rect2(Vector2(x - 1.5, rect.end.y - 3), Vector2(3, 5)), post)
		x += 12.0
