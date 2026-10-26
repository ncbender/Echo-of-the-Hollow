class_name DialogueDefinition
extends Resource
## A conversation of an NPC. The NPC offers the first of its dialogues whose
## condition is met (order = priority). Finishing it (reading every line) sets
## "dialogue.<id>" and reports `event_id` to the StoryService; closing it early
## changes nothing, so it can simply be started again.

@export var id: StringName
@export var condition: StoryCondition
@export var lines: Array[DialogueLine] = []
## Story event reported when the last line was read (e.g. &"talk:mara_cart").
@export var event_id: StringName
## False: offered only until it was finished once.
@export var repeatable: bool = true


func done_flag() -> StringName:
	return StringName("dialogue.%s" % id)
