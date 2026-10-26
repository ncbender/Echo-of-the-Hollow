extends TestCase
## Item Integrity & Salvaging 1.0: favourite / lock marks (single items only),
## item origin (found / crafted / starting; old saves: unknown_legacy, never
## guessed) through save v8 and its migration; protection of equipped, preset,
## quest, unique / set, favourite and locked items; salvaging at the right
## workstation from recipe data with an exact preview, atomic (rollback when the
## materials cannot be stored), refused repeats, full bag, save/load, and no
## material gain from craft -> salvage cycles. Real mouse for the window and
## the Ctrl / Alt marks. Only user://test_saves/.

const DIR := "user://test_saves/salvage"
const PATH := DIR + "/slot_1.save.json"

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	character = CharacterFactory.create_new(db)
	character.world.set_flag(&"prologue.haven_discovered")
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in [PATH] + SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


func _add(item_id: StringName, origin: StringName = &"") -> ItemInstance:
	return character.inventory.add_item(item_id, 1, origin)[0]


## Crafts a Rope Belt the normal way (4 Flax Fiber at the Weaver's House).
func _crafted_belt() -> ItemInstance:
	character.inventory.add_item(&"flax_fiber", 4)
	var before := character.inventory.items().map(func(i: ItemInstance) -> String: return i.instance_id)
	check_eq(ProfessionService.craft(character, &"tl_rope_belt", &"weavers_house").error, "", "rope belt crafted")
	for item in character.inventory.items():
		if item.definition_id == &"rope_belt" and not item.instance_id in before:
			return item
	return null


func test_origin_and_marks() -> void:
	for item in character.inventory.items():
		var definition := db.get_item(item.definition_id)
		if not definition.is_stackable():
			check_eq(item.origin, ItemInstance.ORIGIN_STARTING, "%s: starting gear" % item.definition_id)
	var belt := _crafted_belt()
	check_eq(belt.origin, ItemInstance.ORIGIN_CRAFTED, "crafted item marked crafted")
	var found := _add(&"padded_mantle", ItemInstance.ORIGIN_FOUND)
	check_eq(found.origin, ItemInstance.ORIGIN_FOUND, "found item")
	character.inventory.add_item(&"timber", 5, ItemInstance.ORIGIN_FOUND)
	for item in character.inventory.items():
		if item.definition_id == &"timber":
			check_eq(item.origin, &"", "stacks carry no origin")
			check(ItemProtection.set_favorite(character, item.instance_id, true) != "", "stacks cannot be marked")
	check_eq(ItemProtection.set_favorite(character, belt.instance_id, true), "", "favourite set")
	check_eq(ItemProtection.set_locked(character, found.instance_id, true), "", "lock set")
	check(belt.favorite and found.locked, "marks on the instances")
	# stash keeps instance and marks; sort keeps them too
	character.world.set_restoration(&"old_storehouse", &"restored")
	check_eq(StashService.deposit(character, found.instance_id), "", "locked item stored")
	check(character.stash.find(found.instance_id).locked, "lock kept in the stash")
	check_eq(ItemProtection.set_favorite(character, found.instance_id, true), "", "items in the stash can be marked")
	check_eq(StashService.withdraw(character, found.instance_id), "", "taken back")
	var back := character.inventory.find(found.instance_id)
	check(back != null and back.locked and back.favorite and back.origin == ItemInstance.ORIGIN_FOUND, "same instance, marks and origin kept")
	check(StashService.ownership_errors(character).is_empty(), "ownership consistent")
	# equip / unequip a marked item
	check_eq(character.equipment.equip(belt.instance_id), "", "a favourite can be equipped")
	check(character.equipment.is_equipped(belt.instance_id), "equipped")
	check_eq(character.equipment.unequip(character.equipment.active_loadout().slot_of(belt.instance_id)), "", "unequipped")
	check(belt.favorite, "still a favourite")
	# save / load
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	var again := loaded.character.inventory.find(belt.instance_id)
	var mantle := loaded.character.inventory.find(found.instance_id)
	check(again != null and again.favorite and again.origin == ItemInstance.ORIGIN_CRAFTED, "favourite and origin after loading")
	check(mantle != null and mantle.locked and mantle.favorite and mantle.origin == ItemInstance.ORIGIN_FOUND, "lock after loading")
	check(int(SaveSystem.VERSION) >= 8, "save version 8 or later")


