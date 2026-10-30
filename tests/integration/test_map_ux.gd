extends TestCase
## Map UX 2.0 (docs/MAP_UX_2_0.md): the area map opens centred on the player (again on every opening, kept inside
## the picture at the edges, small maps in the middle), real mouse drags move it (a small press is a click, a drag
## never clicks), the centre button and the arrow keys; the region network from the real map data (whole names,
## you are here vs. the chosen place, waystones only where known), choosing never travels, Travel only from an awake
## waystone you stand at (WaystoneService), and the window keeps the world's input. Only user://test_saves/.

const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]

var db: GameDatabase
var session: SessionState
var _previous: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _character() -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"arcanist"
	return character


func _open(map_id: StringName) -> GameMap:
	check(session.travel(map_id, &"default", false), "travel to %s" % map_id)
	for i in 240:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			await get_tree().process_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


## Viewport (canvas) position of a point of `control` - push_input(event, true) takes these.
func _screen(control: Control, local: Vector2) -> Vector2:
	return control.get_global_transform() * local


## A real mouse press / move / release through the GUI (viewport input).
func _mouse(at: Vector2, pressed: Variant = null) -> void:
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		get_viewport().push_input(button, true)
	await get_tree().process_frame


func _drag(control: Control, from_local: Vector2, by: Vector2) -> void:
	var start := _screen(control, from_local)
	var end := _screen(control, from_local + by)
	await _mouse(start, true)
	for step in 4:
		await _mouse(start.lerp(end, (step + 1) / 4.0))
	await _mouse(end, false)


func _player_view(area: Control, map: GameMap) -> Vector2:
	return area.call(&"world_to_view", map.player.global_position)


## A large map: centred on the player when opened (also after looking around and reopening), never an empty
## margin at the edges, the centre button; real drags move it at once and are kept inside.
func test_area_centres_and_drags() -> void:
	var character := _character()
	session.set_character(character)
	var map := await _open(&"whisper_forest")
	if map == null:
		return
	var panel := map.hud.world_map_panel
	map.player.global_position = Vector2.ZERO   # the west spawn lies at the edge: start in the middle
	await get_tree().physics_frame
	map.hud.toggle_map()
	await _frames(4)
	var area = panel.find_child("AreaMap", true, false)
	check(panel.visible and map.hud.is_window_open(), "the map is open and holds the player's input")
	var content: Vector2 = area.call(&"content_size")
	check(content.x > area.size.x, "the forest is larger than the view (readable scale %.3f)" % area.call(&"scale_factor"))
	var centre: Vector2 = area.size * 0.5
	check(_player_view(area, map).distance_to(centre) <= 1.5, "opened centred on the player (%s / %s)" % [_player_view(area, map), centre])
	var before: Vector2 = area.pan
	await _drag(area, centre, Vector2(-60, -30))
	check((area.pan - before).distance_to(Vector2(-60, -30)) <= 1.5, "a drag moves the picture with the mouse (%s)" % (area.pan - before))
	check(not panel.find_child("RegionMap", true, false).is_visible_in_tree(), "the drag changed no page")
	await _drag(area, centre, Vector2(500, 300))   # far past the edge (inside the window: real mouse positions)
	check(is_equal_approx(area.pan.x, 0.0) and is_equal_approx(area.pan.y, 0.0), "kept at the picture's top-left corner (%s)" % area.pan)
	await _drag(area, centre, Vector2(-500, -300))
	await _drag(area, centre, Vector2(-500, -300))
	check(area.pan.distance_to(area.size - content) <= 1.0, "kept at the bottom-right corner, no empty margin (%s)" % area.pan)
	(panel.find_child("CenterOnPlayer", true, false) as Button).pressed.emit()
	await _frames(1)
	check(_player_view(area, map).distance_to(centre) <= 1.5, "the centre button returns to the player")
	area.grab_focus()
	var key := InputEventAction.new()
	key.action = &"ui_right"
	key.pressed = true
	var at: Vector2 = area.pan
	area._gui_input(key)
	check(area.pan.x < at.x or is_equal_approx(area.pan.x, area.size.x - content.x), "the arrow keys look around")
	map.hud.toggle_map()
	await _frames(2)
	# near the edge: the picture stays inside (the player is off-centre)
	map.player.global_position = map.area_map.bounds.position + Vector2(40, 40)
	await get_tree().physics_frame
	map.hud.toggle_map()
	await _frames(4)
	check(area.pan.distance_to(Vector2.ZERO) <= 1.0, "player at the corner: the picture starts at its corner (%s)" % area.pan)
	check(_player_view(area, map).x < centre.x and _player_view(area, map).y < centre.y, "and the player is off-centre there")
	map.hud.toggle_map()
	await _frames(2)
	map.player.global_position = Vector2.ZERO
	await get_tree().physics_frame
	map.hud.toggle_map()   # reopened: centred again
	await _frames(4)
	check(_player_view(area, map).distance_to(centre) <= 1.5, "reopened centred on the player again")


