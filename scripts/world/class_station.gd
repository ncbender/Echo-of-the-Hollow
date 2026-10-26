class_name ClassStation
extends Interactable
## Safe place where the active class may be changed. In the test arena this is a
## debug station; later a camp/shrine/base building provides the same interface.


func interact(hud: GameHud) -> void:
	hud.open_class_panel(self)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
	var color := Color(0.55, 0.8, 1.0, 0.35 + (0.3 if player_inside else 0.0) * pulse)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 22.0, Color(color, 0.15))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, color, 1.5)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 6, color, 1.0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-3, -16, 6, 14), Color(0.42, 0.4, 0.55))
	draw_circle(Vector2(0, -18), 3.0, Color(0.6, 0.85, 1.0, 0.6 + 0.4 * pulse))
	var font := ThemeDB.fallback_font
	var text := "Class Station"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	WorldText.draw(self, Vector2(-width * 0.5, -24), text, 7, Color(0.8, 0.9, 1.0), 2, Color.BLACK)
