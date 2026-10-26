extends TestCase
## Inventory & Haven Stash 1.0 - the stash window at the Old Storehouse, driven
## by real mouse events (push_input): right click store/take, drag & drop both
## ways, Deposit All Materials, Sort, feedback for refused actions, the stash
## before and after restoring the storehouse, save/load in the middle of use.
## Outside the stash the bag's right click still equips. Only user://test_saves/.

const PATH := "user://test_saves/stash_ui/slot_1.save.json"

var session: SessionState
var map: GameMap
var character: Character
var panel: StashPanel
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.world.set_restoration(&"old_smithy", &"restored")
	character.world.set_flag(&"haven.old_smithy.restored")   # the storehouse can be restored after the smithy
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	var store := map.get_node("Ruins/OldStorehouse") as RuinSite
	map.player.feed_input(InputFrame.new())
	map.player.global_position = store.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	store.interact(map.hud)
	panel = map.hud.stash_panel
	for i in 3:
		await get_tree().process_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _cell(prefix: String, item: ItemInstance) -> ItemCell:
	return panel.find_child("%s_%s" % [prefix, item.instance_id], true, false) as ItemCell


func _mouse(at: Vector2, button_index: int = 0, pressed: bool = true, mask: int = 0) -> void:
	if button_index == 0:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.button_mask = mask
		motion.relative = Vector2(4, 0)
		get_viewport().push_input(motion, true)
	else:
		var click := InputEventMouseButton.new()
		click.button_index = button_index as MouseButton
		click.pressed = pressed
		click.button_mask = mask
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
	await get_tree().process_frame


func _right_click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	await _mouse(at)
	await _mouse(at, MOUSE_BUTTON_RIGHT, true, MOUSE_BUTTON_MASK_RIGHT)
	await _mouse(at, MOUSE_BUTTON_RIGHT, false)
	for i in 2:
		await get_tree().process_frame


## A real drag: press, move in steps with the button held, release on the target.
func _drag(from: Control, to: Control) -> void:
	var start := from.get_global_rect().get_center()
	var end := to.get_global_rect().get_center()
	await _mouse(start)
	await _mouse(start, MOUSE_BUTTON_LEFT, true, MOUSE_BUTTON_MASK_LEFT)
	for step in range(1, 9):
		await _mouse(start.lerp(end, step / 8.0), 0, true, MOUSE_BUTTON_MASK_LEFT)
	await _mouse(end, MOUSE_BUTTON_LEFT, false)
	for i in 3:
		await get_tree().process_frame


func test_ruined_storehouse_opens_the_stash() -> void:
	check(panel.visible, "the stash works while the storehouse is still a ruin")
	check(not RestorationService.is_restored(character, &"old_storehouse"), "really ruined")
	check((panel.find_child("RestoreStorehouse", true, false) as Button).visible, "restoring is offered")
	check(panel.find_child("Discard", true, false) == null, "no discard here")


func test_right_click_store_and_take() -> void:
	var sword := character.inventory.add_item(&"iron_sword", 1)[0]
	panel.rebuild()
	await get_tree().process_frame
	await _right_click(_cell("Bag", sword))
	check(character.stash.has(sword.instance_id) and not character.inventory.has(sword.instance_id), "right click stores")
	check_eq(panel.category, StashService.EQUIPMENT, "shows the item's category")
	await _right_click(_cell("Stash", sword))
	check(character.inventory.has(sword.instance_id) and not character.stash.has(sword.instance_id), "right click takes")
	# several fast clicks on the same (stale) cell never duplicate
	var stale := _cell("Bag", sword)
	stale.right_click_handler.call(stale)
	stale.right_click_handler.call(stale)
	check(character.stash.has(sword.instance_id) != character.inventory.has(sword.instance_id), "exactly one container")
	check(StashService.ownership_errors(character).is_empty(), "consistent")


