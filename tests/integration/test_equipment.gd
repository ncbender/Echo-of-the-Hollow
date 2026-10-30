extends GameplayTestCase
## Equipment: slots, rings, hand rules, class restrictions, stats, class loadouts,
## no loss / no duplication, weapon coupling, persistence.

const ADVENTURER := &"basic_adventurer"
const WARRIOR := &"warrior"
const S := EquipSlot.Slot

var db: GameDatabase
var character: Character
var equipment: CharacterEquipment


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	equipment = character.equipment


func _add(item_id: StringName) -> String:
	return character.inventory.add_item(item_id)[0].instance_id


func _first(item_id: StringName) -> String:
	for item in character.inventory.items():
		if item.definition_id == item_id:
			return item.instance_id
	return ""


func _consistent(label: String) -> void:
	var errors := equipment.integrity_errors()
	errors.append_array(character.inventory.integrity_errors())
	check(errors.is_empty(), "%s: %s" % [label, errors])


func test_starting_gear_is_equipped() -> void:
	check_eq(equipment.get_item(S.MAIN_HAND).definition_id, &"iron_sword", "sword in main hand")
	check_eq(equipment.get_item(S.HEAD).definition_id, &"leather_cap", "cap on head")
	check_eq(equipment.get_item(S.CHEST).definition_id, &"wanderer_coat", "coat on chest")
	check(not equipment.is_equipped(_first(&"steel_greatsword")), "greatsword only carried")
	check_eq(equipment.main_hand_family(), &"one_handed_sword", "main hand family")
	_consistent("start")


func test_slot_mapping_and_wrong_slots() -> void:
	var boots := _add(&"worn_boots")
	check(equipment.equip(boots, S.HEAD) != "", "boots refused on head")
	check_eq(equipment.equip(boots), "", "auto slot works")
	check_eq(equipment.active_loadout().slot_of(boots), S.FEET, "boots on feet")
	check(equipment.equip(_first(&"minor_potion")) != "", "consumable cannot be equipped")
	check(equipment.equip("itm_missing", S.HEAD) != "", "unknown instance refused")
	for item_id: StringName in [&"padded_mantle", &"traveler_cloak", &"leather_bracers", &"leather_gloves", &"rope_belt", &"linen_trousers", &"bone_amulet", &"hollow_charm"]:
		check_eq(equipment.equip(_add(item_id)), "", "%s equips" % item_id)
	check_eq(equipment.active_loadout().slots.size(), 12, "12 slots filled")
	_consistent("all slots")


func test_two_rings_and_ring_moves() -> void:
	var copper := _add(&"copper_ring")
	var silver := _add(&"silver_ring")
	equipment.equip(copper)
	equipment.equip(silver)
	check_eq(equipment.active_loadout().slot_of(copper), S.RING_1, "first ring in slot 1")
	check_eq(equipment.active_loadout().slot_of(silver), S.RING_2, "second ring in slot 2")
	check_eq(equipment.equip(copper, S.RING_2), "", "move copper to ring 2")
	check_eq(equipment.active_loadout().slot_of(copper), S.RING_2, "copper now in ring 2")
	check_eq(equipment.get_item(S.RING_1), null, "ring 1 freed (instance never in two slots)")
	check(character.inventory.has(silver), "displaced silver ring still in inventory")
	_consistent("rings")


func test_two_hander_displaces_off_hand_without_loss() -> void:
	var second_sword := _add(&"militia_sword")
	check(equipment.equip(second_sword, S.OFF_HAND) != "", "one weapon slot: no weapon in the off hand (Weapon Mastery 1.4)")
	var offhand := _add(&"oak_shield")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	check_eq(equipment.equip(offhand, S.OFF_HAND), "", "a shield still goes into the off hand")
	second_sword = offhand
	var greatsword := _first(&"steel_greatsword")
	check_eq(equipment.equip(greatsword), "", "equip two-hander")
	check_eq(equipment.get_item(S.MAIN_HAND).instance_id, greatsword, "two-hander in main hand")
	check_eq(equipment.get_item(S.OFF_HAND), null, "off hand cleared")
	check(equipment.last_displaced.has(second_sword), "off-hand item reported as displaced")
	check(character.inventory.has(second_sword), "off-hand item kept in inventory")
	check_eq(equipment.active_loadout().slots.values().count(greatsword), 1, "two-hander referenced once only")
	check_eq(equipment.equip(second_sword, S.OFF_HAND), "", "off hand while two-hander equipped")
	check_eq(equipment.get_item(S.MAIN_HAND), null, "two-hander displaced back to inventory")
	check(character.inventory.has(greatsword), "two-hander kept")
	_consistent("hand rules")


