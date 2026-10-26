class_name MoveAction
extends SkillAction
## Skill movement along the aim (Blade Rush, Shadowstep). Uses
## Player.start_skill_motion - NOT the dash: no dash charges, no dash iFrames,
## walls and bodies stop it. An optional hit strikes targets passed on the way
## (once per target).

@export var distance: float = 70.0
@export var duration: float = 0.15
## Strike along the path (null = pure movement).
@export var hit: SkillHitSpec
@export var hit_radius: float = 16.0
@export var trail_color: Color = Color(0.6, 0.5, 0.9)


func execute(cast: SkillCast) -> void:
	var player := cast.player()
	var travel := distance * cast.params.range_multiplier
	player.start_skill_motion(cast.direction * travel / maxf(duration, 0.01), duration)
	var zone := SkillZone.new()
	zone.radius = hit_radius * cast.params.radius_multiplier
	zone.duration = duration + 1.0 / 60.0
	zone.interval = 0.0
	zone.team = player.hurtbox.team
	zone.follow = player
	zone.color = trail_color
	zone.payload = cast
	if hit != null:
		var key := "path"
		zone.on_pulse = func(hurtbox: Hurtbox, _pulse: int) -> void:
			if cast.hit_count(key, hurtbox) == 0:
				cast.deliver(hurtbox, hit, player.global_position - cast.direction * 10.0, key)
	cast.spawn(zone, player.global_position)


func describe(params: SkillParams) -> String:
	var text := "Moves %d px towards the cursor (not a dash: no dash charge, no invulnerability)" % roundi(distance * params.range_multiplier)
	if hit != null:
		text += "; strikes enemies on the way: %s" % SkillText.hit(hit, params)
	return text + "."
