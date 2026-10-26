class_name SkillProjectile
extends Node2D
## Straight-flying projectile for skills (Arcane Bolt, Blade Fan ...). Generic
## combat piece: each tick it sweeps its path for hostile hurtboxes and calls
## `on_hit(hurtbox) -> bool` once per target; walls (layer 1) stop it.
## `payload` keeps the owning cast alive while the projectile flies.

var velocity: Vector2 = Vector2.ZERO
var max_distance: float = 200.0
var radius: float = 4.0
## Further targets it may pass through after the first (0 = stops at the first hit).
var pierce: int = 0
var team: StringName = &"player"
var on_hit: Callable
var payload: RefCounted
var color: Color = Color.WHITE

var traveled: float = 0.0
var _hit_ids: Dictionary = {}
var _trail: Array[Vector2] = []


func _ready() -> void:
	z_index = 25


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var motion := velocity * delta
	var space := get_world_2d().direct_space_state
	# Walls end the flight.
	var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + motion, 1)
	var wall := space.intersect_ray(ray)
	var end := global_position + motion
	if not wall.is_empty():
		end = wall.position
	for hurtbox in _sweep(space, global_position, end):
		if _hit_ids.has(hurtbox.get_instance_id()):
			continue
		_hit_ids[hurtbox.get_instance_id()] = true
		var accepted: bool = on_hit.call(hurtbox) if on_hit.is_valid() else false
		if accepted:
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
	traveled += global_position.distance_to(end)
	_trail.push_front(global_position)
	if _trail.size() > 4:
		_trail.pop_back()
	global_position = end
	if not wall.is_empty() or traveled >= max_distance:
		queue_free()


func _sweep(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	var segment := SegmentShape2D.new()
	segment.a = Vector2.ZERO
	segment.b = to - from
	var shapes: Array[Shape2D] = [segment]
	var circle := CircleShape2D.new()
	circle.radius = radius
	shapes.append(circle)
	for shape in shapes:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, from if shape is SegmentShape2D else to)
		query.collision_mask = 8
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.margin = radius
		for result in space.intersect_shape(query, 16):
			var hurtbox := result.collider as Hurtbox
			if hurtbox != null and hurtbox.team != team and not found.has(hurtbox):
				found.append(hurtbox)
	found.sort_custom(func(a: Hurtbox, b: Hurtbox) -> bool:
		return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position))
	return found


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for i in _trail.size():
		draw_circle(to_local(_trail[i]), radius * (0.8 - i * 0.15), Color(color, 0.35 - i * 0.08))
	draw_circle(Vector2.ZERO, radius + 1.0, Color(color, 0.4))
	draw_circle(Vector2.ZERO, radius * 0.7, color.lightened(0.4))
