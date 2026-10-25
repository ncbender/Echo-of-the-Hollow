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

@export_group("Damage")
@export var damage: float = 10.0
@export var damage_type: StringName = &"physical"
@export var poise_damage: float = 10.0
@export var knockback: float = 40.0
## Hitstop in seconds applied by feedback systems when this attack connects.
@export var hitstop: float = 0.0

@export_group("Hit Area")
## Radius of the hit sector in world pixels.
@export var reach: float = 30.0
## Opening angle of the hit sector in degrees (max 180).
@export_range(10.0, 180.0) var arc_degrees: float = 100.0

@export_group("Movement")
## Multiplier on base move speed while this attack runs.
@export var move_multiplier: float = 0.85
## Forward displacement along the aim direction spread over startup + active.
@export var lunge_distance: float = 0.0

@export_group("Combo")
## Follow-up per input. One field per input enforces "max one follow-up per input".
@export var next_light: StringName
@export var next_heavy: StringName
@export_flags("Startup", "Active", "Recovery") var dash_cancel_phases: int = 7
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