func test_drag_and_drop_both_ways() -> void:
	var blade := character.inventory.add_item(&"forged_blade", 1)[0]
	panel.rebuild()
	await get_tree().process_frame
	var zone := panel.find_child("StashZone", true, false) as Control
	await _drag(_cell("Bag", blade), zone)
	check(character.stash.has(blade.instance_id), "dragged into the stash")
	var bag_zone := panel.find_child("BagZone", true, false) as Control
	await _drag(_cell("Stash", blade), bag_zone)
	check(character.inventory.has(blade.instance_id) and not character.stash.has(blade.instance_id), "dragged back into the bag")


func test_refused_actions_explain_why() -> void:
	var sword := character.inventory.add_item(&"iron_sword", 1)[0]
	character.equipment.equip(sword.instance_id, EquipSlot.Slot.MAIN_HAND)
	var crate := character.inventory.add_item(&"supply_crate", 1)[0]
	panel.rebuild()
	await get_tree().process_frame
	await _right_click(_cell("Bag", sword))
	var status := panel.find_child("Status", true, false) as Label
	check(status.text.contains("equipped") and character.inventory.has(sword.instance_id), "equipped: refused with a reason (%s)" % status.text)
	await _right_click(_cell("Bag", crate))
	check(status.text.contains("quest item") and character.inventory.has(crate.instance_id), "quest item: refused (%s)" % status.text)


func test_deposit_all_sort_and_capacity_after_restoring() -> void:
	character.inventory.add_item(&"iron_ore", 14)
	character.inventory.add_item(&"storm_ore", 3)
	character.inventory.add_item(&"timber", 10)
	character.inventory.add_item(&"stone", 10)
	panel.rebuild()
	(panel.find_child("DepositAll", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(character.inventory.count(&"iron_ore") == 0 and character.stash.count(&"iron_ore") == 14, "Deposit All Materials")
	check_eq(panel.category, StashService.MATERIALS, "the Material Vault is shown")
	(panel.find_child("Sort", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check((panel.find_child("Capacity", true, false) as Label).text.contains("no slot limit"), "vault capacity shown")
	# restoring pays from the bag (stored materials do not count): take timber and stone out first
	for item_id: StringName in [&"timber", &"stone"]:
		var stored := character.stash.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == item_id)
		for item: ItemInstance in stored:
			StashService.withdraw(character, item.instance_id)
	var before := StashService.capacity(character, StashService.EQUIPMENT)
	var stash_before := character.stash.to_array()
	(panel.find_child("RestoreStorehouse", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(map.hud.restoration_panel.visible, "restoration window from the stash")
	var store := map.get_node("Ruins/OldStorehouse") as RuinSite
	check_eq(store.restore(map.hud), "", "restored")
	check(StashService.capacity(character, StashService.EQUIPMENT) > before, "larger chest after restoring")
	check_eq(character.stash.to_array(), stash_before, "no stored item touched by the restoration")


func test_save_load_while_using_the_stash() -> void:
	var sword := character.inventory.add_item(&"iron_sword", 1)[0]
	character.inventory.add_item(&"iron_ore", 7)
	panel.rebuild()
	await get_tree().process_frame
	await _right_click(_cell("Bag", sword))
	panel.deposit_all_materials()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved mid-use")
	var restored := SaveSystem.load_from(PATH, session.database).character
	check(restored.stash.has(sword.instance_id) and restored.stash.count(&"iron_ore") == 7, "stash contents after loading")
	check(StashService.ownership_errors(restored).is_empty(), "no duplicates")
	DirAccess.remove_absolute(PATH)


func test_outside_the_stash_right_click_still_equips() -> void:
	map.hud.close_windows()
	var sword := character.inventory.add_item(&"iron_sword", 1)[0]
	for hand: int in [EquipSlot.Slot.MAIN_HAND, EquipSlot.Slot.OFF_HAND]:
		character.equipment.unequip(hand)
	map.hud.toggle_inventory()
	await get_tree().process_frame
	var cell := map.hud.inventory_panel.find_child("Item_%s" % sword.instance_id, true, false) as ItemCell
	await _right_click(cell)
	check(character.equipment.is_equipped(sword.instance_id), "inventory right click equips (not stores)")
	check(not character.stash.has(sword.instance_id), "nothing stored")
