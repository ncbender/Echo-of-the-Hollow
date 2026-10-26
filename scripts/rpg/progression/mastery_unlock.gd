class_name MasteryUnlock
extends Resource
## One reward on a weapon mastery track: a combo technique (requirement_id
## matches AttackDefinition.unlock_requirement) or a named milestone.

@export var level: int = 1
## Empty for pure milestones without gameplay effect yet.
@export var requirement_id: StringName
@export var display_name: String
@export_multiline var description: String


func is_technique() -> bool:
	return requirement_id != &""
