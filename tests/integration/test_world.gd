extends TestCase
## Regions, maps, transitions, spawn points, persistent world/map state, save/load
## after a map change. Uses REAL scene changes through SessionState.travel().

const DIR := "user://test_saves"

var session: SessionState
var db: GameDatabase
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	session = SessionState.find(get_tree())
	db = session.database
	_previous_character = session.character
	_previous_path = session.save_path
	session.set_character(CharacterFactory.create_new(db))
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = DIR.path_join("world_test.save.json")


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(session.save_path + suffix):
			DirAccess.remove_absolute(session.save_path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _travel(map_id: StringName, spawn_id: StringName, fade: bool = false) -> GameMap:
	check(session.travel(map_id, spawn_id, fade), "travel to %s accepted" % map_id)
	return await _await_map(map_id)


func _await_map(map_id: StringName, limit: int = 120) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _spawn_position(map: GameMap, spawn_id: StringName) -> Vector2:
	return map.find_spawn(spawn_id).global_position


func test_region_and_map_data_are_consistent() -> void:
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var region: RegionDefinition = db.regions.get(&"hollow_outskirts")
	if not check(region != null, "first region exists"):
		return
	check_eq(region.map_ids.size(), db.maps.size(), "every map belongs to the region")
	for map_id in region.map_ids:
		var map_def: MapDefinition = db.maps[map_id]
		var scene: GameMap = load(map_def.scene_path).instantiate()
		check_eq(scene.map_id, map_id, "%s scene declares its map id" % map_id)
		var spawn_ids := {}
		for point: SpawnPoint in scene.find_children("*", "SpawnPoint", true, false):
			check(not spawn_ids.has(point.spawn_id), "%s: unique spawn id %s" % [map_id, point.spawn_id])
			spawn_ids[point.spawn_id] = true
		check(spawn_ids.has(&"default"), "%s has a default spawn" % map_id)
		for transition: MapTransition in scene.find_children("*", "MapTransition", true, false):
			var target_def: MapDefinition = db.maps.get(transition.target_map_id)
			if check(target_def != null, "%s -> unknown map %s" % [map_id, transition.target_map_id]):
				var target: GameMap = load(target_def.scene_path).instantiate()
				check(target.find_spawn(transition.target_spawn_id) != null,
					"%s -> %s: spawn %s exists" % [map_id, transition.target_map_id, transition.target_spawn_id])
				target.free()
		scene.free()


func test_travel_between_maps_keeps_character_and_positions() -> void:
	var character := session.character
	var home := await _travel(&"home_base", &"default")
	check(home.player.global_position.distance_to(_spawn_position(home, &"default")) < 1.0, "spawned at home default")
	character.mastery.add_xp(&"one_handed_sword", 150)
	var forest := await _travel(&"whisper_forest", &"from_home", true)
	if forest == null:
		return
	check(forest.player.global_position.distance_to(_spawn_position(forest, &"from_home")) < 1.0, "forest entry position")
	check(session.character == character, "same character object")
	check_eq(get_tree().get_nodes_in_group(&"player").size(), 1, "exactly one player in the tree")
	check_eq(character.mastery.get_level(&"one_handed_sword"), 2, "mastery kept")
	check_eq(forest.player.combat.weapon.id, &"one_handed_sword", "equipped weapon applied in new map")
	check(forest.bridge.character == character, "bridge bound to the session character")
	home = await _travel(&"home_base", &"from_forest")
	check(home.player.global_position.distance_to(_spawn_position(home, &"from_forest")) < 1.0, "return position")
	check_eq(character.world.map_id, &"home_base", "world map id updated")
	check_eq(character.world.spawn_id, &"from_forest", "world spawn id updated")
	check_eq(int(character.world.get_map_value(&"home_base", "visits", 0)), 2, "map state: visit counter")


func test_walking_through_doorway_changes_map() -> void:
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var input := InputFrame.new()
	input.move = Vector2.LEFT
	forest.player.feed_input(input)
	var home := await _await_map(&"home_base", 240)
	if home != null:
		check(home.player.global_position.distance_to(_spawn_position(home, &"from_forest")) < 1.0, "arrived at the forest door of the base")


func test_second_request_during_transition_is_ignored() -> void:
	await _travel(&"home_base", &"default")
	check(session.travel(&"whisper_forest", &"from_home", true), "first request")
	check(not session.travel(&"test_arena", &"from_home", true), "second request ignored")
	await _await_map(&"whisper_forest")


func test_normal_enemies_respawn_but_boss_stays_defeated() -> void:
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	var grunt := forest.get_node("Enemies/GruntA") as Enemy
	for enemy in [warden, grunt]:
		var hit := HitData.new()
		hit.damage = 10000.0
		(enemy as Enemy).hurtbox.receive_hit(hit)
	check(session.character.world.has_flag(&"defeated.whisper_forest_grove_warden"), "boss defeat flag set")
	await _travel(&"home_base", &"from_forest")
	forest = await _travel(&"whisper_forest", &"from_home")
	await get_tree().process_frame
	var again := forest.get_node_or_null("Enemies/GroveWarden")
	check(again == null or again.is_queued_for_deletion(), "boss stays defeated")
	check(forest.get_node_or_null("Enemies/GruntA") != null, "normal grunt respawned")


func test_save_and_load_after_map_change() -> void:
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	session.character.world.set_flag(&"test.forest_seen")
	var character_id := session.character.id
	check_eq(session.save_game(), OK, "saved in the forest")
	await _travel(&"home_base", &"from_forest")
	session.set_character(CharacterFactory.create_new(db))
	var result := session.load_game()
	check(result.ok(), "loaded: %s" % [result.errors])
	var loaded := await _await_map(&"whisper_forest")
	if loaded == null:
		return
	check_eq(session.character.id, character_id, "same character restored")
	check(session.character.world.has_flag(&"test.forest_seen"), "world flag restored")
	check(loaded.player.global_position.distance_to(_spawn_position(loaded, &"from_home")) < 1.0, "spawned at the saved spawn point")


func test_version_1_save_is_migrated() -> void:
	var character := CharacterFactory.create_new(db)
	var data := character.to_dict()
	(data.world as Dictionary).erase("map_states")
	var payload := JSON.stringify(data)
	var file := FileAccess.open(session.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": SaveSystem.FORMAT, "version": 1, "checksum": payload.sha256_text(), "payload": payload}))
	file.close()
	var result := SaveSystem.load_from(session.save_path, db)
	check(result.ok(), "v1 save loads: %s" % [result.errors])
	if result.ok():
		check(result.character.world.map_states.is_empty(), "map states initialised empty")
		check_eq(result.character.inventory.to_array(), character.inventory.to_array(), "content preserved")
