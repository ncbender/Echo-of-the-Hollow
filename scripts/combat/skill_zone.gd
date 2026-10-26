class_name SkillZone
extends Node2D
## Area that pulses on hostile hurtboxes for a while (Whirlwind, Arcane Rift,
## Rune Sigil, Smoke Veil, strikes along a skill movement). Generic combat piece:
## after `delay`, every `interval` seconds (0 = every tick) it calls
## `on_pulse(hurtbox, pulse_index) -> bool` for each hostile hurtbox inside, until
## `duration` ends. Optionally follows a node (the player while spinning).

var radius: float = 30.0
var delay: float = 0.0
var duration: float = 0.5
var interval: float = 0.25
var team: StringName = &"player"
var follow: Node2D
var on_pulse: Callable
## Called once when the zone ends (detonations, cleanup).
var on_end: Callable
var payload: RefCounted
var color: Color = Color.WHITE
## Visual style: 0 = ring, 1 = sigil (runes), 2 = cloud.
var style: int = 0

var age: float = 0.0
var pulses: int = 0
var _next_pulse: float = 0.0


func _ready() -> void:
	z_index = -1 if style == 2 else 15
	_next_pulse = delay


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	age += delta
	while age + 0.00001 >= _next_pulse and _next_pulse <= delay + duration + 0.00001:
		_pulse()
		_next_pulse += maxf(interval, 1.0 / 60.0)
	if age >= delay + duration:
		if on_end.is_valid():
			on_end.call()
		queue_free()


func is_armed() -> bool:
	return age >= delay


func hostile_hurtboxes() -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	if not is_inside_tree():
		return found
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.collider as Hurtbox
		if hurtbox != null and hurtbox.team != team:
			found.append(hurtbox)
	return found


func _pulse() -> void:
	for hurtbox in hostile_hurtboxes():
		if on_pulse.is_valid():
			on_pulse.call(hurtbox, pulses)
	pulses += 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var armed := is_armed()
	var fade := clampf((delay + duration - age) / 0.2, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	match style:
		1:
			var spin := age * 2.0
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, (0.9 if armed else 0.4) * fade), 1.5)
			for i in 6:
				var a := spin + TAU * i / 6.0
				draw_line(Vector2.from_angle(a) * radius * 0.4, Vector2.from_angle(a + 1.2) * radius * 0.85,
						Color(color, 0.7 * fade), 1.0)
		2:
			for i in 5:
				var offset := Vector2.from_angle(age * 0.7 + TAU * i / 5.0) * radius * 0.35
				draw_circle(offset, radius * 0.6, Color(color, 0.18 * fade))
		_:
			draw_circle(Vector2.ZERO, radius, Color(color, (0.16 if armed else 0.06) * fade))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.8 * fade), 1.5)
	draw_set_transform(Vector2.ZERO)
