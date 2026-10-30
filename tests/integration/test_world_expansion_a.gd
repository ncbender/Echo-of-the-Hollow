extends TestCase
## Region 1 World Expansion A (docs/WORLD_EXPANSION_A_1_0.md): the large Whisper Forest and
## Tangled Wood keep every id, trigger and gate of the old maps; the camera stays inside the
## map; the main road, the Twisted Roots and both exits are walked with real movement; the
## shortcut opens once from the east and survives save/load; the main-road fights are
## one-time, so the way back never repeats them; old saves land on their spawns.
## Only user://test_saves/.

const DIR := "user://test_saves/world_expansion_a"
const PROFILE := DIR + "/slot_1.save.json"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
## Node ids of the old Whisper Forest: saved gathering state must still find its nodes.
const OLD_FOREST_NODES: Array[StringName] = [&"treea", &"treeb", &"treec", &"treed", &"rocka", &"rockb", &"rockc",
	&"veina", &"veinb", &"deposit", &"flaxa", &"flaxb", &"duskleaf", &"stag", &"stag_b"]
## Main road of each map, from the arrival spawn (waypoints of the layout, docs).
const FOREST_ROAD: Array[Vector2] = [Vector2(-760, 40), Vector2(-300, -20), Vector2(150, -180), Vector2(650, -300), Vector2(1080, -420)]
const WOOD_ROAD: Array[Vector2] = [Vector2(-820, -120), Vector2(-520, -330), Vector2(-150, -420), Vector2(200, -220)]
const WOOD_ROAD_EAST: Array[Vector2] = [Vector2(420, 60), Vector2(760, 240)]
const ONE_TIME := {&"whisper_forest": [&"wf_road_husks"], &"tangled_wood": [&"tw_bend_wolves", &"tw_heart_watch"]}
## Side quest fights (Paket C, test_side_quests): one-time, behind their quest condition.
const QUEST_FIGHTS := {&"whisper_forest": [&"lost_hunter_den"], &"tangled_wood": [&"roots_keep_guardians"]}
const PER_VISIT := {&"whisper_forest": [&"wf_trail_wolves", &"wf_forager_wolves"],
	&"tangled_wood": [&"tangled_path_husks", &"tw_north_hardened", &"tangled_hollow_wolves"]}

