class_name ClassChoiceStation
extends Interactable
## The heart of the Whispering Stone: opens the one-time choice of the first
## class (ClassChoicePanel) once all three echoes were walked.

@export var title: String = "Altar of Choice"


func _ready() -> void:
	super._ready()
	prompt = "Listen to %s" % title


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
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -2), Vector2(-7, -24), Vector2(0, -30), Vector2(7, -23), Vector2(9, -2)]), Color(0.45, 0.44, 0.5))
	draw_circle(Vector2(0, -16), 3.5, Color(color, 0.5 + 0.5 * pulse))
	WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -36), title, 7, color, 2, Color.BLACK)
