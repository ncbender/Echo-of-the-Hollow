extends TestCase
## Professions Foundation 1.0: nine class-independent professions, levels and
## XP (ranks, level bands, first-craft bonus), recipe learning (automatic,
## recipe item, no double learning), crafting as one transaction (recipe,
## level, workstation, materials, room - refused crafts change nothing), fast
## repeats, gathering XP and node depletion across save/load, stash materials
## at Haven workstations, save/load and the v6 -> v7 migration.

const PATH := "user://test_saves/professions/slot_1.save.json"
const SMITHY := &"old_smithy"

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = SessionState.find(get_tree()).database
	character = CharacterFactory.create_new(db)
	character.inventory.capacity = 80


func _units(item_id: StringName) -> int:
	return character.inventory.count(item_id) + character.stash.count(item_id)


func test_nine_professions_level_one_for_everyone() -> void:
	check_eq(db.professions.size(), 9, "nine professions")
	var crafting := ProfessionService.professions(db, ProfessionDefinition.Kind.CRAFTING).map(func(p: ProfessionDefinition) -> StringName: return p.id)
	var gathering := ProfessionService.professions(db, ProfessionDefinition.Kind.GATHERING).map(func(p: ProfessionDefinition) -> StringName: return p.id)
	check_eq(crafting.size(), 5, "five crafting professions")
	check_eq(gathering.size(), 4, "four gathering professions")
	for id: StringName in [&"blacksmithing", &"leatherworking", &"tailoring", &"woodworking", &"alchemy"]:
		check(id in crafting, "%s is a crafting profession" % id)
	for id: StringName in [&"mining", &"herbalism", &"woodcutting", &"skinning"]:
		check(id in gathering, "%s is a gathering profession" % id)
	for profession: ProfessionDefinition in db.professions.values():
		check_eq(character.professions.level(profession.id), 1, "%s starts at level 1" % profession.id)
		check(character.professions.xp_to_next(profession.id) > 0, "%s has XP to the next level" % profession.id)
		check_eq(profession.max_level, 100, "%s goes to 100" % profession.id)
	# class-independent: a different active class changes nothing
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	check_eq(character.professions.level(&"mining"), 1, "professions do not depend on the class")


func test_levels_ranks_and_xp_bands() -> void:
	for entry: Array in [[1, "Apprentice"], [20, "Apprentice"], [21, "Journeyman"], [40, "Journeyman"], [41, "Artisan"], [61, "Expert"], [80, "Expert"], [81, "Master"], [100, "Master"]]:
		check_eq(ProfessionService.rank_name(entry[0]), entry[1], "level %d -> %s" % entry)
	for entry: Array in [[10, 10, 1.0], [15, 10, 1.0], [16, 10, 0.5], [25, 10, 0.5], [26, 10, 0.15], [35, 10, 0.15], [36, 10, 0.0]]:
		check_near(ProfessionService.xp_share(entry[0], entry[1]), entry[2], 0.0001, "level %d on a level %d recipe" % [entry[0], entry[1]])
	var levels := character.professions.add_xp(&"mining", 100000)
	check(levels > 0 and character.professions.level(&"mining") <= 100, "levels capped at 100 (%d)" % character.professions.level(&"mining"))
	character.professions.add_xp(&"mining", 10000000)
	check_eq(character.professions.level(&"mining"), 100, "maximum reached")
	check_eq(character.professions.xp(&"mining"), 0, "no XP stored above the maximum")


func test_automatic_and_item_recipes_are_learned_once() -> void:
	check(character.professions.knows(&"bs_smelt_iron"), "level-1 recipes are known from the start")
	check(not character.professions.knows(&"lw_leather_bracers"), "pattern recipe not known")
	check(ProfessionService.learn_recipe(character, &"bs_smelt_iron").contains("already know"), "learning twice is refused")
	var pattern: ItemInstance = character.inventory.add_item(&"pattern_leather_bracers", 1)[0]
	var xp_before := character.professions.xp(&"leatherworking")
	check_eq(ProfessionService.learn_from_item(character, pattern.instance_id), "", "pattern learned")
	check(character.professions.knows(&"lw_leather_bracers") and not character.inventory.has(pattern.instance_id), "recipe learned, pattern used up")
	var second: ItemInstance = character.inventory.add_item(&"pattern_leather_bracers", 1)[0]
	check(ProfessionService.learn_from_item(character, second.instance_id).contains("already know"), "second pattern refused")
	check(character.inventory.has(second.instance_id), "the second pattern is kept (nothing lost)")
	check_eq(character.professions.xp(&"leatherworking"), xp_before, "learning never gives XP")


func test_crafting_is_one_transaction() -> void:
	character.inventory.add_item(&"iron_ore", 7)
	var result := ProfessionService.craft(character, &"bs_smelt_iron", SMITHY)
	check_eq(result.error, "", "smelted")
	check(character.inventory.count(&"iron_ore") == 4 and character.inventory.count(&"iron_ingot") == 1, "3 ore -> 1 ingot")
	check(result.first and result.xp == 16, "first craft: base 8 + 100 %% bonus (%d)" % result.xp)
	var second := ProfessionService.craft(character, &"bs_smelt_iron", SMITHY)
	check(not second.first and second.xp == 8, "afterwards the base XP (%d)" % second.xp)
	check_eq(character.professions.xp(&"blacksmithing"), 24, "XP added once per craft")


