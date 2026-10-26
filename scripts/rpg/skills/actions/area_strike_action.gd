class_name AreaStrikeAction
extends SkillAction
## Instant strike around or in front of the caster (Furious Strike, Warbreaker,
## Mana Pulse, Execution ...): every hostile hurtbox in the sector is hit once.

const FX_SCRIPT: GDScript = preload("res://scripts/fx/shockwave_fx.gd")

@export var radius: float = 34.0
## Sector width around the aim direction; >= 360 hits all around.
@export var arc_degrees: float = 120.0
## Sector centre in front of the caster (px along the aim).
@export var forward_offset: float = 0.0
@export var hit: SkillHitSpec
@export var fx_color: Color = Color(1.0, 0.8, 0.5)


func execute(cast: SkillCast) -> void:
	var center := cast.player().global_position + cast.direction * forward_offset
	var reach := radius * cast.params.radius_multiplier
	for hurtbox in cast.targets_in(center, reach, arc_degrees, cast.direction):
		cast.deliver(hurtbox, hit, center, "strike")
	var fx: Node2D = FX_SCRIPT.new()
	fx.set(&"radius", reach)
	fx.set(&"color", fx_color)
	fx.set(&"lifetime", 0.22)
	cast.spawn(fx, center)


func describe(params: SkillParams) -> String:
	var shape := "around you" if arc_degrees >= 360.0 else "in a %d° arc" % roundi(arc_degrees)
	return "Strikes %s (radius %d): %s." % [shape, roundi(radius * params.radius_multiplier), SkillText.hit(hit, params)]
