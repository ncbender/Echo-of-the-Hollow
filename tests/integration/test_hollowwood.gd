extends TestCase
## Hollowwood crafting loop (docs/PROFESSIONS.md): every gathering track has
## reachable level-1 and level-3 nodes in playable maps (walked to with real
## movement, no forced fight on the way), level requirement, yield, XP and a
## depletion that survives save/load; the Leather Bracers pattern lies in the
## Whisper Forest once (persistent), learning is permanent and a second
## pattern is refused; the new recipes craft equippable items that had no
## source; no recipe hands out potions or unsupported weapons; every gathered
## material feeds a recipe or a restoration. Only user://test_saves/.

const DIR := "user://test_saves/hollowwood"
const PATH := DIR + "/slot_1.save.json"
const GATHERING := [&"mining", &"herbalism", &"woodcutting", &"skinning"]
## Walk plans from the map's arrival point: waypoints, then the node.
const ROUTES := {
	&"whisper_forest": {  # World Expansion A: the Forager's Path south of the entrance
		"StagRemainsB": [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-1110, 500), Vector2(-1110, 560), Vector2(-1150, 600)],
		"StagRemains": [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-1000, 496)],
		"TreeA": [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-1080, 276)],
		"FlaxA": [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-1090, 396)],
		"RockA": [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-800, 346)]},
	&"whispering_stone": {"OldOak": [], "RichIronVein": [], "DuskleafCluster": [Vector2(-210, 280)],
		"ElkRemains": [Vector2(240, 280), Vector2(240, 60)]},
}
const NEW_NODES := {&"old_oak": &"woodcutting", &"rich_iron_vein": &"mining", &"duskleaf_cluster": &"herbalism", &"elk_remains": &"skinning"}

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


func _placed_nodes() -> Dictionary:   # map id -> Array of [node name, ResourceNodeDefinition, position]
	var result := {}
	for map_id: StringName in [&"old_road", &"whisper_forest", &"whispering_stone"]:
		var map_def: MapDefinition = db.maps.get(map_id)
		var scene := (load(map_def.scene_path) as PackedScene).instantiate()
		result[map_id] = []
		for node: ResourceNode in scene.find_children("*", "ResourceNode", true, false):
			result[map_id].append([String(node.name), node.definition, node.position + (node.get_parent() as Node2D).position])
		scene.free()
	return result


func test_every_track_has_level_1_and_level_3_nodes_with_a_purpose() -> void:
	var placed := _placed_nodes()
	var used := {}
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if recipe.craftable:
			for cost in recipe.inputs:
				used[cost.item_id] = true
	for ruin: RuinDefinition in db.ruins.values():
		for cost in ruin.costs + ruin.revitalize_costs:
			used[cost.item_id] = true
	for profession_id: StringName in GATHERING:
		var levels := {}
		for map_id: StringName in placed:
			for entry: Array in placed[map_id]:
				var definition: ResourceNodeDefinition = entry[1]
				if definition.profession_id == profession_id:
					levels[definition.required_level] = true
					check(definition.gather_xp > 0 and definition.yield_quantity > 0, "%s: rewards XP and a yield" % definition.id)
					check(used.has(definition.yield_item_id), "%s: %s is used by a recipe or a restoration" % [definition.id, definition.yield_item_id])
		check(levels.has(1) and levels.has(3), "%s: level 1 and level 3 sources placed (%s)" % [profession_id, levels.keys()])
	for node_id: StringName in NEW_NODES:
		var definition: ResourceNodeDefinition = db.resource_nodes.get(node_id)
		if check(definition != null, "%s defined" % node_id):
			check_eq(definition.profession_id, NEW_NODES[node_id], "%s profession" % node_id)
			check(definition.respawn_seconds > 0.0, "%s respawns (existing real-time rule)" % node_id)
	check(ProfessionService.validate_data(db).is_empty(), "profession data valid: %s" % [ProfessionService.validate_data(db)])


func test_no_potions_or_unsupported_outputs() -> void:
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		var item := db.get_item(recipe.output_item_id)
		if not recipe.craftable:
			continue
		check(item.category != ItemDefinition.Category.CONSUMABLE or item.potion_effect != null, "%s: a craftable consumable must work (potion effect)" % recipe.id)
		if item.category == ItemDefinition.Category.WEAPON:
			check(db.weapons.has(item.weapon_family_id), "%s: weapon of a supported family" % recipe.id)
		if not item.is_equippable() and item.potion_effect == null:
			var feeds := db.profession_recipes.values().any(func(r: ProfessionRecipeDefinition) -> bool:
				return r.craftable and r.inputs.any(func(c: ItemCost) -> bool: return c.item_id == item.id))
			var restores := db.ruins.values().any(func(r: RuinDefinition) -> bool:
				return (r.costs + r.revitalize_costs).any(func(c: ItemCost) -> bool: return c.item_id == item.id))
			check(feeds or restores, "%s: material output is processed further or restores a building" % recipe.id)
	check(not (db.profession_recipes[&"al_stoneskin"] as ProfessionRecipeDefinition).craftable, "the draught stays data only")