var db: GameDatabase
var session: SessionState
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = PROFILE
	session.saves.reset()
	_clean()


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## Finished prologue, the_first_signs active at step 0; the main-road fights already cleared
## (so a walk is never interrupted) unless `fights` is true.
func _character(fights: bool = false) -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for step in quest.steps:
			if step.completion_flag != &"":
				character.world.set_flag(step.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"arcanist"
	StoryService.start(character, &"the_first_signs")
	if not fights:
		for map_id: StringName in ONE_TIME:
			for encounter_id: StringName in ONE_TIME[map_id]:
				character.world.set_flag(StringName("encounter.%s" % encounter_id))
	return character


func _travel(map_id: StringName, spawn_id: StringName) -> GameMap:
	check(session.travel(map_id, spawn_id, false), "travel to %s accepted" % map_id)
	return await _await_map(map_id)


func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


## Real movement towards `target` (no teleport). True when it was reached.
func _walk_to(map: GameMap, target: Vector2, limit: int = 600) -> bool:
	var frame := InputFrame.new()
	for i in limit:
		if not is_instance_valid(map) or get_tree().current_scene != map:
			return false
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


func _blocked_at(map: GameMap, at: Vector2) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits := map.get_world_2d().direct_space_state.intersect_shape(query)
	return hits.filter(func(hit: Dictionary) -> bool: return hit.collider is StaticBody2D)


func _encounter(map: Node, encounter_id: StringName) -> Encounter:
	for node in map.find_children("*", "Encounter", true, false):
		if (node as Encounter).encounter_id == encounter_id:
			return node
	return null


# --- scene data ---------------------------------------------------------------------------------

func test_sizes_ids_and_triggers_are_kept() -> void:
	var forest: GameMap = load("res://scenes/maps/whisper_forest.tscn").instantiate()
	check_eq((forest.get_node("Floor") as Node2D).get(&"area"), Rect2(-1280, -720, 2560, 1440), "forest: 2560 x 1440")
	check_eq(forest.camera_bounds, Rect2(-1312, -752, 2624, 1504), "forest camera bounds: the map plus 32 px, so exit portals stay in view")
	var home := forest.get_node("ToHomeBase") as MapTransition
	check([home.target_map_id, home.target_spawn_id] == [&"home_base", &"from_forest"], "west exit to Haven unchanged")
	var east := forest.get_node("EastPath/ToTangledWood") as MapTransition
	check([east.target_map_id, east.target_spawn_id] == [&"tangled_wood", &"from_forest"], "east exit unchanged")
	var open_flags := (forest.get_node("EastPath") as StoryConditional).condition.required_flags
	check(open_flags.size() == 1 and open_flags.has(&"prologue.completed"), "east exit opens after the prologue")
	var gate_flags := (forest.get_node("EastRoots") as StoryConditional).condition.forbidden_flags
	check(gate_flags.size() == 1 and gate_flags.has(&"prologue.completed"), "the prologue gate is kept")
	check_eq((forest.get_node("EastRoots/RootsHint") as StoryTrigger).hint_id, &"east_roots", "gate hint id kept")
	var bar := forest.get_node("EastRoots/Bar") as Node2D
	check(absf(bar.global_position.y - east.global_position.y) < 1.0 and bar.global_position.x < east.global_position.x, "the bar closes the exit gap")
	for spawn_id: StringName in [&"default", &"from_home", &"from_tangled"]:
		check(forest.find_spawn(spawn_id) != null, "forest spawn %s kept" % spawn_id)
	var pack := forest.get_node("HuntersPack") as StoryPickup
	check(pack.persistent_id == &"forest_hunters_pack" and pack.item_id == &"pattern_leather_bracers", "Hunter's Pack and its recipe kept")
	var cache := forest.get_node("WardensCache") as StoryPickup   # Chapter 1 Rare Reward 1.0: materials, no Rare
	check(cache.persistent_id == &"whisper_forest_wardens_cache" and cache.item_id == &"iron_ingot", "Warden's Cache kept (without the Rare)")
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	check(warden.persistent_id == &"whisper_forest_grove_warden" and is_equal_approx(warden.scale.x, 1.3), "Grove Warden kept")
	check(warden.global_position.distance_to(cache.global_position) < 240.0, "the cache lies in the Warden's clearing")
	for name: String in ["GruntA", "GruntB", "GruntC"]:
		check((forest.get_node("Enemies/" + name) as Enemy).equipment_loot == load("res://data/loot/hollow_grunt_equipment.tres"), "%s keeps its equipment roll" % name)
	check(forest.get_node("Player").get_index() < forest.get_node("Enemies").get_index(), "forest: Player precedes Enemies")
	var ids := {}
	for node: ResourceNode in forest.find_children("*", "ResourceNode", true, false):
		check(not ids.has(node.node_id), "unique node id %s" % node.node_id)
		ids[node.node_id] = node.definition
	for node_id in OLD_FOREST_NODES:
		check(ids.has(node_id), "old node id %s kept" % node_id)
	check(ids.size() <= OLD_FOREST_NODES.size() + 2, "no material inflation (%d nodes)" % ids.size())
	check(forest.get_node("QuestAnchors").get_child_count() >= 5, "places reserved for The Lost Hunter")
	forest.free()

	var wood: GameMap = load("res://scenes/maps/tangled_wood.tscn").instantiate()
	check_eq((wood.get_node("Floor") as Node2D).get(&"area"), Rect2(-1152, -864, 2304, 1728), "wood: 2304 x 1728")
	check_eq(wood.camera_bounds, Rect2(-1184, -896, 2368, 1792), "wood camera bounds: the map plus 32 px")
	var roots := wood.get_node("TwistedRoots") as Readable
	check(roots.persistent_id == &"tangled_twisted_roots" and roots.event_id == &"interact:tangled_roots", "Twisted Roots trigger kept")
	check((wood.get_node("GnawedRoots") as Readable).persistent_id == &"tangled_gnawed_roots", "Gnawed Roots kept")
	var chapel := wood.get_node("ToChapel") as MapTransition
	check([chapel.target_map_id, chapel.target_spawn_id] == [&"chapel", &"from_tangled"] and chapel.get_parent() == wood, "way to the Chapel unconditional")
	var back := wood.get_node("ToWhisperForest") as MapTransition
	check([back.target_map_id, back.target_spawn_id] == [&"whisper_forest", &"from_tangled"], "way back unchanged")
	for spawn_id: StringName in [&"default", &"from_forest", &"from_chapel"]:
		check(wood.find_spawn(spawn_id) != null, "wood spawn %s kept" % spawn_id)
	check(wood.get_node("Encounters/PathHusks") is Encounter and wood.get_node("Encounters/HollowWolves") is Encounter, "old encounter nodes kept")
	check(wood.get_node("QuestAnchors").get_child_count() >= 5, "places reserved for What the Roots Keep")
	for node: Readable in wood.find_children("*", "Readable", true, false):
		if wood.get_node("RootsKeep").is_ancestor_of(node):
			continue   # the side quest's own marker, marks and cache (test_side_quests)
		check(node.rewards.is_empty() or wood.get_node("Finds").is_ancestor_of(node), "%s hands out nothing outside the finds (test_gameplay_polish)" % node.name)
		check(node.event_id == &"" or node == roots, "%s reports no new story event" % node.name)
	wood.free()


func test_main_road_fights_are_one_time_the_rest_per_visit() -> void:
	for map_id: StringName in ONE_TIME:
		var scene: Node = load((db.maps[map_id] as MapDefinition).scene_path).instantiate()
		for encounter_id: StringName in ONE_TIME[map_id]:
			var encounter := _encounter(scene, encounter_id)
			check(encounter != null and encounter.persistent and encounter.condition == null, "%s: one-time main-road fight" % encounter_id)
		for encounter_id: StringName in PER_VISIT[map_id]:
			var encounter := _encounter(scene, encounter_id)
			check(encounter != null and not encounter.persistent, "%s: optional, comes back per visit" % encounter_id)
		for encounter_id: StringName in QUEST_FIGHTS[map_id]:
			var encounter := _encounter(scene, encounter_id)
			check(encounter != null and encounter.persistent and encounter.condition != null, "%s: one-time quest fight behind its condition" % encounter_id)
		check_eq(scene.find_children("*", "Encounter", true, false).size(),
			ONE_TIME[map_id].size() + PER_VISIT[map_id].size() + QUEST_FIGHTS[map_id].size(), "%s: no other encounter" % map_id)
		for node in scene.find_children("*", "Enemy", true, false):
			check(map_id == &"whisper_forest", "%s: placed enemies only in the forest (%s)" % [map_id, node.name])
		scene.free()


# --- real maps ----------------------------------------------------------------------------------

func test_camera_stays_inside_the_map() -> void:
	session.set_character(_character())
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var camera := forest.player.get_node("Camera2D") as Camera2D
	check_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], [-1312, -752, 1312, 752], "forest camera limits")
	check_eq(camera.zoom, Vector2.ONE * ((camera as CameraShake).base_zoom / forest.get_window().content_scale_factor), "zoom untouched")
	var wood := await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	camera = wood.player.get_node("Camera2D") as Camera2D
	check_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], [-1184, -896, 1184, 896], "wood camera limits")
	check(camera.get_screen_center_position().distance_to(wood.player.global_position) < 400.0, "camera starts at the spawn, not across the map")
	var haven := await _travel(&"home_base", &"from_forest")
	if haven == null:
		return
	camera = haven.player.get_node("Camera2D") as Camera2D
	check(camera.limit_left < -100000 and camera.limit_right > 100000, "small maps keep the free camera")


