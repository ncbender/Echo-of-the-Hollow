extends SceneTree
## Whisper Forest – Placed Enemy Target Fix 1.0, functional check in a real window (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/forest_target_visual_check.gd
## Calm at the Haven entrance; a placed grunt closes in and hits; the Grove Warden telegraphs and hits;
## the Warden stays calm at the east exit; the east exit still leads on. Logs movement, attack starts and
## player HP (a target alone is no proof of an attack). Fresh test characters, saves only under
## user://test_saves/. Screenshots and log: tests/output/forest_targets/.

const OUTPUT := "res://tests/output/forest_targets"
const GRUNTS: Array[String] = ["Enemies/GruntA", "Enemies/GruntB", "Enemies/GruntC"]

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/forest_targets_visual/slot_1.save.json"
	session.settings.set_reduce_motion(true)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	# 1. the Haven entrance stays calm
	session.set_character(CharacterFactory.create_new(session.database))
	await _open(&"whisper_forest", &"from_home")
	var starts := {}
	for path in GRUNTS + ["Enemies/GroveWarden"]:
		starts[path] = (map.get_node(path) as Enemy).global_position
	_place(map.find_spawn(&"from_home").global_position)
	await _physics(120)
	var moved := 0.0
	for path in starts:
		moved = maxf(moved, (map.get_node(path) as Enemy).global_position.distance_to(starts[path]))
	_log("measured entrance: largest enemy movement in 2 s = %.2f px, player HP %.0f/%.0f" % [moved, map.player.health.health, map.player.health.max_health])
	_check(moved < 0.5, "calm at the Haven entrance")
	await _shot("01_entrance_calm")
	# 2. a placed grunt closes in and hits
	var grunt := map.get_node("Enemies/GruntB") as Enemy
	var grunt_start := grunt.global_position
	_place(grunt.global_position + Vector2(-120, 0))
	var hp := map.player.health.health
	await _physics(25)
	await _shot("02a_grunt_closing_in")
	var attacked := false
	for i in 240:
		await physics_frame
		if grunt.combat.state == CombatComponent.State.ATTACKING:
			attacked = true
			break
	await _physics(12)
	await _shot("02b_grunt_telegraph")
	await _physics(80)
	await _shot("02c_grunt_after_hit")
	_log("measured grunt: moved %.1f px, attack started %s, player HP %.0f -> %.0f" % [grunt.global_position.distance_to(grunt_start), attacked, hp, map.player.health.health])
	_check(attacked and map.player.health.health < hp, "the grunt really attacks and hits")
	# 3. the Grove Warden telegraphs and hits (grunts removed so only the Warden fights)
	for path in GRUNTS:
		(map.get_node(path) as Enemy).queue_free()
	map.player.health.reset()
	var warden := map.get_node("Enemies/GroveWarden") as Enemy
	_place(warden.global_position + Vector2(-60, -20))
	hp = map.player.health.health
	attacked = false
	for i in 240:
		await physics_frame
		if warden.combat.state == CombatComponent.State.ATTACKING:
			attacked = true
			break
	await _physics(15)
	await _shot("03a_warden_telegraph")
	await _physics(80)
	await _shot("03b_warden_after_hit")
	_log("measured warden: attack started %s, player HP %.0f -> %.0f" % [attacked, hp, map.player.health.health])
	_check(attacked and map.player.health.health < hp, "the Grove Warden really attacks and hits")
	# 4. calm at the east exit after the prologue, exit still usable
	session.set_character(_after_prologue())
	await _open(&"whisper_forest", &"from_home")
	for path in GRUNTS:
		(map.get_node(path) as Enemy).queue_free()
	warden = map.get_node("Enemies/GroveWarden") as Enemy
	var home := warden.global_position
	_place(Vector2(290, -156))
	await _physics(120)
	_log("measured east exit: player %.0f px from the Warden (aggro %.0f), Warden moved %.2f px, state %s"
		% [Vector2(290, -156).distance_to(home), warden.config.aggro_range, warden.global_position.distance_to(home), warden.combat.state])
	_check(warden.global_position.distance_to(home) < 0.5, "the Warden stays calm at the east exit")
	await _shot("04_east_exit_warden_calm")
	var input := InputFrame.new()
	input.move = Vector2.RIGHT
	map.player.feed_input(input)
	var start := map
	for i in 300:
		await physics_frame
		if current_scene != start:
			break
	await _await_map(&"tangled_wood")
	_check(map.map_id == &"tangled_wood", "the east exit still leads into the Tangled Wood")
	await _shot("05_tangled_wood_reached")
	_log("RESULT: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("forest_targets_visual_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		for path in SaveSlots.all_paths(session.save_path):
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	quit(0 if failures == 0 else 1)


func _after_prologue() -> Character:
	var character := CharacterFactory.create_new(session.database)
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	StoryService.start(character, &"the_first_signs")
	return character


func _place(at: Vector2) -> void:
	map.player.feed_input(InputFrame.new())
	map.player.global_position = at
	map.player.reset_physics_interpolation()


func _open(map_id: StringName, spawn_id: StringName) -> void:
	session.travel(map_id, spawn_id, false)
	await _await_map(map_id)


func _await_map(map_id: StringName) -> void:
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			break
	await _physics(5)


func _physics(count: int) -> void:
	for i in count:
		await physics_frame


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
