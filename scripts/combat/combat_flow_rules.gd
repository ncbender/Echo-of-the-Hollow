class_name CombatFlowRules
extends Resource
## Prototype values of Combat Flow 1.5 (docs/WEAPON_MASTERY_COMBAT_FLOW.md). Not
## final balance; change only with a playtest.

const DEFAULT_PATH := "res://data/combat/combat_flow_rules.tres"

## Share of the (burden-lengthened) recovery at which a buffered combo input transitions.
@export var transition_ratio: float = 0.75
## Seconds before the transition from which a combo input is buffered (never
## before the windup ends).
@export var prebuffer: float = 0.18
## A fresh attack pressed while another action blocks (dash, skill) waits this long.
@export var start_buffer: float = 0.12
## Defensive cancel share of the recovery by AttackDefinition.FlowRole:
## base quick, base heavy, combo step, quick finisher, heavy finisher.
@export var cancel_ratios: PackedFloat32Array = PackedFloat32Array([0.5, 0.65, 0.55, 0.65, 0.75])
## Recovery movement: the first share keeps the windup factor, then it blends to 100 %.
@export var recovery_move_hold: float = 0.5
@export_group("Bow")
## LMB held this long (seconds) from a chain-starting press asks for Flowing Draw.
@export var flowing_draw_hold: float = 0.25
@export var flowing_draw_shots: int = 3
## Walking share while RMB holds the Precision Stance.
@export var precision_stance_move: float = 0.65

static var _default: CombatFlowRules


static func get_default() -> CombatFlowRules:
	if _default == null:
		_default = load(DEFAULT_PATH) if ResourceLoader.exists(DEFAULT_PATH) else CombatFlowRules.new()
	return _default


func cancel_ratio(role: int) -> float:
	return cancel_ratios[role] if role >= 0 and role < cancel_ratios.size() else 0.5