func test_one_weapon_slot_for_every_family_and_class() -> void:
	var sword := _first(&"iron_sword")
	check(equipment.equip(sword, S.OFF_HAND) != "", "a weapon never goes to the off hand")
	check_eq(equipment.get_item(S.MAIN_HAND).instance_id, sword, "sword stays in the main hand")
	for item_id: StringName in [&"iron_dagger", &"iron_axe", &"iron_mace", &"oak_wand", &"ash_spear", &"oak_staff", &"hunting_bow", &"steel_greatsword"]:
		var item := _add(item_id)
		check_eq(equipment.quick_slot(character.inventory.find(item)), S.MAIN_HAND, "%s: right click goes to the main hand" % item_id)
		for class_id: StringName in [&"basic_adventurer", &"warrior", &"arcanist", &"shadowrunner"]:
			check_eq(equipment.can_equip(item, S.MAIN_HAND, class_id), "", "%s may wield %s" % [class_id, item_id])
	_consistent("one weapon slot")


func test_shield_and_class_restrictions() -> void:
	var shield := _add(&"oak_shield")
	check(equipment.equip(shield) != "", "adventurer cannot use shields")
	var helm := _add(&"warlord_helm")
	check(equipment.equip(helm) != "", "warrior-only helm refused for adventurer")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	check_eq(equipment.equip(shield), "", "warrior uses shield")
	check_eq(equipment.get_item(S.OFF_HAND).instance_id, shield, "shield in off hand")
	check_eq(equipment.get_item(S.MAIN_HAND).definition_id, &"iron_sword", "one-hander plus shield")
	check_eq(equipment.equip(helm), "", "warrior helm allowed")
	_consistent("restrictions")


func test_stats_recomputed_without_accumulation() -> void:
	var coat := _first(&"wanderer_coat")
	var base := character.get_stat(Stats.MAX_HEALTH)
	check_eq(base, 110.0, "100 base + 10 coat")
	for i in 20:
		equipment.unequip(S.CHEST)
		equipment.equip(coat)
	check_eq(character.get_stat(Stats.MAX_HEALTH), 110.0, "no stacking after 20 re-equips")
	equipment.unequip(S.CHEST)
	check_eq(character.get_stat(Stats.MAX_HEALTH), 100.0, "bonus gone after unequip")
	check_eq(character.get_stat(Stats.ARMOR), 3.0, "cap armor only")
	var ring := _add(&"silver_ring")
	equipment.equip(ring)
	check_eq(character.get_stat(Stats.CRIT_CHANCE), 3.0, "ring crit")
	check_eq(character.get_stat(Stats.PHYSICAL_DAMAGE), 3.0, "ring damage")


func test_class_loadouts_are_separate_and_share_instances() -> void:
	var items_before := character.inventory.used_slots()
	character.classes.unlock(WARRIOR)
	check_eq(equipment.loadout_for(WARRIOR).get_id(S.MAIN_HAND), _first(&"iron_sword"), "warrior loadout initialised from adventurer")
	character.switch_class(WARRIOR, true)
	var greatsword := _first(&"steel_greatsword")
	equipment.equip(greatsword)
	var helm := _add(&"warlord_helm")
	equipment.equip(helm)
	check_eq(equipment.main_hand_family(), &"two_handed_sword", "warrior uses greatsword")
	check_eq(character.get_stat(Stats.MAX_HEALTH), 120.0 + 15.0 + 10.0, "warrior + helm + coat")
	character.switch_class(ADVENTURER, true)
	check_eq(equipment.main_hand_family(), &"one_handed_sword", "adventurer keeps the sword")
	check_eq(equipment.get_item(S.HEAD).definition_id, &"leather_cap", "adventurer keeps cap")
	check_eq(character.get_stat(Stats.MAX_HEALTH), 110.0, "only active loadout counts")
	check(equipment.is_referenced(_first(&"wanderer_coat")), "coat referenced")
	check(equipment.is_equipped(_first(&"wanderer_coat"), WARRIOR) and equipment.is_equipped(_first(&"wanderer_coat"), ADVENTURER), "same coat instance in both loadouts")
	check_eq(character.inventory.used_slots(), items_before + 1, "no item duplicated (only the new helm)")
	_consistent("loadouts")


