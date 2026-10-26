extends TestCase
## Artisan Quarter workshop restoration (docs/PROLOGUE_AND_HAVEN.md, Werkstätten):
## the four workshops go Ruined -> Restored -> Revitalized, each step checked
## first and paid once from the material plan it shows; refused, repeated and
## stage-skipping requests change nothing; stages survive save/load; old v7
## saves without workshop stages load as ruined; no stat bonus; the bench
## works in every stage; the window flow (bench first, restore from there).
## Costs only use items with a reachable source. Only user://test_saves/.

const DIR := "user://test_saves/workshops"
const PROFILE := DIR + "/slot_1.save.json"
const WORKSHOPS := {
	&"tanners_lodge": [&"TannersLodge", &"leatherworking"],
	&"weavers_house": [&"WeaversHouse", &"tailoring"],
	&"woodwrights_workshop": [&"WoodwrightsWorkshop", &"woodworking"],
	&"alchemists_cottage": [&"AlchemistsCottage", &"alchemy"],
}

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	character.world.set_flag(&"prologue.haven_discovered")
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE) + [DIR + "/stages.save.json"]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _give(costs: Array[ItemCost], times: int = 1) -> void:
	for cost in costs:
		character.inventory.add_item(cost.item_id, cost.quantity * times)


## Items a player can obtain in normal play: yields of resource nodes placed in
## a playable map, and the outputs of processing recipes made only from such
## items (one level of processing is all the costs use).
func _obtainable_items() -> Dictionary:
	var gathered := {}
	for scene_path: String in ["res://scenes/maps/whisper_forest.tscn", "res://scenes/maps/old_road.tscn"]:
		var scene := (load(scene_path) as PackedScene).instantiate()
		for node: ResourceNode in scene.find_children("*", "ResourceNode", true, false):
			if node.definition != null:
				gathered[node.definition.yield_item_id] = true
		scene.free()
	var result := gathered.duplicate()
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if recipe.craftable and recipe.is_processing and recipe.unlock_source == ProfessionRecipeDefinition.UnlockSource.AUTOMATIC \
				and recipe.required_level == 1 and recipe.inputs.all(func(c: ItemCost) -> bool: return gathered.has(c.item_id)):
			result[recipe.output_item_id] = true
	return result


func test_workshop_data() -> void:
	check(RestorationService.validate_data(db).is_empty(), "ruin data valid: %s" % [RestorationService.validate_data(db)])
	var obtainable := _obtainable_items()
	for ruin_id: StringName in WORKSHOPS:
		var ruin: RuinDefinition = db.ruins[ruin_id]
		check(ruin.restorable and ruin.can_revitalize(), "%s: restore and revitalize offered" % ruin_id)
		check(ruin.building_id == &"" and ruin.profession_id == WORKSHOPS[ruin_id][1], "%s: workshop of %s, no building" % [ruin_id, WORKSHOPS[ruin_id][1]])
		check(ruin.restored_text != "" and ruin.revitalized_text != "", "%s: stage texts" % ruin_id)
		for cost in ruin.costs + ruin.revitalize_costs:
			check(obtainable.has(cost.item_id), "%s: %s has a source in the world" % [ruin_id, cost.item_id])
	for ruin_id: StringName in [&"old_smithy", &"old_storehouse"]:
		check(not (db.ruins[ruin_id] as RuinDefinition).can_revitalize(), "%s: no revitalize step in this version" % ruin_id)


