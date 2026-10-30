extends TestCase
## Map & Fog of War 1.0 (docs/MAP_AND_FOG_OF_WAR_1_0.md): the minimap view (north up, follows
## the player, stops at the map edge, arrow off-centre there), the fog (a new map is dark, only
## real movement explores, walls and closed barriers keep the far side dark, a quest start
## reveals nothing), markers only on explored ground and never closed exits, the fog in the
## save (WorldState map state, Save v15 unchanged, old saves and broken data load safely), the
## map window (M, Area/Region, no undiscovered waystone names, Esc) at 100/125/150 % UI.
## Only user://test_saves/.

const DIR := "user://test_saves/map_fog"
const PROFILE := DIR + "/slot_1.save.json"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
const ONE_TIME := {&"whisper_forest": [&"wf_road_wolves", &"wf_split_oak"], &"tangled_wood": [&"tw_root_arch"],
	&"chapel": [&"chapel_yard"], &"wardens_rest": [&"wr_forecourt"]}
const FOREST_BOUNDS := Rect2(-1312, -752, 2624, 1504)
## The forest main road from the west spawn (as in test_world_expansion_a).
const FOREST_ROAD: Array[Vector2] = [Vector2(-760, 40), Vector2(-300, -20)]

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
	session.settings.set_ui_scale(1.0)
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


## Finished prologue, the_first_signs active, the one-time fights cleared.
func _character() -> Character:
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
			await get_tree().process_frame
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
	await get_tree().process_frame
	return map.player.global_position.distance_to(target) < 8.0


