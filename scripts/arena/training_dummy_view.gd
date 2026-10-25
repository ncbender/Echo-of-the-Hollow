extends Node2D
## Placeholder visuals for the training dummy: post, body, health/poise bars.

const COLOR_WOOD := Color("8a6a48")
const COLOR_STRAW := Color("d8b86a")
const COLOR_DEAD := Color("4a4038")
const BAR_WIDTH := 22.0

@onready var dummy: TrainingDummy = get_parent()
@onready var fx: HitReactionFx = $"../HitReactionFx"


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var health := dummy.health
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

	var o := fx.offset
	var body := COLOR_STRAW if not health.is_dead() else COLOR_DEAD
	if health.is_staggered():
		body = body.lerp(Color("9fc8ff"), 0.5)
	body = body.lerp(Color.WHITE, fx.flash)
	draw_line(Vector2(0, 6), o * 0.4 + Vector2(0, -6), COLOR_WOOD, 3.0)
	draw_rect(Rect2(o + Vector2(-7, -18), Vector2(14, 16)), body)
	draw_circle(o + Vector2(0, -22), 5.0, body)
	draw_line(o + Vector2(-10, -13), o + Vector2(10, -13), COLOR_WOOD, 2.0)

	var top := Vector2(-BAR_WIDTH * 0.5, -34)
	draw_rect(Rect2(top, Vector2(BAR_WIDTH, 3)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(BAR_WIDTH * health.health / health.max_health, 3)), Color("d9534f"))
	draw_rect(Rect2(top + Vector2(0, 4), Vector2(BAR_WIDTH, 2)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top + Vector2(0, 4), Vector2(BAR_WIDTH * health.poise / health.max_poise, 2)), Color("e9c46a"))
	if health.is_staggered():
		_draw_label("BROKEN", Vector2(0, -38), Color("9fc8ff"))
	elif health.is_dead():
		_draw_label("DOWN", Vector2(0, -38), Color("c0c0c0"))


func _draw_label(text: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string_outline(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color.BLACK)
	draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