func test_v7_items_become_unknown_legacy_and_keep_their_data() -> void:
	var sword := _add(&"forged_blade", ItemInstance.ORIGIN_FOUND)
	sword.quality = 3
	sword.material_id = &"frost_glass"
	sword.affixes.append({"affix": "test", "tier": 2, "stat": "physical_damage", "flat": 4.0, "percent": 0.0})
	sword.sockets.append(&"garnet")
	sword.essences.append(&"storm_wolf")
	character.stash.add_item(&"timber", 3)
	var payload := character.to_dict()
	for list: Array in [payload.inventory, payload.stash.items]:
		for entry: Dictionary in list:
			entry.erase("origin")   # a v7 save had no origin
	var errors: PackedStringArray = []
	var migrated: Dictionary = SaveMigrations.migrate(payload.duplicate(true), 7, errors)
	check(errors.is_empty(), "v7 -> v8 migrated")
	for list: Array in [migrated.inventory, migrated.stash.items]:
		for entry: Dictionary in list:
			check_eq(entry.get("origin"), "unknown_legacy", "%s: origin not guessed" % entry.def)
	var warnings: PackedStringArray = []
	var old := Character.from_dict(migrated, db, warnings)
	var blade := old.inventory.find(sword.instance_id)
	if check(blade != null, "same instance id"):
		check_eq(blade.origin, ItemInstance.ORIGIN_LEGACY, "legacy origin")
		check(not blade.favorite and not blade.locked, "no marks")
		check(blade.quality == 3 and blade.material_id == &"frost_glass" and blade.affixes.size() == 1 and blade.sockets == [&"garnet"]
			and blade.essences == [&"storm_wolf"], "quality, imprint, affixes, sockets, essences kept")
	check_eq(old.inventory.items().size(), character.inventory.items().size(), "every item kept")
	check_eq(old.stash.count(&"timber"), 3, "stash kept")
	# through the real loader: a v7 file
	var text := JSON.stringify(payload)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": SaveSystem.FORMAT, "version": 7, "checksum": text.sha256_text(), "payload": text}))
	file.close()
	var result := SaveSystem.load_from(PATH, db)
	check(result.ok(), "v7 file loads: %s" % [result.errors])
	if result.ok():
		check_eq(result.character.inventory.find(sword.instance_id).origin, ItemInstance.ORIGIN_LEGACY, "v7 file: legacy origin")
	# unknown origin values are not trusted either
	var odd := ItemInstance.from_dict({"id": "itm_x", "def": "rope_belt", "qty": 1, "origin": "bought_on_the_moon"})
	check_eq(odd.origin, ItemInstance.ORIGIN_LEGACY, "unknown origin value -> unknown_legacy")


func test_protection_classes_block_salvage() -> void:
	var cases := {}
	var equipped := _crafted_belt()
	character.equipment.equip(equipped.instance_id)
	cases["equipped"] = equipped
	var preset := _crafted_belt()
	check_eq(PresetService.save_preset(character, character.classes.active_class_id, 0, "Test"), "", "preset saved")
	var build := character.builds.get_build(character.classes.active_class_id)
	(build.presets[0].equipment as Dictionary)["BELT_ALT"] = preset.instance_id   # a preset that lists the belt
	cases["preset"] = preset
	var favourite := _crafted_belt()
	ItemProtection.set_favorite(character, favourite.instance_id, true)
	cases["favourite"] = favourite
	var locked := _crafted_cloak()
	ItemProtection.set_locked(character, locked.instance_id, true)
	cases["locked"] = locked
	cases["quest"] = _add(&"old_key")
	cases["unique"] = _add(&"crushing_oath")
	cases["set"] = _add(&"warden_helm")
	cases["no recipe"] = _add(&"iron_sword")
	for label: String in cases:
		var item: ItemInstance = cases[label]
		var bag := JSON.stringify(character.inventory.to_array())
		var result := SalvageService.salvage(character, item.instance_id, &"weavers_house")
		check(result.error != "", "%s refused: %s" % [label, result.error])
		check_eq(JSON.stringify(character.inventory.to_array()), bag, "%s: nothing changed" % label)
	check(ItemProtection.destroy_block(character, cases["unique"].instance_id).contains("Unique"), "unique / set: strict block")
	check(ItemProtection.destroy_block(character, cases["set"].instance_id).contains("set"), "set items blocked")
	ItemProtection.set_locked(character, locked.instance_id, false)
	check_eq(SalvageService.salvage_error(character, locked.instance_id, &"weavers_house"), "", "unlocked: salvageable again")


