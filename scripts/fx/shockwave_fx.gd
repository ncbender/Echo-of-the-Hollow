extends Node2D
## Expanding ring for area item effects (Echo Shockwave, essence discharge).
## Purely visual; frees itself.

var radius: float = 52.0
var lifetime: float = 0.3
var color: Color = Color(1.0, 0.7, 0.3)
var _age: float = 0.0


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var ring := Color(color, 1.0 - t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * t), 0.0, TAU, 40, ring, 3.0 * (1.0 - t) + 1.0)
	draw_circle(Vector2.ZERO, radius * 0.3 * (1.0 - t), Color(color.lightened(0.4), 0.4 * (1.0 - t)))
