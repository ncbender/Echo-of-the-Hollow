class_name SkillCast
extends RefCounted
## Runtime state of ONE skill cast: origin, aim, resolved params and the hits
## already dealt. Actions use it to find targets and to deliver hits; projectile
## and zone nodes keep it alive while they exist.
## deliver() is the only place a skill hit is built: HitData (source SKILL) ->
## status interplay -> AttackModifiers that opt into skill hits -> target Hurtbox
## -> statuses, resource, ItemEffectRunner.dispatch_hit (one event stream).

var runtime: ClassRuntime
var skill: SkillDefinition
var params: SkillParams
var origin: Vector2
var direction: Vector2
var cast_id: int = 0
## Damage factor for this cast only (empowered follow-ups).
var damage_scale: float = 1.0
var hits_landed: int = 0
## Runs once the caster arrived (movement actions); then `pending` follow.
var arrival: Callable
var pending: Array[SkillAction] = []
## Targets hit per key ("strike", "zone:3" ...): instance id -> hit count.
var _hit_counts: Dictionary = {}


func player() -> Player:
	return runtime.player


## Hurtboxes of hostile teams within `radius` of `center`, optionally limited to
## a sector of `arc_degrees` around `facing` (>= 360 = full circle).
func targets_in(center: Vector2, radius: float, arc_degrees: float = 360.0, facing: Vector2 = Vector2.ZERO) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	for hurtbox in runtime.effects.query_hurtboxes(center, radius):
		if arc_degrees < 360.0 and facing != Vector2.ZERO:
			var to_target := hurtbox.global_position - center
			if to_target.length() > 2.0 and absf(facing.angle_to(to_target)) > deg_to_rad(arc_degrees) * 0.5:
				continue
		result.append(hurtbox)
	return result


## How often `hurtbox` was hit under `key` in this cast.
func hit_count(key: String, hurtbox: Hurtbox) -> int:
	return _hit_counts.get(key, {}).get(hurtbox.get_instance_id(), 0)


## Delivers one hit of `spec` to `hurtbox`. `from` is the knockback origin.
## Returns the accepted HitData or null (friendly, invulnerable, dead).
func deliver(hurtbox: Hurtbox, spec: SkillHitSpec, from: Vector2, key: String = "") -> HitData:
	var player_node := player()
	if hurtbox == null or not is_instance_valid(hurtbox) or player_node == null \
			or hurtbox.team == player_node.hurtbox.team or hurtbox.is_invulnerable():
		return null
	var target := hurtbox.get_entity()
	var status := StatusComponent.of(target)
	var hit := HitData.new()
	hit.source = HitData.Source.SKILL
	hit.skill_id = skill.id
	hit.attacker = player_node
	hit.target = target
	hit.attack_instance_id = -cast_id   # negative: never collides with weapon swings
	hit.damage = spec.damage * params.damage_multiplier * damage_scale
	hit.poise_damage = spec.poise_damage * params.poise_multiplier
	hit.damage_type = spec.damage_type
	hit.hitstop = spec.hitstop
	hit.position = hurtbox.global_position
	var away := hurtbox.global_position - from
	hit.knockback = (away.normalized() if away.length() > 0.5 else direction) * spec.knockback
	hit.tags.assign(params.tags)
	hit.tags.append(&"skill")
	hit.tags.append_array(spec.tags)
	if status != null:
		if spec.bonus_status != &"" and status.has(spec.bonus_status):
			hit.damage *= spec.bonus_multiplier
			hit.tags.append(StringName("vs_%s" % spec.bonus_status))
		for status_id: StringName in params.status_bonus:
			if status.has(status_id):
				hit.damage *= params.status_bonus[status_id]
				hit.tags.append(StringName("vs_%s" % status_id))
		if spec.consume_status != &"":
			var consumed := status.consume(spec.consume_status)
			if consumed > 0:
				hit.damage += consumed * spec.consume_damage_per_stack * params.damage_multiplier * damage_scale
				hit.poise_damage += consumed * spec.consume_poise_per_stack
				hit.tags.append(StringName("consumed_%s" % spec.consume_status))
				runtime.note_consumed(spec.consume_status, consumed, target)
	for modifier in player_node.combat.modifiers:
		if modifier.applies_to_skill_hits():
			modifier.modify_hit(hit)
	if not hurtbox.receive_hit(hit):
		return null
	hits_landed += 1
	_impact_fx(hurtbox, hit)
	if key != "":
		var counts: Dictionary = _hit_counts.get(key, {})
		counts[hurtbox.get_instance_id()] = counts.get(hurtbox.get_instance_id(), 0) + 1
		_hit_counts[key] = counts
	for spec_status in spec.statuses + params.statuses:
		if spec_status != null and runtime.rng.randf() < spec_status.chance:
			runtime.apply_status(target, spec_status.status_id, spec_status.power, spec_status.stacks)
	runtime.gain(spec.resource_on_hit + params.resource_on_hit)
	runtime.effects.dispatch_hit(hit)
	return hit


## Adds a purely visual or runtime node (projectile, zone, fx) to the world.
func spawn(node: Node2D, at: Vector2) -> void:
	runtime.effects.spawn_fx(node, at)


## Executes `actions` in order; a movement action defers the rest until arrival.
func run_actions(actions: Array[SkillAction]) -> void:
	for index in actions.size():
		var action := actions[index]
		if action.defers_following():
			pending.assign(actions.slice(index + 1))
			action.execute(self)
			return
		action.execute(self)


## Skill movement of `motion` at `speed` px/s through Player.start_skill_motion
## (exact distance, walls/bodies block, no dash charge, no iFrames).
func move(motion: Vector2, speed: float) -> void:
	var player_node := player()
	if motion.length() < 0.5 or speed <= 0.0:
		arrive(true)
		return
	runtime.hold_cast(self)
	player_node.skill_motion_finished.connect(arrive, CONNECT_ONE_SHOT)
	player_node.start_skill_motion(motion.normalized() * speed, motion.length() / speed)


## End of the movement: on arrival the arrival hit and the pending actions run;
## an interrupted movement (hit reaction, death) drops them.
func arrive(completed: bool) -> void:
	runtime.release_cast(self)
	if not completed or player() == null:
		pending.clear()
		arrival = Callable()
		return
	origin = player().global_position
	if arrival.is_valid():
		var callback := arrival
		arrival = Callable()
		callback.call()
	var rest: Array[SkillAction] = pending.duplicate()
	pending.clear()
	run_actions(rest)


## Visual feedback of an accepted skill hit: the skill's impact effect and, when
## the hit consumed a status (mark detonation, execution), a burst in that
## status's colour. Purely cosmetic.
func _impact_fx(hurtbox: Hurtbox, hit: HitData) -> void:
	var world := CombatFx.world_of(player())
	var fx := skill.fx
	if fx != null and fx.impact_style >= 0:
		CombatFx.spawn(world, hurtbox.global_position, fx.impact_style, fx.impact_color, fx.impact_radius, 0.3, direction)
	for tag in hit.tags:
		if String(tag).begins_with("consumed_"):
			var status: StatusEffectDefinition = runtime.character.database.statuses.get(StringName(String(tag).trim_prefix("consumed_")))
			var tint := status.color if status != null else Color.WHITE
			CombatFx.spawn(world, hurtbox.global_position, CombatFx.Style.STAR, tint, 22.0, 0.4)
			CombatFx.spawn(world, hurtbox.global_position, CombatFx.Style.RING, tint, 26.0, 0.35)
