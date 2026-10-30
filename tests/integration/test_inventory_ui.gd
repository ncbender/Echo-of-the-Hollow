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
	# Menu UX Polish 1.0: the item name only in the hover tooltip, no usage hint in the window
	var main_hand := panel.find_child("Slot_MAIN_HAND", true, false)
	check(not _texts(main_hand).has(character.database.get_item(&"steel_greatsword").display_name), "no item name beside the slot")
	check(not " ".join(_texts(panel)).contains("Hover:") and not " ".join(_texts(panel)).contains("Right-click"), "no visible usage hint")
	var cell := main_hand.get_node("Cell") as ItemCell
	cell.hovered.emit(cell)
	await get_tree().process_frame
	check(panel.tooltip.visible and " ".join(_texts(panel.tooltip)).contains(character.database.get_item(&"steel_greatsword").display_name),
		"hover: the tooltip names the item")
	panel.tooltip.hide_tooltip()


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
	var bag := character.inventory.items().filter(func(i: ItemInstance) -> bool: return character.inventory.takes_slot(i))
	check_eq(panel.visible_items().size(), bag.size(), "sorting never hides or duplicates bag items (equipped gear is in its slots)")


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


## Real input through the viewport (not direct method calls): mouse motion and
## button events at the centre of a control.
func _mouse_at(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _move(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _mouse_at(control)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)   # canvas coordinates
	await get_tree().process_frame


func _right_click(control: Control) -> void:
	await _move(control)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		click.position = _mouse_at(control)
		click.global_position = click.position
		get_viewport().push_input(click, true)
	await get_tree().process_frame


func _bag_cell(item: ItemInstance) -> ItemCell:
	return panel.find_child("Item_%s" % item.instance_id, true, false) as ItemCell


func test_right_click_equips_and_unequips_with_predictable_slots() -> void:
	var before := character.inventory.items().size()
	var silver := _instance(&"silver_ring")
	var copper := _instance(&"copper_ring")
	await _right_click(_bag_cell(silver))
	check(character.equipment.get_item(EquipSlot.Slot.RING_1) == silver, "first ring -> Ring 1 (first empty)")
	await _right_click(_bag_cell(copper))
	check(character.equipment.get_item(EquipSlot.Slot.RING_2) == copper, "second ring -> Ring 2 (next empty)")
	character.inventory.capacity += 5   # the debug kit fills the bag
	var third: ItemInstance = character.inventory.add_item(&"silver_ring", 1)[0]
	panel.rebuild()
	await _right_click(_bag_cell(third))
	check(character.equipment.get_item(EquipSlot.Slot.RING_1) == third and character.equipment.get_item(EquipSlot.Slot.RING_2) == copper,
		"both full -> Ring 1 is replaced, Ring 2 kept")
	check(character.inventory.has(silver.instance_id) and not character.equipment.is_equipped(silver.instance_id), "replaced ring back in the bag")
	# right click on the paper doll unequips
	var doll := panel.find_child("Slot_RING_2", true, false).find_child("Cell", true, false) as ItemCell
	await _right_click(doll)
	check(character.equipment.get_item(EquipSlot.Slot.RING_2) == null and character.inventory.has(copper.instance_id), "paper doll right click unequips")
	# Equipment Inventory Separation 1.0: an equipped item is only in its slot, not in the bag grid
	check(_bag_cell(third) == null, "the equipped ring is not shown in the bag")
	var ring_1 := panel.find_child("Slot_RING_1", true, false).find_child("Cell", true, false) as ItemCell
	await _right_click(ring_1)
	check(not character.equipment.is_equipped(third.instance_id) and _bag_cell(third) != null, "unequipped from the paper doll -> back in the bag")
	# one weapon slot (Weapon Mastery 1.4): every one-hander goes to the main hand and replaces the previous one
	for hand: int in [EquipSlot.Slot.MAIN_HAND, EquipSlot.Slot.OFF_HAND]:
		character.equipment.unequip(hand)
	var swords: Array[ItemInstance] = []
	for item_id: StringName in [&"iron_sword", &"militia_sword", &"echo_blade"]:
		swords.append(_instance(item_id))
	for sword in swords:
		panel.rebuild()
		await _right_click(_bag_cell(sword))
	check(character.equipment.get_item(EquipSlot.Slot.MAIN_HAND) == swords[2] and character.equipment.get_item(EquipSlot.Slot.OFF_HAND) == null,
		"each sword replaced the previous one in the main hand; the off hand stays free")
	# non-equippable: nothing happens, item kept
	var ore := _instance(&"iron_ore")
	await _right_click(_bag_cell(ore))
	check(character.inventory.has(ore.instance_id), "materials are never removed by right click")
	check_eq(character.inventory.items().size(), before + 1, "no item lost or copied (one ring added by the test)")
	check(character.equipment.integrity_errors().is_empty() and character.inventory.integrity_errors().is_empty(), "consistent references")


func test_no_action_buttons_and_no_destruction() -> void:
	var potion := _instance(&"minor_potion")
	panel.select_item(potion.instance_id)
	for button_name: String in ["Equip", "Unequip", "Discard", "EquipOffhand", "EquipRing1", "EquipRing2", "Actions"]:
		check(panel.find_child(button_name, true, false) == null, "%s removed" % button_name)
	await _right_click(_bag_cell(potion))
	check(character.inventory.has(potion.instance_id), "right click never destroys")


func test_hover_shows_tooltip_with_comparison_inside_the_screen() -> void:
	var equipped := _instance(&"iron_sword")
	character.equipment.equip(equipped.instance_id, EquipSlot.Slot.MAIN_HAND)
	panel.rebuild()
	await get_tree().process_frame
	var other := _instance(&"stormcaller_fang")
	await _move(_bag_cell(other))
	await get_tree().process_frame
	var tooltip := panel.tooltip
	check(tooltip.visible and tooltip.item == other, "hover shows the tooltip at once")
	check(tooltip.item != null and tooltip.compared_items().has(equipped), "compared with the equipped main hand")
	check_eq(tooltip.get_child_count(), 2, "item card + equipped card")
	var view := panel.get_viewport_rect()
	check(view.grow(1.0).encloses(tooltip.get_global_rect()), "tooltip inside the screen: %s" % tooltip.get_global_rect())
	# the right-most bag cell: the tooltip flips to the left of it
	var cells := panel.find_children("Item_*", "ItemCell", true, false)
	var right_most := cells[0] as ItemCell
	for cell: ItemCell in cells:
		if cell.get_global_rect().end.x > right_most.get_global_rect().end.x:
			right_most = cell
	await _move(right_most)
	await get_tree().process_frame
	check(view.grow(1.0).encloses(tooltip.get_global_rect()), "edge cell: tooltip still inside the screen")
	await _move(panel.find_child("Gold", true, false) as Control)
	check(not tooltip.visible, "tooltip hides when the mouse leaves the item")


func test_gold_is_a_counter_not_a_bag_item() -> void:
	character.inventory.add_item(&"gold_coin", 1234)
	var used := character.inventory.used_slots()
	panel.rebuild()
	check_eq((panel.find_child("Gold", true, false) as Label).text, "Gold  %s" % InventoryPanel.gold_text(character.inventory.count(&"gold_coin")), "wallet counter")
	check_eq(InventoryPanel.gold_text(1234), "1,234", "thousands separator")
	check(not panel.visible_items().any(func(i: ItemInstance) -> bool: return i.definition_id == &"gold_coin"), "gold not in the bag grid")
	character.inventory.add_item(&"gold_coin", 10)
	check_eq(character.inventory.used_slots(), used, "gold takes no bag slot")
	check(character.inventory.count(&"gold_coin") >= 1244, "gold still stored in the inventory (save format unchanged)")


func test_equipment_survives_save_and_load_after_right_click() -> void:
	var ring := _instance(&"silver_ring")
	await _right_click(_bag_cell(ring))
	var sword := _instance(&"iron_sword")
	await _right_click(_bag_cell(sword))
	character.inventory.add_item(&"gold_coin", 77)
	var path := "user://test_saves/inventory_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	SaveSystem.save_to(character, path)
	var restored := SaveSystem.load_from(path, session.database).character
	check(restored != null, "loaded")
	if restored != null:
		check_eq(restored.equipment.get_item(EquipSlot.Slot.RING_1).instance_id, ring.instance_id, "Ring 1 instance id kept")
		var sword_slot := character.equipment.active_loadout().slot_of(sword.instance_id)
		check(sword_slot >= 0, "sword equipped by right click")
		check_eq(restored.equipment.get_item(sword_slot).instance_id, sword.instance_id, "weapon instance id kept in its slot")
		check_eq(restored.inventory.count(&"gold_coin"), character.inventory.count(&"gold_coin"), "gold kept")
		check(restored.inventory.integrity_errors().is_empty() and restored.equipment.integrity_errors().is_empty(), "consistent after load")
	DirAccess.remove_absolute(path)


func test_overview_and_details_pages() -> void:
	panel.left_page = "Overview"
	panel.rebuild()
	check(_texts(panel).has("Max Health"), "overview lists core stats")
	panel.left_page = "Details"
	panel.rebuild()
	var stats := character.get_stats()
	for stat in Stats.ALL:   # Playtest Corrections 1.0: only what is in effect (base values always)
		check(_texts(panel).has(Stats.display_name(stat)) == InventoryPanel.shows_stat(stat, float(stats.get(stat, 0.0))), "details list %s only when in effect" % stat)


## Equipment Inventory Separation 1.0: drag & drop and right click move gear between bag and slots;
## the bag count follows; with a full bag unequipping is refused with a message (item stays worn).
func test_drag_and_drop_and_full_bag_refusal() -> void:
	var boots := _instance(&"worn_boots")
	if not check(boots != null, "carried boots"):
		return
	var used := character.inventory.used_slots()
	var feet := panel.find_child("Slot_FEET", true, false).find_child("Cell", true, false) as ItemCell
	feet._drop_data(Vector2.ZERO, {"instance_id": boots.instance_id, "from_slot": -1, "from_stash": false})   # bag -> slot
	await get_tree().process_frame
	check(character.equipment.get_item(EquipSlot.Slot.FEET) == boots, "dropped onto the feet slot: equipped")
	check(_bag_cell(boots) == null and character.inventory.used_slots() == used - 1, "not in the bag grid, one bag slot free")
	check(panel._bag_title.text.contains("%d / " % (used - 1)), "bag count follows (%s)" % panel._bag_title.text)
	var empty := panel._grid.get_children().filter(func(n: Node) -> bool: return n is ItemCell and (n as ItemCell).item() == null)
	if check(not empty.is_empty(), "an empty bag cell"):
		(empty[0] as ItemCell)._drop_data(Vector2.ZERO, {"instance_id": boots.instance_id, "from_slot": EquipSlot.Slot.FEET, "from_stash": false})   # slot -> bag
		await get_tree().process_frame
		check(character.equipment.get_item(EquipSlot.Slot.FEET) == null and _bag_cell(boots) != null, "dragged back into the bag")
	# full bag: right click on the paper doll is refused, the item stays worn
	character.equipment.equip(boots.instance_id, EquipSlot.Slot.FEET)
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1)
	panel.rebuild()
	await get_tree().process_frame
	feet = panel.find_child("Slot_FEET", true, false).find_child("Cell", true, false) as ItemCell
	await _right_click(feet)
	var status := panel.find_child("Status", true, false) as Label
	check(character.equipment.get_item(EquipSlot.Slot.FEET) == boots, "full bag: still equipped")
	check(status != null and status.text == CharacterEquipment.BAG_FULL, "a clear message (%s)" % (status.text if status else "-"))
	check(character.equipment.integrity_errors().is_empty() and character.inventory.integrity_errors().is_empty(), "consistent")
