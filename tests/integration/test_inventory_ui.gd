extends TestCase
## UI/UX redesign B: inventory, paper doll (15 slots), categories, sorting,
## item description order, comparison, equip/unequip through buttons and
## drag & drop without duplication, discard only after confirmation.

var session: SessionState
var map: GameMap
var character: Character
var panel: InventoryPanel
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	GameMap.give_debug_items(character)
	GameMap.give_crafting_kit(character)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame
	map.hud.toggle_inventory()
	panel = map.hud.inventory_panel
	await get_tree().process_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _instance(item_id: StringName) -> ItemInstance:
	for item in character.inventory.items():
		if item.definition_id == item_id and not character.equipment.is_equipped(item.instance_id):
			return item
	return null


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text)
	for button: Button in node.find_children("*", "Button", true, false):
		texts.append(button.text)
	return texts


func test_paper_doll_shows_all_fifteen_slots() -> void:
	check(panel.visible, "inventory open")
	for slot: int in EquipSlot.Slot.values():
		check(panel.find_child("Slot_%s" % EquipSlot.key_of(slot), true, false) != null, "paper doll slot %s" % EquipSlot.display_name(slot))
	var two_hander := _instance(&"steel_greatsword")
	check_eq(character.equipment.equip(two_hander.instance_id, EquipSlot.Slot.MAIN_HAND), "", "two-hander equipped")
	panel.rebuild()
	var off_hand := panel.find_child("Slot_OFF_HAND", true, false)
	check(_texts(off_hand).has("Two-hander"), "off hand shows the two-hander block")


func test_categories_and_sorting() -> void:
	panel.select_category("Materials")
	for item in panel.visible_items():
		check_eq(ItemDescriber.category_tab(character.database.get_item(item.definition_id)), "Materials", "only materials")
	check(not panel.visible_items().is_empty(), "materials listed")
	panel.select_category("All")
	panel.sort_mode = "Name"
	panel.rebuild()
	var names: Array = panel.visible_items().map(func(i: ItemInstance) -> String: return character.database.get_item(i.definition_id).display_name)
	var sorted := names.duplicate()
	sorted.sort()
	check_eq(names, sorted, "sorted by name")
	check_eq(panel.visible_items().size(), character.inventory.items().size(), "sorting never hides or duplicates items")


func test_description_order_and_comparison() -> void:
	var blade := _instance(&"stormcaller_fang")
	var lines := ItemDescriber.lines(character, blade)
	var order: Array = []
	for line in lines:
		if line.style == "section":
			order.append(line.text)
	check_eq(lines[0].style, "title", "1 name first")
	check(lines[1].text.begins_with("Epic"), "2 rarity / type / item level: %s" % lines[1].text)
	var expected := ["Base", "Monster Essences", "Quality", "Unique, Set & Evolution"]
	var seen := order.filter(func(t: String) -> bool: return t in expected)
	check_eq(seen, expected, "section order %s" % [order])
	check(String(order[order.size() - 1]).begins_with("Compared with"), "comparison last")
	var delta := ItemDescriber.comparison(character, blade, character.database.get_item(&"stormcaller_fang"))
	check(delta.size() >= 2 and delta[1].text.ends_with("(better)") or delta[1].text.ends_with("(worse)"), "deltas say better/worse in words")


func test_equip_buttons_and_drag_drop_never_duplicate() -> void:
	var before := character.inventory.items().size()
	var ring := _instance(&"silver_ring")
	panel.select_item(ring.instance_id)
	var equip := panel.find_child("EquipRing2", true, false) as Button
	check(equip != null, "ring offers Ring 2")
	equip.pressed.emit()
	check(character.equipment.get_item(EquipSlot.Slot.RING_2) == ring, "ring in Ring 2")
	# drag the ring onto Ring 1, then back into the bag
	var ring1 := panel.find_child("Slot_RING_1", true, false).find_child("Cell", true, false) as ItemCell
	check(ring1._can_drop_data(Vector2.ZERO, {"instance_id": ring.instance_id, "from_slot": EquipSlot.Slot.RING_2}), "drop allowed")
	ring1._drop_data(Vector2.ZERO, {"instance_id": ring.instance_id, "from_slot": EquipSlot.Slot.RING_2})
	check(character.equipment.get_item(EquipSlot.Slot.RING_1) == ring and character.equipment.get_item(EquipSlot.Slot.RING_2) == null, "moved, not copied")
	var bag_cell := panel.find_children("Item_*", "ItemCell", true, false)[0] as ItemCell
	bag_cell._drop_data(Vector2.ZERO, {"instance_id": ring.instance_id, "from_slot": EquipSlot.Slot.RING_1})
	check(not character.equipment.is_equipped(ring.instance_id), "unequipped by dropping on the bag")
	check_eq(character.inventory.items().size(), before, "same number of items")
	check(character.equipment.integrity_errors().is_empty() and character.inventory.integrity_errors().is_empty(), "no duplicates or broken references")


func test_discard_needs_confirmation() -> void:
	var potion := _instance(&"minor_potion")
	panel.select_item(potion.instance_id)
	(panel.find_child("Discard", true, false) as Button).pressed.emit()
	var dialog := map.hud.confirm_dialog
	check(dialog.visible, "confirmation shown")
	dialog.cancel()
	check(character.inventory.has(potion.instance_id), "cancel keeps the item")
	(panel.find_child("Discard", true, false) as Button).pressed.emit()
	dialog.confirm()
	check(not character.inventory.has(potion.instance_id), "confirmed discard removes it")


func test_overview_and_details_pages() -> void:
	panel.left_page = "Overview"
	panel.rebuild()
	check(_texts(panel).has("Max Health"), "overview lists core stats")
	panel.left_page = "Details"
	panel.rebuild()
	for stat in Stats.ALL:
		check(_texts(panel).has(Stats.display_name(stat)), "details list %s" % stat)
