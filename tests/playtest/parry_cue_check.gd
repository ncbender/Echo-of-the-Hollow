extends SceneTree
## Parry Timing Cue 1.0 window check (NOT headless, 1920 x 1080, 100 % UI): short real attack sequences in motion - a
## Hardened Husk (swipe cued, slam not), a Rootbound Sentinel (strike cued), a normal grunt (never cued) - captured as
## frame sequences (every 2nd frame) around the cue, plus the player parrying REACTION s after the cue.
##   godot --path . -s res://tests/playtest/parry_cue_check.gd
## Output: tests/output/parry_cue/<enemy>_<nn>.png and a log of cue / press / parry frames.

const OUTPUT := "res://tests/output/parry_cue"

var session: SessionState
var map: GameMap
var checks: int = 0
var failures: int = 0


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
	var character := CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	session.set_character(character)
	change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 300:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 10:
		await process_frame
	map.player.health.max_health = 99999.0
	map.player.health.health = 99999.0
	await _sequence("husk", load("res://data/enemies/hardened_husk.tres"), null, 2, true)
	await _sequence("sentinel", load("res://data/enemies/rootbound_sentinel.tres"), load("res://data/enemies/sentinel_attacks.tres"), 1, true)
	await _sequence("grunt", load("res://data/enemies/grunt_config.tres"), null, 1, false)
	print("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


## `attacks` attacks of one enemy next to the player; frames saved around every windup; the player presses Shift
## ParryCue.REACTION s after each cue (real input path: the player's own InputFrame).
func _sequence(label: String, config: EnemyConfig, attacks: WeaponFamily, count: int, expect_cue: bool) -> void:
	var player := map.player
	player.global_position = Vector2(-40, 40)
	var enemy := map.spawn_enemy(player.global_position + Vector2(24, 0), config, attacks)
	var view := enemy.get_node("View") as EnemyView
	var parried := [0]
	var on_parry := func(_hit: HitData) -> void: parried[0] += 1
	player.defense.parried.connect(on_parry)
	var shot := 0
	var started := 0
	var last_instance := -1
	var press_at := -1
	var frame_index := 0
	var cues_seen := 0
	for i in 600:
		var f := InputFrame.new()
		f.aim_direction = Vector2.RIGHT
		if press_at >= 0 and frame_index >= press_at and frame_index < press_at + 3:
			f.defend_pressed = frame_index == press_at
			f.defend_held = true
		player.feed_input(f)
		await physics_frame
		await process_frame
		frame_index += 1
		if enemy.combat.state == CombatComponent.State.ATTACKING and enemy.combat.attack_instance != last_instance:
			last_instance = enemy.combat.attack_instance
			started += 1
			print("%s frame %d: attack %s starts" % [label, frame_index, enemy.combat.current_attack.id])
		if view.cue_count > cues_seen:
			cues_seen = view.cue_count
			press_at = frame_index + roundi(ParryCue.REACTION * 60.0)
			print("%s frame %d: cue (%.3f s to the hit), Shift at frame %d" % [label, frame_index, ParryCue.time_to_hit(enemy.combat), press_at])
		if enemy.state == Enemy.State.TELEGRAPH or view.cue_visible() or (enemy.combat.phase == CombatComponent.Phase.ACTIVE and enemy.combat.state == CombatComponent.State.ATTACKING):
			if frame_index % 2 == 0 and shot < 80:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().get_region(Rect2i(760, 380, 400, 300)).save_png(ProjectSettings.globalize_path(OUTPUT.path_join("%s_%02d.png" % [label, shot])))
				shot += 1
		if started > count and enemy.combat.state != CombatComponent.State.ATTACKING:
			break
	player.defense.parried.disconnect(on_parry)
	_check((cues_seen > 0) == expect_cue, "%s: cue %s (%d)" % [label, "shown" if expect_cue else "never shown", cues_seen])
	if expect_cue:
		_check(parried[0] >= 1, "%s: Shift %.2f s after the cue parried (%d)" % [label, ParryCue.REACTION, parried[0]])
	print("%s: %d frames saved" % [label, shot])
	enemy.queue_free()
	for i in 20:
		await process_frame


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s %s" % ["CHECK OK  " if ok else "CHECK FAIL", text])
