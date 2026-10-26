class_name EssencePoiseEffect
extends ItemEffect
## Essence of the Stone Golem: FULLY CHARGED heavy finishers (all `required_tags`,
## charge tier = the attack's maximum tier) deal more poise damage. Pure
## AttackModifier on the existing hit pipeline; damage and timings are untouched.

@export var required_tags: Array[StringName] = [&"heavy", &"finisher"]
## Extra poise damage at power 1.0 (0.6 = +60 %); essence power scales the bonus.
@export var poise_bonus: float = 0.6


func get_attack_modifiers_for(runner: ItemEffectRunner, source_key: String) -> Array[AttackModifier]:
	var modifier := FullChargeModifier.new()
	modifier.effect = self
	modifier.runner_ref = weakref(runner)   # runner owns the modifier: no strong cycle
	modifier.source_key = source_key
	var result: Array[AttackModifier] = [modifier]
	return result


class FullChargeModifier:
	extends AttackModifier

	var effect: EssencePoiseEffect
	var runner_ref: WeakRef
	var source_key: String

	func modify_hit(hit: HitData) -> void:
		var runner := runner_ref.get_ref() as ItemEffectRunner
		if runner == null or hit.target == null:
			return
		for tag in effect.required_tags:
			if not tag in hit.tags:
				return
		var profile := hit.attack.charge_profile if hit.attack != null else null
		if profile == null or profile.max_tier() <= 0 or hit.charge_tier < profile.max_tier():
			return
		var shared := runner.shared_state(effect.effect_id)
		if shared.get("last_swing", -1) == hit.attack_instance_id and shared.get("last_target", 0) == hit.target.get_instance_id():
			return   # two carriers: still one bonus per hit
		shared["last_swing"] = hit.attack_instance_id
		shared["last_target"] = hit.target.get_instance_id()
		hit.poise_damage *= 1.0 + effect.poise_bonus * runner.power(source_key)
		hit.tags.append(effect.effect_id)
