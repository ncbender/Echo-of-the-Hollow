class_name ConditionalHitBonusEffect
extends ItemEffect
## Talent/item effect: hits matching `condition` get percent bonuses per rank
## (power) on damage, poise damage and knockback, through the AttackModifier hook
## (weapon hits; skill hits when the condition allows the Skill source).
## Never changes attack data or timings.

@export var condition: HitCondition
@export var damage_percent: float = 0.0
@export var poise_percent: float = 0.0
@export var knockback_percent: float = 0.0
## Tag added to bonus hits (feedback, tests).
@export var mark_tag: StringName


func get_attack_modifiers_for(runner: ItemEffectRunner, source_key: String) -> Array[AttackModifier]:
	var modifier := BonusModifier.new()
	modifier.effect = self
	modifier.runner_ref = weakref(runner)
	modifier.source_key = source_key
	var result: Array[AttackModifier] = [modifier]
	return result


class BonusModifier:
	extends AttackModifier

	var effect: ConditionalHitBonusEffect
	var runner_ref: WeakRef
	var source_key: String

	func applies_to_skill_hits() -> bool:
		return effect.condition == null or (effect.condition.sources & (1 << HitData.Source.SKILL)) != 0

	func modify_hit(hit: HitData) -> void:
		var runner: ItemEffectRunner = runner_ref.get_ref()
		if runner == null or (effect.condition != null and not effect.condition.matches(hit, runner)):
			return
		var power := runner.power(source_key)
		hit.damage *= 1.0 + effect.damage_percent * power / 100.0
		hit.poise_damage *= 1.0 + effect.poise_percent * power / 100.0
		hit.knockback *= 1.0 + effect.knockback_percent * power / 100.0
		if effect.mark_tag != &"":
			hit.tags.append(effect.mark_tag)
