extends TestCase
## Preset Activation Atomicity Fix 1.0 (docs/TALENT_SYSTEM.md, Build-Presets): activating a preset is all or
## nothing. PresetService.validate checks the whole activation first - including the loadout change with the
## bag measured in its real target state (CharacterEquipment.loadout_error = the checks of apply_loadout) - and
## a refused activation leaves the character exactly as it was: talents, skills, mods, respec count, loadouts,
## bag, stash and gold. A successful one applies the whole preset and pays the reset only then.

const S := EquipSlot.Slot

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	var definition := db.get_class_def(&"warrior")
	var xp := 0
	for level in range(1, 20):
		xp += definition.xp_to_next(level)
	character.classes.add_xp(&"warrior", xp)   # level 20: 16 points


## Everything an activation may touch, as plain data.
func _state() -> Dictionary:
	return {
		"build": character.builds.get_build(&"warrior").to_dict(),
		"equipment": character.equipment.to_dict(),
		"bag": character.inventory.to_array(),
		"stash": character.stash.to_array(),
		"gold": character.inventory.count(&"gold_coin"),
		"used": character.inventory.used_slots(),
	}


func _ids() -> Array:
	var ids: Array = []
	for item in character.inventory.items():
		ids.append(item.instance_id)
	for item in character.stash.items():
		ids.append(item.instance_id)
	ids.sort()
	return ids


func _fill_bag() -> void:
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"worn_boots", 1, ItemInstance.ORIGIN_STARTING)


func _learn(node_id: StringName, times: int = 1) -> void:
	for i in times:
		check_eq(TalentService.learn(character, &"warrior", node_id), "", "learn %s" % node_id)


func _head() -> String:
	return character.equipment.active_loadout().get_id(S.HEAD)


## A refused activation: the reason, and the whole state unchanged.
func _refused(index: int, contains: String, label: String) -> void:
	var before := _state()
	var ids := _ids()
	var error := PresetService.activate(character, &"warrior", index, true)
	check(error != "" and error.contains(contains), "%s: refused (%s)" % [label, error])
	check_eq(_state(), before, "%s: nothing changed" % label)
	check_eq(_ids(), ids, "%s: no item created, lost or duplicated" % label)
	check(StashService.ownership_errors(character).is_empty(), "%s: ownership consistent" % label)


func test_a_enough_room_and_m_items_kept() -> void:
	var cap := _head()
	check(cap != "", "starting cap worn")
	check_eq(character.equipment.unequip(S.HEAD), "", "cap off")
	PresetService.save_preset(character, &"warrior", 0, "Bare head")
	check_eq(character.equipment.equip(cap, S.HEAD), "", "cap on again")
	var ids := _ids()
	check(PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 0)).is_empty(), "valid with room")
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "activated")
	check_eq(_head(), "", "A: the preset's loadout")
	check(character.inventory.has(cap) and character.inventory.takes_slot(character.inventory.find(cap)), "the cap is a bag item again")
	check_eq(_ids(), ids, "M: same instances, none created or lost")


func test_b_full_bag_swap_fits_c_full_bag_refused() -> void:
	var cap := _head()
	var helm: String = character.inventory.add_item(&"warden_helm", 1, ItemInstance.ORIGIN_STARTING)[0].instance_id
	check_eq(character.equipment.equip(helm, S.HEAD), "", "helm on")
	PresetService.save_preset(character, &"warrior", 0, "Helm")
	check_eq(character.equipment.unequip(S.HEAD), "", "helm off")
	PresetService.save_preset(character, &"warrior", 1, "Bare head")
	check_eq(character.equipment.equip(cap, S.HEAD), "", "cap on")
	_fill_bag()
	check_eq(character.inventory.free_slots(), 0, "bag full")
	# C: the target leaves the cap in the bag - one slot more than there is
	check(Array(PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 1))).has(CharacterEquipment.BAG_FULL), "C: the bag reason before the click")
	_refused(1, "bag is full", "C")
	check_eq(_head(), cap, "C: the cap stays worn")
	# B: helm in, cap out - the freed slot takes the cap
	var ids := _ids()
	check(PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 0)).is_empty(), "B: swap valid with a full bag")
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "B: activated")
	check_eq(_head(), helm, "B: helm worn")
	check_eq(character.inventory.free_slots(), 0, "B: bag exactly full, not over")
	check_eq(_ids(), ids, "B: same instances")


