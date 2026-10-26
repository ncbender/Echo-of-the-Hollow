extends TestCase
## Inventory & Haven Stash 1.0: ownership (one container per item), categories
## as views, atomic transfers, stack merging, capacities, edge cases (full
## containers, equipped and preset items, rapid repeats), save/load and the
## v5 -> v6 migration. Only user://test_saves/.

const PATH := "user://test_saves/stash/slot_1.save.json"

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = SessionState.find(get_tree()).database
	character = CharacterFactory.create_new(db)
	character.inventory.capacity = 60


func _add(item_id: StringName, amount: int = 1) -> ItemInstance:
	var added := character.inventory.add_item(item_id, amount)
	return added[added.size() - 1] if not added.is_empty() else null


func _total(item_id: StringName) -> int:
	return character.inventory.count(item_id) + character.stash.count(item_id)


func _all_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for item in character.inventory.items():
		ids.append(item.instance_id)
	for item in character.stash.items():
		ids.append(item.instance_id)
	return ids


func test_categories_are_views_of_one_container() -> void:
	check_eq(StashService.category_of(db.get_item(&"iron_sword")), StashService.EQUIPMENT, "regular weapon -> Equipment Chest")
	check_eq(StashService.category_of(db.get_item(&"crushing_oath")), StashService.COLLECTION, "unique -> Collection Vault")
	check_eq(StashService.category_of(db.get_item(&"warden_helm")), StashService.COLLECTION, "set item -> Collection Vault")
	check_eq(StashService.category_of(db.get_item(&"iron_ore")), StashService.MATERIALS, "ore -> Material Vault")
	check_eq(StashService.category_of(db.get_item(&"storm_wolf_essence")), StashService.MATERIALS, "essence -> Material Vault")
	check_eq(StashService.category_of(db.get_item(&"gold_coin")), &"", "gold is never stored")
	check_eq(StashService.category_of(db.get_item(&"supply_crate")), &"", "quest items stay in the bag")
	for item_id: StringName in [&"iron_sword", &"crushing_oath", &"iron_ore"]:
		var item := _add(item_id, 3 if item_id == &"iron_ore" else 1)
		check_eq(StashService.deposit(character, item.instance_id), "", "%s stored" % item_id)
	check_eq(character.stash.items().size(), 3, "one container holds all categories")
	var seen := 0
	for category in StashService.CATEGORIES:
		seen += StashService.items(character, category).size()
	check_eq(seen, 3, "every stored item in exactly one category view")
	check_eq(StashService.capacity(character, StashService.MATERIALS), -1, "Material Vault has no slot limit")


func test_equipment_keeps_identity_and_crafted_state() -> void:
	var blade := _add(&"forged_blade")
	blade.quality = 3
	blade.material_id = &"storm_ore"
	blade.affixes.append({"affix": "sharpened", "tier": 3, "value": 4.0, "flat": 0.0, "percent": 0.0})
	blade.essences.append(&"storm_wolf")
	blade.sockets.append(&"garnet")
	var before := blade.to_dict()
	check_eq(StashService.deposit(character, blade.instance_id), "", "deposited")
	check(character.stash.find(blade.instance_id) == blade and not character.inventory.has(blade.instance_id), "moved (same instance), not copied")
	check_eq(StashService.withdraw(character, blade.instance_id), "", "withdrawn")
	check_eq(character.inventory.find(blade.instance_id).to_dict(), before, "affixes, essences, sockets, quality, material unchanged")


func test_material_stacks_merge_only_when_identical() -> void:
	var first := _add(&"iron_ore", 30)
	StashService.deposit(character, first.instance_id)
	var second := _add(&"iron_ore", 30)
	var second_id := second.instance_id
	check_eq(StashService.deposit(character, second_id), "", "second stack deposited")
	var stacks := character.stash.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"iron_ore")
	check_eq(stacks.size(), 2, "30 + 30 with max 50 -> a full stack and a partial one")
	check_eq(character.stash.count(&"iron_ore"), 60, "quantity kept")
	check_eq((stacks[0] as ItemInstance).quantity, 50, "existing stack filled first")
	check(character.stash.has(second_id), "the rest keeps its instance id")
	var storm := _add(&"storm_ore", 5)
	StashService.deposit(character, storm.instance_id)
	check_eq(character.stash.count(&"storm_ore"), 5, "different material: own stack, no merge")
	var odd := _add(&"iron_ore", 5)
	odd.quality = 1   # per-instance state: never merged
	StashService.deposit(character, odd.instance_id)
	check(character.stash.has(odd.instance_id) and odd.quantity == 5, "a stack with its own state stays separate")
	check_eq(_total(&"iron_ore"), 65, "no ore lost or created")
	check(StashService.ownership_errors(character).is_empty(), "consistent: %s" % [StashService.ownership_errors(character)])