func test_each_workshop_walks_both_steps_atomically() -> void:
	var stats_before := character.get_stats().duplicate()
	var capacity := character.inventory.capacity
	for ruin_id: StringName in WORKSHOPS:
		var ruin: RuinDefinition = db.ruins[ruin_id]
		check_eq(RestorationService.next_stage(character, ruin), RestorationService.RESTORED, "%s: next is restored" % ruin_id)
		# missing materials: nothing changes
		var before := character.inventory.to_array()
		check(RestorationService.advance(character, ruin, RestorationService.RESTORED).begins_with("Missing: "), "%s: refused without materials" % ruin_id)
		check(RestorationService.advance(character, ruin, RestorationService.REVITALIZED).begins_with("Restore "), "%s: revitalize needs the restoration first" % ruin_id)
		check_eq(character.inventory.to_array(), before, "%s: nothing consumed" % ruin_id)
		check_eq(RestorationService.stage(character, ruin_id), RestorationService.RUINED, "%s: still ruined" % ruin_id)
		# one short of one cost: nothing changes
		_give(ruin.costs)
		character.inventory.remove_quantity(ruin.costs[0].item_id, 1)
		before = character.inventory.to_array()
		check(RestorationService.restore_error(character, ruin).begins_with("Missing"), "%s: one short is refused" % ruin_id)
		check_eq(RestorationService.restore(character, ruin), RestorationService.restore_error(character, ruin), "%s: restore refuses the same way" % ruin_id)
		check_eq(character.inventory.to_array(), before, "%s: nothing consumed when one short" % ruin_id)
		character.inventory.add_item(ruin.costs[0].item_id, 1)
		# restore: exactly the shown plan is consumed
		var plan: Array = RestorationService.material_plan(character, ruin, RestorationService.RESTORED).plan
		var counts := _counts(ruin.costs)
		check_eq(RestorationService.advance(character, ruin, RestorationService.RESTORED), "", "%s restored" % ruin_id)
		for index in ruin.costs.size():
			var cost := ruin.costs[index]
			check_eq(counts[cost.item_id] - character.inventory.count(cost.item_id), int(plan[index].bag), "%s: %s consumed as planned" % [ruin_id, cost.item_id])
			check_eq(character.inventory.count(cost.item_id), 0, "%s: exactly %d %s consumed" % [ruin_id, cost.quantity, cost.item_id])
		check_eq(RestorationService.stage(character, ruin_id), RestorationService.RESTORED, "%s: restored" % ruin_id)
		check(character.world.has_flag(ruin.restored_flag()), "%s: restored flag" % ruin_id)
		# revitalize
		check_eq(RestorationService.next_stage(character, ruin), RestorationService.REVITALIZED, "%s: next is revitalized" % ruin_id)
		check(RestorationService.advance(character, ruin, RestorationService.REVITALIZED).begins_with("Missing: "), "%s: revitalize refused without materials" % ruin_id)
		_give(ruin.revitalize_costs)
		check_eq(RestorationService.advance(character, ruin, RestorationService.REVITALIZED), "", "%s revitalized" % ruin_id)
		for cost in ruin.revitalize_costs:
			check_eq(character.inventory.count(cost.item_id), 0, "%s: exactly %d %s consumed" % [ruin_id, cost.quantity, cost.item_id])
		check_eq(RestorationService.stage(character, ruin_id), RestorationService.REVITALIZED, "%s: revitalized" % ruin_id)
		check(character.world.has_flag(ruin.revitalized_flag()), "%s: revitalized flag" % ruin_id)
		check_eq(RestorationService.next_stage(character, ruin), &"", "%s: no further step" % ruin_id)
		# done: every further request is refused and changes nothing
		_give(ruin.costs)
		_give(ruin.revitalize_costs)
		before = character.inventory.to_array()
		check(RestorationService.advance(character, ruin, RestorationService.RESTORED).contains("already restored"), "%s: never restored twice" % ruin_id)
		check(RestorationService.advance(character, ruin, RestorationService.REVITALIZED).contains("already revitalized"), "%s: never revitalized twice" % ruin_id)
		check_eq(character.inventory.to_array(), before, "%s: refused repeats consume nothing" % ruin_id)
		for cost in ruin.costs + ruin.revitalize_costs:
			character.inventory.remove_quantity(cost.item_id, cost.quantity)
	check_eq(character.get_stats(), stats_before, "no stat changes from restoring or revitalizing")
	check_eq(character.inventory.capacity, capacity, "no inventory bonus from workshops")


