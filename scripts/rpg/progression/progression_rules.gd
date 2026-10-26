class_name ProgressionRules
extends Resource
## XP tuning for weapon mastery and class progression. PRELIMINARY values;
## the progression speed is not balanced yet (docs/PROGRESSION_SYSTEM.md).

@export_group("Weapon Mastery XP")
## Base mastery XP for one accepted hit (one per swing and target).
@export var mastery_xp_per_hit: int = 4
## Bonus for hits of attacks tagged "finisher".
@export var finisher_bonus_xp: int = 6
## Bonus for hits of fully charged heavy attacks.
@export var full_charge_bonus_xp: int = 4

@export_group("Training Targets")
## Hits on targets in group "training_target" give this fraction of normal XP.
@export_range(0.0, 1.0) var training_xp_multiplier: float = 0.5
## Total mastery XP one training target instance can give per session.
@export var training_xp_cap_per_target: int = 60

@export_group("Class XP")
## Class XP for an accepted hit on a non-training target.
@export var class_xp_per_hit: int = 1
