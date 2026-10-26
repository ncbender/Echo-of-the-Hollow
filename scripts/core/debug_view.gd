class_name DebugView
extends RefCounted
## Static debug-draw toggles (no autoload needed). Toggled by the arena (F1).

const COLOR_LUNGE := Color(0.45, 1.0, 0.55, 0.9)
const COLOR_KNOCKBACK := Color(1.0, 0.35, 0.3, 0.95)

## F1: hitboxes, hurtboxes and the lunge/knockback vectors.
static var show_hitboxes: bool = true


## Draws `vector` 1:1 in world pixels from the canvas origin (the arrow tip marks
## where the movement ends). Only called while show_hitboxes is on.
static func draw_vector(canvas: CanvasItem, vector: Vector2, color: Color) -> void:
	if vector.length_squared() < 0.25:
		return
	var tip := vector
	var side := vector.normalized().orthogonal() * 2.0
	canvas.draw_line(Vector2.ZERO, tip, color, 1.0)
	canvas.draw_colored_polygon(PackedVector2Array([tip + vector.normalized() * 3.0, tip + side, tip - side]), color)