func test_repeated_requests_never_skip_a_stage() -> void:
	var ruin: RuinDefinition = db.ruins[&"tanners_lodge"]
	_give(ruin.costs, 2)
	_give(ruin.revitalize_costs)
	var results: Array[String] = []
	for i in 6:   # a double / triple click on Restore
		results.append(RestorationService.advance(character, ruin, RestorationService.RESTORED))
	check_eq(results.count(""), 1, "exactly one restoration out of six requests")
	check_eq(RestorationService.stage(character, &"tanners_lodge"), RestorationService.RESTORED, "restored, not revitalized")
	for cost in ruin.costs:
		check_eq(character.inventory.count(cost.item_id), cost.quantity, "%s paid once" % cost.item_id)
	for cost in ruin.revitalize_costs:
		check_eq(character.inventory.count(cost.item_id), cost.quantity, "%s untouched" % cost.item_id)
	check(RestorationService.advance(character, ruin, &"bogus").begins_with("Unknown"), "unknown stage refused")
	check(RestorationService.advance(character, null, RestorationService.RESTORED).begins_with("Unknown"), "unknown ruin refused")


func test_story_condition_gates_the_workshops() -> void:
	character.world.flags.erase(&"prologue.haven_discovered")
	for ruin_id: StringName in WORKSHOPS:
		var ruin: RuinDefinition = db.ruins[ruin_id]
		_give(ruin.costs)
		check_eq(RestorationService.restore_error(character, ruin), RestorationService.UNAVAILABLE, "%s: not before Haven" % ruin_id)


func test_stages_survive_save_and_load() -> void:
	var lodge: RuinDefinition = db.ruins[&"tanners_lodge"]
	var house: RuinDefinition = db.ruins[&"weavers_house"]
	_give(lodge.costs)
	_give(lodge.revitalize_costs)
	_give(house.costs)
	RestorationService.restore(character, lodge)
	RestorationService.advance(character, lodge, RestorationService.REVITALIZED)
	RestorationService.restore(character, house)
	var path := DIR + "/stages.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded")
	check_eq(RestorationService.stage(loaded.character, &"tanners_lodge"), RestorationService.REVITALIZED, "lodge revitalized after loading")
	check_eq(RestorationService.stage(loaded.character, &"weavers_house"), RestorationService.RESTORED, "house restored after loading")
	check_eq(RestorationService.stage(loaded.character, &"woodwrights_workshop"), RestorationService.RUINED, "workshop still ruined")
	check_eq(RestorationService.next_stage(loaded.character, house), RestorationService.REVITALIZED, "house can go on after loading")
	check_eq(loaded.character.inventory.to_array(), character.inventory.to_array(), "bag unchanged by the round trip")


func test_v7_save_without_workshop_stages_loads_ruined() -> void:
	character.inventory.add_item(&"timber", 7)
	var data := character.to_dict()
	(data.world as Dictionary)["restoration"] = {"old_smithy": "restored"}   # a v7 save from before this change
	check_eq(int(SaveSystem.VERSION), 7, "save format stays version 7")
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(data, db, warnings)
	check(warnings.is_empty(), "no warnings: %s" % [warnings])
	for ruin_id: StringName in WORKSHOPS:
		check_eq(RestorationService.stage(loaded, ruin_id), RestorationService.RUINED, "%s: ruined by default" % ruin_id)
	check_eq(RestorationService.stage(loaded, &"old_smithy"), RestorationService.RESTORED, "existing restoration kept")
	check_eq(loaded.inventory.count(&"timber"), 7, "nothing consumed by loading")
	data.world.restoration = {"tanners_lodge": "revitalized", "weavers_house": "shiny"}
	warnings.clear()
	loaded = Character.from_dict(data, db, warnings)
	check_eq(RestorationService.stage(loaded, &"tanners_lodge"), RestorationService.REVITALIZED, "revitalized stage read")
	check(RestorationService.stage(loaded, &"weavers_house") == RestorationService.RUINED and warnings.size() == 1, "unknown stage ignored with a warning")