func test_station_preview_and_result() -> void:
	var belt := _crafted_cloak()
	check(SalvageService.salvage(character, belt.instance_id, &"tanners_lodge").error.begins_with("Salvage this at The Weaver's House"), "wrong station refused")
	check(SalvageService.salvage(character, belt.instance_id, &"").error.begins_with("Salvage this at"), "away from a station refused")
	check_eq(SalvageService.station_for(db, &"militia_sword"), &"old_smithy", "metal: Blacksmithing")
	check_eq(SalvageService.station_for(db, &"leather_gloves"), &"tanners_lodge", "leather: Leatherworking")
	check_eq(SalvageService.station_for(db, &"linen_trousers"), &"weavers_house", "cloth: Tailoring")
	check_eq(SalvageService.station_for(db, &"oak_shield"), &"woodwrights_workshop", "wood: Woodworking")
	check_eq(SalvageService.station_for(db, &"iron_sword"), &"", "no profession recipe: not salvageable")
	check_eq(SalvageService.station_for(db, &"stoneskin_draught"), &"", "alchemy: none")
	var share := SalvageService.return_share(character, belt)
	check(share >= 0.2 and share <= 0.3, "normal item: 20-30 %% (%.3f)" % share)
	check_eq(SalvageService.return_share(character, belt), share, "the roll is fixed for the instance")
	var preview := SalvageService.outputs(character, belt)
	var flax := character.inventory.count(&"flax_fiber")
	var result := SalvageService.salvage(character, belt.instance_id, &"weavers_house")
	if preview.is_empty():
		check(result.error.begins_with("Nothing"), "an empty return is refused, the item stays")
		return
	check_eq(result.error, "", "salvaged")
	check_eq(result.outputs, preview, "result equals the preview")
	check_eq(character.inventory.count(&"flax_fiber"), flax + int(preview[0].quantity), "materials added")
	check(character.inventory.find(belt.instance_id) == null, "item gone")


func test_rapid_repeats_and_rollback() -> void:
	var cloak := _crafted_cloak()
	var preview := SalvageService.outputs(character, cloak)
	check(not preview.is_empty(), "the cloak returns flax")
	var results: Array[String] = []
	for i in 4:
		results.append(SalvageService.salvage(character, cloak.instance_id, &"weavers_house").error)
	check_eq(results.count(""), 1, "one salvage out of four clicks")
	check_eq(character.inventory.count(&"flax_fiber"), int(preview[0].quantity), "materials once")
	check(StashService.ownership_errors(character).is_empty(), "no duplicate")
	# a credit that fails: everything is undone, the same instance returns
	var belt := _crafted_belt()
	var saved := belt.to_dict()
	var bag := JSON.stringify(character.inventory.to_array())
	var bad: Array[Dictionary] = [{"item_id": &"flax_fiber", "quantity": 1}, {"item_id": &"no_such_material", "quantity": 1}]
	var failed := SalvageService.apply(character, belt, bad)
	check(failed.error != "", "failed credit reported")
	check(character.inventory.find(belt.instance_id) != null and character.inventory.find(belt.instance_id).to_dict() == saved, "same instance back, unchanged")
	check_eq(character.inventory.count(&"flax_fiber"), int(preview[0].quantity), "no material kept from the failed credit")
	check_eq(character.inventory.items().size(), (JSON.parse_string(bag) as Array).size(), "no item lost or added")