func test_spawns_and_places_are_free() -> void:
	session.set_character(_character())
	for entry: Array in [[&"whisper_forest", &"from_home"], [&"tangled_wood", &"from_forest"]]:
		var map := await _travel(entry[0], entry[1])
		if map == null:
			return
		for point: SpawnPoint in map.find_children("*", "SpawnPoint", true, false):
			check(_blocked_at(map, point.global_position).is_empty(), "%s: spawn %s free" % [map.map_id, point.spawn_id])
		for spawn: EncounterSpawn in map.find_children("*", "EncounterSpawn", true, false):
			check(_blocked_at(map, spawn.global_position).is_empty(), "%s: encounter spawn %s/%s free" % [map.map_id, spawn.get_parent().name, spawn.name])
		for node: ResourceNode in map.find_children("*", "ResourceNode", true, false):
			check(_blocked_at(map, node.global_position + Vector2(0, 16)).is_empty(), "%s: %s can be stood at" % [map.map_id, node.name])
		for node: Area2D in map.find_children("*", "Readable", true, false) + map.find_children("*", "Checkpoint", true, false):
			check(_blocked_at(map, node.global_position).is_empty(), "%s: %s reachable" % [map.map_id, node.name])
		for i in 3:
			await get_tree().physics_frame
		check(Interactable.find_active(get_tree()) == null, "%s: no prompt on arrival" % map.map_id)


