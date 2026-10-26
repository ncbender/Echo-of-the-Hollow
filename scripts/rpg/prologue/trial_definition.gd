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
## Grunts spawned for the trial (used when `enemy_configs` is empty).
@export var enemy_count: int = 3
## Enemy variants spawned for the trial, one per entry (Whispering Stone echoes).
@export var enemy_configs: Array[EnemyConfig] = []
## Text of this path on the class choice at the Whispering Stone.
@export_multiline var choice_text: String


func make_build(slot_count: int) -> ClassBuild:
	var build := ClassBuild.new(class_id, slot_count)
	for node_id: StringName in talents:
		build.talents[node_id] = talents[node_id]
	for index in mini(slot_count, skill_slots.size()):
		build.slots[index] = skill_slots[index]
	return build
