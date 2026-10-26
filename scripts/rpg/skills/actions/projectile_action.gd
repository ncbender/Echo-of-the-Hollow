class_name ProjectileAction
extends SkillAction
## Fires projectiles along the aim (Arcane Bolt, Astral Lance, Blade Fan ...).
## Extra projectiles from mods fan out; pierce lets them pass through targets.

@export var count: int = 1
## Total fan angle for count > 1.
@export var spread_degrees: float = 18.0
@export var speed: float = 260.0
@export var max_distance: float = 180.0
@export var radius: float = 4.0
@export var pierce: int = 0
@export var hit: SkillHitSpec
@export var color: Color = Color(0.8, 0.6, 1.0)
## Look of the projectile: 0 orb (arcane), 1 shard (frost, lance), 2 knife.
@export_enum("Orb", "Shard", "Knife") var shape: int = 0


func execute(cast: SkillCast) -> void:
	var total := maxi(1, count + cast.params.extra_projectiles)
	var spread := deg_to_rad(spread_degrees if total > 1 else 0.0)
	var origin := cast.player().global_position + cast.direction * 6.0
	for index in total:
		var angle := 0.0 if total == 1 else -spread * 0.5 + spread * index / (total - 1)
		var projectile := SkillProjectile.new()
		projectile.velocity = cast.direction.rotated(angle) * speed
		projectile.max_distance = max_distance * cast.params.range_multiplier
		projectile.radius = radius * cast.params.radius_multiplier
		projectile.pierce = pierce + cast.params.extra_pierce
		projectile.team = cast.player().hurtbox.team
		projectile.color = color
		projectile.shape = shape
		projectile.payload = cast
		projectile.on_hit = func(hurtbox: Hurtbox) -> bool:
			return cast.deliver(hurtbox, hit, projectile.global_position - projectile.velocity.normalized() * 8.0, "projectile:%d" % index) != null
		cast.spawn(projectile, origin)


func describe(params: SkillParams) -> String:
	var total := maxi(1, count + params.extra_projectiles)
	var pierce_text := ", piercing %d" % (pierce + params.extra_pierce) if pierce + params.extra_pierce > 0 else ""
	return "Fires %d projectile%s (range %d%s): %s." % [total, "s" if total > 1 else "",
		roundi(max_distance * params.range_multiplier), pierce_text, SkillText.hit(hit, params)]
