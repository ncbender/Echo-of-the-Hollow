class_name StoryObjective
extends Resource
## One goal of a story quest step, counted from story events
## (StoryService.notify): "talk:mara_cart", "interact:supply_crate",
## "enter:haven", "encounter:cart_attack", "restore:old_smithy" ...
## Data-driven: no quest-specific code anywhere.

@export var event_id: StringName
@export var amount: int = 1
@export var description: String
## Counts every occurrence of the event since the game began (world counter
## "count.<event>"), not only while the step is active - e.g. class trials
## completed before the step started.
@export var cumulative: bool = false
