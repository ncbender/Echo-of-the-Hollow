class_name InventoryPanel
extends PanelContainer
## Inventory window: slot grid, selected item details and actions.
## Only calls public Character/Inventory methods; holds no item state itself
## except the id of the selected instance.

const COLUMNS := 6
const SLOT_SIZE := Vector2(46, 16)

var character: Character

var _layout: HBoxContainer
var _grid: GridContainer
var _header: Label
var _details: Label
var _actions: HBoxContainer
var _status: Label
var _selected_id: String = ""


func _ready() -> void:
	var outer := VBoxContainer.new()
	add_child(outer)
	_header = UiTheme.label("", UiTheme.COLOR_ACCENT)
	outer.add_child(_header)
	_layout = HBoxContainer.new()
	_layout.add_theme_constant_override(&"separation", 6)
	outer.add_child(_layout)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 1)
	_grid.add_theme_constant_override(&"v_separation", 1)
	_layout.add_child(_grid)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(130, 0)
	_layout.add_child(side)
	_details = UiTheme.label("Select an item.", UiTheme.COLOR_DIM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD
	side.add_child(_details)
	_actions = HBoxContainer.new()
	side.add_child(_actions)
	_status = UiTheme.label("", Color(1.0, 0.85, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	side.add_child(_status)
	var close := Button.new()
	close.text = "Close [I / Esc]"
	close.pressed.connect(hide)
	outer.add_child(close)


func open(target_character: Character) -> void:
	if character != target_character:
		if character != null and character.inventory.changed.is_connected(rebuild):
			character.inventory.changed.disconnect(rebuild)
		character = target_character
		character.inventory.changed.connect(rebuild)
	_status.text = ""
	show()
	rebuild()


func rebuild() -> void:
	if character == null or not is_inside_tree():
		return
	var inventory := character.inventory
	if not inventory.has(_selected_id):
		_selected_id = ""
	_header.text = "Inventory  %d / %d slots" % [inventory.used_slots(), inventory.capacity]
	for child in _grid.get_children():
		child.queue_free()
	var items := inventory.items()
	for index in inventory.capacity:
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_text = true
		button.toggle_mode = true
		if index < items.size():
			var item := items[index]
			var definition := character.database.get_item(item.definition_id)
			button.text = _slot_text(item, definition)
			button.tooltip_text = definition.display_name
			button.add_theme_color_override(&"font_color", definition.rarity_color())
			button.button_pressed = item.instance_id == _selected_id
			button.pressed.connect(_select.bind(item.instance_id))
		else:
			button.disabled = true
		_grid.add_child(button)
	_show_details()


func _slot_text(item: ItemInstance, definition: ItemDefinition) -> String:
	var text := definition.display_name
	if item.quantity > 1:
		text = "%d %s" % [item.quantity, text]
	if _is_equipped(item.instance_id):
		text = "[E] " + text
	return text


## Overridden by the equipment-aware version (Phase 5).
func _is_equipped(_instance_id: String) -> bool:
	return false


func _select(instance_id: String) -> void:
	_selected_id = instance_id
	_status.text = ""
	rebuild()


func _show_details() -> void:
	for child in _actions.get_children():
		child.queue_free()
	var item := character.inventory.find(_selected_id)
	if item == null:
		_details.text = "Select an item."
		return
	var definition := character.database.get_item(item.definition_id)
	var lines: PackedStringArray = [
		definition.display_name,
		"%s %s%s" % [ItemDefinition.Rarity.keys()[definition.rarity].capitalize(),
			ItemDefinition.Category.keys()[definition.category].capitalize(),
			"  x%d" % item.quantity if definition.is_stackable() else ""],
	]
	if definition.is_equippable():
		lines.append("Slot: %s" % ItemDefinition.SlotKind.keys()[definition.slot_kind].capitalize())
	for modifier in definition.base_stats + item.affix_modifiers():
		lines.append(modifier.describe())
	for effect in definition.effects:
		lines.append("* " + effect.description)
	if not definition.required_class_ids.is_empty():
		lines.append("Requires: %s" % ", ".join(PackedStringArray(definition.required_class_ids)))
	if definition.description != "":
		lines.append(definition.description)
	_details.text = "\n".join(lines)
	_add_actions(item, definition)


func _add_actions(item: ItemInstance, _definition: ItemDefinition) -> void:
	var discard := Button.new()
	discard.text = "Discard"
	discard.pressed.connect(func() -> void:
		var removed := character.discard_item(item.instance_id)
		_status.text = "Discarded." if removed else "Cannot discard.")
	_actions.add_child(discard)


func _add_action(text: String, callback: Callable, enabled: bool = true) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(callback)
	_actions.add_child(button)