func test_forest_main_road_on_foot_to_the_wood() -> void:
	var character := _character()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	for point in FOREST_ROAD:
		if not check(await _walk_to(forest, point), "forest road point %s reached (player at %s)" % [point, forest.player.global_position]):
			return
	for path: String in ["Enemies/GruntA", "Enemies/GruntB", "Enemies/GruntC", "Enemies/GroveWarden"]:
		var enemy := forest.get_node(path) as Enemy
		check(enemy.combat.state == CombatComponent.State.IDLE, "%s stayed out of the road" % path)
	check(is_equal_approx(forest.player.health.health, forest.player.health.max_health), "no damage on the main road")
	var exit := forest.get_node("EastPath/ToTangledWood") as Node2D
	await _walk_to(forest, exit.global_position + Vector2(-42, 0))
	var input := InputFrame.new()
	input.move = Vector2.RIGHT
	forest.player.feed_input(input)
	var wood := await _await_map(&"tangled_wood")
	if wood == null:
		return
	check(StoryService.at_step(character, &"the_first_signs", 1), "enter:tangled_wood still advances the quest")


func test_wood_main_road_twisted_roots_and_chapel_on_foot() -> void:
	var character := _character()
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	for point in WOOD_ROAD:
		if not check(await _walk_to(wood, point), "wood road point %s reached (player at %s)" % [point, wood.player.global_position]):
			return
	var roots := wood.get_node("TwistedRoots") as Readable
	await _walk_to(wood, roots.global_position + Vector2(0, 12))
	for i in 3:
		await get_tree().physics_frame
	check(roots.player_inside, "the Twisted Roots lie on the main road")
	roots.interact(wood.hud)
	check(StoryService.at_step(character, &"the_first_signs", 2), "examining advances the quest")
	for point in WOOD_ROAD_EAST:
		if not check(await _walk_to(wood, point), "wood road point %s reached" % point):
			return
	var exit := wood.get_node("ToChapel") as Node2D
	await _walk_to(wood, exit.global_position + Vector2(-32, 0))
	var input := InputFrame.new()
	input.move = Vector2.RIGHT
	wood.player.feed_input(input)
	check(await _await_map(&"chapel") != null, "the way to the Chapel is open")


