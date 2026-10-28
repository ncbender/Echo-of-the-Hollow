extends SceneTree
## Chapter 1 "The Roots Remember" M1 visual check in a real window (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/roots_m1_visual_check.gd
## Whisper Forest east exit closed (prologue running) and open (prologue completed), the walk
## into the Tangled Wood, an overview of the wood, the examination prompt and text, the tracker
## placeholder, both encounters, the optional hollow and the walk back. Fresh test characters,
## saves only under user://test_saves/. Screenshots and log: tests/output/roots_m1/.

const OUTPUT := "res://tests/output/roots_m1"
const QUEST := &"the_first_signs"

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/roots_m1_visual/slot_1.save.json"
	session.settings.set_reduce_motion(true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	# 1. prologue still running: the roots close the way east
	var early := CharacterFactory.create_new(session.database)
	StoryService.begin_prologue(early)
	session.set_character(early)
	await _open(&"whisper_forest", &"from_home")
	await _walk_to(Vector2(270, -156), Vector2.RIGHT, 70)
	_check(map.map_id == &"whisper_forest" and map.player.global_position.x < 320.0, "prologue: the roots block the exit")
	_check(early.world.has_flag(&"hint.east_roots"), "prologue: barrier hint shown")
	await _shot("01_forest_roots_closed")
	# 2. prologue completed: open exit, into the wood
	var character := _finished_prologue()
	session.set_character(character)
	await _open(&"whisper_forest", &"from_home")
	map.player.global_position = Vector2(250, -156)
	map.player.reset_physics_interpolation()
	await _frames(20)
	await _shot("02_forest_exit_open")
	await _walk_to(Vector2(290, -156), Vector2.RIGHT, 0)
	await _await_map(&"tangled_wood")
	_check(map.map_id == &"tangled_wood", "walked east into the Tangled Wood")
	_check(StoryService.at_step(character, QUEST, 1), "arrival step done")
	await _frames(20)
	await _shot("03_wood_arrival")
	await _overview("04_wood_overview")
	# path bend and husks
	map.player.global_position = Vector2(-40, -70)
	map.player.reset_physics_interpolation()
	await _frames(45)
	_check((map.get_node("Encounters/PathHusks") as Encounter).running, "husks attack on the path")
	await _shot("05_path_husks")
	_kill_all()
	await _frames(30)
	# examination
	map.player.global_position = Vector2(228, 0)
	map.player.reset_physics_interpolation()
	await _frames(20)
	var roots := map.get_node("TwistedRoots") as Readable
	_check(roots.player_inside and Interactable.find_active(self) == roots, "standing at the twisted roots")
	await _shot("06_roots_prompt")
	roots.interact(map.hud)
	await _frames(20)
	await _shot("07_roots_text")
	map.hud.close_windows()
	await _frames(10)
	_check(StoryService.at_step(character, QUEST, 2), "examined: placeholder step")
	await _shot("08_tracker_placeholder")
	# optional hollow
	map.player.global_position = Vector2(144, 170)
	map.player.reset_physics_interpolation()
	await _frames(10)
	await _walk_to(Vector2(144, 170), Vector2.DOWN, 25)
	await _frames(30)
	_check((map.get_node("Encounters/HollowWolves") as Encounter).running, "wolves in the hollow")
	await _shot("09_hollow_wolves")
	_kill_all()
	map.player.global_position = Vector2(110, 290)
	map.player.reset_physics_interpolation()
	await _frames(20)
	await _shot("10_gnawed_roots")
	# back west
	await _walk_to(Vector2(-300, 0), Vector2.LEFT, 0)
	await _await_map(&"whisper_forest")
	_check(map.map_id == &"whisper_forest", "walked back into the Whisper Forest")
	_check(map.player.global_position.distance_to(map.find_spawn(&"from_tangled").global_position) < 1.0, "at the east spawn")
	var warden := map.get_node("Enemies/GroveWarden") as Enemy
	var warden_home := warden.global_position
	map.player.feed_input(InputFrame.new())
	for i in 90:
		await physics_frame
	_check(warden.global_position.distance_to(warden_home) < 2.0, "the Grove Warden stays put on return")
	_check(Interactable.find_active(self) == null, "no interaction prompt at the return spawn")
	await _frames(5)
	await _shot("11_forest_return")
	_log("RESULT: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("roots_m1_visual_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		for path in SaveSlots.all_paths(session.save_path):
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	quit(0 if failures == 0 else 1)


func _finished_prologue() -> Character:
	var character := CharacterFactory.create_new(session.database)
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	StoryService.start(character, QUEST)
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
	camera.zoom = Vector2(2.3, 2.3)
	camera.position = Vector2(0, 70)
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
	var path := OUTPUT.path_join("%s.png" % label)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
	_log("%s %s" % ["PASS" if ok else "FAIL", text])


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)