func _open(map_id: StringName) -> bool:
	var map_def: MapDefinition = db.maps.get(map_id)
	character.world.map_id = map_id
	get_tree().change_scene_to_file(map_def.scene_path)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.is_node_ready() and not session.is_traveling():
			map = current
			map.player.feed_input(InputFrame.new())
			for enemy in map.find_children("*", "Enemy", true, false):
				enemy.queue_free()   # walking is checked, not fighting
			await get_tree().physics_frame
			return true
	fail("%s not loaded" % map_id)
	return false


func _walk_to(target: Vector2, limit: int = 900) -> bool:
	var frame := InputFrame.new()
	for i in limit:
		var to := target - map.player.global_position
		if to.length() < 8.0:
			break
		frame.move = to.normalized()
		frame.aim_direction = to.normalized()
		map.player.feed_input(frame)
		await get_tree().physics_frame
	map.player.feed_input(InputFrame.new())
	await get_tree().physics_frame
	return map.player.global_position.distance_to(target) < 8.0


func test_nodes_and_pack_are_reachable_on_foot() -> void:
	for map_id: StringName in ROUTES:
		if not await _open(map_id):
			return
		var start := map.player.global_position
		var encounters := map.find_children("*", "Encounter", true, false)
		var routes: Dictionary = ROUTES[map_id]
		if map_id == &"whisper_forest":
			routes = routes.duplicate()
			routes["HuntersPack"] = [Vector2(-1100, 10), Vector2(-1100, 200), Vector2(-1110, 500), Vector2(-1110, 560), Vector2(-1150, 600)]
		for node_name: String in routes:
			var target := map.find_child(node_name, true, false) as Area2D
			if not check(target != null, "%s: %s placed" % [map_id, node_name]):
				continue
			map.player.global_position = start
			map.player.reset_physics_interpolation()
			await get_tree().physics_frame
			for point: Vector2 in routes[node_name]:
				await _walk_to(point)
			await _walk_to(target.global_position + Vector2(0, 16))
			for i in 3:
				await get_tree().physics_frame
			check(target.get(&"player_inside") == true, "%s: %s reached on foot (player at %s)" % [map_id, node_name, map.player.global_position])
		for encounter: Node in encounters:
			check(not encounter.get(&"running") and not encounter.get(&"done"), "%s: no encounter triggered on the way (%s)" % [map_id, encounter.name])
		get_tree().unload_current_scene()
		await get_tree().process_frame


func test_level_3_nodes_gather_and_stay_depleted() -> void:
	var now := 1000.0
	for node_id: StringName in NEW_NODES:
		var definition: ResourceNodeDefinition = db.resource_nodes[node_id]
		var profession_id: StringName = NEW_NODES[node_id]
		var before := character.inventory.count(definition.yield_item_id)
		var error := ResourceGathering.gather(character, &"whispering_stone", node_id, definition, now)
		check(error.begins_with("Requires") and error.ends_with("level 3"), "%s refused at level 1: %s" % [node_id, error])
		check_eq(character.inventory.count(definition.yield_item_id), before, "%s: nothing gathered at level 1" % node_id)
		check_eq(character.professions.xp(profession_id), 0, "%s: no XP when refused" % node_id)
		_raise(profession_id, 3)
		check_eq(ResourceGathering.gather(character, &"whispering_stone", node_id, definition, now), "", "%s gathered at level 3" % node_id)
		check_eq(character.inventory.count(definition.yield_item_id), before + definition.yield_quantity, "%s: %d x %s" % [node_id, definition.yield_quantity, definition.yield_item_id])
		check_eq(character.professions.xp(profession_id), definition.gather_xp, "%s: %d XP" % [node_id, definition.gather_xp])
		check(ResourceGathering.gather(character, &"whispering_stone", node_id, definition, now + 1.0).ends_with("depleted"), "%s depleted" % node_id)
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	for node_id: StringName in NEW_NODES:
		var definition: ResourceNodeDefinition = db.resource_nodes[node_id]
		check(not ResourceGathering.is_available(loaded.character.world, &"whispering_stone", node_id, now + 10.0), "%s still depleted after loading" % node_id)
		check(ResourceGathering.is_available(loaded.character.world, &"whispering_stone", node_id, now + definition.respawn_seconds), "%s back after its respawn time" % node_id)


