class_name QuestRewardService
extends RefCounted
## NPC Quest Turn-ins 1.0 T1 (docs/NPC_QUEST_TURNINS_1_0_T1.md): the one reward of a story
## quest (StoryQuestDefinition.turn_in_gold, since 1.1 M1 also turn_in_items), claimed later at
## its NPC. Completing the quest and taking the reward are separate: the quest completes as
## before; the reward is a persistent claim of its own, in two world flags:
##  * quest_reward_entitled.<id> - set only by register_completion, i.e. when the quest
##    completes LIVE (StoryService._settle with announce). Never by resettle (load-time
##    reconstruction), never by a migration: completions before T1 earn nothing (R-B)
##  * quest_reward_claimed.<id>  - set only by claim(), right after the whole reward was added
## A missing claimed flag alone is never a claim. Stateless; no NPC or UI code here.
## 1.1 M1 (docs/NPC_QUEST_TURNINS_1_1_M1.md): a mixed reward (gold + stackable materials) is
## paid all or nothing - room for every material is checked before anything is added, and a
## failed credit undoes exactly the quantities this claim added.

const NONE := &"none"
const PENDING := &"pending"
const CLAIMED := &"claimed"

const HANDOVER_FAILED := "The reward could not be handed over."
const BAG_FULL := "Your bag is full. Make room for the reward first."


static func entitled_flag(quest_id: StringName) -> StringName:
	return StringName("quest_reward_entitled.%s" % quest_id)


static func claimed_flag(quest_id: StringName) -> StringName:
	return StringName("quest_reward_claimed.%s" % quest_id)


## True if the quest hands out anything (gold and/or materials).
static func has_reward(quest: StoryQuestDefinition) -> bool:
	return quest != null and (quest.turn_in_gold > 0 or not quest.turn_in_items.is_empty())


## The materials of the reward, summed per item id (data order kept).
static func reward_items(quest: StoryQuestDefinition) -> Dictionary:
	var items := {}
	for cost in quest.turn_in_items:
		if cost != null:
			items[cost.item_id] = int(items.get(cost.item_id, 0)) + cost.quantity
	return items


## Called by StoryService when `quest` completes live. Idempotent (set_flag).
static func register_completion(character: Character, quest: StoryQuestDefinition) -> void:
	if has_reward(quest) and not character.world.has_flag(claimed_flag(quest.id)):
		character.world.set_flag(entitled_flag(quest.id))


## none | pending | claimed. Claimed wins over everything (contradictory flags never
## pay again); pending needs the entitlement AND the quest still completed.
static func state(character: Character, quest_id: StringName) -> StringName:
	if character.world.has_flag(claimed_flag(quest_id)):
		return CLAIMED
	if character.world.has_flag(entitled_flag(quest_id)) and StoryService.is_completed(character, quest_id):
		return PENDING
	return NONE


## "" if the reward can be taken now, else the reason (also for the T2 NPC window).
static func can_claim(character: Character, quest_id: StringName) -> String:
	var quest := StoryService.definition(character, quest_id)
	if not has_reward(quest):
		return "There is no reward for this."
	match state(character, quest_id):
		CLAIMED:
			return "You were already rewarded."
		NONE:
			return "There is no reward waiting for you."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	var slots := slots_needed(character, reward_items(quest))
	if slots < 0:
		return HANDOVER_FAILED   # invalid material data: never a partial reward
	if slots > character.inventory.free_slots():
		return BAG_FULL
	return ""


## New bag slots all `items` (item id -> quantity) need together: existing stacks of the
## same item are filled first, the rest needs ceil(rest / max_stack) slots per item. -1 if
## an entry is no stackable, non-currency item or its quantity is not positive. Reads only.
static func slots_needed(character: Character, items: Dictionary) -> int:
	var slots := 0
	for item_id: StringName in items:
		var definition := character.database.get_item(item_id)
		var left := int(items[item_id])
		if definition == null or not definition.is_stackable() or definition.is_currency or left <= 0:
			return -1
		for item in character.inventory.items():
			if item.definition_id == item_id:
				left -= definition.max_stack - item.quantity
		if left > 0:
			slots += ceili(float(left) / definition.max_stack)
	return slots


