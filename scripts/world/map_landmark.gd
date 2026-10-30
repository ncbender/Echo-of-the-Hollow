@tool
class_name MapLandmark
extends Marker2D
## A named place on the area map and minimap (Map & Fog of War 1.0): shown once its spot
## was explored, never before. Pure presentation data - no gameplay reads it.

@export var label: String = ""


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 6.0, Color(0.9, 0.8, 0.4, 0.6))
