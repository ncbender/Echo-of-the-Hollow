class_name EssenceResonanceEffect
extends ItemEffect
## Storm Wolf + Stone Golem in the same weapon: a target marked by a discharge
## (`mark_id`) takes extra poise damage from the player's NEXT hit. Each mark is
## consumed by one hit and expires on its own; discharge hits themselves never
## pass attack modifiers, so the resonance can never feed itself.

@export var mark_id: StringName = &"charged"
## +50 % poise damage on the consuming hit.
@export var poise_multiplier: float = 1.5


func get_attack_modifiers_for(runner: ItemEffectRunner, _source_key: String) -> Array[AttackModifier]:
	var modifier := MarkModifier.new()
	modifier.effect = self
	modifier.runner_ref = weakref(runner)   # runner owns the modifier: no strong cycle
	var result: Array[AttackModifier] = [modifier]
	return result


class MarkModifier:
	extends AttackModifier

	var effect: EssenceResonanceEffect
	var runner_ref: WeakRef

	func modify_hit(hit: HitData) -> void:
		var runner := runner_ref.get_ref() as ItemEffectRunner
		if runner != null and runner.consume_mark(hit.target, effect.mark_id):
			hit.poise_damage *= effect.poise_multiplier
			hit.tags.append(effect.effect_id)
			var shared := runner.shared_state(effect.effect_id)
			shared["triggers"] = shared.get("triggers", 0) + 1
