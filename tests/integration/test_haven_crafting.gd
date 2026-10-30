extends TestCase
## UI Usability & Haven Crafting 1.0 (docs/UI_USABILITY_HAVEN_CRAFTING_1_0.md): at a Haven workstation
## crafting reads bag + Haven stash (bag first) in every stage of the Old Storehouse - profession crafts
## (ProfessionService) and the Old Smithy's forge recipes (BaseBuilder). One material plan for display,
## check and consumption; a refused craft changes nothing; away from Haven no stash. Synthetic characters,
## files only under user://test_saves/haven_crafting/.

const PATH := "user://test_saves/haven_crafting/slot_1.save.json"
const SMITHY := &"old_smithy"
const SMELT := &"bs_smelt_iron"          # 3 Iron Ore -> 1 Iron Ingot
const SWORD := &"bs_militia_sword"       # 3 Iron Ingot + 1 Oak Plank -> Militia Sword

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = SessionState.find(get_tree()).database
	character = CharacterFactory.create_new(db)
	character.inventory.capacity = 80
	check(not StashService.is_upgraded(character), "fixture: the Old Storehouse is still a ruin")


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _state() -> Array:
	return [character.inventory.to_array(), character.stash.to_array(), character.professions.to_dict()]


func _forge_recipe() -> RecipeDefinition:
	var smithy := load("res://data/base/buildings/smithy.tres") as BuildingDefinition
	return smithy.recipes[0] if smithy != null and not smithy.recipes.is_empty() else null


func test_a_bag_only_b_stash_only_c_split_bag_first() -> void:
	# A: enough in the bag - the stash is not touched
	character.inventory.add_item(&"iron_ore", 3)
	character.stash.add_item(&"iron_ore", 5)
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "A: crafted from the bag")
	check_eq([character.inventory.count(&"iron_ore"), character.stash.count(&"iron_ore")], [0, 5], "A: stash untouched")
	# B: only the stash has it
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "B: crafted from the stash alone")
	check_eq(character.stash.count(&"iron_ore"), 2, "B: 3 taken from the stash")
	# C: the spec's example - 5 needed, bag 2, stash 8 -> 2 bag + 3 stash (two smelts: 3 + 3 of 10)
	character.inventory.add_item(&"iron_ore", 2)
	character.stash.add_item(&"iron_ore", 6)   # stash 8
	var plan: Array = ProfessionService.material_plan(character, (db.profession_recipes[SMELT] as ProfessionRecipeDefinition).inputs, true).plan
	check_eq(plan[0], {"item_id": &"iron_ore", "bag": 2, "stash": 1}, "C: bag first, then the stash")
	check_eq(ProfessionService.available(character, &"iron_ore", SMITHY), 10, "C: shown 10 (2 + 8)")
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "C: crafted across both")
	check_eq([character.inventory.count(&"iron_ore"), character.stash.count(&"iron_ore")], [0, 7], "C: 2 bag + 1 stash used")
	check_eq(character.inventory.count(&"iron_ingot"), 3, "three ingots made")
	check(StashService.ownership_errors(character).is_empty(), "ownership consistent")


func test_d_not_enough_together_and_e_never_away_from_haven() -> void:
	character.inventory.add_item(&"iron_ore", 1)
	character.stash.add_item(&"iron_ore", 1)
	var before := _state()
	var result := ProfessionService.craft(character, SMELT, SMITHY)
	check(result.error.contains("Iron Ore 2/3"), "D: refused, bag + stash counted (%s)" % result.error)
	check_eq(_state(), before, "D: nothing changed")
	# E: away from any workstation the stash is never read
	character.stash.add_item(&"iron_ore", 5)
	check(not ProfessionService.uses_stash(character, &""), "E: no stash away from a workstation")
	check_eq(ProfessionService.available(character, &"iron_ore", &""), 1, "E: bag only")
	before = _state()
	check(ProfessionService.craft(character, SMELT, &"").error != "", "E: refused away from the workstation")
	check_eq(_state(), before, "E: nothing changed")
	var forge := _forge_recipe()
	if check(forge != null, "forge recipe"):
		check(BaseBuilder.craft_error(character, forge, false) != "", "E: forge without stash reach uses the bag only")


func test_f_several_inputs_across_both_sources() -> void:
	character.inventory.add_item(&"iron_ingot", 1)
	character.stash.add_item(&"iron_ingot", 2)
	character.stash.add_item(&"oak_plank", 1)
	check_eq(ProfessionService.craft(character, SWORD, SMITHY).error, "", "F: militia sword from bag + stash")
	for item_id: StringName in [&"iron_ingot", &"oak_plank"]:
		check_eq(character.inventory.count(item_id) + character.stash.count(item_id), 0, "F: all %s used" % item_id)
	check_eq(character.inventory.count(&"militia_sword"), 1, "F: one sword")


