class_name ZoneAction
extends SkillAction
## A lasting area (Whirlwind around the caster, Arcane Rift / Rune Sigil in
## front, Smoke Veil cloud). Pulses its hit on hostile targets; an optional
## `end_hit` fires once when the zone ends (sigil detonation).

enum Placement { FOLLOW_CASTER, AT_CASTER, AHEAD }

@export var placement: Placement = Placement.AHEAD
## Distance ahead of the caster for AHEAD.
@export var distance: float = 60.0
@export var radius: float = 30.0
@export var delay: float = 0.0
@export var duration: float = 1.0
## Seconds between pulses (0 = every tick).
@export var interval: float = 0.25
## Hits per target over the whole zone (0 = unlimited).
@export var max_hits_per_target: int = 0
## Pulsing hit (may be null for pure end-hit zones).
@export var hit: SkillHitSpec
## Hit dealt to every target inside when the zone ends.
@export var end_hit: SkillHitSpec
## Buff for the caster while standing inside (e.g. smoke): status of the zone.
@export var color: Color = Color(0.7, 0.6, 1.0)
@export_enum("Ring", "Sigil", "Cloud") var style: int = 0


func execute(cast: SkillCast) -> void:
	var zone := SkillZone.new()
	zone.radius = radius * cast.params.radius_multiplier
	zone.delay = delay
	zone.duration = duration
	zone.interval = interval
	zone.team = cast.player().hurtbox.team
	zone.color = color
	zone.style = style
	zone.payload = cast
	var at := cast.player().global_position
	match placement:
		Placement.FOLLOW_CASTER:
			zone.follow = cast.player()
		Placement.AHEAD:
			at += cast.direction * distance * cast.params.range_multiplier
	var key := "zone:%d" % zone.get_instance_id()
	if hit != null:
		zone.on_pulse = func(hurtbox: Hurtbox, _pulse: int) -> void:
			if max_hits_per_target <= 0 or cast.hit_count(key, hurtbox) < max_hits_per_target:
				cast.deliver(hurtbox, hit, zone.global_position, key)
	if end_hit != null:
		zone.on_end = func() -> void:
			for hurtbox in zone.hostile_hurtboxes():
				cast.deliver(hurtbox, end_hit, zone.global_position, key + ":end")
	cast.spawn(zone, at)


func describe(params: SkillParams) -> String:
	var parts: PackedStringArray = []
	var where := "around you" if placement != Placement.AHEAD else "ahead"
	parts.append("Creates a zone %s (radius %d, %.1fs%s)" % [where, roundi(radius * params.radius_multiplier), duration,
		", arms after %.1fs" % delay if delay > 0.0 else ""])
	if hit != null:
		parts.append("pulses every %.2fs: %s" % [interval, SkillText.hit(hit, params)])
	if end_hit != null:
		parts.append("on expiry: %s" % SkillText.hit(end_hit, params))
	return "; ".join(parts) + "."