func test_discarding_equipped_item_clears_all_loadouts() -> void:
	character.classes.unlock(WARRIOR)
	var coat := _first(&"wanderer_coat")
	check(equipment.is_equipped(coat, WARRIOR), "warrior references coat")
	check(character.discard_item(coat), "discard")
	check(not equipment.is_referenced(coat), "no loadout references the discarded coat")
	check_eq(character.get_stat(Stats.MAX_HEALTH), 100.0, "stats updated")
	_consistent("discard")


func test_random_equipment_operations_keep_invariants() -> void:
	character.classes.unlock(WARRIOR)
	for item_id: StringName in [&"militia_sword", &"oak_shield", &"copper_ring", &"silver_ring", &"warlord_helm", &"worn_boots"]:
		_add(item_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total_items := character.inventory.items().size()   # bag + equipment slots (Equipment Inventory Separation 1.0)
	for i in 400:
		var items := character.inventory.items()
		match rng.randi() % 4:
			0, 1:
				var item := items[rng.randi() % items.size()]
				equipment.equip(item.instance_id, rng.randi_range(-1, EquipSlot.Slot.size() - 1))
			2:
				equipment.unequip(rng.randi() % EquipSlot.Slot.size())
			3:
				character.switch_class(WARRIOR if character.classes.active_class_id == ADVENTURER else ADVENTURER, true)
		var errors := equipment.integrity_errors()
		errors.append_array(character.inventory.integrity_errors())   # never over the bag capacity
		if not errors.is_empty():
			fail("step %d: %s" % [i, errors])
			return
	check_eq(character.inventory.items().size(), total_items, "no item lost or created")


func test_weapon_follows_main_hand() -> void:
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	bridge.name = "ProgressionBridge"
	player.add_child(bridge)
	bridge.bind(player, character)
	check_eq(player.combat.weapon.id, &"one_handed_sword", "combat uses equipped sword")
	var f := frame()
	await tick(light(f))
	equipment.equip(_first(&"steel_greatsword"))
	check_eq(player.combat.weapon.id, &"one_handed_sword", "no weapon swap mid-attack")
	await tick(f, 40)
	check_eq(player.combat.weapon.id, &"two_handed_sword", "switched once idle")
	equipment.equip(_add(&"hunting_bow"))
	await tick(frame(), 2)
	check_eq(player.combat.weapon.id, &"bow", "the bow from the inventory replaces the greatsword (no quick swap)")
	equipment.unequip(S.MAIN_HAND)
	await tick(frame(), 2)
	check_eq(player.combat.weapon.id, db.rules.fallback_weapon_family, "fallback without weapon")


func test_loadout_serialization_drops_invalid_references() -> void:
	character.classes.unlock(WARRIOR)
	var data := equipment.to_dict()
	var restored := CharacterEquipment.new(db, character.inventory, character.classes)
	var warnings: PackedStringArray = []
	restored.from_dict(data, warnings)
	check(warnings.is_empty(), "clean restore: %s" % [warnings])
	check_eq(restored.to_dict(), data, "roundtrip identical")
	var greatsword := _first(&"steel_greatsword")
	var broken := {
		"basic_adventurer": {"MAIN_HAND": greatsword, "OFF_HAND": _first(&"iron_sword"), "HEAD": "itm_missing", "NOSE": "x"},
	}
	restored.from_dict(broken, warnings)
	check_eq(restored.loadout_for(ADVENTURER).get_id(S.HEAD), "", "missing item reference dropped")
	check_eq(restored.loadout_for(ADVENTURER).get_id(S.OFF_HAND), "", "off hand with two-hander dropped")
	check_eq(restored.loadout_for(ADVENTURER).get_id(S.MAIN_HAND), greatsword, "valid reference kept")
	check(warnings.size() >= 3, "warnings reported")
	check(restored.integrity_errors().is_empty(), "restored loadouts consistent")
