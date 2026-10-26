extends TestCase
## Home base building: plots, costs, occupancy, unlocks, storage bonus, crafting,
## persistence across map changes and save/load.

const DIR := "user://test_saves"

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func _plot(id: StringName) -> BuildingPlotDefinition:
	return db.plots[id]


func _building(id: StringName) -> BuildingDefinition:
	return db.buildings[id]


func _give(costs: Array[ItemCost], times: int = 1) -> void:
	for cost in costs:
		character.inventory.add_item(cost.item_id, cost.quantity * times)


func _totals() -> Dictionary:
	var totals := {}
	for item_id: StringName in [&"timber", &"stone", &"iron_ore", &"iron_sword"]:
		totals[item_id] = character.inventory.count(item_id)
	return totals


func test_data() -> void:
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	check_eq(db.plots.size(), 3, "three plots")
	for id: StringName in [&"smithy", &"storage", &"training_ground"]:
		check(db.buildings.has(id) and _building(id).scene != null, "%s defined with scene" % id)
	# Haven has no free build plots any more: six fixed ruins (Prologue & Haven slice)
	var home: Node = load(db.maps[&"home_base"].scene_path).instantiate()
	var ruin_ids := {}
	for plot: BuildPlot in home.find_children("*", "BuildPlot", true, false):
		check(plot is RuinSite, "only ruins in Haven (%s)" % plot.name)
		if plot is RuinSite:
			ruin_ids[(plot as RuinSite).ruin_id] = true
			check(db.ruins.has((plot as RuinSite).ruin_id), "ruin %s defined" % (plot as RuinSite).ruin_id)
	check_eq(ruin_ids.size(), 6, "six ruins placed in Haven")
	home.free()


func test_cannot_build_without_materials() -> void:
	var before := _totals()
	check(BaseBuilder.build(character, _plot(&"plot_west"), _building(&"smithy")) != "", "refused")
	check_eq(BaseBuilder.plot_state(character, &"plot_west"), &"", "plot still empty")
	check_eq(_totals(), before, "nothing consumed")
	character.inventory.add_item(&"timber", 6)
	character.inventory.add_item(&"stone", 4)
	character.inventory.add_item(&"iron_ore", 2)   # one short
	check(BaseBuilder.build(character, _plot(&"plot_west"), _building(&"smithy")).begins_with("missing"), "partial materials refused")
	check_eq(character.inventory.count(&"timber"), 6, "no partial consumption")


func test_build_consumes_exact_costs_once() -> void:
	var smithy := _building(&"smithy")
	_give(smithy.costs, 2)
	var before := _totals()
	check_eq(BaseBuilder.build(character, _plot(&"plot_west"), smithy), "", "built")
	for cost in smithy.costs:
		check_eq(character.inventory.count(cost.item_id), before[cost.item_id] - cost.quantity, "%s consumed exactly" % cost.item_id)
	check_eq(BaseBuilder.plot_state(character, &"plot_west"), &"smithy", "plot occupied")
	check(character.world.has_flag(&"building.smithy"), "building flag set")
	var after := _totals()
	check(BaseBuilder.build(character, _plot(&"plot_west"), _building(&"storage")) != "", "occupied plot refused")
	check(BaseBuilder.build(character, _plot(&"plot_east"), smithy) != "", "unique smithy cannot be built twice")
	check_eq(_totals(), after, "refusals consumed nothing")
	check(character.inventory.integrity_errors().is_empty(), "inventory consistent")


func test_required_flag_unlocks_training_ground() -> void:
	var training := _building(&"training_ground")
	_give(training.costs)
	check(BaseBuilder.build(character, _plot(&"plot_east"), training).begins_with("requires"), "needs a smithy first")
	_give(_building(&"smithy").costs)
	BaseBuilder.build(character, _plot(&"plot_west"), _building(&"smithy"))
	check_eq(BaseBuilder.build(character, _plot(&"plot_east"), training), "", "unlocked after smithy")


func test_storage_bonus_and_persistence() -> void:
	var storage := _building(&"storage")
	_give(storage.costs)
	var base_capacity := character.inventory.capacity
	BaseBuilder.build(character, _plot(&"plot_north"), storage)
	check_eq(character.inventory.capacity, base_capacity + storage.inventory_capacity_bonus, "storage adds slots")
	var path := DIR.path_join("base_test.save.json")
	DirAccess.make_dir_recursive_absolute(DIR)
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db).character
	check_eq(BaseBuilder.plot_state(loaded, &"plot_north"), &"storage", "building restored")
	check_eq(loaded.inventory.capacity, base_capacity + storage.inventory_capacity_bonus, "bonus rebuilt after load")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func test_smithy_recipe_is_atomic() -> void:
	_give(_building(&"smithy").costs)
	BaseBuilder.build(character, _plot(&"plot_west"), _building(&"smithy"))
	var recipe: RecipeDefinition = _building(&"smithy").recipes[0]
	check(BaseBuilder.craft(character, recipe) != "", "no ore -> refused")
	_give(recipe.inputs)
	var swords := character.inventory.count(&"iron_sword")
	check_eq(BaseBuilder.craft(character, recipe), "", "crafted")
	check_eq(character.inventory.count(&"iron_sword"), swords + 1, "sword added")
	for input in recipe.inputs:
		check_eq(character.inventory.count(input.item_id), 0, "%s consumed" % input.item_id)
	check(BaseBuilder.craft(character, recipe) != "", "second craft refused without inputs")


func test_restored_ruin_survives_map_change() -> void:
	var session := SessionState.find(get_tree())
	var previous := session.character
	session.set_character(character)
	character.world.set_flag(&"prologue.haven_discovered")
	character.inventory.add_item(&"supply_crate", 2)
	check_eq(RestorationService.restore(character, db.ruins[&"old_smithy"]), "", "Old Smithy restored")
	for i in 2:
		var home: Node = load(db.maps[&"home_base"].scene_path).instantiate()
		add_child(home)
		await get_tree().process_frame
		var plot := home.get_node("Ruins/OldSmithy") as RuinSite
		check(plot.built_building() != null and plot.built_building().id == &"smithy", "ruin shows the smithy (load %d)" % i)
		check(plot.get_child_count() >= 2, "building scene instantiated (load %d)" % i)
		home.queue_free()
		await get_tree().process_frame
	session.set_character(previous)
