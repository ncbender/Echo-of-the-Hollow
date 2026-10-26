class_name DefenseProfile
extends Resource
## How a weapon (WeaponFamily.defense_profile) or a shield (ItemDefinition.defense_profile)
## defends on Shift (docs/COMBAT_DESIGN.md "Block & Parry"). Pure data; the
## DefenseComponent runs it. Prototype values - not balanced by a human playtest.

@export var id: StringName
@export var display_name: String

@export_group("Parry")
## Seconds after pressing Shift in which a parryable hit is parried.
@export var parry_window: float = 0.15
## Width of the protected front sector for parries (degrees around the facing).
@export var parry_arc_degrees: float = 120.0
## Anti-spam: seconds from one parry press until the next parry may start.
@export var parry_cooldown: float = 0.55
## Lockout after a parry window that caught nothing and Shift was released (whiff).
@export var parry_recovery: float = 0.3
## Poise damage dealt to the attacker by a successful parry (scaled by EnemyConfig.parry_poise_multiplier).
@export var parry_poise_damage: float = 30.0
## Seconds after a successful parry in which the next weapon hit is a counter.
@export var counter_window: float = 1.0
@export var counter_damage_multiplier: float = 1.5

@export_group("Block")
## False: holding Shift after the parry window does nothing (parry-only defense).
@export var can_block: bool = true
## Fraction of damage removed by a block (0.45 = 45 % less).
@export_range(0.0, 0.95) var block_reduction: float = 0.45
@export var block_arc_degrees: float = 120.0
## Locomotion factor while parrying or blocking.
@export var move_multiplier: float = 0.5
## Lockout after releasing a block.
@export var block_recovery: float = 0.15
## Knockback factor of blocked hits.
@export var block_knockback_multiplier: float = 0.5
## Poise damage dealt to the attacker when one of its hits is blocked.
@export var block_poise_damage: float = 4.0
## Lockout when a guard-breaking attack hits the block (the block fails).
@export var guard_break_recovery: float = 0.6

@export_group("Presentation")
@export var color: Color = Color(0.85, 0.9, 1.0)
## Audio cue ids played by the combat audio layer (CombatAudio).
@export var block_sound: StringName = &"block"
@export var parry_sound: StringName = &"parry"