func test_full_bag_refuses_before_anything_changes() -> void:
	var cloak := _crafted_cloak()
	var preview := SalvageService.outputs(character, cloak)
	var flax_stack := db.get_item(&"flax_fiber").max_stack
	# fill every free slot with swords: no flax stack to join, only the cloak's own slot frees up
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"iron_sword", 1)
	# one output stack fits into that slot
	check_eq(SalvageService.salvage_error(character, cloak.instance_id, &"weavers_house"), "", "the freed slot holds the flax")
	check(int(preview[0].quantity) <= flax_stack, "one stack")
	# a second output kind would not fit: prove the room check counts slots
	var two: Array[Dictionary] = [{"item_id": &"flax_fiber", "quantity": 1}, {"item_id": &"timber", "quantity": 1}]
	check(not SalvageService._room_after_removal(character, cloak, two), "two new stacks do not fit into one freed slot")


func test_save_load_after_salvage() -> void:
	var belt := _crafted_cloak()
	var keep := _crafted_belt()
	ItemProtection.set_locked(character, keep.instance_id, true)
	var result := SalvageService.salvage(character, belt.instance_id, &"weavers_house")
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	if result.error == "":
		check(loaded.character.inventory.find(belt.instance_id) == null, "salvaged item stays gone")
	check(loaded.character.inventory.find(keep.instance_id).locked, "locked item kept and locked")
	check_eq(loaded.character.inventory.count(&"flax_fiber"), character.inventory.count(&"flax_fiber"), "materials saved")


## Every salvageable recipe, crafted and salvaged ten times from raw materials:
## the raw material stock only shrinks; salvaging gives no profession XP.
func test_craft_salvage_cycles_never_gain() -> void:
	for profession_id: StringName in SalvageService.SALVAGE_PROFESSIONS:
		_raise(profession_id, 10)
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if SalvageService.source_recipe(db, recipe.output_item_id) != recipe:
			continue
		character.professions.learn(recipe.id)   # pattern recipes too
		var station := ProfessionService.station_of(db, recipe)
		var raw := SalvageService.raw_materials(db, recipe)
		var spent := 0.0
		var back := 0
		for cycle in 10:
			# craft from raw: run the processing steps, then the recipe
			for item_id: StringName in raw:
				character.inventory.add_item(item_id, ceili(float(raw[item_id])))
				spent += ceili(float(raw[item_id]))
			for cost in recipe.inputs:
				var processing := SalvageService._processing_recipe(db, cost.item_id)
				for n in cost.quantity:
					if processing != null:
						ProfessionService.craft(character, processing.id, ProfessionService.station_of(db, processing))
			var crafted := ProfessionService.craft(character, recipe.id, station)
			if not check_eq(crafted.error, "", "%s crafted from raw materials" % recipe.id):
				break
			var item: ItemInstance = null
			for candidate in character.inventory.items():
				if candidate.definition_id == recipe.output_item_id:
					item = candidate
			var xp := character.professions.xp(recipe.profession_id)
			var salvaged := SalvageService.salvage(character, item.instance_id, station)
			check_eq(character.professions.xp(recipe.profession_id), xp, "%s: no XP from salvaging" % recipe.id)
			for entry: Dictionary in salvaged.outputs:
				back += int(entry.quantity)
		check(back < spent * 0.41, "%s: %d raw units back from %d spent (<= 40 %%)" % [recipe.id, back, spent])
		check(back < spent, "%s: no material gain" % recipe.id)


# --- window and marks with the real mouse -----------------------------------------

func _open_haven() -> bool:
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.is_node_ready() and not session.is_traveling():
			map = current
			map.player.feed_input(InputFrame.new())
			return true
	fail("Haven not loaded")
	return false


