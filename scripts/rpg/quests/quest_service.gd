class_name QuestService
extends RefCounted
## Class quest rules (docs/CLASS_QUESTS.md). Stateless; progress lives in the
## character's QuestLog. Quests are taken and turned in at a class station;
## turning one in permanently unlocks its class.


static func quests_for(character: Character) -> Array[ClassQuestDefinition]:
	var result: Array[ClassQuestDefinition] = []
	for quest: ClassQuestDefinition in character.database.quests.values():
		result.append(quest)
	result.sort_custom(func(a: ClassQuestDefinition, b: ClassQuestDefinition) -> bool: return a.display_name < b.display_name)
	return result


## "" if the quest can be started now, otherwise the reason.
static func can_start(character: Character, quest_id: StringName) -> String:
	var quest: ClassQuestDefinition = character.database.quests.get(quest_id)
	if quest == null:
		return "Unknown quest."
	if not quest.available:
		return "This class cannot be unlocked yet."
	if quest.requires_prologue and not character.prologue.is_completed():
		return "Complete the prologue first."
	if character.classes.is_unlocked(quest.class_id):
		return "Class already unlocked."
	if character.quests.state(quest_id) != "":
		return "Quest already taken."
	return ""


static func start(character: Character, quest_id: StringName) -> String:
	var error := can_start(character, quest_id)
	if error != "":
		return error
	character.quests.entries[quest_id] = {"state": "active", "progress": {}}
	character.quests.changed.emit()
	return ""


## Counts a combat event for all active quests.
static func record(character: Character, kind: TrialObjective.Kind, target_id: StringName, amount: float) -> void:
	var touched := false
	for quest_id in character.quests.active_ids():
		var quest: ClassQuestDefinition = character.database.quests.get(quest_id)
		if quest == null:
			continue
		var progress: Dictionary = character.quests.entries[quest_id].progress
		for index in quest.objectives.size():
			var objective := quest.objectives[index]
			if ObjectiveRules.matches(objective, kind, target_id):
				progress[index] = ObjectiveRules.advance(objective, progress.get(index, 0.0), amount)
				touched = true
	if touched:
		character.quests.changed.emit()


static func objectives_done(character: Character, quest: ClassQuestDefinition) -> bool:
	for index in quest.objectives.size():
		if character.quests.progress(quest.id, index) + 0.0001 < quest.objectives[index].amount:
			return false
	return true


static func can_turn_in(character: Character, quest_id: StringName, at_station: bool) -> String:
	var quest: ClassQuestDefinition = character.database.quests.get(quest_id)
	if quest == null or character.quests.state(quest_id) != "active":
		return "Quest not active."
	if not at_station:
		return "Turn in class quests at a class station."
	if not objectives_done(character, quest):
		return "Objectives not complete yet."
	for cost in quest.deliveries:
		if character.inventory.count(cost.item_id) < cost.quantity:
			var item := character.database.get_item(cost.item_id)
			return "Missing %d x %s." % [cost.quantity, item.display_name if item else String(cost.item_id)]
	return ""


## Completes the quest: deliveries are consumed (all or nothing) and the class
## is unlocked permanently.
static func turn_in(character: Character, quest_id: StringName, at_station: bool) -> String:
	var error := can_turn_in(character, quest_id, at_station)
	if error != "":
		return error
	var quest: ClassQuestDefinition = character.database.quests[quest_id]
	for cost in quest.deliveries:
		if not character.inventory.remove_quantity(cost.item_id, cost.quantity):
			return "Delivery failed."
	character.quests.entries[quest_id].state = "completed"
	character.classes.unlock(quest.class_id)
	character.quests.changed.emit()
	return ""
