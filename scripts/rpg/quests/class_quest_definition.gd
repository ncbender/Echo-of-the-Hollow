class_name ClassQuestDefinition
extends Resource
## A class unlock quest (docs/CLASS_QUESTS.md): taken and turned in at a class
## station; completing it permanently unlocks `class_id`. Every class that was
## not chosen in the prologue - and later classes like Guardian and
## Soulbinder - is unlocked this way.

@export var id: StringName
@export var class_id: StringName
@export var display_name: String
@export_multiline var description: String
## Only after the prologue choice (the prologue decides the first class).
@export var requires_prologue: bool = true
## False for prepared quests whose class is not playable yet.
@export var available: bool = true
## Counted while the quest is active (kills, skill hits ...).
@export var objectives: Array[TrialObjective] = []
## Delivered (consumed) at turn-in.
@export var deliveries: Array[ItemCost] = []
