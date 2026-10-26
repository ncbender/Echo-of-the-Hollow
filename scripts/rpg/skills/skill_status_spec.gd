class_name SkillStatusSpec
extends Resource
## A status a skill hit (or talent effect) applies to its target.

@export var status_id: StringName
## 0..1 chance per hit.
@export_range(0.0, 1.0) var chance: float = 1.0
@export var stacks: int = 1
@export var power: float = 1.0


static func make(id: StringName, stack_count: int = 1, chance_value: float = 1.0) -> SkillStatusSpec:
	var spec := SkillStatusSpec.new()
	spec.status_id = id
	spec.stacks = stack_count
	spec.chance = chance_value
	return spec
