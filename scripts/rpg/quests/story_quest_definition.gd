class_name StoryQuestDefinition
extends Resource
## A story quest (prologue, main quest) made of ordered steps. Progress lives in
## the character's QuestLog next to class quests; rules in StoryService.

@export var id: StringName
@export var display_name: String
## Shown above the quest name ("Prologue", "The Roots Remember").
@export var chapter: String
@export_multiline var description: String
@export var steps: Array[StoryStep] = []
## World flag set when the quest is completed.
@export var completion_flag: StringName
## Started automatically when this quest is completed.
@export var next_quest_ids: Array[StringName] = []
## Stub quests (the story continues in a later update) never complete.
@export var open_ended: bool = false
## NPC Quest Turn-ins 1.0 (docs/NPC_QUEST_TURNINS_1_0_T1.md): gold handed out once by
## `turn_in_npc_id` after the quest was completed under the reward system (0 = no reward).
## Completion itself never waits for it; QuestRewardService holds the claim rules.
@export var turn_in_gold: int = 0
@export var turn_in_npc_id: StringName
## NPC Quest Turn-ins 1.1 M1 (docs/NPC_QUEST_TURNINS_1_1_M1.md): stackable materials handed
## out together with the gold, all or nothing (empty = gold-only reward, as T1).
@export var turn_in_items: Array[ItemCost] = []
## 1.1 M3 (docs/NPC_QUEST_TURNINS_1_1_M3.md): where the reward is collected, as the journal and
## tracker name it ("Mara in Haven"). Display text only; empty = the T3 lines with the NPC's name.
@export var turn_in_place: String = ""
