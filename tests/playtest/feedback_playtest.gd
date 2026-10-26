extends SceneTree
## Visual integration test of Combat Defense & Feedback 0.4 (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/feedback_playtest.gd
## In the arena: skill VFX of all three classes, parry and block against real
## grunt attacks, the unblockable telegraph, arcane marks / detonation / chill,
## weak point / execution, bleeding, poise break, six enemies at once (frame
## time), effect cleanup, a scene change, and the audio cues that played.
## Screenshots and log: tests/output/feedback/.

const OUTPUT := "res://tests/output/feedback"

var session: SessionState
var map: GameMap
var input := InputFrame.new()
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/feedback_playtest.save.json"
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	await _feedback()
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("feedback_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _feedback() -> void:
	var character := CharacterFactory.create_new(session.database)
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		character.classes.unlock(class_id)
		character.classes.add_xp(class_id, 1500)
	character.classes.set_active(&"warrior")
	session.set_character(character)
	change_scene_to_file("res://scenes/arena/test_arena.tscn")
	await _wait_map(&"test_arena")
	var player := map.player
	player.feed_input(input)
	var audio := current_scene.get_node("CombatAudio") as CombatAudio
	var runtime := map.bridge.class_runtime
	var build := func() -> ClassBuild: return character.builds.get_build()

	# Warrior: rage aura, rush impact, slam sparks
	player.global_position = Vector2(-40, 150)
	var target := _grunt(Vector2(60, 150))
	await _wait(6)
	runtime.pool.gain(100.0)
	await _press(build.call().slot_of(&"battle_cry"), 6)
	_check(_fx(CombatFx.Style.AURA) == 1, "warrior: Battle Cry aura")
	await _wait(25)
	await _press(build.call().slot_of(&"blade_rush"), 15)   # ~86 px at 500 px/s: arrival after ~10 ticks
	await _shot("01_warrior_blade_rush")
	_check(_fx(CombatFx.Style.CROSS) >= 1, "warrior: Blade Rush impact cross")
	await _wait(30)
	runtime.pool.gain(100.0)
	await _press(build.call().slot_of(&"warbreaker"), 6)
	await _shot("02_warrior_warbreaker")
	_check(&"warrior_skill" in audio.played and &"hit_heavy" in audio.played, "warrior skill and impact sounds")
	target.queue_free()
	await _wait(40)

	# Parry and block against a real attacking grunt
	player.global_position = Vector2(0, 150)
	var attacker := _grunt(Vector2(26, 150), null, true)
	attacker.config.heavy_attack_interval = 0
	input.aim_direction = Vector2.RIGHT
	var parried := false
	for i in 400:
		input.defend_held = false
		var c := attacker.combat
		if c.state == CombatComponent.State.ATTACKING and c.phase == CombatComponent.Phase.STARTUP \
				and c.current_attack.startup - c.phase_time <= 4.0 / 60.0 and player.defense.state == DefenseComponent.State.IDLE:
			input.defend_pressed = true
			input.defend_held = true
		await physics_frame
		if player.defense.last_outcome == DefenseComponent.Outcome.PARRIED:
			parried = true
			break
	await _wait(3)
	await _shot("03_parry")
	_check(parried and &"parry" in audio.played, "real grunt swipe parried (PARRY + sound)")
	var blocked := false
	for i in 300:
		input.defend_held = true
		if player.defense.state == DefenseComponent.State.IDLE:
			input.defend_pressed = true
		await physics_frame
		if player.defense.last_outcome == DefenseComponent.Outcome.BLOCKED:
			blocked = true
			break
	await _shot("04_block")
	input.defend_held = false
	_check(blocked and &"block" in audio.played, "real grunt swipe blocked (block sound)")
	attacker.queue_free()
	await _wait(30)

	# Unblockable telegraph (Grove Warden slam data)
	var warden := _grunt(Vector2(60, 150), load("res://data/enemies/grove_warden_attacks.tres"), true)
	warden.config.heavy_attack_interval = 1
	warden.config.attack_range = 70.0
	var warned := false
	for i in 240:
		await physics_frame
		if warden.state == Enemy.State.TELEGRAPH and warden.combat.current_attack.is_unblockable():
			warned = true
			break
	await _wait(10)
	await _shot("05_unblockable_telegraph")
	_check(warned and &"unblockable_warn" in audio.played, "unblockable telegraph + warning sound")
	warden.queue_free()
	player.health.reset()
	await _wait(30)

	# Arcanist: one rune per mark, detonation, chill
	character.classes.set_active(&"arcanist")
	await _wait(4)
	runtime = map.bridge.class_runtime
	player.global_position = Vector2(-60, 150)
	var marked := _grunt(Vector2(-20, 150))
	await _wait(6)
	await _press(build.call().slot_of(&"arcane_bolt"), 30)
	await _press(build.call().slot_of(&"arcane_bolt"), 30)
	_check(StatusComponent.of(marked).stacks(&"arcane_mark") == 2, "two arcane marks (two runes)")
	await _shot("06_arcane_marks")
	await _press(build.call().slot_of(&"mana_pulse"), 4)
	await _shot("07_detonation")
	_check(&"arcane_detonate" in audio.played and not StatusComponent.of(marked).has(&"arcane_mark"), "detonation: sound, marks gone")
	await _wait(30)
	await _press(build.call().slot_of(&"frostbind"), 25)
	await _shot("08_chill")
	_check(StatusComponent.of(marked).has(&"chill"), "chill marker")
	marked.queue_free()
	await _wait(30)

	# Shadowrunner: afterimages, reticle, execution; bleeding; poise break
	character.classes.set_active(&"shadowrunner")
	await _wait(4)
	runtime = map.bridge.class_runtime
	runtime.pool.gain(100.0)
	player.global_position = Vector2(-80, 150)
	var prey := _grunt(Vector2(40, 150))
	await _wait(6)
	await _press(build.call().slot_of(&"shadowstep"), 5)
	await _shot("09_shadowstep")
	await _wait(15)
	_check(StatusComponent.of(prey).has(&"weak_point"), "weak point reticle after Shadowstep")
	await _shot("10_weak_point")
	runtime.pool.gain(100.0)
	await _press(build.call().slot_of(&"execution"), 4)
	await _shot("11_execution")
	_check(&"execution" in audio.played and not StatusComponent.of(prey).has(&"weak_point"), "execution consumed the weak point (sound)")
	map.bridge.apply_status(prey, &"bleeding", 1.0, 3)
	await _wait(20)
	await _shot("12_bleeding")
	var breaker := HitData.new()
	breaker.poise_damage = 100000.0
	prey.hurtbox.receive_hit(breaker)
	await _wait(3)
	await _shot("13_poise_break")
	_check(&"poise_break" in audio.played, "poise break sound")
	prey.queue_free()

	# Six enemies with effects: frame time
	var crowd: Array[Enemy] = []
	for i in 6:
		crowd.append(_grunt(Vector2(-60 + 20 * i, 120 + 15 * (i % 2))))
	player.global_position = Vector2(-90, 125)
	await _wait(6)
	var start := Time.get_ticks_usec()
	for i in 4:
		runtime.pool.gain(100.0)
		runtime.cooldowns.clear()
		await _press(build.call().slot_of(&"expose_weakness"), 8)
		input.light_pressed = true
		await _wait(15)
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / 92.0
	await _shot("14_crowd")
	_check(ms < 34.0, "six enemies with effects: %.1f ms per frame" % ms)
	for grunt in crowd:
		grunt.queue_free()
	await _wait(90)
	_check(_fx(-1) <= _fx(CombatFx.Style.AURA), "all one-shot effects cleaned up")
	_log("audio cues: %s" % [audio.played])

	# Scene change: nothing survives
	session.travel(&"home_base", &"from_arena", false)
	await _wait_map(&"home_base")
	_check(_fx(-1) == 0, "no effects after a scene change")
	player = map.player
	player.use_external_input = false


func _grunt(at: Vector2, attacks: WeaponFamily = null, attacking: bool = false) -> Enemy:
	var grunt := map.spawn_enemy(at)
	if attacks != null:
		grunt.attacks = attacks
		grunt.combat.set_weapon(attacks)
	grunt.config = grunt.config.duplicate()
	grunt.config.move_speed = 0.0
	grunt.config.attack_range = 40.0 if attacking else 0.0
	grunt.health.max_health = 100000.0
	grunt.health.reset()
	return grunt


## Skill slot press (the player consumes edge flags itself).
func _press(slot: int, wait: int) -> void:
	input.aim_direction = Vector2.RIGHT
	input.ability_slot = slot
	await _wait(wait)


func _fx(style: int) -> int:
	return current_scene.find_children("*", "CombatFx", true, false).filter(func(fx: CombatFx) -> bool:
		return style < 0 or fx.style == style).size()


func _wait(ticks: int) -> void:
	for i in ticks:
		await physics_frame


func _wait_map(map_id: StringName) -> void:
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			break
	for i in 10:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s.png" % label)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	_log(("PASS " if ok else "FAIL ") + text)


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)
