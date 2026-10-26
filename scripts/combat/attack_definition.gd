class_name AttackDefinition
extends Resource
## One node of a weapon family's combo tree. All combat behaviour of an attack
## is data; CombatComponent contains no per-attack special cases.

enum InputType { LIGHT, HEAVY }

## Bit flags for dash_cancel_phases.
const CANCEL_STARTUP := 1
const CANCEL_ACTIVE := 2
const CANCEL_RECOVERY := 4

@export var id: StringName
@export var display_name: String
@export var weapon_family_id: StringName
@export var input_type: InputType = InputType.LIGHT

@export_group("Timing")
@export var startup: float = 0.1
@export var active: float = 0.08
@export var recovery: float = 0.2
## Seconds into recovery after which a follow-up attack may cancel the recovery.
@export var chain_delay: float = 0.0
## Seconds after recovery ends during which the combo can still continue.
@export var combo_window: float = 0.35
## How strongly the owner's attack speed applies (1 = fully, 0 = never, e.g. for
## attacks whose timing is a fixed telegraph). See CombatComponent.attack_speed.
@export_range(0.0, 1.0) var attack_speed_scaling: float = 1.0

@export_group("Damage")
@export var damage: float = 10.0
@export var damage_type: StringName = &"physical"
@export var poise_damage: float = 10.0
## Knockback DISTANCE in px against a standard target (resistance 0). The receiver
## scales it once (EnemyConfig.knockback_resistance, player reaction multiplier);
## KnockbackMotion covers exactly that distance unless a wall/character blocks it.
@export var knockback: float = 6.0
## Hitstop in seconds applied by feedback systems when this attack connects.
@export var hitstop: float = 0.0

@export_group("Hit Area")
## Radius of the hit sector in world pixels.
@export var reach: float = 30.0
## Opening angle of the hit sector in degrees (max 180).
@export_range(10.0, 180.0) var arc_degrees: float = 100.0

@export_group("Hit Reaction")
## Reaction this attack requests from targets that support hit reactions (player).
@export var hit_reaction: HitReaction.Type = HitReaction.Type.NONE
## Reaction duration in seconds; 0 = the target's configured default for the type.
@export var reaction_duration: float = 0.0

@export_group("Movement")
## Multiplier on base move speed while this attack runs.
@export var move_multiplier: float = 0.85
## Attack lunge: forward displacement in px along the attack direction fixed at attack
## start, spread evenly over startup + active. Ends with the attack (cancel, dash,
## hit reaction, recovery); walls and characters block it like normal movement.
## 0 = stationary attack.
@export var lunge_distance: float = 0.0

@export_group("Combo")
## Follow-up per input. One field per input enforces "max one follow-up per input".
@export var next_light: StringName
@export var next_heavy: StringName
@export_flags("Startup", "Active", "Recovery") var dash_cancel_phases: int = 7
## Phases in which hit reactions cannot interrupt this attack (hyper armor). 0 = always interruptible.
@export_flags("Startup", "Active", "Recovery") var uninterruptible_phases: int = 0
## Requirement id that must be unlocked (e.g. weapon mastery). Empty = always available.
@export var unlock_requirement: StringName
## Heavy attacks reference their charge tiers here; null for light attacks.
@export var charge_profile: ChargeProfile

@export_group("Hooks")
## Free-form tags forwarded with every hit (for future talents, uniques, VFX/SFX).
@export var effect_tags: Array[StringName] = []


func get_follow_up_id(input: InputType) -> StringName:
	return next_light if input == InputType.LIGHT else next_heavy


func total_duration() -> float:
	return startup + active + recovery
