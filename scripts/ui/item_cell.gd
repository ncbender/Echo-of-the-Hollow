class_name ItemCell
extends ItemSlotButton
## Icon slot of the bag grid or the paper doll: ItemIcon, rich item tooltip
## (ItemDescriber, same section order everywhere) and drag & drop. Dropping
## only calls the owner's `drop_handler`, which goes through
## CharacterEquipment - an item is never copied by dragging.

const SIZE := Vector2(56, 56)

var character: Character
var instance_id: String = ""
## Equipment slot of a paper-doll cell (-1 = bag cell).
var equip_slot: int = -1
## Callable(cell: ItemCell, data: Dictionary) -> void; set by the window.
var drop_handler: Callable

var _icon: ItemIcon


func _init() -> void:
	super._init()
	custom_minimum_size = SIZE
	clip_text = false
	toggle_mode = true
	_icon = ItemIcon.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6
	_icon.offset_top = 6
	_icon.offset_right = -6
	_icon.offset_bottom = -6
	add_child(_icon)


func setup(target_character: Character, item: ItemInstance, slot: int = -1) -> ItemCell:
	character = target_character
	equip_slot = slot
	instance_id = item.instance_id if item != null else ""
	var definition := character.database.get_item(item.definition_id) if item != null else null
	_icon.setup(definition, item.quantity if item != null else 1, item != null and slot < 0 and character.equipment.is_equipped(instance_id))
	text = ""
	tooltip_text = definition.display_name if definition != null else ""
	return self


func item() -> ItemInstance:
	return character.inventory.find(instance_id) if character != null and instance_id != "" else null


func _make_custom_tooltip(_for_text: String) -> Object:
	var current := item()
	if current == null:
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	ItemDescriber.build(box, character, current, UiTheme.TOOLTIP_MAX_WIDTH - 24)
	return box


func _get_drag_data(_at_position: Vector2) -> Variant:
	var current := item()
	if current == null:
		return null
	var preview := ItemIcon.new().setup(character.database.get_item(current.definition_id), current.quantity)
	preview.custom_minimum_size = ItemIcon.SIZE
	set_drag_preview(preview)
	return {"instance_id": instance_id, "from_slot": equip_slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drop_handler.is_valid() and data is Dictionary and (data as Dictionary).has("instance_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_handler.call(self, data)
