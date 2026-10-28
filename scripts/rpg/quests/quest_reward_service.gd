class_name QuestRewardService
extends RefCounted
## NPC Quest Turn-ins 1.0 T1 (docs/NPC_QUEST_TURNINS_1_0_T1.md): the one gold reward of a
## story quest (StoryQuestDefinition.turn_in_gold), claimed later at its NPC. Completing the
## quest and taking the reward are separate: the quest completes as before; the reward is
## a persistent claim of its own, in two world flags:
##  * quest_reward_entitled.<id> - set only by register_completion, i.e. when the quest
##    completes LIVE (StoryService._settle with announce). Never by resettle (load-time
##    reconstruction), never by a migration: completions before T1 earn nothing (R-B)
##  * quest_reward_claimed.<id>  - set only by claim(), right after the gold was added
## A missing claimed flag alone is never a claim. Stateless; no NPC or UI code here.

const NONE := &"none"
const PENDING := &"pending"
const CLAIMED := &"claimed"


static func entitled_flag(quest_id: StringName) -> StringName:
	return StringName("quest_reward_entitled.%s" % quest_id)


static func claimed_flag(quest_id: StringName) -> StringName:
	return StringName("quest_reward_claimed.%s" % quest_id)


## Called by StoryService when `quest` completes live. Idempotent (set_flag).
static func register_completion(character: Character, quest: StoryQuestDefinition) -> void:
	if quest.turn_in_gold > 0 and not character.world.has_flag(claimed_flag(quest.id)):
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
	if quest == null or quest.turn_in_gold <= 0:
		return "There is no reward for this."
	match state(character, quest_id):
		CLAIMED:
			return "You were already rewarded."
		NONE:
			return "There is no reward waiting for you."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	return ""


## Takes the pending reward: exactly turn_in_gold gold (currency: no bag slot), then the
## claimed flag - both in the same synchronous call, so every save snapshot holds both or
## neither. A refused or failed credit changes nothing. With `session`, a success asks for
## one milestone save. Returns "" or the reason.
static func claim(character: Character, quest_id: StringName, session: SessionState = null) -> String:
	var error := can_claim(character, quest_id)
	if error != "":
		return error
	var gold := StoryService.definition(character, quest_id).turn_in_gold
	if character.inventory.add_item(EconomyService.GOLD, gold, ItemInstance.ORIGIN_QUEST).is_empty():
		return "The reward could not be handed over."   # add_item is all-or-nothing: no gold kept
	character.world.set_flag(claimed_flag(quest_id))
	if session != null:
		session.request_critical_save("quest reward %s" % quest_id)
	return ""


## Validation of the reward data (GameDatabase, via StoryService.validate_data).
static func validate_quest(db: GameDatabase, quest: StoryQuestDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	if quest.turn_in_gold < 0:
		errors.append("story quest %s: negative turn_in_gold" % quest.id)
	if quest.turn_in_gold > 0 and not db.npcs.has(quest.turn_in_npc_id):
		errors.append("story quest %s: turn-in npc %s unknown" % [quest.id, quest.turn_in_npc_id])
	if quest.turn_in_gold > 0 and quest.open_ended:
		errors.append("story quest %s: an open-ended quest never completes, its reward is unreachable" % quest.id)
	return errors