func _walk_road(map: GameMap) -> bool:
	for point in FOREST_ROAD:
		if not await _walk_to(map, point, 900):
			fail("road point %s not reached (player at %s)" % [point, map.player.global_position])
			return false
	return true


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _labels(markers: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for marker in markers:
		result.append(str(marker.label))
	return result


## A fresh fog on `map` explored only from `at` (the map's own fog is left alone).
func _fresh_reveal(map: GameMap, at: Vector2) -> MapFog:
	var fog := MapFog.new(map.area_map.bounds)
	fog.reveal(at, map.area_map)
	return fog


# --- A minimap ----------------------------------------------------------------------------------

func test_minimap_view_follows_and_stops_at_the_edges() -> void:
	var view := Vector2(1024, 1024)
	check_eq(AreaMinimap.view_rect(FOREST_BOUNDS, Vector2(0, 0), view), Rect2(-512, -512, 1024, 1024), "centred on the player inside")
	check_eq(AreaMinimap.view_rect(FOREST_BOUNDS, Vector2(-1240, 0), view).position, Vector2(-1312, -512), "stops at the west edge")
	check_eq(AreaMinimap.view_rect(FOREST_BOUNDS, Vector2(1280, 700), view).position, Vector2(288, -272), "stops at the south-east corner")
	var small := Rect2(-300, -200, 600, 400)
	check_eq(AreaMinimap.view_rect(small, Vector2(250, 150), view).get_center(), small.get_center(), "a map smaller than the view is centred")
	session.set_character(_character())
	var forest := await _travel(&"whisper_forest", &"default")
	if forest == null:
		return
	var minimap := forest.hud.minimap
	check(minimap.is_bound() and minimap.is_visible_in_tree(), "the minimap shows the forest")
	check(not (forest.hud.minimap_frame.get_node("Unavailable") as Control).visible, "no placeholder text")
	check(minimap.size.x >= 180.0 and minimap.size.y >= 180.0, "fills the 200 px frame (%s)" % minimap.size)
	var at_edge := minimap.world_to_minimap(forest.player.global_position)
	check(at_edge.x < minimap.size.x * 0.25 and absf(at_edge.y - minimap.size.y * 0.5) < 6.0,
		"at the west edge the arrow sits left of centre (%s)" % at_edge)
	check(await _walk_road(forest), "walked the road to the Split Oak")
	var inside := minimap.world_to_minimap(forest.player.global_position)
	check(inside.distance_to(minimap.size * 0.5) < 3.0, "inside the map the arrow is centred (%s)" % inside)
	var north := minimap.world_to_minimap(forest.player.global_position + Vector2(0, -100))
	check(north.y < inside.y and is_equal_approx(north.x, inside.x), "north is up")
	check(forest.player.aim_direction.x > 0.5, "facing east after walking east (the arrow points along aim_direction)")
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	check(wood.hud.minimap.is_bound() and wood.hud.minimap.map == wood, "rebound on the next map")
	check(wood.area_map.bounds.size != forest.area_map.bounds.size if is_instance_valid(forest) else true, "own size per map")


# --- B fog ----------------------------------------------------------------------------------------

func test_new_map_is_dark_and_only_movement_explores() -> void:
	var character := _character()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"default")
	if forest == null:
		return
	var fog := forest.fog
	var total := fog.width * fog.height
	var first := fog.explored_count()
	check(first > 0 and first < total * 0.05, "a new map starts dark but the player's surroundings (%d of %d cells)" % [first, total])
	check(fog.is_explored_at(forest.player.global_position), "the player's own cell is explored")
	check(not fog.is_explored_at(Vector2(820, 420)), "the far clearing is unexplored")
	StoryService.start(character, &"the_lost_hunter")
	for i in 5:
		await get_tree().process_frame
	check_eq(fog.explored_count(), first, "starting a quest reveals nothing")
	check(not fog.is_explored_at(Vector2(-640, -560)), "the hunter's camp stays dark")
	check(await _walk_road(forest), "walked the road to the Split Oak")
	check(fog.explored_count() > first, "walking explores")
	check(fog.is_explored_at(Vector2(-300, -20)) and fog.is_explored_at(Vector2(-700, 0)), "the way walked is explored")
	var stored := str(character.world.get_map_value(&"whisper_forest", MapFog.STATE_KEY, ""))
	check(stored.begins_with("v1:%dx%d:" % [fog.width, fog.height]), "kept as a map state in WorldState (%s...)" % stored.left(12))
	var near := 0
	var px := Vector2(fog.width, fog.height) * 0.0
	for cell_y in fog.height:
		for cell_x in fog.width:
			if fog.is_explored(Vector2i(cell_x, cell_y)):
				px = fog.cell_centre(Vector2i(cell_x, cell_y))
				near += 1 if px.x > 600.0 else 0
	check_eq(near, 0, "nothing east of x = 600 explored")


func test_walls_and_closed_barriers_keep_the_far_side_dark() -> void:
	session.set_character(_character())
	var wood := await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	var barrier := wood.get_node("Shortcut/Closed/Barrier") as Node2D
	var east := barrier.global_position + Vector2(56, 0)
	var west := barrier.global_position + Vector2(-96, 0)
	check(not wood.area_map.is_solid(east) and not wood.area_map.is_solid(west), "both sides of the shortcut are open ground")
	check(wood.area_map.is_solid(barrier.global_position), "the closed barrier is solid on the map")
	check(not _fresh_reveal(wood, east).is_explored_at(west), "closed: the far side of the roots stays dark")
	wood.session.get_character().world.set_flag(&"read.tw_brittle_roots")
	for i in 4:
		await get_tree().process_frame
	check(not wood.area_map.is_solid(barrier.global_position), "torn open: the map picture is rebuilt without the barrier")
	check(_fresh_reveal(wood, east).is_explored_at(west), "open: the way through is explored")
	# a separate room: the Heart of the Roots behind its walls is not revealed from the main road below
	var outside := Vector2(180, -40)
	if not wood.area_map.is_solid(outside):
		var fog := _fresh_reveal(wood, outside)
		var dark := 0
		for y in range(-330, -130, 32):
			dark += 0 if fog.is_explored_at(Vector2(180, y)) else 1
		check(dark > 0, "walls keep at least part of the Heart of the Roots dark from the road (%d dark samples)" % dark)


