class_name EssenceDischargeEffect
extends ItemEffect
## Essence of the Storm Wolf: a successful HEAVY FINISHER (attack tagged with all
## `required_tags`) releases an electric discharge around the struck target:
## shock damage (scaled by the Shock Damage stat and the essence power), a little
## poise and knockback, and a short `mark_id` mark on every struck enemy (used by
## the essence resonance). Limits: once per swing for all carriers of this effect,
## internal cooldown, discharge hits go straight to the hurtboxes (never re-trigger
## effects, never give XP, never pass attack modifiers - no chains).

const FX_SCRIPT: GDScript = preload("res://scripts/fx/shockwave_fx.gd")

@export var required_tags: Array[StringName] = [&"heavy", &"finisher"]
@export var radius: float = 44.0
## Fraction of the triggering hit's damage dealt as shock damage.
@export var damage_ratio: float = 0.35
@export var poise_damage: float = 6.0
## Knockback distance in px (KnockbackMotion model).
@export var knockback_distance: float = 4.0
@export var cooldown: float = 0.8
@export var mark_id: StringName = &"charged"
@export var mark_duration: float = 2.0
@export var fx_color: Color = Color(0.55, 0.8, 1.0)


func on_hit_landed(hit: HitData, runner: ItemEffectRunner, source_key: String) -> void:
	for tag in required_tags:
		if not tag in hit.tags:
			return
	var shared := runner.shared_state(effect_id)
	if shared.get("last_swing", -1) == hit.attack_instance_id or runner.time < shared.get("ready_at", 0.0):
		return
	shared["last_swing"] = hit.attack_instance_id
	shared["ready_at"] = runner.time + cooldown
	shared["triggers"] = shared.get("triggers", 0) + 1
	var power := runner.power(source_key)
	var shock: float = 1.0 + runner.stats.get(Stats.SHOCK_DAMAGE, 0.0) / 100.0
	var center := hit.position
	var struck := 0
	for hurtbox in runner.query_hurtboxes(center, radius):
		var discharge := HitData.new()
		discharge.attacker = hit.attacker
		discharge.target = hurtbox.get_entity()
		discharge.attack = hit.attack
		discharge.attack_instance_id = hit.attack_instance_id
		discharge.damage = hit.damage * damage_ratio * power * shock
		discharge.damage_type = &"shock"
		discharge.poise_damage = poise_damage * power
		discharge.knockback = (hurtbox.global_position - center).normalized() * knockback_distance
		discharge.position = hurtbox.global_position
		discharge.tags.append(&"discharge")
		if hurtbox.receive_hit(discharge):
			struck += 1
			runner.mark(discharge.target, mark_id, mark_duration)
	shared["last_struck"] = struck
	var fx: Node2D = FX_SCRIPT.new()
	fx.set(&"radius", radius)
	fx.set(&"color", fx_color)
	runner.spawn_fx(fx, center)
