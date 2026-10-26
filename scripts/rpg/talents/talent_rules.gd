class_name TalentRules
extends Resource
## Binding talent and build rules (docs/TALENT_SYSTEM.md).

## Points needed in lower tiers of the same tree, per tier 1..7.
@export var tier_points: PackedInt32Array = [0, 5, 10, 15, 20, 25, 30]
## First class level that grants a talent point; one point per level from here
## (level 60 = 51 points).
@export var first_point_level: int = 10
@export var skill_slots: int = 4
@export var preset_slots: int = 5

@export_group("Respec")
## Normal in-game currency (never rare crafting resources).
@export var respec_currency_item: StringName = &"gold_coin"
@export var respec_base_cost: int = 10
@export var respec_cost_per_level: int = 2
## The first full respec of every class is free.
@export var first_respec_free: bool = true


func points_at_level(level: int) -> int:
	return maxi(0, level - first_point_level + 1)


func respec_cost(level: int) -> int:
	return respec_base_cost + respec_cost_per_level * maxi(0, level - 1)


func tier_requirement(tier: int) -> int:
	return tier_points[clampi(tier, 1, tier_points.size()) - 1]
