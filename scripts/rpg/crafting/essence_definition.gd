class_name EssenceDefinition
extends Resource
## A monster essence that can be bound into an essence slot. The inventory item
## (item_id) is consumed when inserted and only comes back through extraction.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var item_id: StringName
## Combat behaviour while the carrying item is equipped (ItemEffect pipeline).
@export var effect: ItemEffect
@export var allowed_slot_kinds: Array[ItemDefinition.SlotKind] = []
@export var color: Color = Color.WHITE