## Takes the pending reward: the materials, then the gold (currency: no bag slot), then the
## claimed flag - all in the same synchronous call, so every save snapshot holds all or
## nothing. A refused or failed credit changes nothing. With `session`, a success asks for
## one milestone save. Returns "" or the reason.
static func claim(character: Character, quest_id: StringName, session: SessionState = null) -> String:
	var error := can_claim(character, quest_id)
	if error != "":
		return error
	var quest := StoryService.definition(character, quest_id)
	error = pay(character, quest.turn_in_gold, reward_items(quest))
	if error != "":
		return error
	character.world.set_flag(claimed_flag(quest_id))
	if session != null:
		session.request_critical_save("quest reward %s" % quest_id)
	return ""


## The credit itself (called by claim after its checks; tests call it with entries that
## cannot be added to prove the rollback). Adds every material (add_item: all or nothing per
## item), then the gold. On any failure the quantities added so far are taken back exactly:
## touched existing stacks return to their previous quantity, new stacks are removed - other
## stacks of the same item are never touched. Returns "" or the reason; sets no flag.
static func pay(character: Character, gold: int, items: Dictionary) -> String:
	var inventory := character.inventory
	var undo: Array[Dictionary] = []
	for item_id: StringName in items:
		var before := _stack_quantities(inventory, item_id)
		var touched := inventory.add_item(item_id, int(items[item_id]), ItemInstance.ORIGIN_QUEST)
		if touched.is_empty():
			_undo(inventory, undo)
			return HANDOVER_FAILED
		undo.append({"before": before, "touched": touched})
	if gold > 0 and inventory.add_item(EconomyService.GOLD, gold, ItemInstance.ORIGIN_QUEST).is_empty():
		_undo(inventory, undo)   # add_item is all-or-nothing: no gold kept
		return HANDOVER_FAILED
	return ""


static func _stack_quantities(inventory: Inventory, item_id: StringName) -> Dictionary:
	var quantities := {}
	for item in inventory.items():
		if item.definition_id == item_id:
			quantities[item.instance_id] = item.quantity
	return quantities


static func _undo(inventory: Inventory, undo: Array[Dictionary]) -> void:
	for index in range(undo.size() - 1, -1, -1):
		var before: Dictionary = undo[index].before
		for item: ItemInstance in undo[index].touched:
			if before.has(item.instance_id):
				inventory.set_quantity(item.instance_id, int(before[item.instance_id]))
			else:
				inventory.remove_instance(item.instance_id)


## Validation of the reward data (GameDatabase, via StoryService.validate_data).
static func validate_quest(db: GameDatabase, quest: StoryQuestDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if quest.turn_in_gold < 0:
		errors.append("story quest %s: negative turn_in_gold" % quest.id)
	for cost in quest.turn_in_items:
		if cost == null:
			errors.append("story quest %s: empty turn_in_items entry" % quest.id)
			continue
		var definition := db.get_item(cost.item_id)
		if definition == null:
			errors.append("story quest %s: turn-in item %s unknown" % [quest.id, cost.item_id])
		elif not definition.is_stackable() or definition.is_currency:
			errors.append("story quest %s: turn-in item %s is no stackable material (gold: turn_in_gold)" % [quest.id, cost.item_id])
		if cost.quantity <= 0:
			errors.append("story quest %s: turn-in item %s needs a positive quantity" % [quest.id, cost.item_id])
	if has_reward(quest) and not db.npcs.has(quest.turn_in_npc_id):
		errors.append("story quest %s: turn-in npc %s unknown" % [quest.id, quest.turn_in_npc_id])
	if has_reward(quest) and quest.open_ended:
		errors.append("story quest %s: an open-ended quest never completes, its reward is unreachable" % quest.id)
	return errors
