class_name EnemyConfig
extends Resource
## Tuning for a simple melee enemy. Variants (Rootbound Husk, Hollowfang Wolf
## ...) are configs of the same grunt scene: data, not new enemy code.

@export_group("Identity")
@export var display_name: String = "Hollow Grunt"
@export var body_color: Color = Color("b5524a")
@export var body_radius: float = 8.0
## Overrides of the scene's HealthComponent (0 = keep the scene value).
@export var max_health: float = 0.0
@export var max_poise: float = 0.0

@export_group("Movement")

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
## Scales the knockback distance of every hit; poise damage is unaffected.
## Tiers (docs/COMBAT_DESIGN.md): small -0.5 (pushed 1.5x), standard 0, heavy 0.5,
## elite 0.8, boss 1 (no positional knockback).
@export_range(-1.0, 1.0) var knockback_resistance: float = 0.0
## Deceleration of knockback movement in px/s² (speed of the push, not its distance).
@export var knockback_decay: float = 1000.0
## Seconds the corpse stays before it is removed.
@export var despawn_delay: float = 0.8

@export_group("Parry")
## Scales the poise damage of a player's successful parry against this enemy.
@export var parry_poise_multiplier: float = 1.0
## A successful parry interrupts this enemy's attack and dazes it briefly.
## Bosses: false - parries never lock a boss down (poise still applies, scaled).
@export var parry_interrupts: bool = true
## Extra pause before the next attack after being parried.
@export var parry_daze: float = 0.5

@export_group("Statuses")
## Status id -> resistance 0..1 (1 = immune), e.g. {&"bleeding": 0.5}. Shortens the
## duration and weakens the power of statuses applied to this enemy.
@export var status_resistances: Dictionary[StringName, float] = {}
## Largest total locomotion slow (chill ...) this enemy accepts. Bosses use a low cap.
@export_range(0.0, 0.9) var max_slow: float = 0.6

@export_group("Rewards")
## Items dropped as pickups on death.
@export var drops: Array[ItemCost] = []
## Weapon mastery XP for the killing blow's weapon family.
@export var mastery_xp_reward: int = 20
## Class XP for the active class.
@export var class_xp_reward: int = 30


## Factor applied to HitData.knockback distances (1 = standard, 0 = immovable).
func knockback_taken() -> float:
	return maxf(0.0, 1.0 - knockback_resistance)
