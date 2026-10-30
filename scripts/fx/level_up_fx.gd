class_name LevelUpFx
extends Node2D
## Loot & Progress Feedback 1.0: the short world pulse of a real level-up, a child of the player (follows the hero,
## freed with the map - never left behind at an old position). Procedural pixel art, whole pixels, no blur, no
## gameplay. HERO: a gold ring widening from the feet and a few square sparks rising (0.9 s). MASTERY: smaller and
## different in shape and colour - a steel-cyan diamond outline flashing outward at weapon height (0.45 s).

enum { HERO, MASTERY }

const HERO_TIME := 0.9
const MASTERY_TIME := 0.45
## Rising sparks of the hero pulse: [x offset, start delay, speed px/s, size].
const SPARKS := [[-14, 0.0, 46, 3], [-6, 0.12, 58, 2], [3, 0.05, 52, 3], [11, 0.18, 40, 2], [16, 0.08, 62, 2], [-18, 0.22, 50, 2]]
const GOLD := Color("e2c27a")
const GOLD_DARK := Color("8a6a35")

var kind: int = HERO
var age: float = 0.0


func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func duration() -> float:
	return HERO_TIME if kind == HERO else MASTERY_TIME


func _process(delta: float) -> void:
	age += delta
	if age >= duration():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := age / duration()
	if kind == HERO:
		_draw_hero(t)
	else:
		_draw_mastery(t)


## Gold ring (flattened like the ground shadow) widening and fading, square sparks rising beside the hero.
func _draw_hero(t: float) -> void:
	var radius := roundf(lerpf(10.0, 34.0, ease(t, 0.5)))
	var alpha := 1.0 - t
	var points := PackedVector2Array()
	for i in 33:
		var angle := TAU * i / 32.0
		points.append((Vector2(cos(angle) * radius, sin(angle) * radius * 0.45) + Vector2(0, 6)).round())
	draw_polyline(points, Color(GOLD_DARK, alpha), 3.0)
	draw_polyline(points, Color(GOLD, alpha), 1.0)
	for spark: Array in SPARKS:
		var life := age - float(spark[1])
		if life <= 0.0:
			continue
		var rise := life * float(spark[2])
		var size := float(spark[3])
		var at := Vector2(float(spark[0]), -6.0 - rise).round()
		draw_rect(Rect2(at, Vector2.ONE * size), Color(GOLD, clampf(1.0 - rise / 44.0, 0.0, 1.0)))


## A diamond outline (four corners, never a circle) flashing outward around the weapon height, steel-cyan.
func _draw_mastery(t: float) -> void:
	var reach := roundf(lerpf(6.0, 22.0, ease(t, 0.4)))
	var alpha := 1.0 - t
	var centre := Vector2(0, -6)
	var diamond := PackedVector2Array([centre + Vector2(0, -reach), centre + Vector2(reach, 0), centre + Vector2(0, reach),
		centre + Vector2(-reach, 0), centre + Vector2(0, -reach)])
	draw_polyline(diamond, Color(UiTheme.RESONANCE_DIM, alpha), 3.0)
	draw_polyline(diamond, Color(Color("d8f2f6"), alpha), 1.0)