func test_markers_only_on_explored_ground_and_no_closed_exits() -> void:
	var character := _character()
	StoryService.start(character, &"what_the_roots_keep")
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	var dark := MapFog.new(wood.area_map.bounds)
	check(MapMarkers.collect(wood, character, dark).is_empty(), "no markers on an unexplored map")
	var labels := _labels(MapMarkers.collect(wood, character, wood.fog))
	check("Knotted Marker" not in labels and "Heart of the Roots" not in labels, "root marks and far places not shown before discovery (%s)" % [labels])
	var at_marker := _fresh_reveal(wood, Vector2(-820, -60))
	var near := _labels(MapMarkers.collect(wood, character, at_marker))
	check("Root Arch" in near, "a landmark appears once its ground is explored (%s)" % [near])
	for marker in MapMarkers.collect(wood, character, wood.fog):
		check(marker.kind not in [&"enemy", &"resource", &"loot"], "no enemies, resources or loot")
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var sealed := chapel.get_node("SealedEast") as StoryConditional
	check(sealed.is_active(), "the east way is still sealed")
	var east_fog := MapFog.new(chapel.area_map.bounds)
	east_fog.reveal(Vector2(754, -380), chapel.area_map)
	var exits := MapMarkers.collect(chapel, character, east_fog).filter(func(m: Dictionary) -> bool: return m.kind == MapMarkers.EXIT)
	check(exits.is_empty(), "a sealed exit is never shown as an exit (%s)" % [exits])
	check(chapel.area_map.is_solid(Vector2(808, -380)), "the sealed way is drawn closed")


# --- C save / load ----------------------------------------------------------------------------------

func test_fog_survives_save_load_and_travel() -> void:
	var character := _character()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"default")
	if forest == null:
		return
	check(await _walk_road(forest), "walked the road to the Split Oak")
	var walked := forest.fog.explored_count()
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	check(wood.fog.explored_count() < walked, "each map has its own fog")
	forest = await _travel(&"whisper_forest", &"from_tangled")
	if forest == null:
		return
	check(forest.fog.is_explored_at(Vector2(-300, -20)) and forest.fog.is_explored_at(Vector2(-1100, 0)), "kept across travel")
	check(forest.fog.explored_count() >= walked, "nothing lost on the way back")
	check_eq(session.save_game(), OK, "saved")
	check_eq(SaveSystem.VERSION, 15, "Save v15 unchanged")
	var raw := FileAccess.get_file_as_string(session.save_path)
	check(raw.contains("fog") and raw.contains("v1:"), "the fog is in the save file (payload JSON)")
	var before := forest.fog.encode()
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	forest = await _await_map(&"whisper_forest")
	if forest == null:
		return
	check(forest.fog.is_explored_at(Vector2(-300, -20)) and forest.fog.is_explored_at(Vector2(-1100, 0)), "explored ground restored")
	var after := MapFog.new(forest.area_map.bounds)
	after.decode(before)
	check(forest.fog.explored_count() >= after.explored_count(), "no cell lost by save/load")


func test_old_saves_and_broken_fog_load_safely() -> void:
	var world := WorldState.new()
	var fog := MapFog.new(FOREST_BOUNDS)
	check(not fog.load_from(world, &"whisper_forest") and fog.load_warning == "", "a save without fog: dark, no warning")
	for broken: String in ["junk", "v2:82x47:AAAA", "v1:3x3:AAAA", "v1:82x47:not base64!", "v1:axb:AAAA"]:
		# decode() is load_from() without the push_warning (the runner counts warnings as errors)
		var fresh := MapFog.new(FOREST_BOUNDS)
		check(not fresh.decode(broken) and fresh.load_warning != "", "'%s' discarded with a warning" % broken)
		check_eq(fresh.explored_count(), 0, "'%s': starts dark, nothing half applied" % broken)
	var round := MapFog.new(FOREST_BOUNDS)
	round.reveal(Vector2.ZERO, null)
	var copy := MapFog.new(FOREST_BOUNDS)
	check(copy.decode(round.encode()) and copy.explored_count() == round.explored_count(), "encode/decode round trip")
	# an old v15 save without any fog: the map loads and only the player's surroundings are explored
	var character := _character()
	check(character.world.get_map_value(&"whisper_forest", MapFog.STATE_KEY, null) == null, "no fog stored yet")
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"default")
	if forest == null:
		return
	var count := forest.fog.explored_count()
	check(count > 0 and count < 200, "no fog in the save: the map loads, only the near area explored (%d)" % count)


