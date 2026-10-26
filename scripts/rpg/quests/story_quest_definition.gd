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