func test_leather_bracers_pattern_from_the_forest() -> void:
	if not await _open(&"whisper_forest"):
		return
	var pack := map.get_node("HuntersPack") as StoryPickup
	check(pack.visible, "the Hunter's Pack lies in the forest")
	map.player.global_position = pack.global_position + Vector2(0, 14)
	for i in 4:
		await get_tree().physics_frame
	pack.interact(map.hud)
	check_eq(character.inventory.count(&"pattern_leather_bracers"), 1, "pattern recovered")
	check(not pack.visible, "the pack is gone")
	check_eq(pack.take(), "Nothing to recover.", "only once")
	check_eq(character.inventory.count(&"pattern_leather_bracers"), 1, "still exactly one pattern")
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok() and loaded.character.world.has_flag(&"pickup.forest_hunters_pack"), "taken flag saved")
	get_tree().unload_current_scene()
	await get_tree().process_frame
	character = loaded.character
	session.set_character(character)
	if not await _open(&"whisper_forest"):
		return
	check(not (map.get_node("HuntersPack") as StoryPickup).visible, "no second pack after loading")
	# learn it: permanent, a second pattern is refused and kept
	var pattern := _first(&"pattern_leather_bracers")
	check_eq(ProfessionService.learn_from_item(character, pattern.instance_id), "", "pattern learned")
	check(character.professions.knows(&"lw_leather_bracers"), "Leather Bracers known")
	check_eq(character.inventory.count(&"pattern_leather_bracers"), 0, "pattern consumed")
	character.inventory.add_item(&"pattern_leather_bracers", 1)
	check(ProfessionService.learn_from_item(character, _first(&"pattern_leather_bracers").instance_id).begins_with("You already know"), "second pattern refused")
	check_eq(character.inventory.count(&"pattern_leather_bracers"), 1, "second pattern kept")
	# craft it at the Tanner's Lodge once the level allows
	character.inventory.add_item(&"cured_leather", 4)
	check(ProfessionService.craft(character, &"lw_leather_bracers", &"tanners_lodge").error.begins_with("Requires"), "level 3 needed")
	_raise(&"leatherworking", 3)
	check_eq(ProfessionService.craft(character, &"lw_leather_bracers", &"tanners_lodge").error, "", "Leather Bracers crafted")
	check_eq(character.inventory.count(&"leather_bracers"), 1, "bracers in the bag")
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved again")
	var again := SaveSystem.load_from(PATH, db)
	check(again.ok() and again.character.professions.knows(&"lw_leather_bracers"), "learned recipe survives save/load")


func test_new_recipes_craft_and_refuse_safely() -> void:
	var plan := {&"tl_rope_belt": [&"weavers_house", &"tailoring", 1], &"tl_padded_mantle": [&"weavers_house", &"tailoring", 2],
		&"tl_traveler_cloak": [&"weavers_house", &"tailoring", 3], &"lw_worn_boots": [&"tanners_lodge", &"leatherworking", 2]}
	for recipe_id: StringName in plan:
		var recipe: ProfessionRecipeDefinition = db.profession_recipes.get(recipe_id)
		if not check(recipe != null, "%s exists" % recipe_id):
			continue
		var station: StringName = plan[recipe_id][0]
		check(db.get_item(recipe.output_item_id).is_equippable(), "%s makes an equippable item" % recipe_id)
		_raise(plan[recipe_id][1], plan[recipe_id][2])
		ProfessionService.learn_automatic(character)
		check(character.professions.knows(recipe_id), "%s learned automatically at level %d" % [recipe_id, plan[recipe_id][2]])
		var bag := character.inventory.to_array()
		check(ProfessionService.craft(character, recipe_id, station).error.begins_with("Missing materials"), "%s: refused without materials" % recipe_id)
		for cost in recipe.inputs:
			character.inventory.add_item(cost.item_id, cost.quantity)
		check(ProfessionService.craft(character, recipe_id, &"alchemists_cottage").error.begins_with("Craft this at"), "%s: wrong station refused" % recipe_id)
		var results: Array[String] = []
		for i in 4:   # rapid clicks with material for one
			results.append(ProfessionService.craft(character, recipe_id, station).error)
		check_eq(results.count(""), 1, "%s: exactly one craft from four clicks" % recipe_id)
		check_eq(character.inventory.count(recipe.output_item_id), 1, "%s: one %s" % [recipe_id, recipe.output_item_id])
		for cost in recipe.inputs:
			check_eq(character.inventory.count(cost.item_id), 0, "%s: %s consumed" % [recipe_id, cost.item_id])
		character.inventory.remove_quantity(recipe.output_item_id, 1)
		check_eq(character.inventory.to_array().size(), bag.size(), "%s: bag back to its start" % recipe_id)
	# a full bag refuses before anything is consumed
	var belt: ProfessionRecipeDefinition = db.profession_recipes[&"tl_rope_belt"]
	for cost in belt.inputs:
		character.inventory.add_item(cost.item_id, cost.quantity)
	var filler := 0
	while character.inventory.room_for(&"rope_belt") > 0 and filler < 200:
		character.inventory.add_item(&"iron_sword", 1)
		filler += 1
	var before := character.inventory.count(&"flax_fiber")
	check_eq(ProfessionService.craft(character, &"tl_rope_belt", &"weavers_house").error, "Your bag is full.", "full bag refused")
	check_eq(character.inventory.count(&"flax_fiber"), before, "nothing consumed with a full bag")


func _first(item_id: StringName) -> ItemInstance:
	for item in character.inventory.items():
		if item.definition_id == item_id:
			return item
	return null


## Raises a profession to `target` through normal XP (no state poking).
func _raise(profession_id: StringName, target: int) -> void:
	while character.professions.level(profession_id) < target:
		character.professions.add_xp(profession_id, character.professions.xp_to_next(profession_id) - character.professions.xp(profession_id))
