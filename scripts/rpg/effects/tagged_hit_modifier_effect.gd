class_name TaggedHitModifierEffect
extends ItemEffect
## Generic combat effect for runes and evolution mutations: hits whose attack
## carries ALL `required_tags` (e.g. heavy, finisher) get multiplied damage,
## poise damage and knockback distance. Pure AttackModifier on the existing hit
## pipeline - attack data, timings and reach are never changed.

@export var required_tags: Array[StringName] = [&"heavy"]
## Only fully charged hits (charge tier = the attack's maximum tier).
@export var full_charge_only: bool = false
@export var damage_multiplier: float = 1.0
@export var poise_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0


func get_attack_modifiers() -> Array[AttackModifier]:
	var modifier := TagModifier.new()
	modifier.effect = self
	var result: Array[AttackModifier] = [modifier]
	return result


class TagModifier:
	extends AttackModifier

	var effect: TaggedHitModifierEffect

	func modify_hit(hit: HitData) -> void:
		for tag in effect.required_tags:
			if not tag in hit.tags:
				return
		if effect.full_charge_only:
			var profile := hit.attack.charge_profile if hit.attack != null else null
			if profile == null or profile.max_tier() <= 0 or hit.charge_tier < profile.max_tier():
				return
		hit.damage *= effect.damage_multiplier
		hit.poise_damage *= effect.poise_multiplier
		hit.knockback *= effect.knockback_multiplier
		hit.tags.append(effect.effect_id)
