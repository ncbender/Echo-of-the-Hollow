class_name MapTransition
extends Area2D
## Walking into this area loads `target_map_id` and spawns the player at
## `target_spawn_id`. The character itself lives in the session, so nothing is
## copied: the next map simply binds its own Player to the same Character.

signal transition_requested(map_id: StringName, spawn_id: StringName)

@export var target_map_id: StringName
@export var target_spawn_id: StringName = &"default"
@export var label: String = ""

var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body is Player:
		return
	_used = true   # one request per arrival, even if the body re-enters this frame
	transition_requested.emit(target_map_id, target_spawn_id)
	var session := SessionState.find(get_tree())
	if session != null:
		session.travel(target_map_id, target_spawn_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	var color := Color(0.65, 0.5, 1.0, 0.35 + 0.3 * pulse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.55, 1.0))
	draw_circle(Vector2.ZERO, 18.0, Color(color, 0.18))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, color, 2.0)
	draw_set_transform(Vector2.ZERO)
	if label != "":
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		WorldText.draw(self, Vector2(-width * 0.5, -24), label, 7, Color(0.85, 0.8, 1.0), 2, Color.BLACK)
