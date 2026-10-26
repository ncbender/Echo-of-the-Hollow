class_name TrialDefinition
extends Resource
## A temporary class trial of the prologue (docs/CLASS_QUESTS.md). The class is
## played with a TEMPORARY build at `trial_level`: nothing of it is unlocked,
## saved or kept afterwards (no talent points, no skills, no items).

@export var id: StringName
@export var class_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var trial_level: int = 12
## Temporary talent allocation (node id -> rank); validated like any build.
@export var talents: Dictionary[StringName, int] = {}
## Temporary Q/E/R/F skills.
@export var skill_slots: Array[StringName] = []
@export var objectives: Array[TrialObjective] = []
## Grunts spawned for the trial.
@export var enemy_count: int = 3


func make_build(slot_count: int) -> ClassBuild:
	var build := ClassBuild.new(class_id, slot_count)
	for node_id: StringName in talents:
		build.talents[node_id] = talents[node_id]
	for index in mini(slot_count, skill_slots.size()):
		build.slots[index] = skill_slots[index]
	return build
