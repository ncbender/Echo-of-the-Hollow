class_name AttackHitbox
extends Node2D
## Sector-shaped hit query around the attacker. Queries the physics space directly
## while active (no Area2D overlap latency) and remembers every hurtbox already hit
## during the current activation, so one swing never hits the same target twice -
## unless the attack declares an explicit multi-hit limit (max_hits_per_target,
## rehit_interval on the attack clock) or a target cap (max_targets).

const ARC_SEGMENTS := 10
const COLOR_ACTIVE := Color(1.0, 0.3, 0.25, 0.4)
const COLOR_ARMED := Color(1.0, 0.85, 0.3, 0.7)

@export_flags_2d_physics var hurtbox_mask: int = 8
@export var team: StringName = &"player"

var reach: float = 30.0
var arc_degrees: float = 90.0
var direction: Vector2 = Vector2.RIGHT
## True between attack start and the end of the active window (shows the outline).
var armed: bool = false
## Hit limits of the current activation (set by configure_limits; defaults = one hit per target).
var max_hits_per_target: int = 1
var rehit_interval: float = 0.0
var max_targets: int = 0
## Attack clock in seconds, advanced by the owner (pauses with hitstop).
var clock: float = 0.0

var _active: bool = false
var _hit_ids: Dictionary = {}   # hurtbox instance id -> [hits, clock of the last hit]
var _shape := ConvexPolygonShape2D.new()


func configure(new_reach: float, new_arc_degrees: float, new_direction: Vector2) -> void:
	reach = new_reach
	arc_degrees = clampf(new_arc_degrees, 1.0, 180.0)
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.RIGHT
	_shape.points = sector_points()
	configure_limits(1, 0.0, 0)


func configure_limits(hits_per_target: int, interval: float, targets: int) -> void:
	max_hits_per_target = maxi(1, hits_per_target)
	rehit_interval = maxf(0.0, interval)
	max_targets = maxi(0, targets)


func activate() -> void:
	_active = true
	_hit_ids.clear()


func deactivate() -> void:
	_active = false
	armed = false


func is_active() -> bool:
	return _active


## Hurtboxes overlapping the sector that may be hit now: not yet hit in this
## activation, or (multi-hit attacks) below their hit limit and past the rehit interval.
func scan() -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	if not _active or not is_inside_tree():
		return found
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(direction.angle(), global_position)
	query.collision_mask = hurtbox_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for result in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := result.collider as Hurtbox
		if hurtbox == null or hurtbox.team == team or not _may_hit(hurtbox.get_instance_id()):
			continue
		if max_targets > 0 and not _hit_ids.has(hurtbox.get_instance_id()) and _hit_ids.size() + _new_count(found) >= max_targets:
			continue
		found.append(hurtbox)
	return found


func mark_hit(hurtbox: Hurtbox) -> void:
	var entry: Array = _hit_ids.get(hurtbox.get_instance_id(), [0, 0.0])
	_hit_ids[hurtbox.get_instance_id()] = [int(entry[0]) + 1, clock]


## Hits this activation dealt to `hurtbox`.
func hits_on(hurtbox: Hurtbox) -> int:
	var entry: Array = _hit_ids.get(hurtbox.get_instance_id(), [0, 0.0])
	return int(entry[0])


func _may_hit(instance_id: int) -> bool:
	if not _hit_ids.has(instance_id):
		return true
	var entry: Array = _hit_ids[instance_id]
	return int(entry[0]) < max_hits_per_target and clock - float(entry[1]) >= rehit_interval - 0.00001


func _new_count(found: Array[Hurtbox]) -> int:
	var count := 0
	for hurtbox in found:
		if not _hit_ids.has(hurtbox.get_instance_id()):
			count += 1
	return count


func hit_count() -> int:
	return _hit_ids.size()


## Sector polygon in local space, pointing along +X (rotated by `direction` when queried).
## The apex sits 1 px behind the origin so a 180° sector stays strictly convex.
func sector_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(-1.0, 0.0)])
	var half := deg_to_rad(arc_degrees) * 0.5
	for i in ARC_SEGMENTS + 1:
		var angle := -half + (2.0 * half) * float(i) / ARC_SEGMENTS
		points.append(Vector2.from_angle(angle) * reach)
	return points


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not DebugView.show_hitboxes or not (armed or _active):
		return
	var points := sector_points()
	var rotated := PackedVector2Array()
	for point in points:
		rotated.append(point.rotated(direction.angle()))
	if _active:
		draw_colored_polygon(rotated, COLOR_ACTIVE)
	rotated.append(rotated[0])
	draw_polyline(rotated, COLOR_ARMED if not _active else Color(COLOR_ACTIVE, 0.9), 1.0)