func test_full_containers_refuse_cleanly() -> void:
	# Equipment Chest full
	character.inventory.capacity = 200
	var limit := StashService.capacity(character, StashService.EQUIPMENT)
	for i in limit:
		StashService.deposit(character, _add(&"iron_sword").instance_id)
	var extra := _add(&"iron_sword")
	var error := StashService.deposit(character, extra.instance_id)
	check(error.contains("Equipment Chest is full"), "full chest refuses: %s" % error)
	check(character.inventory.has(extra.instance_id) and not character.stash.has(extra.instance_id), "nothing moved")
	# bag full: withdrawing is refused, the stash keeps the item
	character.inventory.capacity = character.inventory.used_slots()
	var stored := StashService.items(character, StashService.EQUIPMENT)[0]
	error = StashService.withdraw(character, stored.instance_id)
	check(error.contains("bag is full"), "full bag refuses: %s" % error)
	check(character.stash.has(stored.instance_id), "item stays in the stash")
	# materials: a withdraw that only fits partly is refused as a whole
	character.inventory.capacity = 200
	var ore := _add(&"iron_ore", 45)
	StashService.deposit(character, ore.instance_id)
	character.inventory.capacity = character.inventory.used_slots()
	_add(&"iron_ore", 1)   # fails (bag full) - nothing to merge into
	var vault_ore: ItemInstance = character.stash.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"iron_ore")[0]
	error = StashService.withdraw(character, vault_ore.instance_id)
	check(error.contains("Not enough room"), "partial room is refused: %s" % error)
	check_eq(character.stash.count(&"iron_ore"), 45, "all ore still in the vault")
	check(StashService.ownership_errors(character).is_empty(), "consistent")


func test_equipped_and_preset_items() -> void:
	var sword := _add(&"iron_sword")
	character.equipment.equip(sword.instance_id, EquipSlot.Slot.MAIN_HAND)
	var error := StashService.deposit(character, sword.instance_id)
	check(error.contains("equipped"), "equipped items stay: %s" % error)
	check(character.inventory.has(sword.instance_id), "still in the bag")
	# a preset only references: storing the item makes the preset say where it is
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	character.equipment.equip(sword.instance_id, EquipSlot.Slot.MAIN_HAND)
	PresetService.save_preset(character, &"warrior", 0, "Sword")
	character.equipment.unequip(EquipSlot.Slot.MAIN_HAND)
	var other_class := character.equipment.loadout_for(&"basic_adventurer")
	if other_class.slot_of(sword.instance_id) >= 0:
		character.equipment.unequip(other_class.slot_of(sword.instance_id), &"basic_adventurer")
	check_eq(StashService.deposit(character, sword.instance_id), "", "unequipped item can be stored")
	var errors := PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 0))
	check(" ".join(errors).contains("Haven stash"), "preset names the stash: %s" % [errors])
	check_eq(StashService.withdraw(character, sword.instance_id), "", "taken out again")
	check(PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 0)).is_empty(), "preset usable again")


func test_rapid_repeats_never_duplicate() -> void:
	var sword := _add(&"iron_sword")
	var ore := _add(&"iron_ore", 20)
	var before := _all_ids().size()
	var results: PackedStringArray = []
	for i in 6:   # like very fast right clicks on stale cells
		results.append(StashService.deposit(character, sword.instance_id))
		results.append(StashService.deposit(character, ore.instance_id))
	check_eq(results.count(""), 2, "each item moved exactly once")
	check(results[2].contains("no longer in your bag"), "later clicks are refused: %s" % results[2])
	for i in 6:
		StashService.withdraw(character, sword.instance_id)
	check(character.inventory.has(sword.instance_id) and not character.stash.has(sword.instance_id), "in exactly one container")
	check_eq(_all_ids().size(), before, "no instance created or lost")
	check_eq(_total(&"iron_ore"), 20, "quantities exact")


