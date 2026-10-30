extends SceneTree
## Map UX 2.0 window check (NOT headless, 1920 x 1080, 100 % UI): Haven's area map, the Whisper Forest centred, the
## player at the edge, dragged with the real mouse and centred again, the partly known region with an awake and a
## silent waystone, a chosen place, the help opened by keyboard, Travel at Haven's waystone. Session only (no save).
##   godot --path . -s res://tests/playtest/map_ux_check.gd
## Screenshots: tests/output/map_ux/<name>.png

const OUTPUT := "res://tests/output/map_ux"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]

var session: SessionState
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	root.borderless = 1920 >= DisplayServer.screen_get_size().x
	root.position = DisplayServer.screen_get_position()
	session.settings.set_ui_scale(1.0)
	session.settings.set_reduce_motion(true)
	var character := CharacterFactory.create_new(session.database)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	for map_id: StringName in [&"home_base", &"old_road", &"whispering_stone", &"whisper_forest", &"tangled_wood"]:
		character.world.set_map_value(map_id, "visits", 1)
	character.world.waystones.append(&"haven")   # Haven awake, the Whispering Stone silent, Chapel / Warden's Rest unknown
	session.set_character(character)
	# Haven
	var map := await _travel(&"home_base")
	map.hud.toggle_map()
	await _frames(8)
	await _shot("area_haven")
	map.hud.toggle_map()
	# the forest, from the middle
	map = await _travel(&"whisper_forest")
	map.player.global_position = Vector2(-200, 0)
	await _frames(4)
	map.hud.toggle_map()
	await _frames(8)
	var area = map.hud.world_map_panel.find_child("AreaMap", true, false)
	_check(area.call(&"world_to_view", map.player.global_position).distance_to(area.size * 0.5) <= 1.5, "forest opened centred on the player")
	await _shot("area_forest_centred")
	# dragged with the real mouse, then the centre button
	await _drag(area, area.size * 0.5, Vector2(-400, -250))
	await _shot("area_forest_dragged")
	(map.hud.world_map_panel.find_child("CenterOnPlayer", true, false) as Button).grab_focus()
	await _frames(2)
	(map.hud.world_map_panel.find_child("CenterOnPlayer", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(area.call(&"world_to_view", map.player.global_position).distance_to(area.size * 0.5) <= 1.5, "centred again")
	await _shot("area_forest_recentred")
	map.hud.toggle_map()
	# at the edge
	map.player.global_position = map.area_map.bounds.end - Vector2(60, 60)
	await _frames(4)
	map.hud.toggle_map()
	await _frames(8)
	await _shot("area_forest_edge")
	# the region from the forest: partly known, the Tangled Wood chosen, help by keyboard
	map.hud.world_map_panel.show_page("Region")
	await _frames(4)
	var graph = map.hud.world_map_panel.find_child("RegionMap", true, false)
	await _shot("region_partial")
	graph.select(&"whispering_stone")
	(map.hud.world_map_panel.find_child("RegionHelp", true, false) as Control).grab_focus()
	await _frames(4)
	await _shot("region_chosen_help")
	map.hud.toggle_map()
	# at Haven's awake waystone: Travel to... nothing else is awake - wake the Whispering Stone for this view
	character.world.waystones.append(&"whispering_stone")
	map = await _travel(&"home_base")
	var stone := map.get_node("Waystone") as Node2D
	map.player.global_position = stone.global_position
	for i in 8:
		await physics_frame
	map.hud.toggle_map()
	map.hud.world_map_panel.show_page("Region")
	await _frames(4)
	graph = map.hud.world_map_panel.find_child("RegionMap", true, false)
	graph.select(&"whispering_stone")
	await _frames(4)
	var travel := map.hud.world_map_panel.find_child("Travel", true, false) as Button
	_check(travel != null and not travel.disabled, "Travel offered at an awake waystone")
	await _shot("region_travel")
	print("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _travel(map_id: StringName) -> GameMap:
	session.travel(map_id, &"default", false)
	for i in 300:
		await process_frame
		var map := current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await _frames(8)
			return map
	_check(false, "map %s reached" % map_id)
	return null


## A real mouse drag (warped OS cursor, real button events) over `control`.
func _drag(control: Control, from_local: Vector2, by: Vector2) -> void:
	var to_screen := func(local: Vector2) -> Vector2: return root.get_final_transform() * (control.get_global_transform() * local)
	var start: Vector2 = to_screen.call(from_local)
	var end: Vector2 = to_screen.call(from_local + by)
	root.warp_mouse(start)
	await _frames(2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = control.get_global_transform() * from_local
	press.global_position = press.position
	root.push_input(press, true)
	for step in 8:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = control.get_global_transform() * (from_local + by * ((step + 1) / 8.0))
		motion.global_position = motion.position
		root.push_input(motion, true)
		root.warp_mouse(start.lerp(end, (step + 1) / 8.0))
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = control.get_global_transform() * (from_local + by)
	release.global_position = release.position
	root.push_input(release, true)
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join("%s.png" % label)))
	print("screenshot %s" % label)


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["CHECK OK  " if ok else "CHECK FAIL", text])
