extends TestCase
## Region 1 World Expansion B (docs/WORLD_EXPANSION_B_1_0.md): the large Chapel and Warden's Rest keep
## every id, trigger and gate; the camera stays inside; the main way (Tangled Wood -> yard -> nave ->
## waystone -> east way -> forecourt -> arena -> Split Watchstone) is walked with real movement; the
## arena is open; the main-way fights are one-time, so the way back repeats none; old saves land on
## their spawns. Only user://test_saves/.

const DIR := "user://test_saves/world_expansion_b"
const PROFILE := DIR + "/slot_1.save.json"
const QUEST := &"the_first_signs"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
const DEFEATED := &"defeated.wardens_rest_rootbound_sentinel"
const ONE_TIME := {&"chapel": [&"chapel_yard"], &"wardens_rest": [&"wr_forecourt"]}
const PER_VISIT := {&"chapel": [&"chapel_cloister"], &"wardens_rest": [&"wr_barracks_wolves"]}

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


## Finished prologue, the_first_signs active at `step` (flags of the earlier steps set); the
## main-way fights already cleared unless `fights` is true.
func _character(step: int, fights: bool = false) -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for quest_step in quest.steps:
			if quest_step.completion_flag != &"":
				character.world.set_flag(quest_step.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"arcanist"
	var main: StoryQuestDefinition = db.story_quests[QUEST]
	character.quests.entries[QUEST] = {"state": "active", "step": step, "progress": {}}
	for index in step:
		if main.steps[index].completion_flag != &"":
			character.world.set_flag(main.steps[index].completion_flag)
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


func _walk_route(map: GameMap, points: Array) -> bool:
	for point: Vector2 in points:
		if not check(await _walk_to(map, point), "%s: point %s reached (player at %s)" % [map.map_id, point, map.player.global_position]):
			return false
	return true


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


func _clear(encounter: Encounter) -> void:
	encounter.start()
	for enemy in encounter.enemies.duplicate():
		var hit := HitData.new()
		hit.damage = 100000.0
		enemy.hurtbox.receive_hit(hit)


func _leave_by(map: GameMap, exit_path: String, direction: Vector2, offset: float = 42.0) -> void:
	var exit := map.get_node(exit_path) as Node2D
	await _walk_to(map, exit.global_position - direction * offset)
	var input := InputFrame.new()
	input.move = direction
	map.player.feed_input(input)


# --- scene data ---------------------------------------------------------------------------------

func test_sizes_ids_gates_and_boss_are_kept() -> void:
	var chapel: GameMap = load("res://scenes/maps/chapel.tscn").instantiate()
	check_eq((chapel.get_node("Floor") as Node2D).get(&"area"), Rect2(-800, -576, 1600, 1152), "chapel: 1600 x 1152")
	check_eq(chapel.camera_bounds, Rect2(-832, -608, 1664, 1216), "chapel camera bounds: the map plus 32 px")
	var stone := chapel.get_node("ChapelWaystone") as Readable
	check([stone.persistent_id, stone.event_id, stone.look] == [&"chapel_old_stone", &"interact:chapel_waystone", Readable.Look.WAYSTONE],
		"Chapel Waystone kept (dormant look)")
	check(chapel.find_children("*", "Waystone", true, false).is_empty(), "no travel waystone in the chapel")
	var sealed := (chapel.get_node("SealedEast") as StoryConditional).condition.forbidden_flags
	var opened := (chapel.get_node("OpenEast") as StoryConditional).condition.required_flags
	check(sealed.size() == 1 and sealed.has(&"chapter1.chapel_waystone_examined") and opened.size() == 1 and opened.has(&"chapter1.chapel_waystone_examined"),
		"the east way still hangs on the waystone examination")
	check_eq((chapel.get_node("SealedEast/SealedHint") as StoryTrigger).hint_id, &"chapel_east_way", "hint id kept")
	var east := chapel.get_node("OpenEast/ToWardensRest") as MapTransition
	check([east.target_map_id, east.target_spawn_id] == [&"wardens_rest", &"from_chapel"], "east transition kept")
	var west := chapel.get_node("ToTangledWood") as MapTransition
	check([west.target_map_id, west.target_spawn_id] == [&"tangled_wood", &"from_chapel"], "west transition kept")
	check(absf((chapel.get_node("SealedEast/SealedWay") as Node2D).global_position.y - east.global_position.y) < 1.0, "the sealed way closes the exit gap")
	for spawn_id: StringName in [&"default", &"from_tangled", &"from_wardens_rest"]:
		check(chapel.find_spawn(spawn_id) != null, "chapel spawn %s kept" % spawn_id)
	check((chapel.get_node("FadedNote") as Readable).persistent_id == &"chapel_faded_note", "Faded Note kept")
	check(chapel.get_node("QuestAnchors").get_child_count() >= 3, "places reserved for Embers of Shelter")
	chapel.free()

	var rest: GameMap = load("res://scenes/maps/wardens_rest.tscn").instantiate()
	check_eq((rest.get_node("Floor") as Node2D).get(&"area"), Rect2(-640, -512, 1280, 1024), "rest: 1280 x 1024")
	check_eq(rest.camera_bounds, Rect2(-672, -544, 1344, 1088), "rest camera bounds: the map plus 32 px")
	var sentinel := rest.get_node("Enemies/RootboundSentinel") as Enemy
	check(sentinel.persistent_id == &"wardens_rest_rootbound_sentinel" and not sentinel.defeat_milestone, "Sentinel id kept (its milestone comes from the Sentinel's Cache)")
	check(sentinel.config == load("res://data/enemies/rootbound_sentinel.tres") and sentinel.attacks == load("res://data/enemies/sentinel_attacks.tres"),
		"Sentinel config and attacks unchanged")
	check(rest.get_node("Player").get_index() < rest.get_node("Enemies").get_index(), "Player precedes Enemies")
	var after := (rest.get_node("AfterSentinel") as StoryConditional).condition.required_flags
	check(after.size() == 1 and after.has(DEFEATED), "the Split Watchstone waits for the defeat")
	var watch := rest.get_node("AfterSentinel/SplitWatchstone") as Readable
	check(watch.persistent_id == &"wardens_rest_watchstone" and watch.event_id == &"interact:wardens_rest_watchstone", "watchstone ids kept")
	check((rest.get_node("ScratchedTally") as Readable).persistent_id == &"wardens_rest_tally", "tally kept")
	var back := rest.get_node("ToChapel") as MapTransition
	check([back.target_map_id, back.target_spawn_id] == [&"chapel", &"from_wardens_rest"], "way back kept")
	check(rest.find_children("*", "MapTransition", true, false).size() == 1, "no way east (no Region 2 transition)")
	check(rest.find_children("*", "Waystone", true, false).is_empty(), "no waystone")
	check_eq(rest.find_children("*", "BossRewardCache", true, false).size(), 1, "one reward cache (Chapter 1 Rare Reward 1.0)")
	for node: Readable in rest.find_children("*", "Readable", true, false):
		check(node.rewards.is_empty() or rest.get_node("HutFind").is_ancestor_of(node), "%s hands out nothing outside the hut find" % node.name)
		check(node.event_id == &"" or node.name == "SplitWatchstone", "%s reports no new story event" % node.name)
	check(rest.get_node("QuestAnchors").get_child_count() >= 1, "place reserved for a later find")
	rest.free()


func test_main_way_fights_one_time_optional_fights_per_visit() -> void:
	for map_id: StringName in ONE_TIME:
		var scene: Node = load((db.maps[map_id] as MapDefinition).scene_path).instantiate()
		for encounter_id: StringName in ONE_TIME[map_id]:
			var encounter := _encounter(scene, encounter_id)
			check(encounter != null and encounter.persistent and encounter.condition == null, "%s: one-time main-way fight" % encounter_id)
		for encounter_id: StringName in PER_VISIT[map_id]:
			var encounter := _encounter(scene, encounter_id)
			check(encounter != null and not encounter.persistent, "%s: optional, comes back per visit" % encounter_id)
		check_eq(scene.find_children("*", "Encounter", true, false).size(), ONE_TIME[map_id].size() + PER_VISIT[map_id].size(), "%s: no other encounter" % map_id)
		for encounter: Encounter in scene.find_children("*", "Encounter", true, false):
			check(encounter.completion_loot == null, "%s: no equipment table" % encounter.encounter_id)
		scene.free()


# --- real maps ----------------------------------------------------------------------------------

func test_camera_spawns_and_places_are_free() -> void:
	session.set_character(_character(3))
	for entry: Array in [[&"chapel", &"from_tangled", [-832, -608, 832, 608]], [&"wardens_rest", &"from_chapel", [-672, -544, 672, 544]]]:
		var map := await _travel(entry[0], entry[1])
		if map == null:
			return
		var camera := map.player.get_node("Camera2D") as Camera2D
		check_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], entry[2], "%s camera limits" % map.map_id)
		check(camera.get_screen_center_position().distance_to(map.player.global_position) < 400.0, "%s: camera starts at the spawn" % map.map_id)
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