func test_refused_crafts_change_nothing() -> void:
	var levels_before := JSON.stringify(character.professions.to_dict().levels)
	var cases := {
		"missing materials": ProfessionService.craft(character, &"bs_smelt_iron", SMITHY),
		"wrong workstation": ProfessionService.craft(character, &"lw_tan_hide", SMITHY),
		"away from a workstation": ProfessionService.craft(character, &"bs_smelt_iron", &""),
		"not learned": ProfessionService.craft(character, &"lw_leather_bracers", &"tanners_lodge"),
		"not craftable yet (potion)": ProfessionService.craft(character, &"al_stoneskin", &"alchemists_cottage"),
		"unknown recipe": ProfessionService.craft(character, &"nope", SMITHY),
	}
	for label: String in cases:
		check((cases[label] as Dictionary).error != "", "%s refused: %s" % [label, (cases[label] as Dictionary).error])
	check(str(cases["missing materials"].error).contains("Iron Ore 0/3"), "names what is missing")
	check(str(cases["wrong workstation"].error).contains("Tanner's Lodge"), "names the right workstation")
	check(str(cases["not craftable yet (potion)"].error).contains("Potions cannot be used yet"), "data-only recipe explained")
	# too low level: a recipe above the profession level
	character.inventory.add_item(&"cured_leather", 4)
	character.professions.learn(&"lw_leather_bracers")   # learned, but needs level 3
	var low := ProfessionService.craft(character, &"lw_leather_bracers", &"tanners_lodge")
	check(low.error.contains("level 3"), "level too low: %s" % low.error)
	character.inventory.remove_quantity(&"cured_leather", 4)
	# full bag: refused before anything is consumed
	character.inventory.add_item(&"iron_ore", 3)
	character.inventory.capacity = character.inventory.used_slots()
	var full := ProfessionService.craft(character, &"bs_smelt_iron", SMITHY)
	check(full.error.contains("bag is full") and character.inventory.count(&"iron_ore") == 3, "full bag: nothing consumed")
	character.inventory.capacity = 80
	character.inventory.remove_quantity(&"iron_ore", 3)
	check_eq(JSON.stringify(character.professions.to_dict().levels), levels_before, "no XP from refused crafts")
	check(not character.professions.crafted_before(&"bs_smelt_iron"), "no first-craft mark from refused crafts")


func test_fast_repeated_crafts_pay_every_time() -> void:
	character.inventory.add_item(&"timber", 5)   # enough for two planks
	var results: PackedStringArray = []
	for i in 6:
		results.append(ProfessionService.craft(character, &"ww_saw_planks", &"woodwrights_workshop").error)
	check_eq(results.count(""), 2, "exactly as many crafts as materials allow")
	check(character.inventory.count(&"oak_plank") == 2 and character.inventory.count(&"timber") == 1, "2 planks, 1 timber left")
	check_eq(character.professions.xp(&"woodworking"), 16 + 8, "XP only for the two real crafts")


func test_whole_vertical_slice_crafts() -> void:
	character.inventory.add_item(&"iron_ore", 9)
	character.inventory.add_item(&"timber", 2)
	character.inventory.add_item(&"raw_hide", 10)
	character.inventory.add_item(&"flax_fiber", 13)
	var steps: Array = [[&"bs_smelt_iron", SMITHY], [&"bs_smelt_iron", SMITHY], [&"bs_smelt_iron", SMITHY], [&"ww_saw_planks", &"woodwrights_workshop"],
		[&"bs_militia_sword", SMITHY], [&"lw_tan_hide", &"tanners_lodge"], [&"lw_tan_hide", &"tanners_lodge"], [&"lw_tan_hide", &"tanners_lodge"],
		[&"lw_tan_hide", &"tanners_lodge"], [&"lw_leather_gloves", &"tanners_lodge"], [&"tl_weave_linen", &"weavers_house"], [&"tl_weave_linen", &"weavers_house"],
		[&"tl_weave_linen", &"weavers_house"], [&"tl_weave_linen", &"weavers_house"], [&"tl_linen_trousers", &"weavers_house"]]
	for step: Array in steps:
		check_eq(ProfessionService.craft(character, step[0], step[1]).error, "", "%s crafted" % step[0])
	for item_id: StringName in [&"militia_sword", &"leather_gloves", &"linen_trousers"]:
		check_eq(character.inventory.count(item_id), 1, "%s made" % item_id)
	check(character.professions.xp(&"blacksmithing") > 0 and character.professions.xp(&"tailoring") > 0, "XP in several professions")