# --- in Haven ------------------------------------------------------------------------

func _open_haven() -> GameMap:
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.is_node_ready() and not session.is_traveling():
			map = current
			map.player.feed_input(InputFrame.new())
			return current
	fail("Haven not loaded")
	return null


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
		await get_tree().process_frame


func test_window_flow_bench_first_then_restore() -> void:
	if await _open_haven() == null:
		return
	var site := map.get_node("Ruins/TannersLodge") as RuinSite
	var ruin := site.ruin()
	map.player.global_position = site.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	var panel := map.hud.professions_panel
	var restoration := map.hud.restoration_panel
	for step: StringName in [RestorationService.RESTORED, RestorationService.REVITALIZED]:
		check_eq(site.prompt, "Work at The Tanner's Lodge", "prompt names the bench (%s)" % step)
		site.interact(map.hud)
		await _frames()
		check(panel.visible and panel.station_id == &"tanners_lodge", "G opens the bench before %s" % step)
		character.inventory.add_item(&"raw_hide", 2)
		panel.select_recipe(&"lw_tan_hide")
		check_eq(panel.craft_selected().error, "", "tanning works before %s" % step)
		await _frames()   # the bag change rebuilds the window once more
		var open := panel.find_child("RestoreWorkshop", true, false) as Button
		if not check(open != null, "workshop button in the bench window"):
			return
		check(open.text.begins_with("Revitalize" if step == RestorationService.REVITALIZED else "Restore"), "button names the step: %s" % open.text)
		await _click(open)
		await _frames()
		check(restoration.visible and not panel.visible, "restoration window opened from the bench")
		var verb := "Revitalize" if step == RestorationService.REVITALIZED else "Restore"
		var button := restoration.find_child(verb, true, false) as Button
		for cost in RestorationService.costs_for(ruin, step):
			var row := restoration.find_child("Cost_%s" % cost.item_id, true, false)
			check(row != null, "preview lists %s" % cost.item_id)
		if step == RestorationService.RESTORED:
			check(button != null and button.disabled, "%s disabled without materials" % verb)
			restoration.hide()
			_give(ruin.costs)
			_give(ruin.revitalize_costs)   # enough for the next step too: a double click must not use it
			site.interact(map.hud)
			await _frames()
			await _click(panel.find_child("RestoreWorkshop", true, false) as Button)
			await _frames()
			button = restoration.find_child(verb, true, false) as Button
		check(button != null and not button.disabled, "%s enabled with the materials" % verb)
		var before_stage := RestorationService.stage(character, ruin.id)
		await _click(button)
		await _click(button)   # double click
		await _frames()
		check_eq(RestorationService.stage(character, ruin.id), step, "one step from a double click (%s -> %s)" % [before_stage, step])
		check(not restoration.visible, "window closes after the step")
		check(site.prompt == "Work at The Tanner's Lodge", "bench prompt unchanged")
		map.hud.close_windows()
	site.interact(map.hud)
	await _frames()
	check(panel.visible and panel.find_child("RestoreWorkshop", true, false) == null, "no button once revitalized")
	panel.select_recipe(&"lw_tan_hide")
	character.inventory.add_item(&"raw_hide", 2)
	check_eq(panel.craft_selected().error, "", "tanning works when revitalized")
	await _frames(3)
	var latest := SaveSlots.latest(PROFILE)
	var saved := SaveSystem.load_from(latest.get("path", ""), db)
	check(saved.ok() and RestorationService.is_revitalized(saved.character, &"tanners_lodge"), "milestone save holds the revitalized lodge")


func _counts(costs: Array[ItemCost]) -> Dictionary:
	var counts := {}
	for cost in costs:
		counts[cost.item_id] = character.inventory.count(cost.item_id)
	return counts
