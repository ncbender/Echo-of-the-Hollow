class_name MoveAction
extends SkillAction
## Attack lunge of a skill (Shadow Strike, Piercing Lunge): a SHORT forward
## step along the aim as part of the attack, like an AttackDefinition lunge.
## Uses Player.start_skill_motion - NOT the dash: no dash charges, no dash
## iFrames, walls and bodies stop it. Following actions (the strike) run when
## the step arrived. Free movement over longer distances is not allowed for
## skills (Class Combat Polish 0.3): longer moves are target-bound
## GapCloserActions. An optional hit strikes targets passed on the way.

## Hard upper limit for a free skill lunge (px, after mods).
const MAX_LUNGE := 40.0

@export var distance: float = 24.0
@export var duration: float = 0.1
## Strike along the path (null = pure movement).
@export var hit: SkillHitSpec
@export var hit_radius: float = 16.0
@export var trail_color: Color = Color(0.6, 0.5, 0.9)


func defers_following() -> bool:
	return true


func travel(params: SkillParams) -> float:
	return minf(distance * params.range_multiplier, MAX_LUNGE)


func execute(cast: SkillCast) -> void:
	var player := cast.player()
	var length := travel(cast.params)
	if hit != null:
		var zone := SkillZone.new()
		zone.radius = hit_radius * cast.params.radius_multiplier
		zone.duration = duration + 1.0 / 60.0
		zone.interval = 0.0
		zone.team = player.hurtbox.team
		zone.follow = player
		zone.color = trail_color
		zone.payload = cast
		var key := "path"
		zone.on_pulse = func(hurtbox: Hurtbox, _pulse: int) -> void:
			if cast.hit_count(key, hurtbox) == 0:
				cast.deliver(hurtbox, hit, player.global_position - cast.direction * 10.0, key)
		cast.spawn(zone, player.global_position)
	cast.move(cast.direction * length, length / maxf(duration, 0.01))


func describe(params: SkillParams) -> String:
	var text := "Lunges %d px forward as part of the attack (not a dash: no dash charge, no invulnerability)" % roundi(travel(params))
	if hit != null:
		text += "; strikes enemies on the way: %s" % SkillText.hit(hit, params)
	return text + "."