func test_stash_materials_at_haven_workstations() -> void:
	character.inventory.add_item(&"iron_ore", 1)
	character.stash.add_item(&"iron_ore", 4)   # bag: 1, stash: 4
	check_eq(character.inventory.count(&"iron_ore"), 1, "1 ore in the bag")
	check(not ProfessionService.uses_stash(character, SMITHY), "ruined storehouse: bag only")
	check(ProfessionService.craft(character, &"bs_smelt_iron", SMITHY).error.contains("Iron Ore 1/3"), "the stash is not counted yet")
	character.world.set_restoration(&"old_storehouse", &"restored")
	check(ProfessionService.uses_stash(character, SMITHY), "restored storehouse: Haven workstations reach the stash")
	check_eq(ProfessionService.available(character, &"iron_ore", SMITHY), 5, "1 + 4, each unit counted once")
	check_eq(ProfessionService.craft(character, &"bs_smelt_iron", SMITHY).error, "", "crafted with stash materials")
	check(character.inventory.count(&"iron_ore") == 0 and character.stash.count(&"iron_ore") == 2, "bag first (1), then stash (2)")
	check(not ProfessionService.uses_stash(character, &""), "never away from a workstation")
	check(StashService.ownership_errors(character).is_empty(), "ownership consistent: %s" % [StashService.ownership_errors(character)])


func test_gathering_gives_xp_and_stays_depleted_after_load() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"stag_remains"]
	check_eq(node.profession_id, &"skinning", "remains are skinned")
	for node_id: StringName in [&"iron_vein", &"oak_tree", &"wild_flax", &"stag_remains"]:
		check((db.resource_nodes[node_id] as ResourceNodeDefinition).profession_id != &"", "%s belongs to a gathering profession" % node_id)
	var now := 1000.0
	check_eq(ResourceGathering.gather(character, &"whisper_forest", &"stag_1", node, now), "", "gathered")
	check_eq(character.inventory.count(&"raw_hide"), 2, "hides")
	check_eq(character.professions.xp(&"skinning"), node.gather_xp, "skinning XP")
	check(ResourceGathering.gather(character, &"whisper_forest", &"stag_1", node, now + 1.0).contains("depleted"), "depleted")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveSystem.save_to(character, PATH)
	var loaded := SaveSystem.load_from(PATH, db).character
	check(not ResourceGathering.is_available(loaded.world, &"whisper_forest", &"stag_1", now + 1.0), "still depleted after loading")
	check(ResourceGathering.gather(loaded, &"whisper_forest", &"stag_1", node, now + 1.0) != "", "no second harvest by save/load")
	check_eq(loaded.professions.xp(&"skinning"), node.gather_xp, "XP not granted twice")
	var high := node.duplicate() as ResourceNodeDefinition
	high.required_level = 10
	check(ResourceGathering.gather(character, &"whisper_forest", &"stag_2", high, now).contains("level 10"), "level requirement for gathering")
	DirAccess.remove_absolute(PATH)


func test_save_load_and_migration() -> void:
	character.inventory.add_item(&"iron_ore", 3)
	ProfessionService.craft(character, &"bs_smelt_iron", SMITHY)
	character.professions.add_xp(&"herbalism", 500)
	var pattern: ItemInstance = character.inventory.add_item(&"pattern_leather_bracers", 1)[0]
	ProfessionService.learn_from_item(character, pattern.instance_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	SaveSystem.save_to(character, PATH)
	var loaded := SaveSystem.load_from(PATH, db).character
	for profession_id: StringName in db.professions:
		check_eq(loaded.professions.level(profession_id), character.professions.level(profession_id), "%s level kept" % profession_id)
		check_eq(loaded.professions.xp(profession_id), character.professions.xp(profession_id), "%s XP kept" % profession_id)
	check(loaded.professions.knows(&"lw_leather_bracers"), "learned recipe kept")
	check(loaded.professions.crafted_before(&"bs_smelt_iron"), "first-craft mark kept (no second bonus)")
	check_eq(ProfessionService.craft_xp(loaded, db.profession_recipes[&"bs_smelt_iron"]), 8, "no first-craft bonus after loading")
	DirAccess.remove_absolute(PATH)
	# v6 save: no professions yet
	var payload := character.to_dict()
	payload.erase("professions")
	var errors: PackedStringArray = []
	var migrated: Dictionary = SaveMigrations.migrate(payload, 6, errors)
	var warnings: PackedStringArray = []
	var old := Character.from_dict(migrated, db, warnings)
	check(errors.is_empty(), "migrated")
	check_eq(old.professions.level(&"blacksmithing"), 1, "old characters start every profession at level 1")
	check(old.professions.knows(&"bs_smelt_iron"), "level-1 recipes learned on load")
	check_eq(old.inventory.to_array(), character.inventory.to_array(), "bag untouched")
	check_eq(old.stash.to_array(), character.stash.to_array(), "stash untouched")
	check_eq(old.world.restoration, character.world.restoration, "restorations untouched")
	check_eq(JSON.stringify(old.builds.to_dict()), JSON.stringify(character.builds.to_dict()), "talents and builds untouched")
	check(SaveSystem.VERSION >= 7, "save version 7 or later (v8: item integrity)")