func test_arena_is_open_around_the_sentinel() -> void:
	session.set_character(_character(4))
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := rest.get_node("Enemies/RootboundSentinel") as Enemy
	var centre := sentinel.global_position
	var blocked := 0
	for ring: float in [40.0, 80.0, 120.0]:
		for k in 24:
			if not _blocked_at(rest, centre + Vector2.from_angle(TAU * k / 24.0) * ring).is_empty():
				blocked += 1
	check_eq(blocked, 0, "no prop within 120 px of the Sentinel's place (dodge, block and parry room)")
	var gate := ((rest.get_node("Walls/GateTowerNorth") as Node2D).global_position + (rest.get_node("Walls/GateTowerSouth") as Node2D).global_position) * 0.5
	check(gate.distance_to(centre) > sentinel.config.aggro_range, "the gate lies outside the Sentinel's aggro")
	for name: String in ["GateRest", "SpawnFromChapel", "Encounters/Forecourt"]:
		check((rest.get_node(name) as Node2D).global_position.distance_to(centre) > sentinel.config.aggro_range + 100.0, "%s far from the Sentinel" % name)


func test_main_way_on_foot_from_the_wood_to_the_split_watchstone() -> void:
	var character := _character(2)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var stone := chapel.get_node("ChapelWaystone") as Readable
	if not await _walk_route(chapel, [Vector2(-300, 0), stone.global_position + Vector2(-12, 0)]):
		return
	for i in 3:
		await get_tree().physics_frame
	check(stone.player_inside, "the waystone is reached along the aisle")
	stone.interact(chapel.hud)
	chapel.hud.close_windows()
	for i in 3:
		await get_tree().physics_frame
	check(StoryService.at_step(character, QUEST, 3), "examined: step 3")
	if not await _walk_route(chapel, [Vector2(270, -40), Vector2(270, -210), Vector2(420, -300)]):
		return
	await _leave_by(chapel, "OpenEast/ToWardensRest", Vector2.RIGHT)
	var rest := await _await_map(&"wardens_rest")
	if rest == null:
		return
	check(StoryService.at_step(character, QUEST, 4), "arrival: step 4")
	var sentinel := rest.get_node("Enemies/RootboundSentinel") as Enemy
	check(sentinel.target == rest.player, "the Sentinel targets the player")
	if not await _walk_route(rest, [Vector2(-240, 0), Vector2(-100, 0)]):
		return
	check(sentinel.global_position.distance_to(rest.player.global_position) <= sentinel.config.aggro_range + 40.0, "through the gate the arena is reached")
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	sentinel.health.apply_hit(lethal)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(DEFEATED), "defeat flag")
	var watch := rest.get_node("AfterSentinel/SplitWatchstone") as Readable
	await _walk_to(rest, watch.global_position + Vector2(0, 10))
	for i in 3:
		await get_tree().physics_frame
	check(watch.is_visible_in_tree() and watch.player_inside, "the Split Watchstone appears and is reached")
	watch.interact(rest.hud)
	check(StoryService.at_step(character, QUEST, 5), "examined: step 5")


