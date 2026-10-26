class_name MapGate
extends Interactable
## A gate used with G (unlike MapTransition, which triggers on touch): travels
## to `target_map_id` / `target_spawn_id` through SessionState.travel().

@export var target_map_id: StringName
@export var target_spawn_id: StringName = &"default"
@export var label: String = ""
@export var color: Color = Color(0.7, 0.6, 1.0)


func interact(_hud: GameHud) -> void:
	var session := SessionState.find(get_tree())
	if session != null:
		session.travel(target_map_id, target_spawn_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.6, 1.0))
	draw_circle(Vector2.ZERO, 18.0, Color(color, 0.18))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(color, 0.4 + 0.3 * pulse), 2.0)
	draw_set_transform(Vector2.ZERO)
	if label != "":
		var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		WorldText.draw(self, Vector2(-width * 0.5, -26), label, 7, color.lightened(0.3), 2, Color.BLACK)