func test_shortcut_opens_once_from_the_east_and_is_saved() -> void:
	var character := _character()
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	var closed := wood.get_node("Shortcut/Closed") as StoryConditional
	var barrier := wood.get_node("Shortcut/Closed/Barrier") as Node2D
	var roots := wood.get_node("Shortcut/BrittleRoots") as Readable
	check(closed.is_active(), "closed at first")
	# from the east: along the main road back to the junction, then the shortcut to the brittle roots
	for point: Vector2 in [Vector2(760, 240), Vector2(420, 60), Vector2(400, 40), Vector2(0, 10), Vector2(-450, -40)]:
		if not check(await _walk_to(wood, point), "shortcut point %s reached" % point):
			return
	await _walk_to(wood, roots.global_position)
	await _walk_to(wood, barrier.global_position + Vector2(-40, 0), 120)
	check(wood.player.global_position.x > barrier.global_position.x, "the roots bar the way while closed")
	await _walk_to(wood, roots.global_position)
	for i in 3:
		await get_tree().physics_frame
	check(roots.player_inside, "brittle roots reachable from the east")
	roots.interact(wood.hud)
	wood.hud.close_windows()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(character.world.has_flag(&"read.tw_brittle_roots") and not closed.is_active(), "torn open: a saved world flag")
	check(await _walk_to(wood, Vector2(-820, -110), 300), "through to the Root Arch")
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	wood = await _await_map(&"tangled_wood")
	if wood == null:
		return
	check(not (wood.get_node("Shortcut/Closed") as StoryConditional).is_active(), "still open after save/load")
	await _travel(&"whisper_forest", &"from_tangled")
	wood = await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	check(not (wood.get_node("Shortcut/Closed") as StoryConditional).is_active(), "still open after a map change")
	check(StoryService.counter(session.character, &"interact:tangled_roots") == 0, "the shortcut never touches the main quest")


func test_way_back_repeats_no_main_road_fight() -> void:
	var character := _character(true)
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	for encounter_id: StringName in ONE_TIME[&"tangled_wood"]:
		var encounter := _encounter(wood, encounter_id)
		check(encounter.can_start(), "%s waits on the first visit" % encounter_id)
		encounter.start()
		for enemy in encounter.enemies.duplicate():
			var hit := HitData.new()
			hit.damage = 100000.0
			enemy.hurtbox.receive_hit(hit)
		check(encounter.done and character.world.has_flag(encounter.cleared_flag()), "%s cleared for good" % encounter_id)
	var forest := await _travel(&"whisper_forest", &"from_tangled")
	if forest == null:
		return
	var road := _encounter(forest, &"wf_road_husks")
	road.start()
	for enemy in road.enemies.duplicate():
		var hit := HitData.new()
		hit.damage = 100000.0
		enemy.hurtbox.receive_hit(hit)
	check(road.done, "forest road fight cleared")
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	forest = await _await_map(&"whisper_forest")
	if forest == null:
		return
	check(not _encounter(forest, &"wf_road_husks").can_start(), "forest road stays clear after loading")
	wood = await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	for encounter_id: StringName in ONE_TIME[&"tangled_wood"]:
		check(not _encounter(wood, encounter_id).can_start(), "%s does not return on the way back" % encounter_id)
	for encounter_id: StringName in PER_VISIT[&"tangled_wood"]:
		check(_encounter(wood, encounter_id).can_start(), "%s: optional fight available again" % encounter_id)


func test_old_saves_land_on_their_spawns() -> void:
	for entry: Array in [[&"whisper_forest", &"from_tangled"], [&"whisper_forest", &"from_home"], [&"tangled_wood", &"from_chapel"],
			[&"whisper_forest", &"forest_rest"], [&"tangled_wood", &"tangled_rest"]]:
		var character := _character()
		character.world.set_flag(&"defeated.whisper_forest_grove_warden")
		character.world.set_flag(&"boss_reward.whisper_forest_grove_warden")
		character.world.map_id = entry[0]
		character.world.spawn_id = entry[1]
		check_eq(SaveSystem.save_to(character, PROFILE), OK, "save written at %s/%s" % entry)
		session.set_character(CharacterFactory.create_new(db))
		check(session.load_game().ok(), "loaded %s/%s" % entry)
		var map := await _await_map(entry[0])
		if map == null:
			return
		var spawn := map.find_spawn(entry[1])
		if not check(spawn != null, "%s has spawn %s" % entry):
			continue
		check(map.player.global_position.distance_to(spawn.global_position) < 1.0, "arrived at %s/%s" % entry)
		if entry[0] == &"whisper_forest":
			await get_tree().process_frame
			var warden := map.get_node_or_null("Enemies/GroveWarden")
			check(warden == null or warden.is_queued_for_deletion(), "defeated Warden stays gone")
			check(not (map.get_node("WardensCache") as StoryPickup).visible, "claimed cache stays closed")
		get_tree().unload_current_scene()
		await get_tree().process_frame
