extends Node2D
## Floating damage number. Frees itself after `lifetime`.

var text: String = ""
var color: Color = Color.WHITE
var lifetime: float = 0.7
var _age: float = 0.0


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_age += delta
	position.y -= 28.0 * delta * (1.0 - _age / lifetime)
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var alpha := clampf(1.5 - _age / lifetime * 1.5, 0.0, 1.0)
	var size := 10
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-width * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
