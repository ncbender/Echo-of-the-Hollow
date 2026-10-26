class_name HitData
extends RefCounted
## Everything known about one resolved hit. Created by the attacker, passed through
## AttackModifiers, then delivered to the target's Hurtbox and broadcast via
## CombatComponent.hit_landed (hook for talents, items and feedback).

## Where a hit comes from. Effects choose which sources they react to
## (ItemEffect.hit_sources), so a skill or a bleed tick never re-triggers
## weapon-hit effects by accident.
enum Source { DIRECT, SKILL, TRIGGERED, STATUS }

var attacker: Node
var target: Node
var attack: AttackDefinition
## Unique per started attack; lets listeners group hits of one swing.
var attack_instance_id: int = 0
var charge_tier: int = 0
var damage: float = 0.0
var damage_type: StringName = &"physical"
var poise_damage: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var hitstop: float = 0.0
var reaction: HitReaction.Type = HitReaction.Type.NONE
var reaction_duration: float = 0.0
var position: Vector2 = Vector2.ZERO
var tags: Array[StringName] = []
var source: Source = Source.DIRECT
## Trigger depth: 0 = caused by a player action (weapon swing, skill), parent
## depth + 1 for hits caused by other hits. ItemEffectRunner never dispatches
## hits deeper than MAX_TRIGGER_DEPTH (no endless trigger chains).
var depth: int = 0
## Skill that produced the hit (source SKILL), else empty.
var skill_id: StringName
## Outcome, filled in by the target's HealthComponent.
var broke_poise: bool = false
var killed: bool = false
## Target statuses (id -> stacks) BEFORE this hit's effects ran; filled by the
## ItemEffectRunner so conditions never see stacks the same hit just added.
var target_statuses: Dictionary = {}
var _snapshot_taken: bool = false


## Stacks of `status_id` on the target before this hit's effects (live value when
## no snapshot was taken).
func target_stacks(status_id: StringName) -> int:
	if _snapshot_taken:
		return target_statuses.get(status_id, 0)
	var status := StatusComponent.of(target)
	return status.stacks(status_id) if status != null else 0


func snapshot_target() -> void:
	if _snapshot_taken:
		return
	_snapshot_taken = true
	var status := StatusComponent.of(target)
	if status != null:
		for status_id in status.active_ids():
			target_statuses[status_id] = status.stacks(status_id)


func is_direct() -> bool:
	return source == Source.DIRECT
