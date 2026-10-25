@tool
class_name WallBlock
extends StaticBody2D
## Rectangular placeholder obstacle. Builds its own collision shape from `size`
## so arena layouts stay a one-line edit in the scene.

@export var size: Vector2 = Vector2(32, 32):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color("3b3647")
@export var top_color: Color = Color("57506a")

var _shape_node: CollisionShape2D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape_node == null:
		_shape_node = CollisionShape2D.new()
		add_child(_shape_node, false, Node.INTERNAL_MODE_FRONT)
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape_node.shape = rect
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, color)
	# Lighter top face fakes the oblique top-down perspective.
	draw_rect(Rect2(rect.position, Vector2(size.x, minf(6.0, size.y * 0.3))), top_color)
