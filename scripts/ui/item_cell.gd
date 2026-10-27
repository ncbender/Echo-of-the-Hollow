class_name ItemCell
extends ItemSlotButton
## Icon slot of the bag grid or the paper doll: ItemIcon and drag & drop.
## Hover / keyboard focus report the cell (`hovered`), so the window shows its
## immediate ItemTooltip; right click calls `right_click_handler` (quick
## equip / unequip). Ctrl+click marks the item a favourite, Alt+click locks it
## (ItemProtection; single items only). Dropping and right clicks only call the owner's handlers,
## which go through CharacterEquipment - an item is never copied.

## Mouse over the cell or keyboard focus on it (cell) / left again (null).
signal hovered(cell: ItemCell)

const SIZE := Vector2(56, 56)

var character: Character
var instance_id: String = ""
## Equipment slot of a paper-doll cell (-1 = bag cell).
var equip_slot: int = -1
## Callable(cell: ItemCell, data: Dictionary) -> void; set by the window.
var drop_handler: Callable
## Callable(cell: ItemCell) -> void; right mouse button. Set by the window.
var right_click_handler: Callable
## Owning container of the shown item (null = the bag; the stash window sets
## Character.stash for its cells).
var container: Inventory

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
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))


func setup(target_character: Character, item: ItemInstance, slot: int = -1) -> ItemCell:
	character = target_character
	equip_slot = slot
	instance_id = item.instance_id if item != null else ""
	var definition := character.database.get_item(item.definition_id) if item != null else null
	_icon.setup(definition, item.quantity if item != null else 1, item != null and slot < 0 and character.equipment.is_equipped(instance_id))
	_icon.favorite = item != null and item.favorite
	_icon.locked = item != null and item.locked
	_icon.rarity = item.rarity if item != null else ItemInstance.RARITY_FROM_DEFINITION
	text = ""
	tooltip_text = ""   # the window's ItemTooltip shows at once (no tooltip delay)
	return self


func item() -> ItemInstance:
	if character == null or instance_id == "":
		return null
	return (container if container != null else character.inventory).find(instance_id)


func _on_hover(entered: bool) -> void:
	hovered.emit(self if entered and item() != null else null)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT and click.pressed and (click.ctrl_pressed or click.alt_pressed):
		accept_event()   # marking never selects, drags or equips
		toggle_mark(&"locked" if click.alt_pressed else &"favorite")
		return
	if click != null and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		accept_event()
		if right_click_handler.is_valid() and item() != null:
			right_click_handler.call(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var current := item()
	if current == null:
		return null
	var preview := ItemIcon.new().setup(character.database.get_item(current.definition_id), current.quantity)
	preview.custom_minimum_size = ItemIcon.SIZE
	set_drag_preview(preview)
	return {"instance_id": instance_id, "from_slot": equip_slot, "from_stash": container != null and container == character.stash}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drop_handler.is_valid() and data is Dictionary and (data as Dictionary).has("instance_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_handler.call(self, data)


## Ctrl+click / Alt+click (UI and tests): toggles the favourite or lock mark
## of the shown item through ItemProtection. "" on success.
func toggle_mark(field: StringName) -> String:
	var current := item()
	if current == null or character == null:
		return "No item."
	if field == &"locked":
		return ItemProtection.set_locked(character, instance_id, not current.locked)
	return ItemProtection.set_favorite(character, instance_id, not current.favorite)
