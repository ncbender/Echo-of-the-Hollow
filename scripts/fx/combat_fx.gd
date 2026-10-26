class_name CombatFx
extends Node2D
## Lightweight procedural combat effect (Combat Defense & Feedback 0.4): one node,
## one style, a fixed lifetime, frees itself. Purely visual - never reads or
## changes gameplay (hitboxes, damage). Pixel-art friendly: thin lines, small
## shapes, no full-screen flashes. Effects that follow something end as soon as
## `follow` is gone or `alive_check` returns false (buff over, death, class change).

enum Style {
	RING,        ## expanding ring (ground)
	SPARKS,      ## short radiating lines
	SLASH,       ## crescent stroke along `direction`
	CROSS,       ## two crossing slashes (finishers)
	STAR,        ## 4-point star burst (detonations, parries)
	GLYPH,       ## rotating triangle sigil (spell casts)
	AFTERIMAGE,  ## fading body silhouette (gap closers)
	FLASH,       ## small soft disc
	AURA,        ## pulsing ring around a followed node (buffs)
	TEXT,        ## short floating word (PARRY, BREAK ...)
}

var style: Style = Style.RING
var color: Color = Color.WHITE
var radius: float = 16.0
var lifetime: float = 0.3
var direction: Vector2 = Vector2.RIGHT
var text: String = ""
var follow: Node2D
var alive_check: Callable
var age: float = 0.0


## Adds an effect to `world` (usually the current map) at `at`. Returns it.
static func spawn(world: Node, at: Vector2, fx_style: Style, fx_color: Color, fx_radius: float = 16.0,
		fx_lifetime: float = 0.3, fx_direction: Vector2 = Vector2.RIGHT) -> CombatFx:
	var fx := CombatFx.new()
	fx.style = fx_style
	fx.color = fx_color
	fx.radius = fx_radius
	fx.lifetime = fx_lifetime
	fx.direction = fx_direction if fx_direction != Vector2.ZERO else Vector2.RIGHT
	fx.position = at
	if world != null and is_instance_valid(world):
		world.add_child(fx)
	return fx


## The node effects should be added to: the current scene, else `near`'s parent.
static func world_of(near: Node) -> Node:
	if near == null or not near.is_inside_tree():
		return null
	var scene := near.get_tree().current_scene
	return scene if scene != null else near.get_parent()


func _ready() -> void:
	z_index = -1 if style in [Style.RING, Style.AURA, Style.GLYPH] else 22


func _process(delta: float) -> void:
	age += delta
	var gone := follow != null and not is_instance_valid(follow)
	if not gone and alive_check.is_valid() and not alive_check.call():
		gone = true
	if gone or (lifetime > 0.0 and age >= lifetime):
		queue_free()
		return
	if follow != null:
		global_position = follow.global_position
	queue_redraw()


func progress() -> float:
	return clampf(age / lifetime, 0.0, 1.0) if lifetime > 0.0 else fmod(age, 1.0)


func _draw() -> void:
	var t := progress()
	var fade := 1.0 - t
	match style:
		Style.RING:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
			draw_arc(Vector2.ZERO, radius * (0.35 + 0.65 * t), 0.0, TAU, 36, Color(color, fade), 2.0 * fade + 1.0)
			draw_set_transform(Vector2.ZERO)
		Style.SPARKS:
			for i in 8:
				var a := TAU * i / 8.0 + 0.4 * sin(i * 1.7)
				var from := Vector2.from_angle(a) * radius * (0.2 + 0.6 * t)
				var to := Vector2.from_angle(a) * radius * (0.45 + 0.75 * t)
				draw_line(from, to, Color(color.lightened(0.3), fade), 1.0)
		Style.SLASH:
			var base := direction.angle()
			draw_arc(Vector2.ZERO, radius, base - 1.0, base - 1.0 + 2.0 * minf(1.0, t * 3.0), 14, Color(color, fade), 2.0)
			draw_arc(Vector2.ZERO, radius * 0.8, base - 0.8, base - 0.8 + 1.6 * minf(1.0, t * 3.0), 12, Color(color.lightened(0.5), fade * 0.7), 1.0)
		Style.CROSS:
			var grow := minf(1.0, t * 4.0)
			for a: float in [PI * 0.25, -PI * 0.25]:
				var axis := Vector2.from_angle(direction.angle() + a) * radius * grow
				draw_line(-axis, axis, Color(color, fade), 2.5)
				draw_line(-axis * 0.7, axis * 0.7, Color(Color.WHITE, fade * 0.8), 1.0)
		Style.STAR:
			var size := radius * (0.4 + 0.8 * t)
			for i in 4:
				var axis := Vector2.from_angle(PI * 0.5 * i + t * 0.6) * size
				draw_line(Vector2.ZERO, axis, Color(color, fade), 2.0)
				draw_line(Vector2.ZERO, axis.rotated(PI * 0.25) * 0.45, Color(color.lightened(0.4), fade), 1.0)
			draw_circle(Vector2.ZERO, radius * 0.25 * fade, Color(Color.WHITE, fade * 0.8))
		Style.GLYPH:
			draw_set_transform(Vector2.ZERO, age * 3.0, Vector2.ONE)
			var points := PackedVector2Array()
			for i in 4:
				points.append(Vector2.from_angle(TAU * i / 3.0) * radius)
			draw_polyline(points, Color(color, fade), 1.5)
			points.clear()
			for i in 4:
				points.append(Vector2.from_angle(TAU * i / 3.0 + PI) * radius * 0.8)
			draw_polyline(points, Color(color.lightened(0.3), fade * 0.8), 1.0)
			draw_set_transform(Vector2.ZERO)
		Style.AFTERIMAGE:
			draw_circle(Vector2(0, -2), 7.0, Color(color, 0.5 * fade))
			draw_circle(Vector2(0, -2), 4.0, Color(color.lightened(0.4), 0.4 * fade))
		Style.FLASH:
			draw_circle(Vector2.ZERO, radius * (0.5 + 0.5 * t), Color(color, 0.45 * fade))
		Style.AURA:
			var pulse := 0.5 + 0.5 * sin(age * 8.0)
			draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, radius + 2.0 * pulse, 0.0, TAU, 28, Color(color, 0.35 + 0.3 * pulse), 1.5)
			draw_set_transform(Vector2.ZERO)
			for i in 3:
				var a := age * 2.5 + TAU * i / 3.0
				draw_circle(Vector2(cos(a) * radius, -6 + sin(a * 2.0) * 4.0), 1.2, Color(color.lightened(0.3), 0.7))
		Style.TEXT:
			var font_size := 8
			var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			WorldText.draw(self, Vector2(-width * 0.5, -22 - 10.0 * t), text, font_size, Color(color, fade), 2, Color(0, 0, 0, fade))
