extends TestCase
## Equipment Inventory Separation 1.0 (docs/EQUIPMENT_SYSTEM.md): an item in an equipment slot of
## the active class is located there and takes no bag slot; equip / unequip / swap / presets /
## class switches are atomic and refused (nothing changes) when the bag cannot take what comes
## back. Save v15 unchanged: old saves (bag counted the equipped items) and new saves (bag full
## plus equipped gear) load without loss. Files only under user://test_saves/equipment_separation/.

const PATH := "user://test_saves/equipment_separation/slot_1.save.json"
const S := EquipSlot.Slot

var db: GameDatabase
var character: Character
var equipment: CharacterEquipment
var bag: Inventory


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	equipment = character.equipment
	bag = character.inventory


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _add(item_id: StringName) -> ItemInstance:
	return bag.add_item(item_id)[0]


## Fills every free bag slot with single (unstackable) items.
func _fill_bag() -> void:
	while bag.free_slots() > 0:
		_add(&"leather_cap")


func _state() -> Array:
	return [bag.to_array(), equipment.to_dict(), bag.used_slots()]


func _consistent(label: String) -> void:
	var errors := StashService.ownership_errors(character)
	check(errors.is_empty(), "%s: consistent %s" % [label, errors])


func test_a_equip_frees_and_b_unequip_takes_a_bag_slot() -> void:
	var boots := _add(&"worn_boots")
	var used := bag.used_slots()
	check(bag.takes_slot(boots), "carried boots use a bag slot")
	check_eq(equipment.equip(boots.instance_id, S.FEET), "", "A: equipped")
	check_eq(bag.used_slots(), used - 1, "A: the bag slot is free")
	check(not bag.takes_slot(boots) and bag.in_equipment(boots.instance_id), "A: located in the equipment slot")
	check_eq(equipment.unequip(S.FEET), "", "B: unequipped")
	check_eq(bag.used_slots(), used, "B: back in a bag slot")
	_consistent("A/B")


func test_c_replacing_returns_exactly_the_old_item() -> void:
	var old_cap := equipment.get_item(S.HEAD)
	var helm := _add(&"warden_helm")
	var used := bag.used_slots()
	var total := bag.items().size()
	check_eq(equipment.equip(helm.instance_id, S.HEAD), "", "helm equipped over the cap")
	check_eq(equipment.last_displaced, [old_cap.instance_id] as Array[String], "C: exactly the old cap came back")
	check(bag.takes_slot(old_cap) and not bag.takes_slot(helm), "C: cap in the bag, helm in the slot")
	check_eq(bag.used_slots(), used, "C: one in, one out")
	check_eq(bag.items().size(), total, "C: no item lost or created")
	_consistent("C")


func test_d_full_bag_swap_reuses_the_freed_slot_e_unequip_refused() -> void:
	var helm := _add(&"warden_helm")
	_fill_bag()
	check_eq(bag.free_slots(), 0, "bag full")
	check_eq(equipment.equip(helm.instance_id, S.HEAD), "", "D: swap with a full bag")
	check_eq(bag.free_slots(), 0, "D: the old cap took the helm's slot")
	var before := _state()
	check_eq(equipment.unequip(S.HEAD), CharacterEquipment.BAG_FULL, "E: unequip refused with a reason")
	check_eq(_state(), before, "E: nothing changed - the helm stays equipped")
	check(equipment.get_item(S.HEAD) == helm, "E: still on the head")
	# an equip that would push two items back (two-hander vs. sword + shield) needs one more slot
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	var shield := _add_after_room(&"oak_shield")
	check_eq(equipment.equip(shield.instance_id, S.OFF_HAND), "", "shield on (its slot freed)")
	_fill_bag()   # the shield freed its slot - full again
	var greatsword := _first_carried(&"steel_greatsword")
	if check(greatsword != null, "a carried greatsword"):
		before = _state()
		check_eq(equipment.equip(greatsword.instance_id, S.MAIN_HAND), CharacterEquipment.BAG_FULL, "E: two coming back, one slot freed: refused")
		check_eq(_state(), before, "E: no partial swap")
		check(equipment.last_displaced.is_empty(), "E: nothing reported as displaced")
	_consistent("D/E")


func _add_after_room(item_id: StringName) -> ItemInstance:
	var filler := _first_carried(&"leather_cap")
	bag.remove_instance(filler.instance_id)
	return _add(item_id)


func _first_carried(item_id: StringName) -> ItemInstance:
	for item in bag.items():
		if item.definition_id == item_id and bag.takes_slot(item):
			return item
	return null


