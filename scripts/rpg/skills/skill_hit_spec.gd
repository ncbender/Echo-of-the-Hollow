class_name SkillHitSpec
extends Resource
## What one skill hit does to a target. Delivered by SkillCast.deliver() as a
## normal HitData (source SKILL) through the target's Hurtbox; character stats
## apply through the AttackModifier hook (CharacterStatModifier), never twice.

@export var damage: float = 10.0
@export var poise_damage: float = 8.0
## Knockback DISTANCE in px (KnockbackMotion model), away from the skill origin.
@export var knockback: float = 6.0
@export var damage_type: StringName = &"physical"
@export var tags: Array[StringName] = []
@export var statuses: Array[SkillStatusSpec] = []
@export var hitstop: float = 0.0

@export_group("Status Interplay")
## Consumes this status on the target; every consumed stack adds the bonuses below
## (arcane mark detonation, weak point execution ...).
@export var consume_status: StringName
@export var consume_damage_per_stack: float = 0.0
@export var consume_poise_per_stack: float = 0.0
## Damage multiplier against targets carrying `bonus_status` (not consumed).
@export var bonus_status: StringName
@export var bonus_multiplier: float = 1.0

@export_group("Resource")
## Class resource gained per target hit.
@export var resource_on_hit: float = 0.0
