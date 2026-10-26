@tool
extends Node2D
## Draws a checkered placeholder floor so movement speed is readable.

@export var area: Rect2 = Rect2(-320, -200, 640, 400)
@export var tile_size: float = 32.0
@export var color_a: Color = Color("24212e")
@export var color_b: Color = Color("29263a")


func _draw() -> void:
	var columns := ceili(area.size.x / tile_size)
	var rows := ceili(area.size.y / tile_size)
	for x in columns:
		for y in rows:
			var tile := Rect2(area.position + Vector2(x, y) * tile_size, Vector2.ONE * tile_size).intersection(area)
			draw_rect(tile, color_a if (x + y) % 2 == 0 else color_b)
