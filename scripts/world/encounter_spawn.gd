@tool
class_name EncounterSpawn
extends Marker2D
## Where one enemy of an Encounter appears, and which variant (EnemyConfig).

@export var config: EnemyConfig


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.35, 0.3, 0.6))