## C with a talent change: the old order paid the reset and switched the talents before the equipment failed.
func test_c_h_i_j_k_l_failed_activation_changes_nothing_not_even_the_talents() -> void:
	_learn(&"war_b_seething", 5)
	_learn(&"war_b_whirlwind")
	check_eq(SkillBook.set_mod(character, &"warrior", &"furious_strike", SkillModDefinition.Slot.FORM, &"furious_wide_arc", true), "", "a mod")
	check_eq(character.equipment.unequip(S.HEAD), "", "cap off")
	PresetService.save_preset(character, &"warrior", 0, "Spin, bare head")
	check_eq(TalentService.respec(character, &"warrior", true), "", "first reset (free)")
	_learn(&"war_wb_hands", 4)
	check_eq(character.equipment.equip(character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"leather_cap")[0].instance_id, S.HEAD), "", "cap on")
	SkillBook.assign_slot(character, &"warrior", 3, &"", true)
	var cost := TalentService.respec_cost(character, &"warrior")
	check(cost > 0, "a talent change costs gold now")
	character.inventory.add_item(&"gold_coin", cost)
	_fill_bag()
	_refused(0, "bag is full", "C+H")
	check_eq(character.builds.get_build(&"warrior").rank(&"war_wb_hands"), 4, "J: talents unchanged")
	check_eq(character.builds.get_build(&"warrior").slots[3], &"", "I: skills unchanged")
	check_eq(character.inventory.count(&"gold_coin"), cost, "L: no gold taken")
	check_eq(character.builds.get_build(&"warrior").respecs, 1, "no reset counted")
	# H: with room the same activation succeeds - and only now costs the reset
	character.inventory.remove_quantity(&"worn_boots", 1)
	var respecs := character.builds.get_build(&"warrior").respecs
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "H: activated with room")
	check_eq(character.inventory.count(&"gold_coin"), 0, "H: exactly the reset cost paid")
	check_eq(character.builds.get_build(&"warrior").respecs, respecs + 1, "H: one reset counted - and kept")
	check_eq(character.builds.get_build(&"warrior").rank(&"war_b_seething"), 5, "the preset's talents")
	check_eq(character.builds.get_build(&"warrior").mod_of(&"furious_strike", SkillModDefinition.Slot.FORM), &"furious_wide_arc", "the preset's mod")
	check_eq(_head(), "", "the preset's loadout")


func test_d_e_missing_and_invalid_references_f_gold_g_same_talents() -> void:
	var helm: String = character.inventory.add_item(&"warden_helm", 1, ItemInstance.ORIGIN_STARTING)[0].instance_id
	check_eq(character.equipment.equip(helm, S.HEAD), "", "helm on")
	PresetService.save_preset(character, &"warrior", 0, "Helm")
	PresetService.save_preset(character, &"warrior", 1, "Wrong slot")
	PresetService.save_preset(character, &"warrior", 2, "Same")
	var wrong: Dictionary = PresetService.get_preset(character, &"warrior", 1).equipment
	wrong[EquipSlot.key_of(S.CHEST)] = helm   # E: a helm in the chest slot
	wrong.erase(EquipSlot.key_of(S.HEAD))
	check_eq(character.equipment.equip(character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"leather_cap")[0].instance_id, S.HEAD), "", "cap on")
	check(character.inventory.take(helm, 1), "D: the helm is gone")
	_refused(0, "Missing item", "D")
	character.inventory.add_item(&"warden_helm", 1, ItemInstance.ORIGIN_STARTING)
	(PresetService.get_preset(character, &"warrior", 1).equipment as Dictionary)[EquipSlot.key_of(S.CHEST)] = character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"warden_helm")[0].instance_id
	_refused(1, "cannot be equipped", "E")
	# F: different talents without the gold
	_learn(&"war_b_seething", 2)
	PresetService.save_preset(character, &"warrior", 3, "Seething")
	check_eq(TalentService.respec(character, &"warrior", true), "", "first reset (free)")
	_learn(&"war_wb_hands")
	check(TalentService.respec_cost(character, &"warrior") > 0 and character.inventory.count(&"gold_coin") < TalentService.respec_cost(character, &"warrior"), "not enough gold")
	_refused(3, "Not enough gold", "F")
	# G: the same talents cost nothing, even without gold
	PresetService.save_preset(character, &"warrior", 2, "Same")
	var respecs := character.builds.get_build(&"warrior").respecs
	var gold := character.inventory.count(&"gold_coin")
	check_eq(PresetService.activation_cost(character, &"warrior", PresetService.get_preset(character, &"warrior", 2)), 0, "G: free")
	check_eq(PresetService.activate(character, &"warrior", 2, true), "", "G: activated")
	check_eq([character.inventory.count(&"gold_coin"), character.builds.get_build(&"warrior").respecs], [gold, respecs], "G: no gold, no reset counted")


