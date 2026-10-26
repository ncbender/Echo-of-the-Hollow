class_name StoryCondition
extends Resource
## When a story element (NPC placement, dialogue, encounter, barrier, pickup)
## is present: world flags and story quest progress. An empty condition is
## always met. Pure data - evaluated by met(), never by element-specific code.

@export var required_flags: Array[StringName] = []
@export var forbidden_flags: Array[StringName] = []
@export var quest_id: StringName
## "any", "active", "completed", "not_completed" (not started or active),
## "started" (active or completed), "not_started".
@export_enum("any", "active", "completed", "not_completed", "started", "not_started") var quest_state: String = "any"
## With an active quest: the current step must lie within [min_step, max_step]
## (-1 = no bound).
@export var min_step: int = -1
@export var max_step: int = -1


func met(character: Character) -> bool:
	for flag in required_flags:
		if not character.world.has_flag(flag):
			return false
	for flag in forbidden_flags:
		if character.world.has_flag(flag):
			return false
	if quest_id == &"":
		return true
	var state := character.quests.state(quest_id)
	match quest_state:
		"active":
			if state != "active":
				return false
		"completed":
			return state == "completed"
		"not_completed":
			if state == "completed":
				return false
		"started":
			if state == "":
				return false
		"not_started":
			return state == ""
	if state == "active":
		var step := character.quests.step(quest_id)
		if (min_step >= 0 and step < min_step) or (max_step >= 0 and step > max_step):
			return false
	elif min_step >= 0 or max_step >= 0:
		return false   # step bounds only match an active quest
	return true


## Null conditions are always met.
static func check(condition: StoryCondition, character: Character) -> bool:
	return condition == null or character == null or condition.met(character)


## Quick constructor for code and tests.
static func at_step(quest: StringName, step: int) -> StoryCondition:
	var condition := StoryCondition.new()
	condition.quest_id = quest
	condition.quest_state = "active"
	condition.min_step = step
	condition.max_step = step
	return condition