func test_optional_areas_reachable_on_foot() -> void:
	session.set_character(_character(4))
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	chapel.get_node("Encounters/Cloister").queue_free()   # walking only
	for route: Array in [
			[Vector2(-300, 0), Vector2(-105, 0), Vector2(-105, -300), chapel.get_node("Lore/CrackedBell").global_position],
			[Vector2(-105, -300), Vector2(160, -420), Vector2(430, -320)],
			[Vector2(430, -320), Vector2(270, -210), Vector2(270, -40), Vector2(70, 0), Vector2(70, 260), Vector2(40, 380)],
			[Vector2(70, 300), Vector2(100, 360), Vector2(120, 433), chapel.get_node("FadedNote").global_position],
			[Vector2(-60, 400), Vector2(-300, 460), Vector2(-420, 360), Vector2(-500, 180), Vector2(-470, 0)]]:
		if not await _walk_route(chapel, route):
			return
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	rest.get_node("Enemies/RootboundSentinel").queue_free()
	rest.get_node("Encounters/BarracksWolves").queue_free()
	for route: Array in [
			[Vector2(-240, 0), Vector2(0, 0), Vector2(380, -180), Vector2(380, -208), Vector2(420, -290), Vector2(420, -380),
				rest.get_node("ScratchedTally").global_position + Vector2(0, 10)],
			[Vector2(420, -290), Vector2(380, -180), Vector2(200, 170), Vector2(200, 230), Vector2(220, 300),
				rest.get_node("Lore/CaptainsLog").global_position + Vector2(0, -20)],
			[Vector2(220, 300), Vector2(200, 170), Vector2(430, 0), rest.get_node("EastRootsHint").global_position]]:
		if not await _walk_route(rest, route):
			return
	for i in 3:
		await get_tree().physics_frame
	check(session.character.world.has_flag(&"hint.wardens_rest_east_roots"), "the closed east way is explained")
	check(rest.player.global_position.x < (rest.get_node("Walls/EastRoots") as Node2D).global_position.x, "the roots stop the way east")


