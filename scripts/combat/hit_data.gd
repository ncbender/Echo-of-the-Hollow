class_name HitData
extends RefCounted
## Everything known about one resolved hit. Created by the attacker, passed through
## AttackModifiers, then delivered to the target's Hurtbox and broadcast via
## CombatComponent.hit_landed (hook for talents, items and feedback).

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