func _click(control: Control, ctrl: bool = false, alt: bool = false) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.ctrl_pressed = ctrl
		click.alt_pressed = alt
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	for i in 3:
		await get_tree().process_frame


func test_salvage_window_and_marks_with_the_mouse() -> void:
	var belt := _crafted_cloak()
	if not await _open_haven():
		return
	var site := map.get_node("Ruins/WeaversHouse") as RuinSite
	map.player.global_position = site.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	site.interact(map.hud)
	var panel := map.hud.professions_panel
	panel.show_page("Salvage")
	for i in 3:
		await get_tree().process_frame
	var row := panel.find_child("Salvage_%s" % belt.instance_id, true, false) as Button
	check(row != null, "the crafted belt is listed")
	var gains := panel.find_children("Gain_*", "", true, false)
	check_eq(gains.size(), SalvageService.outputs(character, belt).size(), "preview rows = return")
	var lock := panel.find_child("MarkLocked", true, false) as Button
	await _click(lock)
	check(belt.locked, "Lock button locks")
	var action := panel.find_child("Salvage", true, false) as Button
	check(action != null and action.disabled and panel.footer.is_ancestor_of(action), "Salvage disabled in the footer while locked")
	await _click(panel.find_child("MarkLocked", true, false) as Button)
	check(not belt.locked, "Unlock button")
	action = panel.find_child("Salvage", true, false) as Button
	var preview := SalvageService.outputs(character, belt)
	if preview.is_empty():
		check(action.disabled, "nothing to recover: disabled")
	else:
		check(not action.disabled, "Salvage enabled")
		await _click(action)
		check(map.hud.confirm_dialog.visible, "confirmation asked")
		check(character.inventory.find(belt.instance_id) != null, "nothing destroyed before confirming")
		var confirm := map.hud.confirm_dialog.find_child("Confirm", true, false) as Button
		await _click(confirm)
		await _click(confirm)   # double click on the dialog
		check(character.inventory.find(belt.instance_id) == null, "salvaged after confirming")
		check(StashService.ownership_errors(character).is_empty(), "consistent")
	map.hud.close_windows()
	# Ctrl / Alt click in the inventory
	var other := _crafted_belt()
	map.hud.toggle_inventory()
	for i in 3:
		await get_tree().process_frame
	var cell := map.hud.inventory_panel.find_children("*", "ItemCell", true, false).filter(func(c: ItemCell) -> bool: return c.instance_id == other.instance_id and c.equip_slot < 0)
	if not check(not cell.is_empty(), "belt cell in the bag"):
		return
	await _click(cell[0], true)
	check(other.favorite, "Ctrl+click: favourite")
	check(not character.equipment.is_equipped(other.instance_id), "marking did not equip")
	cell = map.hud.inventory_panel.find_children("*", "ItemCell", true, false).filter(func(c: ItemCell) -> bool: return c.instance_id == other.instance_id and c.equip_slot < 0)
	await _click(cell[0], false, true)
	check(other.locked, "Alt+click: lock")
	check(ItemDescriber.text(character, other).contains("Locked"), "tooltip text names the lock")


func _raise(profession_id: StringName, target: int) -> void:
	while character.professions.level(profession_id) < target:
		character.professions.add_xp(profession_id, character.professions.xp_to_next(profession_id) - character.professions.xp(profession_id))
	ProfessionService.learn_automatic(character)


## Crafts a Traveler's Cloak (5 Linen Cloth, Tailoring 3): returns 3-4 Flax Fiber.
func _crafted_cloak() -> ItemInstance:
	_raise(&"tailoring", 3)
	character.inventory.add_item(&"linen_cloth", 5)
	var before := character.inventory.items().map(func(i: ItemInstance) -> String: return i.instance_id)
	check_eq(ProfessionService.craft(character, &"tl_traveler_cloak", &"weavers_house").error, "", "cloak crafted")
	for item in character.inventory.items():
		if item.definition_id == &"traveler_cloak" and not item.instance_id in before:
			return item
	return null