func test_f_instance_data_survives_every_move_g_save_load() -> void:
	# a real generated Magic item (affixes rolled by AffixRoller, rarity, origin, base damage) with a favourite mark
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var weights := load("res://data/loot/hollowwood_early_tiers.tres") as AffixTierWeights
	var ring := ItemCreation.generate(db.get_item(&"iron_mace"), ItemDefinition.Rarity.MAGIC, db, rng, weights, 7, ItemInstance.ORIGIN_FOUND).item
	if not check(ring != null and not ring.affixes.is_empty(), "a generated item with affixes"):
		return
	ring.favorite = true
	check_eq(bag.add_instance(ring), "", "carried")
	var data := ring.to_dict()
	check_eq(equipment.equip(ring.instance_id, S.MAIN_HAND), "", "mace equipped")
	check_eq(bag.find(ring.instance_id).to_dict(), data, "F: equipped instance unchanged")
	check_eq(equipment.unequip(S.MAIN_HAND), "", "unequipped")
	check_eq(bag.find(ring.instance_id).to_dict(), data, "F: unequipped instance unchanged")
	equipment.equip(ring.instance_id, S.MAIN_HAND)
	_fill_bag()   # a new-style save: a full bag plus equipped gear
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	check_eq(SaveSystem.save_to(character, PATH), OK, "G: saved (v%d)" % SaveSystem.VERSION)
	var loaded := SaveSystem.load_from(PATH, db)
	if not check(loaded.ok(), "G: loaded %s" % [loaded.errors]):
		return
	var again := loaded.character
	check(again.orphaned_items.is_empty(), "G: nothing orphaned for room (%d)" % again.orphaned_items.size())
	check_eq(again.inventory.items().size(), bag.items().size(), "G: every item loaded")
	check_eq(again.inventory.used_slots(), bag.used_slots(), "G: same bag use")
	check_eq(again.equipment.to_dict(), equipment.to_dict(), "G: same loadouts")
	check_eq(again.inventory.find(ring.instance_id).to_dict(), data, "G: affixes, rarity, base damage, origin, marks kept")
	check(again.inventory.in_equipment(ring.instance_id), "G: still located in its slot")
	check(StashService.ownership_errors(again).is_empty(), "G: consistent %s" % [StashService.ownership_errors(again)])


func test_old_v15_save_with_equipped_items_in_the_bag_count_loads_unchanged() -> void:
	# a save written before this fix: identical format (loadouts reference bag instances) - the
	# bag simply gets the equipped items' slots back. Loading twice gives the same state.
	var payload := character.to_dict()
	var warnings: PackedStringArray = []
	var first := Character.from_dict(payload, db, warnings)
	var second := Character.from_dict(first.to_dict(), db, warnings)
	check_eq(first.to_dict(), payload, "loads into the same data (no migration)")
	check_eq(second.to_dict(), payload, "idempotent")
	var equipped := equipment.active_loadout().instance_ids().size()
	check(equipped > 0, "starting gear is equipped")
	check_eq(first.inventory.used_slots(), first.inventory.items().size() - equipped, "equipped items take no bag slot after loading")
	check(warnings.is_empty(), "no warnings %s" % [warnings])


func test_h_rapid_equip_unequip_and_i_no_duplicates() -> void:
	var ring := _add(&"copper_ring")
	var total := bag.items().size()
	for i in 50:
		equipment.equip(ring.instance_id, S.RING_1 if i % 2 == 0 else S.RING_2)
		if i % 3 == 0:
			equipment.unequip(S.RING_1)
			equipment.unequip(S.RING_2)
	check_eq(bag.items().size(), total, "H: no item lost or created")
	var ids := {}
	for item in bag.items():
		check(not ids.has(item.instance_id), "I: instance %s once" % item.instance_id)
		ids[item.instance_id] = true
	check(equipment.active_loadout().instance_ids().count(ring.instance_id) <= 1, "I: at most one slot")
	for item in character.stash.items():
		check(not bag.has(item.instance_id), "I: never in bag and stash")
	_consistent("H/I")


func test_j_stats_and_set_bonuses_follow_the_slots_only() -> void:
	var pieces: Array[ItemInstance] = []
	for item_id: StringName in [&"warden_helm", &"warden_mail", &"warden_greaves"]:
		pieces.append(_add(item_id))
	for piece in pieces:
		equipment.equip(piece.instance_id)
	var bonuses := character.active_set_bonuses().size()
	check(bonuses > 0, "J: the Hollow Warden set is active")
	var stats := character.get_stats().duplicate()
	_fill_bag()
	check_eq(equipment.unequip(equipment.active_loadout().slot_of(pieces[0].instance_id)), CharacterEquipment.BAG_FULL, "full bag: refused")
	check_eq(character.active_set_bonuses().size(), bonuses, "J: set bonus unchanged after the refusal")
	check_eq(character.get_stats(), stats, "J: stats unchanged after the refusal")
	bag.remove_instance(_first_carried(&"leather_cap").instance_id)
	check_eq(equipment.unequip(equipment.active_loadout().slot_of(pieces[0].instance_id)), "", "room: unequipped")
	check(character.active_set_bonuses().size() < bonuses or character.get_stats() != stats, "J: stats follow the removed piece")
	equipment.equip(pieces[0].instance_id)
	check_eq(character.get_stats(), stats, "J: re-equipped - the same stats (recomputed, not accumulated)")


func test_class_switch_refused_when_the_old_gear_would_not_fit() -> void:
	character.classes.unlock(&"warrior")
	var warrior := equipment.loadout_for(&"warrior")
	for slot: int in warrior.slots.keys():
		warrior.set_id(slot, "")   # the warrior wears nothing: switching brings all gear back
	_fill_bag()
	var before := _state()
	var error := character.switch_class(&"warrior", true)
	check(error.contains("too full"), "refused with a reason (%s)" % error)
	check_eq(character.classes.active_class_id, db.rules.starting_class_id, "still the old class")
	check_eq(_state(), before, "nothing changed")
	for i in equipment.active_loadout().instance_ids().size():
		bag.remove_instance(_first_carried(&"leather_cap").instance_id)
	check_eq(character.switch_class(&"warrior", true), "", "with room: switched")
	check_eq(bag.used_slots(), bag.capacity, "the old class's gear is back in the bag")
	_consistent("class switch")


func test_preset_apply_is_refused_without_room() -> void:
	var head := equipment.active_loadout().get_id(S.HEAD)
	_fill_bag()
	var before := _state()
	check_eq(equipment.apply_loadout(character.classes.active_class_id, {}), CharacterEquipment.BAG_FULL, "an empty preset needs room for all gear")
	check_eq(_state(), before, "nothing changed")
	check_eq(equipment.active_loadout().get_id(S.HEAD), head, "gear still worn")
