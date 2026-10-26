class_name CraftingRequest
extends RefCounted
## What the player wants to do. Only the fields of the chosen operation are used.

var operation: StringName
var instance_id: String
## Item revision the request was previewed for (-1 = no check). A request whose
## item changed in the meantime is refused, so double inputs never apply twice.
var revision: int = -1
var material_id: StringName = &""
var affix_index: int = -1
var focus_tag: StringName = &""
var essence_id: StringName = &""
var slot_index: int = -1
var socketable_id: StringName = &""
var mutation_id: StringName = &""


static func make(operation_id: StringName, item: ItemInstance) -> CraftingRequest:
	var request := CraftingRequest.new()
	request.operation = operation_id
	request.instance_id = item.instance_id if item != null else ""
	request.revision = item.revision if item != null else -1
	return request
