class_name ComboModifierEffect
extends ItemEffect
## Unique effect: modifies existing combo attacks (by id) at runtime through the
## AttackModifier hook. Never adds input sequences and never edits the shared
## AttackDefinition resources.

@export var attack_ids: Array[StringName] = []
@export var reach_multiplier: float = 1.0
@export var poise_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0


func get_attack_modifiers() -> Array[AttackModifier]:
	var modifier := TargetedModifier.new()
	modifier.effect = self
	var result: Array[AttackModifier] = [modifier]
	return result


class TargetedModifier:
	extends AttackModifier

	var effect: ComboModifierEffect

	func applies_to(attack: AttackDefinition) -> bool:
		return attack != null and attack.id in effect.attack_ids

	func modify_hit(hit: HitData) -> void:
		hit.damage *= effect.damage_multiplier
		hit.poise_damage *= effect.poise_multiplier
		hit.tags.append(effect.effect_id)

	func modify_reach(_attack: AttackDefinition, reach: float) -> float:
		return reach * effect.reach_multiplier