func test_way_back_repeats_no_main_way_fight() -> void:
	var character := _character(4, true)
	character.world.set_flag(DEFEATED)
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var forecourt := _encounter(rest, &"wr_forecourt")
	check(forecourt.can_start(), "the forecourt waits on the first visit")
	_clear(forecourt)
	check(character.world.has_flag(forecourt.cleared_flag()), "forecourt cleared for good")
	var chapel := await _travel(&"chapel", &"from_wardens_rest")
	if chapel == null:
		return
	var yard := _encounter(chapel, &"chapel_yard")
	check(yard.can_start(), "the yard waits until it was cleared once")
	_clear(yard)
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	chapel = await _await_map(&"chapel")
	if chapel == null:
		return
	check(not _encounter(chapel, &"chapel_yard").can_start(), "the yard stays clear after loading")
	check(_encounter(chapel, &"chapel_cloister").can_start(), "the optional cloister fight is available again")
	rest = await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	check(not _encounter(rest, &"wr_forecourt").can_start(), "the forecourt does not return")
	check(_encounter(rest, &"wr_barracks_wolves").can_start(), "the optional barracks wolves do")
	await get_tree().process_frame
	var sentinel := rest.get_node_or_null("Enemies/RootboundSentinel")
	check(sentinel == null or sentinel.is_queued_for_deletion(), "the defeated Sentinel stays gone")


func test_old_saves_land_on_their_spawns() -> void:
	for entry: Array in [[&"chapel", &"from_tangled"], [&"chapel", &"from_wardens_rest"], [&"chapel", &"default"], [&"chapel", &"chapel_rest"],
			[&"wardens_rest", &"from_chapel"], [&"wardens_rest", &"default"], [&"wardens_rest", &"wardens_rest_gate"]]:
		var character := _character(4)
		character.world.map_id = entry[0]
		character.world.spawn_id = entry[1]
		check_eq(SaveSystem.save_to(character, PROFILE), OK, "save written at %s/%s" % entry)
		session.set_character(CharacterFactory.create_new(db))
		check(session.load_game().ok(), "loaded %s/%s" % entry)
		var map := await _await_map(entry[0])
		if map == null:
			return
		var spawn := map.find_spawn(entry[1])
		if check(spawn != null, "%s has spawn %s" % entry):
			check(map.player.global_position.distance_to(spawn.global_position) < 1.0, "arrived at %s/%s" % entry)
		get_tree().unload_current_scene()
		await get_tree().process_frame
