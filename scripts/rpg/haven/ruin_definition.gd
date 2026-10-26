class_name RuinDefinition
extends Resource
## A ruin of Haven (docs/PROLOGUE_AND_HAVEN.md). Restoring it is a fixed, data-driven step -
## there are no free build plots. Stages: ruined -> restored -> revitalized
## (revitalizing is prepared in the data but not offered in this slice).
## A restored ruin provides the functions of `building_id` (forge, storage,
## training yard ...) through the existing building definitions.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## False: shows "Restoration unavailable for now." whatever the player carries.
@export var restorable: bool = false
## Story requirement (e.g. Haven reached, the smithy rekindled first).
@export var condition: StoryCondition
@export var costs: Array[ItemCost] = []
## Building whose function and scene the restored ruin provides (may be empty).
@export var building_id: StringName
## Story event reported on restoration (e.g. &"restore:old_smithy").
@export var event_id: StringName
## Played once the restoration is done (optional).
@export var completion_dialogue: DialogueDefinition
## Footprint of the ruin graphics (world px).
@export var footprint: Vector2 = Vector2(60, 40)
## The Haven stash is used here - already while ruined (StashService).
@export var stash_access: bool = false


func restored_flag() -> StringName:
	return StringName("haven.%s.restored" % id)
