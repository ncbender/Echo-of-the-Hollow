class_name ItemEffect
extends Resource
## Base class for special item/set effects. Definitions are shared, stateless
## Resources; per-character runtime state (cooldowns, dedupe) lives in the
## ItemEffectRunner. Two kinds of behaviour can be provided:
##  * combo modifiers: AttackModifiers added to the player's CombatComponent
##    while the effect is active (get_attack_modifiers)
##  * event reactions: on_hit_landed, called once per accepted player hit by the
##    runner (single signal connection, see ItemEffectRunner)
## Plain stat bonuses are NOT effects; they are StatModifiers on the item/set.

@export var effect_id: StringName
@export_multiline var description: String


func get_attack_modifiers() -> Array[AttackModifier]:
	return []


## `runner` is an ItemEffectRunner; `source_key` identifies the owning item/set
## so runtime state of two sources never mixes.
func on_hit_landed(_hit: HitData, _runner: RefCounted, _source_key: String) -> void:
	pass