func test_g_full_bag_h_output_into_a_stack() -> void:
	character.inventory.capacity = character.inventory.used_slots() + 2
	character.stash.add_item(&"iron_ore", 6)
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1)
	var before := _state()
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "Your bag is full.", "G: refused before anything is consumed")
	check_eq(_state(), before, "G: no material lost")
	# H: a partial ingot stack takes the output even with every slot used
	character = CharacterFactory.create_new(db)
	character.inventory.capacity = character.inventory.used_slots() + 2   # starting gear already takes slots
	character.stash.add_item(&"iron_ore", 6)
	check(not character.inventory.add_item(&"iron_ingot", 1).is_empty(), "H: a partial ingot stack")
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1)
	check_eq(character.inventory.free_slots(), 0, "H: no free slot")
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "H: output stacks onto the ingots")
	check_eq(character.inventory.count(&"iron_ingot"), 2, "H: placed by the stack rules")


func test_i_two_crafts_in_a_row_pay_twice_or_refuse() -> void:
	character.inventory.add_item(&"iron_ore", 2)
	character.stash.add_item(&"iron_ore", 2)   # 4: one smelt, not two
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "I: first craft")
	var before := _state()
	check(ProfessionService.craft(character, SMELT, SMITHY).error.contains("Iron Ore 1/3"), "I: the immediate second is refused")
	check_eq(_state(), before, "I: no double consumption, no second ingot")
	check_eq(character.inventory.count(&"iron_ingot"), 1, "I: exactly one output")


func test_j_save_and_load_after_a_split_craft() -> void:
	character.inventory.add_item(&"iron_ore", 1)
	character.stash.add_item(&"iron_ore", 4)
	check_eq(ProfessionService.craft(character, SMELT, SMITHY).error, "", "crafted")
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	check_eq(SaveSystem.save_to(character, PATH), OK, "J: saved (v%d)" % SaveSystem.VERSION)
	var loaded := SaveSystem.load_from(PATH, db)
	if not check(loaded.ok(), "J: loaded %s" % [loaded.errors]):
		return
	var again := loaded.character
	check_eq([again.inventory.count(&"iron_ore"), again.stash.count(&"iron_ore"), again.inventory.count(&"iron_ingot")], [0, 2, 1],
		"J: bag, stash and output as crafted")
	check(StashService.ownership_errors(again).is_empty(), "J: ownership consistent after loading")


func test_k_recipe_and_station_rules_still_apply() -> void:
	character.stash.add_item(&"raw_hide", 10)
	character.stash.add_item(&"iron_ore", 10)
	var before := _state()
	check(ProfessionService.craft(character, &"lw_leather_bracers", &"tanners_lodge").error.contains("not learned"), "K: unlearned recipe refused")
	check(ProfessionService.craft(character, SMELT, &"tanners_lodge").error.begins_with("Craft this at"), "K: wrong workstation refused")
	check_eq(_state(), before, "K: nothing changed")


func test_forge_recipes_use_the_same_plan() -> void:
	var forge := _forge_recipe()
	if not check(forge != null and not forge.inputs.is_empty(), "the Old Smithy has forge recipes"):
		return
	check(ProfessionService.uses_stash(character, SMITHY), "the forge stands in a Haven ruin")
	for cost in forge.inputs:   # half in the bag (rounded down), the rest in the stash
		var in_bag := cost.quantity / 2
		if in_bag > 0:
			character.inventory.add_item(cost.item_id, in_bag)
		character.stash.add_item(cost.item_id, cost.quantity - in_bag)
	var made_before := character.inventory.count(forge.output_item_id)   # starting gear may hold the same item
	check(BaseBuilder.craft_error(character, forge, false) != "", "bag alone is not enough")
	var before := _state()
	check_eq(BaseBuilder.craft(character, forge, false), BaseBuilder.craft_error(character, forge, false), "without stash: refused")
	check_eq(_state(), before, "nothing consumed when refused")
	check_eq(BaseBuilder.craft(character, forge, true), "", "with the stash: crafted")
	for cost in forge.inputs:
		check_eq(character.inventory.count(cost.item_id) + character.stash.count(cost.item_id), 0, "%s used up (bag first)" % cost.item_id)
	check_eq(character.inventory.count(forge.output_item_id) - made_before, forge.output_quantity, "forge output in the bag")
	before = _state()
	check(BaseBuilder.craft(character, forge, true).begins_with("missing"), "an immediate repeat is refused")
	check_eq(_state(), before, "no double output")
