extends SceneTree
## Chapter 1 "The Roots Remember" M2 visual check in a real window (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/roots_m2_visual_check.gd
## 1920x1080 at 100 % and 1280x720 at 150 % UI scale: the Tangled Wood's east exit, the walk into the
## Chapel, an overview, the yard encounter, the Chapel Waystone (prompt, text, tracker), the niche with
## the faded note, the sealed way east and the walk back. Fresh test characters (the_first_signs at
## step 2), saves only under user://test_saves/. Screenshots and log: tests/output/roots_m2/.

const OUTPUT := "res://tests/output/roots_m2"
const QUEST := &"the_first_signs"
const PASSES: Array = [[Vector2i(1920, 1080), 1.0], [Vector2i(1280, 720), 1.5]]

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0
var _tag := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/roots_m2_visual/slot_1.save.json"
	for pass_spec: Array in PASSES:
		await _pass(pass_spec[0], pass_spec[1])
	session.settings.reset_to_defaults()
	_log("RESULT: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("roots_m2_visual_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		for path in SaveSlots.all_paths(session.save_path):
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	quit(0 if failures == 0 else 1)


func _pass(resolution: Vector2i, scale: float) -> void:
	_tag = "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	session.settings.set_ui_scale(scale)
	session.settings.set_reduce_motion(true)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	var character := _character_at_chapel_step()
	session.set_character(character)
	# the Tangled Wood's new east exit
	await _open(&"tangled_wood", &"from_chapel")
	await _frames(15)
	_check(Interactable.find_active(self) == null, "no prompt at the wood's east spawn")
	await _shot("01_wood_east_exit")
	await _walk_to(Vector2(300, 40), Vector2.RIGHT, 0)
	await _await_map(&"chapel")
	_check(map.map_id == &"chapel", "walked east into the Chapel")
	await _frames(15)
	_check(Interactable.find_active(self) == null, "no prompt at the chapel arrival")
	await _shot("02_chapel_arrival")
	await _overview("03_chapel_overview")
	# yard encounter
	map.player.global_position = Vector2(-200, 0)
	map.player.reset_physics_interpolation()
	await _frames(40)
	_check((map.get_node("Encounters/ChapelYard") as Encounter).running, "the yard encounter starts")
	await _shot("04_yard_encounter")
	_kill_all()
	await _frames(30)
	# sealed way east (closed until the waystone is examined; M3 opens it afterwards)
	await _walk_to(Vector2(270, -162), Vector2.RIGHT, 60)
	await _frames(10)
	_check(map.map_id == &"chapel" and map.player.global_position.x < 320.0, "the way east stays closed")
	_check(Interactable.find_active(self) == null, "no prompt at the sealed way")
	await _shot("09_sealed_way")
	# the Chapel Waystone
	map.player.global_position = Vector2(128, 0)
	map.player.reset_physics_interpolation()
	await _frames(20)
	var stone := map.get_node("ChapelWaystone") as Readable
	_check(Interactable.find_active(self) == stone, "at the Chapel Waystone")
	await _shot("05_waystone_prompt")
	stone.interact(map.hud)
	await _frames(20)
	await _shot("06_waystone_text")
	map.hud.close_windows()
	await _frames(10)
	_check(StoryService.at_step(character, QUEST, 3), "step 3 after the examination")
	_check(not WaystoneService.is_active(character, &"chapel_waystone"), "waystone stays dormant")
	await _shot("07_tracker_step3")
	# niche with the faded note
	map.player.global_position = Vector2(118, 140)
	map.player.reset_physics_interpolation()
	await _frames(20)
	_check(Interactable.find_active(self) == map.get_node("FadedNote"), "the faded note in the niche")
	await _shot("08_niche_note")
	# back west
	await _walk_to(Vector2(-300, 0), Vector2.LEFT, 0)
	await _await_map(&"tangled_wood")
	_check(map.map_id == &"tangled_wood" and map.player.global_position.distance_to(map.find_spawn(&"from_chapel").global_position) < 1.0,
		"back in the Tangled Wood at the east spawn")
	await _frames(15)
	await _shot("10_back_in_the_wood")


func _character_at_chapel_step() -> Character:
	var character := CharacterFactory.create_new(session.database)
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	StoryService.start(character, QUEST)
	StoryService.notify(character, &"enter:tangled_wood")
	StoryService.notify(character, &"interact:tangled_roots")
	character.world.set_flag(&"read.tangled_twisted_roots")
	return character


func _open(map_id: StringName, spawn_id: StringName) -> void:
	session.travel(map_id, spawn_id, false)
	await _await_map(map_id)


func _await_map(map_id: StringName) -> void:
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(10)


## Places the player and holds `direction`; frames = 0 waits for a map change instead.
func _walk_to(from: Vector2, direction: Vector2, frames: int) -> void:
	map.player.global_position = from
	map.player.reset_physics_interpolation()
	var input := InputFrame.new()
	input.move = direction
	map.player.feed_input(input)
	var start := map
	for i in (frames if frames > 0 else 300):
		await physics_frame
		if frames == 0 and current_scene != start:
			break
	if is_instance_valid(start) and current_scene == start:
		map.player.feed_input(InputFrame.new())


func _kill_all() -> void:
	for enemy: Enemy in map.find_children("*", "Enemy", true, false):
		var hit := HitData.new()
		hit.damage = 10000.0
		enemy.hurtbox.receive_hit(hit)


func _overview(label: String) -> void:
	var camera := Camera2D.new()
	var size := Vector2(root.size)
	var fit := minf(size.x / 700.0, size.y / 450.0)
	camera.zoom = Vector2(fit, fit)
	camera.position = Vector2(0, 0)
	map.add_child(camera)
	camera.make_current()
	await _frames(5)
	await _shot(label)
	camera.queue_free()
	(map.player.get_node("Camera2D") as Camera2D).make_current()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s_%s.png" % [_tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
	_log("%s %s %s" % ["PASS" if ok else "FAIL", _tag, text])


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)
