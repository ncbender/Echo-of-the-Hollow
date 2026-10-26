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


func is_direct() -> bool:
	return source == Source.DIRECT
