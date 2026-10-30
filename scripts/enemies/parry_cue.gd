class_name ParryCue
extends RefCounted
## Parry Timing Cue 1.0 (docs/PARRY_TIMING_CUE_1_0.md): WHEN to press Shift against an elite's or boss's parryable
## attack - a presentation rule only, it never changes a timing, a window or a hit.
##
## The real timing: the parry window opens on the frame Shift is pressed (DefenseComponent.step, while idle, off
## cooldown) and lasts the defender's DefenseProfile.parry_window (0.12 - 0.15 s); an enemy's melee hit is resolved
## when its attack enters the active phase (CombatComponent scans on entry), i.e. after the startup still left
## (attack speed already applied). A press at `r` seconds after the cue parries when the hit falls inside
## [cue + r, cue + r + window]; with the cue `lead` seconds before the hit that is  lead - window <= r <= lead.
## The cue therefore comes REACTION + window / 2 before the hit: the band of reactions that work is centred on
## REACTION (0.19 s) for every profile - e.g. 0.115 - 0.265 s with the sword guard, 0.13 - 0.25 s with a shield.

## Middle of the human reaction the cue is laid out for (seen -> Shift), seconds.
const REACTION := 0.19
## Parry window assumed when the defender has no profile (the sword guard's).
const DEFAULT_WINDOW := 0.15
## A cue whose moment was missed by more than this (an attack first seen late) is not shown at all.
const LATE := 0.05


## Elites and bosses (EnemyConfig.rank, data) with a parryable melee attack; normal enemies never get a cue (they
## stay parryable), projectiles are not predicted (none in the content).
static func eligible(config: EnemyConfig, attack: AttackDefinition) -> bool:
	return config != null and attack != null and config.rank >= 1 and attack.is_parryable() and not attack.is_projectile()


## Seconds before the hit at which the cue appears, for the defender's parry window.
static func lead(window: float) -> float:
	return REACTION + window * 0.5


## The defender's parry window (its active DefenseProfile), else DEFAULT_WINDOW.
static func window_of(target: Node) -> float:
	var defense: Variant = target.get(&"defense") if target != null and is_instance_valid(target) else null
	if defense is DefenseComponent and (defense as DefenseComponent).profile() != null:
		return (defense as DefenseComponent).profile().parry_window
	return DEFAULT_WINDOW


## Seconds until the running attack's hit (the end of its startup), -1 when it is not in the startup.
static func time_to_hit(combat: CombatComponent) -> float:
	if combat == null or combat.state != CombatComponent.State.ATTACKING or combat.phase != CombatComponent.Phase.STARTUP:
		return -1.0
	return maxf(0.0, combat.phase_duration() - combat.phase_time)
