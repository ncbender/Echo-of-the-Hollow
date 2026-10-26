class_name StoryService
extends RefCounted
## Story quest rules. Stateless: progress lives in the character's QuestLog
## (state, step, progress per objective of the current step), event counters
## and milestone flags in its WorldState. Gameplay only reports events through
## notify(); every completed step emits QuestLog.story_progressed, which the
## session turns into a milestone (critical) save.

const FIRST_QUEST := &"a_road_forgotten"
const START_FLAG := &"prologue.started"
const COUNTER_PREFIX := "count."


## New journey: the first prologue quest becomes active.
static func begin_prologue(character: Character) -> void:
	character.world.set_flag(START_FLAG)
	start(character, FIRST_QUEST)


static func definition(character: Character, quest_id: StringName) -> StoryQuestDefinition:
	return character.database.story_quests.get(quest_id)


## Starts a quest (no-op if it is known already). Returns false for unknown ids.
static func start(character: Character, quest_id: StringName) -> bool:
	var quest := definition(character, quest_id)
	if quest == null:
		return false
	if character.quests.state(quest_id) != "":
		return true
	character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	_settle(character, quest)
	character.quests.changed.emit()
	return true


static func is_active(character: Character, quest_id: StringName) -> bool:
	return character.quests.state(quest_id) == "active"


static func is_completed(character: Character, quest_id: StringName) -> bool:
	return character.quests.state(quest_id) == "completed"


## True while `quest_id` is active at exactly `step`.
static func at_step(character: Character, quest_id: StringName, step: int) -> bool:
	return is_active(character, quest_id) and character.quests.step(quest_id) == step


static func current_step(character: Character, quest_id: StringName) -> StoryStep:
	var quest := definition(character, quest_id)
	var index := character.quests.step(quest_id)
	if quest == null or not is_active(character, quest_id) or index >= quest.steps.size():
		return null
	return quest.steps[index]


static func counter(character: Character, event_id: StringName) -> int:
	return int(character.world.get_flag(StringName(COUNTER_PREFIX + String(event_id)), 0))


static func objective_value(character: Character, quest_id: StringName, index: int) -> int:
	var step := current_step(character, quest_id)
	if step == null or index >= step.objectives.size():
		return 0
	var objective := step.objectives[index]
	var value := counter(character, objective.event_id) if objective.cumulative else int(character.quests.progress(quest_id, index))
	return mini(value, objective.amount)


## Reports a story event. Counts it (world counter) and advances every active
## story quest whose current step waits for it. Returns the quests that moved on.
static func notify(character: Character, event_id: StringName, amount: int = 1) -> Array[StringName]:
	character.world.set_flag(StringName(COUNTER_PREFIX + String(event_id)), counter(character, event_id) + amount)
	var moved: Array[StringName] = []
	for quest_id in character.quests.active_ids():
		var step := current_step(character, quest_id)
		if step == null:
			continue
		var progress: Dictionary = character.quests.entries[quest_id].progress
		var touched := false
		for index in step.objectives.size():
			var objective := step.objectives[index]
			if objective.event_id == event_id:
				progress[index] = float(mini(objective.amount, int(progress.get(index, 0)) + amount))   # float like every loaded value
				touched = true
		if touched and _settle(character, definition(character, quest_id)):
			moved.append(quest_id)
	if not moved.is_empty():
		character.quests.changed.emit()
	return moved


static func step_done(character: Character, quest_id: StringName) -> bool:
	var step := current_step(character, quest_id)
	if step == null or step.objectives.is_empty():
		return false   # open-ended stub step: waits for a later update
	for index in step.objectives.size():
		if objective_value(character, quest_id, index) < step.objectives[index].amount:
			return false
	return true


## Advances through every finished step (several when cumulative objectives are
## already met). Returns true when at least one step was completed.
static func _settle(character: Character, quest: StoryQuestDefinition) -> bool:
	var advanced := false
	while is_active(character, quest.id) and step_done(character, quest.id):
		var entry: Dictionary = character.quests.entries[quest.id]
		var step := quest.steps[int(entry.step)]
		if step.completion_flag != &"":
			character.world.set_flag(step.completion_flag)
		entry.step = int(entry.step) + 1
		entry.progress = {}
		advanced = true
		var finished := int(entry.step) >= quest.steps.size()
		if finished:
			entry.state = "completed"
			if quest.completion_flag != &"":
				character.world.set_flag(quest.completion_flag)
		character.quests.story_progressed.emit(quest.id, int(entry.step), finished)
		if finished:
			for next_id in quest.next_quest_ids:
				start(character, next_id)
	return advanced


## HUD lines of the active story quests: chapter/name, current step, counters.
static func tracker_lines(character: Character) -> PackedStringArray:
	var lines: PackedStringArray = []
	for quest_id in character.quests.active_ids():
		var quest := definition(character, quest_id)
		var step := current_step(character, quest_id)
		if quest == null or step == null:
			continue
		lines.append("%s: %s" % [quest.chapter, quest.display_name] if quest.chapter != "" else quest.display_name)
		lines.append("  " + step.description)
		for index in step.objectives.size():
			var objective := step.objectives[index]
			if objective.amount > 1:
				lines.append("  %s (%d/%d)" % [objective.description, objective_value(character, quest_id, index), objective.amount])
	return lines


## Validation of the story data (GameDatabase).
static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not db.story_quests.has(FIRST_QUEST):
		errors.append("story: first quest %s missing" % FIRST_QUEST)
	for quest: StoryQuestDefinition in db.story_quests.values():
		if quest.steps.is_empty():
			errors.append("story quest %s has no steps" % quest.id)
		for next_id in quest.next_quest_ids:
			if not db.story_quests.has(next_id):
				errors.append("story quest %s continues with unknown quest %s" % [quest.id, next_id])
		for index in quest.steps.size():
			var step := quest.steps[index]
			if step == null:
				errors.append("story quest %s: step %d is empty" % [quest.id, index])
				continue
			if step.objectives.is_empty() and not (quest.open_ended and index == quest.steps.size() - 1):
				errors.append("story quest %s: step %d has no objective" % [quest.id, index])
			for objective in step.objectives:
				if objective == null or objective.event_id == &"" or objective.amount < 1:
					errors.append("story quest %s: invalid objective in step %d" % [quest.id, index])
	return errors
