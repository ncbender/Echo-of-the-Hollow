class_name GapCloserAction
extends SkillAction
## Target-bound gap closer (Shadowstep, Blade Rush - Class Combat Polish 0.3).
## Needs a living enemy within `max_range` inside the aim cone. The caster moves
## to a free spot right in front of it - never through walls or bodies, never a
## teleport, no dash charge, no iFrames - and the arrival hit lands only when
## the movement actually arrived. Without a valid, reachable target the skill
## is refused BEFORE any cost or cooldown (cast_error).
## Following actions of the skill run on arrival (defers_following).

const PLAYER_RADIUS := 6.0
const BODY_MASK := 1 | 4   # world + enemy bodies

@export var max_range: float = 130.0
## Full width of the aim cone in which targets are acquired.
@export var cone_degrees: float = 70.0
## Minimum gap between caster and target centres on arrival (body radii are added).
@export var stop_distance: float = 16.0
## Travel speed in px/s (short distances take few ticks).
@export var speed: float = 600.0
## Enemies passed on the way are struck once (null = none).
@export var path_hit: SkillHitSpec
@export var path_radius: float = 14.0
## Hit on the target when the caster arrived (null = none).
@export var arrival_hit: SkillHitSpec
@export var trail_color: Color = Color(0.6, 0.5, 0.9)


func defers_following() -> bool:
	return true


func cast_error(runtime: ClassRuntime, params: SkillParams) -> String:
	var plan := plan_for(runtime.player, runtime.effects, params.range_multiplier)
	return plan.get("error", "")


## {"target": Hurtbox, "destination": Vector2} or {"error": String}.
func plan_for(player: Player, runner: ItemEffectRunner, range_multiplier: float = 1.0) -> Dictionary:
	if player == null or not player.is_inside_tree():
		return {"error": "No target."}
	var origin := player.global_position
	var aim := player.aim_direction
	var reach := max_range * range_multiplier
	var best: Hurtbox = null
	var best_score := INF
	for hurtbox in runner.query_hurtboxes(origin, reach):
		var entity := hurtbox.get_entity()
		var health := entity.get_node_or_null("HealthComponent") as HealthComponent
		if health != null and health.is_dead():
			continue
		var to := hurtbox.global_position - origin
		var angle := absf(aim.angle_to(to)) if to.length() > 1.0 else 0.0
		if angle > deg_to_rad(cone_degrees) * 0.5:
			continue
		var score := angle + to.length() / reach * 0.35
		if score < best_score:
			best_score = score
			best = hurtbox
	if best == null:
		return {"error": "No enemy in range in front of you."}
	var target := best.get_entity() as Node2D
	var to_target := target.global_position - origin
	var gap := maxf(stop_distance, _body_radius(target) + PLAYER_RADIUS + 2.0)
	var destination := origin
	if to_target.length() > gap:
		destination = target.global_position - to_target.normalized() * gap
	var space := player.get_world_2d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	if target is CollisionObject2D:
		exclude.append((target as CollisionObject2D).get_rid())
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = BODY_MASK
	query.exclude = exclude
	query.transform = Transform2D(0.0, origin)
	query.motion = destination - origin
	if query.motion.length() > 0.5:
		var fractions := space.cast_motion(query)
		if fractions.size() == 2 and fractions[0] < 0.999:
			return {"error": "The way to the target is blocked."}
	query.motion = Vector2.ZERO
	query.transform = Transform2D(0.0, destination)
	if not space.intersect_shape(query, 1).is_empty():
		return {"error": "No room next to the target."}
	return {"target": best, "destination": destination}


func execute(cast: SkillCast) -> void:
	var player := cast.player()
	var plan := plan_for(player, cast.runtime.effects, cast.params.range_multiplier)
	if plan.has("error"):
		cast.arrive(false)   # checked before the cast; a target vanished this tick
		return
	var target: Hurtbox = plan.target
	var motion: Vector2 = plan.destination - player.global_position
	cast.direction = motion.normalized() if motion.length() > 0.5 else (target.global_position - player.global_position).normalized()
	cast.arrival = func() -> void:
		if arrival_hit != null and is_instance_valid(target) \
				and player.global_position.distance_to(target.global_position) <= _reach(target):   # hit only if the caster really arrived
			cast.deliver(target, arrival_hit, player.global_position, "arrival")
	if path_hit != null:
		var zone := SkillZone.new()
		zone.radius = path_radius
		zone.duration = motion.length() / speed + 1.0 / 60.0
		zone.interval = 0.0
		zone.team = player.hurtbox.team
		zone.follow = player
		zone.color = trail_color
		zone.payload = cast
		zone.on_pulse = func(hurtbox: Hurtbox, _pulse: int) -> void:
			if hurtbox != target and cast.hit_count("path", hurtbox) == 0:
				cast.deliver(hurtbox, path_hit, player.global_position, "path")
		cast.spawn(zone, player.global_position)
	# afterimages along the path (visual only)
	var world := CombatFx.world_of(player)
	for i in 3:
		var ghost := CombatFx.spawn(world, player.global_position + motion * (i / 3.0), CombatFx.Style.AFTERIMAGE, trail_color, 7.0, 0.22 + 0.06 * i)
		ghost.z_index = 4
	cast.move(motion, speed)


func _reach(target: Hurtbox) -> float:
	return maxf(stop_distance, _body_radius(target.get_entity()) + PLAYER_RADIUS + 2.0) + 10.0


static func _body_radius(entity: Node) -> float:
	for child in entity.get_children():
		var shape := child as CollisionShape2D
		if shape != null and shape.shape is CircleShape2D:
			return (shape.shape as CircleShape2D).radius
	return 8.0


func describe(params: SkillParams) -> String:
	var text := "Closes in on an enemy in front of you (up to %d px). Needs a reachable target: without one nothing is spent. Not a dash: no dash charge, no invulnerability" % roundi(max_range * params.range_multiplier)
	if path_hit != null:
		text += "; grazes enemies on the way: %s" % SkillText.hit(path_hit, params)
	if arrival_hit != null:
		text += "; on arrival: %s" % SkillText.hit(arrival_hit, params)
	return text + "."