## A small map fits the view: shown whole in the middle (no dragging away).
func test_small_area_sits_in_the_middle() -> void:
	session.set_character(_character())
	var map := await _open(&"home_base")
	if map == null:
		return
	map.hud.toggle_map()
	await _frames(4)
	var area = map.hud.world_map_panel.find_child("AreaMap", true, false)
	var content: Vector2 = area.call(&"content_size")
	for axis in 2:
		if content[axis] <= area.size[axis]:
			check(absf(area.pan[axis] - (area.size[axis] - content[axis]) * 0.5) <= 1.0, "axis %d centred" % axis)
	var before: Vector2 = area.pan
	await _drag(area, area.size * 0.5, Vector2(80, 80))
	for axis in 2:
		if content[axis] <= area.size[axis]:
			check(is_equal_approx(area.pan[axis], before[axis]), "axis %d: a smaller picture does not move" % axis)


## Region: the real network, whole names, the current place in view and in the details, a click (no drag) chooses,
## a drag never chooses, choosing never travels; Travel only from an awake waystone you stand at.
func test_region_select_and_travel_rules() -> void:
	var character := _character()
	for map_def: MapDefinition in db.maps.values():
		if map_def.show_on_map and map_def.id != &"wardens_rest":
			character.world.set_map_value(map_def.id, "visits", 1)
	character.world.waystones.append(&"haven")
	character.world.waystones.append(&"whispering_stone")
	session.set_character(character)
	var map := await _open(&"home_base")
	if map == null:
		return
	var panel := map.hud.world_map_panel
	map.hud.toggle_map()
	panel.show_page("Region")
	await _frames(4)
	var graph = panel.find_child("RegionMap", true, false)
	check_eq(graph.known(), WorldMapPanel.known_maps(character), "the places of the real map data")
	check(not &"wardens_rest" in graph.known(), "an unvisited place is not drawn (only a nameless ?)")
	check(graph.names_fit(), "every place name whole, at most two lines")
	check_eq(graph.selected_id, &"home_base", "the current place chosen at first")
	var here_rect: Rect2 = graph.node_rect(&"home_base")
	check(Rect2(Vector2.ZERO, graph.size).encloses(Rect2(here_rect.position + graph.pan, here_rect.size)), "the current place in view")
	check(_label(panel, "PlaceState").contains("You are here"), "the details say you are here")
	# a drag starting on a place does not choose it
	var stone_rect: Rect2 = graph.node_rect(&"whispering_stone")
	await _drag(graph, stone_rect.get_center() + graph.pan, Vector2(-30, 20))
	check_eq(graph.selected_id, &"home_base", "a drag chose nothing")
	# a click (tiny movement) chooses - and only chooses
	graph.center_on(stone_rect.get_center())
	await _frames(1)
	var click := _screen(graph, stone_rect.get_center() + graph.pan)
	await _mouse(click, true)
	await _mouse(click + Vector2(2, 1))
	await _mouse(click + Vector2(2, 1), false)
	await _frames(2)
	check_eq(graph.selected_id, &"whispering_stone", "a click chose the place")
	check(not session.is_traveling() and get_tree().current_scene == map, "choosing never travels")
	check(_label(panel, "PlaceState").contains("The Whispering Stone: awake"), "its waystone state in the details")
	var travel := panel.find_child("Travel", true, false) as Button
	check(travel != null and travel.disabled and _label(panel, "TravelReason") == "Travel starts at an awake waystone.", "away from a waystone: the reason")
	check(travel != null and travel.size.x > 0.0, "the action stays visible")
	# an unvisited neighbour's waystone is never named
	check(WorldMapPanel.place_waystone(character, &"wardens_rest") == null, "no waystone of an unknown place")
	# keyboard: arrows choose the neighbour in that direction
	graph.grab_focus()
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	graph._gui_input(down)
	check_eq(graph.selected_id, &"home_base", "down from the Whispering Stone: Haven")
	# at Haven's awake waystone: Travel to the Whispering Stone is allowed and starts the journey
	var stone := map.get_node("Waystone") as Waystone
	map.player.global_position = stone.global_position
	for i in 6:
		await get_tree().physics_frame
	graph.select(&"whispering_stone")
	await _frames(2)
	travel = panel.find_child("Travel", true, false) as Button
	check(stone.player_inside and travel != null and not travel.disabled, "at an awake waystone: Travel possible")
	travel.pressed.emit()
	await _frames(2)
	check(session.is_traveling() or (get_tree().current_scene as GameMap).map_id == &"whispering_stone", "the journey started")
	check(not panel.visible, "the window closed for the journey")
	for i in 240:
		await get_tree().process_frame
		if not session.is_traveling():
			break


func _label(root: Node, label_name: String) -> String:
	var label := root.find_child(label_name, true, false) as Label
	return label.text if label != null else ""
