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
## `announce` = false: no signals (used by resettle while a save is loaded).
static func start(character: Character, quest_id: StringName, announce: bool = true) -> bool:
	var quest := definition(character, quest_id)
	if quest == null:
		return false
	if character.quests.state(quest_id) != "":
		return true
	character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	_settle(character, quest, announce)
	if announce:
		character.quests.changed.emit()
	return true


## Re-evaluates every active story quest against the saved counters and flags
## (after loading): steps whose objectives are already met - cumulative goals
## whose amount was lowered, or a cumulative event that arrived while an earlier
## step was still waiting - are completed silently. Idempotent; emits no signal,
## so no milestone save, toast or HUD event is triggered. Class quests are
## skipped (no story definition). Returns the quests that moved on.
static func resettle(character: Character) -> Array[StringName]:
	var moved: Array[StringName] = []
	for quest_id in character.quests.active_ids():
		var quest := definition(character, quest_id)
		if quest != null and _settle(character, quest, false):
			moved.append(quest_id)
	return moved


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
	# side quests start only after the progress pass: their start event never counts as a step
	for quest: StoryQuestDefinition in character.database.story_quests.values():
		if quest.start_event_id == event_id and character.quests.state(quest.id) == "" \
				and StoryCondition.check(quest.start_condition, character) and start(character, quest.id):
			moved.append(quest.id)
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
static func _settle(character: Character, quest: StoryQuestDefinition, announce: bool = true) -> bool:
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
			if announce:   # live completion only - resettle's load-time reconstruction earns no reward (R-B)
				QuestRewardService.register_completion(character, quest)
		if announce:
			character.quests.story_progressed.emit(quest.id, int(entry.step), finished)
		if finished:
			for next_id in quest.next_quest_ids:
				start(character, next_id, announce)
	return advanced


## HUD lines of the active story quests: chapter/name, current step, counters. Side quests
## (started by an event) follow in one compact line each - name and short goal; their full
## step text stays in the Journal (Gameplay Polish 1.0).
static func tracker_lines(character: Character) -> PackedStringArray:
	var lines := main_tracker_lines(character)
	var side := side_tracker_entries(character)
	if not side.is_empty():
		lines.append("Side Quests")
		for entry: Dictionary in side:
			lines.append("  " + str(entry.text))
	return lines


## Main story = the prologue and the main quest chain: every story quest reachable from
## FIRST_QUEST through next_quest_ids (UI Window Foundation 1.0). Every other story quest is a
## side quest - decided by the quest data's own chain, not by start_event_id alone.
static func main_story_ids(db: GameDatabase) -> Dictionary:
	var ids := {}
	var queue: Array[StringName] = [FIRST_QUEST]
	while not queue.is_empty():
		var quest_id: StringName = queue.pop_front()
		var quest: StoryQuestDefinition = db.story_quests.get(quest_id)
		if quest == null or ids.has(quest_id):
			continue
		ids[quest_id] = true
		queue.append_array(quest.next_quest_ids)
	return ids


static func is_main_story(db: GameDatabase, quest_id: StringName) -> bool:
	return main_story_ids(db).has(quest_id)


## The tracker lines of the active story quests started by a chain (main story): headline,
## current step, counters.
static func main_tracker_lines(character: Character) -> PackedStringArray:
	var lines: PackedStringArray = []
	for quest_id in character.quests.active_ids():
		var quest := definition(character, quest_id)
		var step := current_step(character, quest_id)
		if quest == null or step == null or not is_main_story(character.database, quest_id):
			continue
		lines.append("%s: %s" % [quest.chapter, quest.display_name] if quest.chapter != "" else quest.display_name)
		lines.append("  " + step.description)
		for index in step.objectives.size():
			var objective := step.objectives[index]
			if objective.amount > 1:
				lines.append("  %s (%d/%d)" % [objective.description, objective_value(character, quest_id, index), objective.amount])
	return lines


## Active side quests (story quests outside the main chain), in quest log order: {"quest_id", "text"
## ("Name - short goal"), "details" (the full step text, for tooltips)}.
static func side_tracker_entries(character: Character) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for quest_id in character.quests.active_ids():
		var quest := definition(character, quest_id)
		var step := current_step(character, quest_id)
		if quest == null or step == null or is_main_story(character.database, quest_id):
			continue
		entries.append({"quest_id": quest_id, "text": "%s - %s" % [quest.display_name, short_goal(character, quest_id)], "details": step.description})
	return entries


## Combat HUD UX 2.0: active story quests for the HUD tracker - main story (`main`) or side quests, in quest
## log order: {"quest_id", "title" (the quest name, no chapter), "goal" (short_goal: the concrete current goal)}.
static func tracker_entries(character: Character, main: bool) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for quest_id in character.quests.active_ids():
		var quest := definition(character, quest_id)
		if quest == null or current_step(character, quest_id) == null or is_main_story(character.database, quest_id) != main:
			continue
		entries.append({"quest_id": quest_id, "title": quest.display_name, "goal": short_goal(character, quest_id)})
	return entries


## The current step of an active quest as its short objective texts with counters
## ("Carved marks found 1/3"); the step text if it has no objective descriptions.
static func short_goal(character: Character, quest_id: StringName) -> String:
	var step := current_step(character, quest_id)
	if step == null:
		return ""
	var goals: PackedStringArray = []
	for index in step.objectives.size():
		var objective := step.objectives[index]
		if objective.description == "":
			continue
		goals.append("%s %d/%d" % [objective.description, objective_value(character, quest_id, index), objective.amount] if objective.amount > 1 else objective.description)
	if not goals.is_empty():
		return "; ".join(goals)
	return step.hud_goal if step.hud_goal != "" else step.description


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
		errors.append_array(QuestRewardService.validate_quest(db, quest))
		if quest.start_event_id != &"":
			if quest.id == FIRST_QUEST:
				errors.append("story quest %s: the first quest has no start event" % quest.id)
			for other: StoryQuestDefinition in db.story_quests.values():
				if quest.id in other.next_quest_ids:
					errors.append("story quest %s: started by an event and by %s at once" % [quest.id, other.id])
			if not quest.steps.is_empty() and quest.steps[0] != null:
				for objective in quest.steps[0].objectives:
					if objective != null and objective.event_id == quest.start_event_id:
						errors.append("story quest %s: the start event would also finish step 0" % quest.id)
	return errors
