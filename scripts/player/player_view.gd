extends Node2D
## Placeholder visuals for the player. Reads state only, never changes gameplay.

const BODY_RADIUS := 7.0
const COLOR_BODY := Color("6fc3c9")
const COLOR_DASH := Color("bff4ff")
const COLOR_IFRAME := Color(1.0, 1.0, 1.0, 0.45)
const COLOR_AIM := Color("f2e6c2")

var _trail: Array[Vector2] = []

@onready var player: Player = get_parent()


func _process(_delta: float) -> void:
	_update_trail()
	queue_redraw()


func _update_trail() -> void:
	if player.dash.is_dashing():
		_trail.push_front(player.global_position)
		if _trail.size() > 6:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()


func _draw() -> void:
	for i in _trail.size():
		var alpha := 0.35 * (1.0 - float(i) / _trail.size())
		draw_circle(to_local(_trail[i]), BODY_RADIUS * 0.9, Color(COLOR_DASH, alpha))

	# Ground shadow.
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, BODY_RADIUS + 1.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

	var body_color := COLOR_BODY
	if player.dash.is_invulnerable():
		body_color = COLOR_IFRAME
	elif player.dash.is_dashing():
		body_color = COLOR_DASH
	draw_circle(Vector2(0, -2), BODY_RADIUS, body_color)
	draw_circle(Vector2(0, -2) + player.aim_direction * 3.0, 2.0, Color("1d1b26"))

	# Aim pointer.
	var aim := player.aim_direction
	var tip := aim * 16.0
	var side := aim.orthogonal() * 3.0
	draw_colored_polygon(PackedVector2Array([tip, aim * 11.0 + side, aim * 11.0 - side]), COLOR_AIM)
