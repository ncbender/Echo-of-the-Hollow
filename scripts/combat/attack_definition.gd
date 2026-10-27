class_name AttackDefinition
extends Resource
## One node of a weapon family's combo tree. All combat behaviour of an attack
## is data; CombatComponent contains no per-attack special cases.

enum InputType { LIGHT, HEAVY }
## Combat Flow 1.5: role of a node in a combo-path tree; picks the defensive
## cancel share of the recovery (CombatFlowRules.cancel_ratios).
enum FlowRole { BASE_QUICK, BASE_HEAVY, COMBO_STEP, QUICK_FINISHER, HEAVY_FINISHER }

## Bit flags for dash_cancel_phases.
const CANCEL_STARTUP := 1
const CANCEL_ACTIVE := 2
const CANCEL_RECOVERY := 4
## Bit flags for defense_flags.
const DEFENSE_BLOCKABLE := 1
const DEFENSE_PARRYABLE := 2
const DEFENSE_GUARD_BREAK := 4

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
## Absolute damage (enemies, legacy tree). Player weapon attacks (weapon_damage_multiplier
## > 0) keep it as their reference damage at the family reference base (display, tests).
@export var damage: float = 10.0
## Weapon Base Damage 1.0: player weapon attacks deal D_weapon x this (CombatComponent);
## generated as old damage / family reference base, never rounded. 0 = absolute `damage`.
@export var weapon_damage_multiplier: float = 0.0
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

@export_group("Combat Flow")
## Node of the family's combo-path tree (Weapon Mastery 1.4 / Combat Flow 1.5):
## the inputs from the chain start up to and including this attack, e.g. "L",
## "LLH"; bows use L and P (precision). Empty = legacy combo tree (enemies).
@export var combo_input: String = ""
@export var flow_role: FlowRole = FlowRole.BASE_QUICK
## Walking speed share during windup (startup) and active; the recovery starts at
## the windup share and blends to 100 % over its second half (CombatFlowRules).
@export var windup_move: float = 1.0
@export var active_move: float = 1.0
## Share of the recovery at which a buffered combo input transitions (< 0 = rules, 75 %).
@export var transition_ratio: float = -1.0
## Share of the recovery from which dash / parry / block may cancel (< 0 = by flow_role).
@export var defense_cancel_ratio: float = -1.0
## Seconds after the windup before which no combo input is accepted (the
## pre-buffer never starts before the windup ends).
@export var combo_open_at: float = 0.0
## Explicit attack-specific exception: phases that a defense may cancel although
## windup and active are committed by default (none so far).
@export_flags("Startup", "Active") var special_cancel_phases: int = 0
## Direction of the attack movement relative to the attack direction in degrees
## (0 = forward, +-90 = side step). Distance: lunge_distance.
@export var lunge_angle: float = 0.0
## Hit limits: hits per target in one swing, minimum seconds between them, and the
## most targets one swing may hit (0 = no limit).
@export var max_hits_per_target: int = 1
@export var rehit_interval: float = 0.0
@export var max_targets: int = 0
## Ranged attacks: projectiles fired at the start of the active phase (the fire
## event) instead of the melee sector. speed 0 = melee.
@export var projectile_speed: float = 0.0
@export var projectile_range: float = 0.0
@export var projectile_radius: float = 3.0
@export var projectile_count: int = 1
@export var projectile_spread: float = 0.0
@export var projectile_pierce: int = 0
## SkillProjectile.shape: 0 orb, 1 shard, 2 knife/arrow (visual only).
@export var projectile_shape: int = 0
## Animation the attack should play. All Combat Flow attacks use the generic
## placeholder swing/shot of PlayerView until final animations exist.
@export var animation_ref: StringName
@export var placeholder_animation: bool = true

@export_group("Defense")
## How the target may defend against this attack (Block & Parry, Shift).
## Neither Blockable nor Parryable = UNBLOCKABLE (telegraphed differently).
## Guard Breaking: a block fails against it (parry or dash instead).
@export_flags("Blockable", "Parryable", "Guard Breaking") var defense_flags: int = 3


func get_follow_up_id(input: InputType) -> StringName:
	return next_light if input == InputType.LIGHT else next_heavy


func total_duration() -> float:
	return startup + active + recovery


func is_flow() -> bool:
	return combo_input != ""


func is_projectile() -> bool:
	return projectile_speed > 0.0


func is_unblockable() -> bool:
	return defense_flags & (DEFENSE_BLOCKABLE | DEFENSE_PARRYABLE) == 0
