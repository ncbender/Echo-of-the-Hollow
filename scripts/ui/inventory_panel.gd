class_name InventoryPanel
extends PanelContainer
## Inventory + equipment window: slot grid, equipment of the ACTIVE class,
## details/actions of the selected item and resolved stats.
## Only calls public Character methods; holds no item state itself except the
## id of the selected instance.

const COLUMNS := 5
const SLOT_SIZE := Vector2(44, 15)

var character: Character

var _grid: GridContainer
var _equipment_list: VBoxContainer
var _header: Label
var _details: Label
var _actions: HBoxContainer
var _status: Label
var _stats: Label
var _selected_id: String = ""


func _ready() -> void:
	var outer := VBoxContainer.new()
	add_child(outer)
	_header = UiTheme.label("", UiTheme.COLOR_ACCENT)
	outer.add_child(_header)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 6)
	outer.add_child(columns)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 1)
	_grid.add_theme_constant_override(&"v_separation", 1)
	columns.add_child(_grid)

	var middle := VBoxContainer.new()
	middle.custom_minimum_size = Vector2(120, 0)
	columns.add_child(middle)
	_details = UiTheme.label("Select an item.", UiTheme.COLOR_DIM)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD
	middle.add_child(_details)
	_actions = HBoxContainer.new()
	middle.add_child(_actions)
	_status = UiTheme.label("", Color(1.0, 0.85, 0.5))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	middle.add_child(_status)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(130, 0)
	right.add_theme_constant_override(&"separation", 0)
	columns.add_child(right)
	_equipment_list = VBoxContainer.new()
	_equipment_list.add_theme_constant_override(&"separation", 0)
	right.add_child(_equipment_list)
	_stats = UiTheme.label("", UiTheme.COLOR_DIM)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	right.add_child(_stats)

	var close := Button.new()
	close.text = "Close [I / Esc]"
	close.pressed.connect(hide)
	outer.add_child(close)


func open(target_character: Character) -> void:
	if character != target_character:
		_disconnect()
		character = target_character
		character.inventory.changed.connect(rebuild)
		character.stats_changed.connect(rebuild)
	_status.text = ""
	show()
	rebuild()


func rebuild() -> void:
	if character == null or not is_inside_tree() or not visible:
		return
	var inventory := character.inventory
	if not inventory.has(_selected_id):
		_selected_id = ""
	var class_def := character.classes.get_active_definition()
	_header.text = "Inventory %d/%d    -    Equipment of %s (only the active class's gear is effective)" % [
		inventory.used_slots(), inventory.capacity, class_def.display_name if class_def else "-"]
	_rebuild_grid()
	_rebuild_equipment()
	_show_details()


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var items := character.inventory.items()
	for index in character.inventory.capacity:
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_text = true
		button.toggle_mode = true
		if index < items.size():
			var item := items[index]
			var definition := character.database.get_item(item.definition_id)
			var text := definition.display_name
			if item.quantity > 1:
				text = "%d %s" % [item.quantity, text]
			if character.equipment.is_equipped(item.instance_id):
				text = "[E] " + text
			button.text = text
			button.tooltip_text = definition.display_name
			button.add_theme_color_override(&"font_color", definition.rarity_color())
			button.button_pressed = item.instance_id == _selected_id
			button.pressed.connect(_select.bind(item.instance_id))
		else:
			button.disabled = true
		_grid.add_child(button)


func _rebuild_equipment() -> void:
	for child in _equipment_list.get_children():
		child.queue_free()
	for slot: int in EquipSlot.Slot.values():
		var item := character.equipment.get_item(slot)
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size = Vector2(130, 13)
		if item != null:
			var definition := character.database.get_item(item.definition_id)
			button.text = "%s: %s" % [EquipSlot.display_name(slot), definition.display_name]
			button.add_theme_color_override(&"font_color", definition.rarity_color())
			button.pressed.connect(_select.bind(item.instance_id))
		else:
			button.text = "%s: -" % EquipSlot.display_name(slot)
			button.add_theme_color_override(&"font_color", UiTheme.COLOR_DIM)
			if slot == EquipSlot.Slot.OFF_HAND and _main_hand_is_two_handed():
				button.text = "Off Hand: (two-hander)"
		_equipment_list.add_child(button)
	var stats := character.get_stats()
	var lines: PackedStringArray = []
	for stat in Stats.ALL:
		lines.append("%s: %s" % [Stats.display_name(stat), _format(stats[stat])])
	var bonuses := character.active_set_bonuses()
	for bonus in bonuses:
		lines.append("Set: " + bonus.description)
	_stats.text = "\n".join(lines)


func _main_hand_is_two_handed() -> bool:
	var item := character.equipment.get_item(EquipSlot.Slot.MAIN_HAND)
	return item != null and character.database.get_item(item.definition_id).slot_kind == ItemDefinition.SlotKind.TWO_HAND_WEAPON


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
	if definition.set_id != &"":
		var set_def: SetDefinition = character.database.sets.get(definition.set_id)
		lines.append("Set: %s (%d equipped)" % [set_def.display_name if set_def else String(definition.set_id),
			character.equipped_set_counts().get(definition.set_id, 0)])
	if not definition.required_class_ids.is_empty():
		lines.append("Requires: %s" % ", ".join(PackedStringArray(definition.required_class_ids)))
	if definition.description != "":
		lines.append(definition.description)
	_details.text = "\n".join(lines)
	_add_actions(item, definition)


func _add_actions(item: ItemInstance, definition: ItemDefinition) -> void:
	var equipment := character.equipment
	if definition.is_equippable():
		var current_slot := equipment.active_loadout().slot_of(item.instance_id)
		if current_slot >= 0:
			_add_action("Unequip", func() -> void: _report(equipment.unequip(current_slot), "Unequipped."))
		else:
			_add_action("Equip", func() -> void: _equip(item, -1))
		if definition.slot_kind == ItemDefinition.SlotKind.ONE_HAND_WEAPON and current_slot != EquipSlot.Slot.OFF_HAND:
			_add_action("Off-hand", func() -> void: _equip(item, EquipSlot.Slot.OFF_HAND))
		if definition.slot_kind == ItemDefinition.SlotKind.RING:
			for ring: int in [EquipSlot.Slot.RING_1, EquipSlot.Slot.RING_2]:
				if ring != current_slot:
					_add_action(EquipSlot.display_name(ring), func() -> void: _equip(item, ring))
	_add_action("Discard", func() -> void:
		_report("" if character.discard_item(item.instance_id) else "cannot discard", "Discarded."))


func _equip(item: ItemInstance, slot: int) -> void:
	var error := character.equipment.equip(item.instance_id, slot)
	var displaced: PackedStringArray = []
	for instance_id in character.equipment.last_displaced:
		var other := character.inventory.find(instance_id)
		if other != null:
			displaced.append(character.database.get_item(other.definition_id).display_name)
	var text := "Equipped."
	if not displaced.is_empty():
		text += " Moved back to inventory: %s." % ", ".join(displaced)
	_report(error, text)


func _report(error: String, success_text: String) -> void:
	_status.text = error if error != "" else success_text
	rebuild()


func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	_actions.add_child(button)


func _format(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _disconnect() -> void:
	if character == null:
		return
	if character.inventory.changed.is_connected(rebuild):
		character.inventory.changed.disconnect(rebuild)
	if character.stats_changed.is_connected(rebuild):
		character.stats_changed.disconnect(rebuild)


func _exit_tree() -> void:
	_disconnect()