# --- D map window, F resolutions ---------------------------------------------------------------------

func test_map_window_area_region_and_no_spoilers() -> void:
	var character := _character()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"default")
	if forest == null:
		return
	var panel := forest.hud.world_map_panel
	for ui_scale: float in [1.0, 1.25, 1.5]:
		session.settings.set_ui_scale(ui_scale)
		await get_tree().process_frame
		await _key(KEY_M)
		await get_tree().process_frame
		check(panel.visible and panel.page == "Area", "M opens the map on Area (%d %%)" % int(ui_scale * 100))
		check(forest.hud.is_window_open(), "the window blocks the player's input")
		var canvas := panel.get_viewport_rect()
		var rect := panel.get_global_rect()
		check(canvas.encloses(rect), "map window inside the canvas at %d %% (%s in %s)" % [int(ui_scale * 100), rect, canvas.size])
		var area := panel.get_node("%s" % panel.get_path_to(panel.find_child("AreaMap", true, false))) as Control
		check(area != null and area.size.x > 200.0 and canvas.encloses(area.get_global_rect()), "area picture inside the window")
		var minimap_rect := forest.hud.minimap_frame.get_global_rect()
		check(canvas.encloses(minimap_rect), "minimap frame inside the canvas at %d %%" % int(ui_scale * 100))
		await _key(KEY_M)
		check(not panel.visible, "M closes it again")
	await _key(KEY_M)
	panel.show_page("Region")
	await get_tree().process_frame
	var legend: Array[String] = []
	for label in panel.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			legend.append((label as Label).text)
	var text := " | ".join(legend)
	for waystone in WaystoneService.all(db):
		var known := waystone in WorldMapPanel.known_waystones(character)
		if not known:
			check(not text.contains(waystone.display_name), "undiscovered waystone '%s' not named" % waystone.display_name)
	check(not text.contains("undiscovered"), "no 'undiscovered' list")
	check(&"chapel" not in WorldMapPanel.known_maps(character), "unvisited places are not on the region map")
	await _key(KEY_ESCAPE)
	check(not panel.visible, "Esc closes the map")
	check(not get_tree().paused, "the map never pauses the game")


func test_landmarks_stand_on_open_ground_and_pictures_are_small() -> void:
	for map_id: String in ["whisper_forest", "tangled_wood", "chapel", "wardens_rest"]:
		var map: Node2D = load("res://scenes/maps/%s.tscn" % map_id).instantiate()
		var area := AreaMap.new(map)
		var landmarks := map.find_children("*", "MapLandmark", true, false)
		check(landmarks.size() == 4, "%s: four named landmarks" % map_id)
		for node in landmarks:
			var landmark := node as MapLandmark
			check(landmark.label != "" and not area.is_solid(landmark.global_position), "%s: '%s' on open ground" % [map_id, landmark.label])
		var fog := MapFog.new(area.bounds)
		check(area.width * area.height <= 400 * 260 and fog.width * fog.height <= 100 * 70,
			"%s: small pictures (raster %dx%d, fog %dx%d)" % [map_id, area.width, area.height, fog.width, fog.height])
		print("    %s raster %dx%d fog %dx%d" % [map_id, area.width, area.height, fog.width, fog.height])
		map.free()
