class_name ClassChoiceStation
extends Interactable
## Prologue altar: opens the one-time starting class choice (ClassChoicePanel).


func _ready() -> void:
	super._ready()
	prompt = "Choose your class"


func interact(hud: GameHud) -> void:
	hud.open_class_choice(self)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.002)
	var color := Color(1.0, 0.85, 0.45)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 28.0, Color(color, 0.12))
	for i in 3:
		draw_arc(Vector2.ZERO, 14.0 + i * 7.0, 0.0, TAU, 32, Color(color, 0.25 + 0.25 * pulse), 1.5)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-6, -20, 12, 18), Color(0.45, 0.4, 0.3))
	draw_circle(Vector2(0, -24), 5.0, Color(color, 0.6 + 0.4 * pulse))
	var text := "Altar of Choice"
	var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	WorldText.draw(self, Vector2(-width * 0.5, -34), text, 7, color, 2, Color.BLACK)
