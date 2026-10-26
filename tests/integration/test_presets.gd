extends TestCase
## Class Foundation G1: build presets - five slots per class, free save/rename,
## activation at a class station (free with identical talents, respec cost
## otherwise), full validation (talents, skills, mods, items, gold), item
## references only (never new items), persistence and class switching.

const SAVE := "user://test_saves/presets.save.json"
const S := EquipSlot.Slot

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	var definition := db.get_class_def(&"warrior")
	var needed := 0
	for level in range(1, 30):
		needed += definition.xp_to_next(level)
	character.classes.add_xp(&"warrior", needed)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _learn(node_id: StringName, ranks: int) -> void:
	for i in ranks:
		check_eq(TalentService.learn(character, &"warrior", node_id), "", "learn %s" % node_id)


func _item(definition_id: StringName) -> ItemInstance:
	return character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == definition_id)[0]


func test_five_slots_save_rename_and_free_reload() -> void:
	check_eq(PresetService.slot_count(character), 5, "five preset slots")
	_learn(&"war_b_seething", 5)
	check_eq(PresetService.save_preset(character, &"warrior", 0, "Speed"), "", "saved (free)")
	check(PresetService.save_preset(character, &"warrior", 5, "x") != "", "only five slots")
	check_eq(PresetService.rename_preset(character, &"warrior", 0, "Berserk"), "", "renamed (free)")
	check_eq(PresetService.get_preset(character, &"warrior", 0).name, "Berserk", "new name")
	var gold := character.inventory.count(&"gold_coin")
	check_eq(PresetService.activation_cost(character, &"warrior", PresetService.get_preset(character, &"warrior", 0)), 0, "identical talents: free")
	check(PresetService.activate(character, &"warrior", 0, false) != "", "activation only at a class station")
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "activated")
	check_eq(character.inventory.count(&"gold_coin"), gold, "nothing paid")


func test_different_talents_cost_a_respec_and_skills_follow() -> void:
	_learn(&"war_b_seething", 5)
	_learn(&"war_b_whirlwind", 1)
	SkillBook.assign_slot(character, &"warrior", 3, &"whirlwind", true)
	SkillBook.set_mod(character, &"warrior", &"furious_strike", SkillModDefinition.Slot.FORM, &"furious_wide_arc", true)
	PresetService.save_preset(character, &"warrior", 1, "Whirl")
	TalentService.respec(character, &"warrior", true)   # first one is free
	_learn(&"war_wb_hands", 5)
	_learn(&"war_wb_skin", 1)
	check_eq(character.builds.get_build().slot_of(&"whirlwind"), -1, "whirlwind left the bar with its talent")
	var preset := PresetService.get_preset(character, &"warrior", 1)
	var cost := PresetService.activation_cost(character, &"warrior", preset)
	check_eq(cost, TalentService.rules(character).respec_cost(30), "different talents: normal respec cost")
	check(Array(PresetService.validate(character, &"warrior", preset)).any(func(e: String) -> bool: return e.contains("gold")), "gold checked")
	character.inventory.add_item(&"gold_coin", cost)
	check_eq(PresetService.activate(character, &"warrior", 1, true), "", "activated")
	check_eq(character.inventory.count(&"gold_coin"), 0, "respec cost paid")
	var build := character.builds.get_build()
	check_eq(build.rank(&"war_b_seething"), 5, "preset talents")
	check_eq(build.rank(&"war_wb_hands"), 0, "old talents gone")
	check_eq(build.slots[3], &"whirlwind", "preset skill slot")
	check_eq(build.mod_of(&"furious_strike", SkillModDefinition.Slot.FORM), &"furious_wide_arc", "preset mod")
	check_eq(build.presets.size(), 5, "presets kept after activation")
	check_near(character.get_stat(Stats.ATTACK_SPEED), 10.0, 0.001, "talent stats applied once")


func test_equipment_references_and_missing_items() -> void:
	var sword := _item(&"iron_sword")
	var great := _item(&"steel_greatsword")
	character.equipment.equip(sword.instance_id, S.MAIN_HAND)
	PresetService.save_preset(character, &"warrior", 0, "Sword")
	character.equipment.equip(great.instance_id, S.MAIN_HAND)
	PresetService.save_preset(character, &"warrior", 1, "Great")
	var items_before := character.inventory.items().size()
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "sword preset")
	check_eq(character.equipment.get_item(S.MAIN_HAND), sword, "same instance equipped")
	check_eq(character.inventory.items().size(), items_before, "no item created")
	check(character.equipment.integrity_errors().is_empty(), "loadout consistent")
	character.discard_item(great.instance_id)
	var errors := PresetService.validate(character, &"warrior", PresetService.get_preset(character, &"warrior", 1))
	check(Array(errors).any(func(e: String) -> bool: return e.contains("Missing item")), "missing item reported: %s" % [errors])
	check(PresetService.activate(character, &"warrior", 1, true) != "", "invalid preset refused")
	check_eq(character.equipment.get_item(S.MAIN_HAND), sword, "nothing changed by the refused activation")
	check(not character.inventory.has(great.instance_id), "missing item is not recreated")


func test_invalid_talents_and_locked_skills_are_refused() -> void:
	_learn(&"war_b_seething", 5)
	_learn(&"war_b_whirlwind", 1)
	SkillBook.assign_slot(character, &"warrior", 3, &"whirlwind", true)
	PresetService.save_preset(character, &"warrior", 2, "Tampered")
	var preset := PresetService.get_preset(character, &"warrior", 2)
	preset.talents["war_b_unbound"] = 1   # capstone without the points below
	var errors := PresetService.validate(character, &"warrior", preset)
	check(not errors.is_empty(), "invalid talent allocation refused: %s" % [errors])
	preset.talents.erase("war_b_unbound")
	preset.talents.erase("war_b_whirlwind")
	errors = PresetService.validate(character, &"warrior", preset)
	check(Array(errors).any(func(e: String) -> bool: return e.contains("Whirlwind")), "skill without its talent refused: %s" % [errors])


func test_presets_per_class_and_persistence() -> void:
	_learn(&"war_b_seething", 3)
	PresetService.save_preset(character, &"warrior", 0, "War")
	check_eq(PresetService.get_preset(character, &"basic_adventurer", 0), {}, "presets are per class")
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok(), "loaded")
	var preset := PresetService.get_preset(loaded.character, &"warrior", 0)
	check_eq(preset.get("name"), "War", "preset name restored")
	check(PresetService.same_talents(loaded.character, &"warrior", preset), "talent allocation restored")
	check_eq(PresetService.activate(loaded.character, &"warrior", 0, true), "", "activatable after load")
