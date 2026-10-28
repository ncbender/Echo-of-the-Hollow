extends SceneTree
## Chapter 1 "The Roots Remember" M3 visual check in a real window (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/roots_m3_visual_check.gd
## 1920x1080 at 100 % and 1280x720 at 150 % UI scale: the Chapel's opened east way, the walk into
## Warden's Rest, an overview, the Rootbound Sentinel's slam as a frame sequence (windup braced,
## active, recovery exposed) with measured frame counts, a light strike, the find after the defeat,
## the tracker, the optional tally and the walk back. Fresh test characters (the_first_signs at
## step 3), saves only under user://test_saves/. Screenshots and log: tests/output/roots_m3/.

const OUTPUT := "res://tests/output/roots_m3"
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
	session.save_path = "user://test_saves/roots_m3_visual/slot_1.save.json"
	for pass_spec: Array in PASSES:
		await _pass(pass_spec[0], pass_spec[1])
	session.settings.reset_to_defaults()
	_log("RESULT: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("roots_m3_visual_log.txt"), FileAccess.WRITE)
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
	var character := _character_at_step_3()
	session.set_character(character)
	# the Chapel's opened east way
	await _open(&"chapel", &"from_wardens_rest")
	await _frames(15)
	_check(Interactable.find_active(self) == null, "no prompt at the chapel's east spawn")
	await _shot("01_chapel_east_way_open")
	await _walk_to(Vector2(290, -162), Vector2.RIGHT, 0)
	await _await_map(&"wardens_rest")
	_check(map.map_id == &"wardens_rest" and StoryService.at_step(character, QUEST, 4), "walked into Warden's Rest, step 4")
	await _frames(15)
	await _shot("02_rest_arrival")
	await _overview("03_rest_overview")
	var sentinel := map.get_node("Enemies/RootboundSentinel") as Enemy
	var view := sentinel.get_node("View")
	_check(sentinel.target == map.player, "the Sentinel targets the player")
	# the slam as a frame sequence
	_check(await _provoke(sentinel, true), "the slam starts")
	var startup := 0
	var braced := true
	var shots := {5: "04a_windup_start", 30: "04b_windup_mid", 55: "04c_windup_late"}
	while sentinel.combat.state == CombatComponent.State.ATTACKING and sentinel.combat.phase == CombatComponent.Phase.STARTUP:
		startup += 1
		braced = braced and sentinel.is_braced()
		if shots.has(startup):
			await _shot(shots[startup])
		await physics_frame
	_log("measured %s: slam windup %d frames, braced throughout: %s" % [_tag, startup, braced])
	_check(startup >= 54 and startup <= 66 and braced, "windup about 1 s, braced")
	if sentinel.combat.phase == CombatComponent.Phase.ACTIVE:
		await _shot("05_slam_active")
	while sentinel.combat.phase == CombatComponent.Phase.ACTIVE:
		await physics_frame
	var at := sentinel.global_position
	var recovery := 0
	var exposed := true
	while sentinel.combat.state == CombatComponent.State.ATTACKING and sentinel.combat.phase == CombatComponent.Phase.RECOVERY:
		recovery += 1
		exposed = exposed and view.is_exposed()
		if recovery == 10:
			await _shot("06a_recovery_start")
		if recovery == 60:
			await _shot("06b_recovery_late")
		await physics_frame
	var moved := sentinel.global_position.distance_to(at)
	_log("measured %s: recovery %d frames, exposed throughout: %s, moved %.2f px" % [_tag, recovery, exposed, moved])
	_check(recovery >= 72 and recovery <= 84 and exposed and moved < 1.0, "recovery about 1.3 s, exposed, standing still")
	_check(await _provoke(sentinel, false), "the strike starts")
	await _frames(12)
	_check(not sentinel.is_braced(), "the strike is not braced")
	await _shot("07_strike_windup")
	# the defeat and the find
	map.player.global_position = Vector2(110, -70)
	map.player.reset_physics_interpolation()
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	sentinel.health.apply_hit(lethal)
	await _frames(60)
	var stone := map.get_node("AfterSentinel/SplitWatchstone") as Readable
	_check(stone.is_visible_in_tree(), "the find appears after the defeat")
	map.player.global_position = Vector2(110, -66)
	map.player.reset_physics_interpolation()
	await _frames(10)
	_check(Interactable.find_active(self) == stone, "standing at the find")
	await _shot("08_find_after_defeat")
	stone.interact(map.hud)
	await _frames(20)
	await _shot("09_find_text")
	map.hud.close_windows()
	await _frames(10)
	_check(StoryService.at_step(character, QUEST, 5), "step 5")
	await _shot("10_tracker_step5")
	# optional tally in the hut
	map.player.global_position = Vector2(280, -165)
	map.player.reset_physics_interpolation()
	await _frames(15)
	_check(Interactable.find_active(self) == map.get_node("ScratchedTally"), "the tally in the hut")
	await _shot("11_hut_tally")
	# back west
	await _walk_to(Vector2(-300, 0), Vector2.LEFT, 0)
	await _await_map(&"chapel")
	_check(map.map_id == &"chapel" and map.player.global_position.distance_to(map.find_spawn(&"from_wardens_rest").global_position) < 1.0,
		"back at the chapel's east way")
	await _frames(15)
	await _shot("12_back_in_the_chapel")


func _character_at_step_3() -> Character:
	var character := CharacterFactory.create_new(session.database)
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	StoryService.start(character, QUEST)
	for event: StringName in [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone"]:
		StoryService.notify(character, event)
	for flag: StringName in [&"read.tangled_twisted_roots", &"read.chapel_old_stone"]:
		character.world.set_flag(flag)
	return character


func _provoke(sentinel: Enemy, heavy: bool) -> bool:
	map.player.feed_input(InputFrame.new())
	map.player.global_position = sentinel.global_position + Vector2(0, 26)
	map.player.reset_physics_interpolation()
	sentinel._attacks_started = 1 if heavy else 0
	sentinel._cooldown = 0.0
	for i in 120:
		await physics_frame
		if sentinel.combat.state == CombatComponent.State.ATTACKING:
			return (sentinel.combat.current_attack.input_type == AttackDefinition.InputType.HEAVY) == heavy
	return false


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


func _overview(label: String) -> void:
	var camera := Camera2D.new()
	var size := Vector2(root.size)
	var fit := minf(size.x / 700.0, size.y / 450.0)
	camera.zoom = Vector2(fit, fit)
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