## Activation keeps what a preset does not hold: the respec count, unlocks from other sources, other presets.
func test_activation_keeps_respecs_unlocks_and_presets() -> void:
	var build := character.builds.get_build(&"warrior")
	build.unlocked_skills.append(&"whirlwind")   # a quest / boss unlock (not from a talent)
	build.respecs = 3
	PresetService.save_preset(character, &"warrior", 0, "Now")
	PresetService.save_preset(character, &"warrior", 4, "Other")
	var presets := build.presets.duplicate(true)
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "activated")
	check_eq(build.respecs, 3, "respec count kept (the next reset is not free again)")
	check(&"whirlwind" in build.unlocked_skills, "unlock from another source kept")
	check_eq(build.presets, presets, "presets kept")
	check(not build.to_dict().has("equipment") and not build.to_dict().has("name"), "no preset fields leak into the build")


## The rollback tool: restore_loadout puts back exactly the earlier loadout (used when a later step fails).
func test_restore_loadout_undoes_apply_loadout() -> void:
	var before := _state()
	var slots := character.equipment.loadout_for(&"warrior").slots.duplicate()
	check_eq(character.equipment.apply_loadout(&"warrior", {}), "", "everything off (room enough)")
	check_eq(_head(), "", "applied")
	character.equipment.restore_loadout(&"warrior", slots)
	check_eq(_state(), before, "restored exactly")


## loadout_error = apply_loadout's verdict without changing anything.
func test_loadout_error_matches_apply_loadout_and_changes_nothing() -> void:
	_fill_bag()
	var before := _state()
	var error := character.equipment.loadout_error(&"warrior", {})
	check_eq(error, CharacterEquipment.BAG_FULL, "dry run: full bag")
	check_eq(_state(), before, "dry run changed nothing")
	check_eq(character.equipment.apply_loadout(&"warrior", {}), error, "the real call agrees")
	check_eq(_state(), before, "and refused without a change")
	var current := character.equipment.loadout_for(&"warrior").to_dict()
	check_eq(character.equipment.loadout_error(&"warrior", current), "", "the current loadout always fits")


func test_n_save_load_and_o_save_rename_delete() -> void:
	check_eq(PresetService.save_preset(character, &"warrior", 0, "First"), "", "O: save")
	check_eq(PresetService.rename_preset(character, &"warrior", 0, "Renamed"), "", "O: rename")
	check_eq(PresetService.save_preset(character, &"warrior", 1, "Gone"), "", "save")
	check_eq(PresetService.delete_preset(character, &"warrior", 1), "", "O: delete")
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "activated")
	var path := "user://test_saves/preset_atomicity/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), 15, "N: save v15")
	file.close()
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "N: loads cleanly %s" % [loaded.warnings])
	var restored := loaded.character
	check_eq(restored.builds.get_build(&"warrior").to_dict(), character.builds.get_build(&"warrior").to_dict(), "N: build identical")
	check_eq(restored.equipment.to_dict(), character.equipment.to_dict(), "N: loadouts identical")
	check_eq(PresetService.get_preset(restored, &"warrior", 0).get("name"), "Renamed", "N: preset kept")
	check(PresetService.get_preset(restored, &"warrior", 1).is_empty(), "N: deleted stays deleted")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
