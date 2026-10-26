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
## Hit sources (HitData.Source bits) that reach on_hit_landed. Default: weapon hits
## only, so skills, status ticks and triggered hits never re-trigger weapon effects.
@export_flags("Direct", "Skill", "Triggered", "Status") var hit_sources: int = 1


func get_attack_modifiers() -> Array[AttackModifier]:
	return []


## Variant for modifiers that need runtime state (marks, power): receives the
## runner and this source's key. Defaults to get_attack_modifiers().
func get_attack_modifiers_for(_runner: ItemEffectRunner, _source_key: String) -> Array[AttackModifier]:
	return get_attack_modifiers()


## Called once per dispatched hit whose source is in `hit_sources`.
## `source_key` identifies the owning item/set/talent so runtime state of two
## sources never mixes.
func on_hit_landed(_hit: HitData, _runner: ItemEffectRunner, _source_key: String) -> void:
	pass
