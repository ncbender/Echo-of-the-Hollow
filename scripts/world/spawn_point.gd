@tool
class_name SpawnPoint
extends Marker2D
## Named spawn position of a map (target of transitions, saves and respawn).

@export var spawn_id: StringName = &"default"


func _ready() -> void:
	add_to_group(&"spawn_point")


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 4.0, Color(0.4, 1.0, 0.5, 0.6))
