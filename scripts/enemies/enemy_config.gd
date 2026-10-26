class_name EnemyConfig
extends Resource
## Tuning for a simple melee enemy.

@export var move_speed: float = 70.0
## Starts chasing when the target is closer than this.
@export var aggro_range: float = 260.0
## Starts an attack when the target is closer than this.
@export var attack_range: float = 28.0
## Stops walking at this distance to avoid pushing into the target.
@export var stop_distance: float = 18.0
## Pause after an attack before the next one may start.
@export var attack_cooldown: float = 0.9
## Every n-th attack uses the family's heavy root (0 = never).
@export var heavy_attack_interval: int = 3
## 0 = full knockback, 1 = immovable.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.2
## Converts HitData.knockback (attack data) into launch speed for this enemy.
@export var knockback_scale: float = 3.0
## How fast knockback velocity decays (px/s²).
@export var knockback_decay: float = 1000.0
## Seconds the corpse stays before it is removed.
@export var despawn_delay: float = 0.8

@export_group("Rewards")
## Weapon mastery XP for the killing blow's weapon family.
@export var mastery_xp_reward: int = 20
## Class XP for the active class.
@export var class_xp_reward: int = 30
