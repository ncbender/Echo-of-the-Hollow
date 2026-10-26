class_name RuinDefinition
extends Resource
## A ruin of Haven (docs/PROLOGUE_AND_HAVEN.md). Restoring it is a fixed, data-driven step -
## there are no free build plots. Stages: ruined -> restored -> revitalized.
## Restoring costs `costs`; revitalizing (only where `revitalize_costs` is set,
## the Artisan Quarter workshops) costs `revitalize_costs`. Both steps are
## look, order and comfort - never stats or production multipliers.
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
## Workstation of this profession (Old Smithy: Blacksmithing; the Artisan
## Quarter workshops) - usable in every stage, also while ruined.
@export var profession_id: StringName

@export_group("Stages")
## What the restored building is like (restoration window preview; empty = the
## building's description or a generic line).
@export_multiline var restored_text: String
## Costs of restored -> revitalized. Empty: this ruin cannot be revitalized.
@export var revitalize_costs: Array[ItemCost] = []
## What the revitalized building is like (restoration window preview).
@export_multiline var revitalized_text: String


func restored_flag() -> StringName:
	return StringName("haven.%s.restored" % id)


func revitalized_flag() -> StringName:
	return StringName("haven.%s.revitalized" % id)


func can_revitalize() -> bool:
	return not revitalize_costs.is_empty()