func test_deposit_all_materials_and_sort() -> void:
	_add(&"iron_ore", 12)
	_add(&"storm_ore", 4)
	_add(&"stone_golem_essence", 2)
	var sword := _add(&"iron_sword")
	_add(&"supply_crate", 1)
	_add(&"gold_coin", 30)
	var result := StashService.deposit_all_materials(character)
	check_eq(result.moved, 3, "three material stacks moved")
	check(character.inventory.has(sword.instance_id) and character.inventory.count(&"supply_crate") == 1 and character.inventory.count(&"gold_coin") == 30,
		"equipment, quest items and gold stay")
	StashService.deposit(character, _add(&"crushing_oath").instance_id)
	StashService.deposit(character, sword.instance_id)
	var ids_before := _all_ids()
	ids_before.sort()
	StashService.sort(character)
	var order := character.stash.items().map(func(i: ItemInstance) -> StringName: return StashService.category_of(db.get_item(i.definition_id)))
	check_eq(order[0], StashService.EQUIPMENT, "sorted by category: equipment first")
	check_eq(order[order.size() - 1], StashService.COLLECTION, "collection last")
	var ids_after := _all_ids()
	ids_after.sort()
	check_eq(ids_after, ids_before, "sorting changes no ids")


func test_capacity_grows_when_the_storehouse_is_restored() -> void:
	var ruined := StashService.capacity(character, StashService.EQUIPMENT)
	check(ruined >= 60, "a basic chest already while ruined (%d)" % ruined)
	character.world.set_restoration(&"old_storehouse", &"restored")
	check(StashService.capacity(character, StashService.EQUIPMENT) > ruined, "restored: more room")
	check(StashService.capacity(character, StashService.COLLECTION) > db.rules.stash_collection_slots, "collection grows too")


func test_save_load_keeps_stash_and_everything_else() -> void:
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	character.classes.add_xp(&"warrior", 9000)
	TalentService.learn(character, &"warrior", &"war_b_seething")
	var sword := _add(&"iron_sword")
	var blade := _add(&"forged_blade")
	blade.affixes.append({"affix": "sharpened", "tier": 3, "value": 4.0, "flat": 0.0, "percent": 0.0})
	StashService.deposit(character, blade.instance_id)
	StashService.deposit(character, _add(&"iron_ore", 33).instance_id)
	StashService.deposit(character, _add(&"warden_helm").instance_id)
	character.equipment.equip(sword.instance_id, EquipSlot.Slot.MAIN_HAND)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded: %s" % [loaded.errors])
	var restored := loaded.character
	check_eq(restored.stash.to_array(), character.stash.to_array(), "stash identical (ids, stacks, crafted state)")
	check_eq(restored.inventory.to_array(), character.inventory.to_array(), "bag identical")
	check_eq(restored.equipment.get_item(EquipSlot.Slot.MAIN_HAND).instance_id, sword.instance_id, "equipment slot kept")
	check_eq(restored.classes.get_level(&"warrior"), character.classes.get_level(&"warrior"), "class level unchanged")
	check_eq(restored.builds.get_build(&"warrior").talents, character.builds.get_build(&"warrior").talents, "talents unchanged")
	check(StashService.ownership_errors(restored).is_empty(), "no duplicates after loading")
	DirAccess.remove_absolute(PATH)


func test_v5_save_migrates_to_an_empty_stash() -> void:
	var payload := character.to_dict()
	payload.erase("stash")   # how a version 5 save looks
	var errors: PackedStringArray = []
	var migrated: Dictionary = SaveMigrations.migrate(payload, 5, errors)
	check(errors.is_empty() and migrated.stash is Dictionary and (migrated.stash.items as Array).is_empty(), "empty stash added")
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(migrated, db, warnings)
	check_eq(loaded.stash.items().size(), 0, "loads with an empty stash")
	check_eq(loaded.inventory.to_array(), character.inventory.to_array(), "bag untouched by the migration")


func test_damaged_save_never_loads_an_item_twice() -> void:
	var sword := _add(&"iron_sword")
	var payload := character.to_dict()
	payload["stash"] = {"items": [sword.to_dict()]}   # same instance in bag and stash
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(payload, db, warnings)
	check(loaded.inventory.has(sword.instance_id) and not loaded.stash.has(sword.instance_id), "only one copy loaded")
	check(loaded.orphaned_items.size() >= 1, "the other copy is kept as orphan (never deleted)")
	check(" ".join(warnings).contains("also in the bag"), "reported: %s" % [warnings])
