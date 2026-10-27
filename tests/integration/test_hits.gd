extends GameplayTestCase
## Hit pipeline: dummy health/poise, revive, iFrames, modifiers, hitstop.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")


class DoubleDamageModifier:
	extends AttackModifier

	func modify_hit(hit: HitData) -> void:
		hit.damage *= 2.0
		hit.tags.append(&"doubled")


func _spawn_dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _swing_light(f: InputFrame) -> void:
	await tick(light(f))
	await tick(f, 24)


func test_dummy_loses_health_per_hit() -> void:
	spawn_legacy_player()
	var dummy := _spawn_dummy(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _swing_light(f)
	var damage := SWORD.get_attack(&"sword_light_1").damage
	check_eq(dummy.hits_taken, 1, "one hit taken")
	check_near(dummy.health.health, dummy.health.max_health - damage, 0.01, "health reduced by attack damage")


func test_one_swing_hits_several_targets_once_each() -> void:
	spawn_legacy_player()
	var upper := _spawn_dummy(Vector2(18, -14))
	var lower := _spawn_dummy(Vector2(18, 14))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _swing_light(f)
	check_eq(upper.hits_taken, 1, "upper dummy hit once")
	check_eq(lower.hits_taken, 1, "lower dummy hit once")


func test_poise_break_staggers_and_recovers() -> void:
	spawn_legacy_player()
	var dummy := _spawn_dummy(Vector2(24, 0))
	await wait_physics(2)
	var broken := [false]
	dummy.health.poise_broken.connect(func() -> void: broken[0] = true)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	# L-L-H crush deals 55 poise; the dummy has 60. Two light hits first (8 each).
	await tick(light(f))
	await tick(f, 12)
	await tick(light(f))
	await tick(f, 12)
	await tick(heavy_down(f))
	await tick(heavy_up(f))
	await tick(f, 30)
	check(broken[0], "poise broken by L-L-H")
	check(dummy.health.is_staggered(), "dummy staggered")
	await tick(f, 70)
	check(not dummy.health.is_staggered(), "stagger ends")
	check_near(dummy.health.poise, dummy.health.max_poise, 0.01, "poise refilled after stagger")


func test_dummy_dies_ignores_hits_and_revives() -> void:
	var dummy := _spawn_dummy(Vector2.ZERO)
	await wait_physics(1)
	var hit := HitData.new()
	hit.damage = 1000.0
	check(dummy.hurtbox.receive_hit(hit), "lethal hit accepted")
	check(dummy.health.is_dead(), "dummy down")
	check(not dummy.hurtbox.receive_hit(HitData.new()), "no hits while down")
	await wait_physics(seconds_to_ticks(dummy.revive_delay) + 2)
	check(not dummy.health.is_dead(), "dummy revived")
	check_near(dummy.health.health, dummy.health.max_health, 0.01, "revived at full health")


func test_dash_iframes_reject_hits() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	check(player.hurtbox.receive_hit(HitData.new()), "hit accepted when not dashing")
	var f := frame(Vector2.RIGHT)
	await tick(dash_press(f))
	check(not player.hurtbox.receive_hit(HitData.new()), "hit rejected during iFrames")
	await tick(f, 11)
	check(player.dash.is_dashing(), "still dashing")
	check(player.hurtbox.receive_hit(HitData.new()), "hit accepted after iFrame window")


func test_modifiers_and_hit_event_hook() -> void:
	spawn_legacy_player()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	player.combat.modifiers.append(DoubleDamageModifier.new())
	var landed: Array[HitData] = []
	player.combat.hit_landed.connect(func(hit: HitData) -> void: landed.append(hit))
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _swing_light(f)
	if check_eq(landed.size(), 1, "hit_landed emitted once"):
		check_near(landed[0].damage, SWORD.get_attack(&"sword_light_1").damage * 2.0, 0.01, "modifier applied")
		check(&"doubled" in landed[0].tags, "modifier tag present")
		check(landed[0].attacker == player, "attacker is the player")


func test_hitstop_is_local_to_attacker_and_target() -> void:
	spawn_legacy_player()
	var target := _spawn_dummy(Vector2(24, 0))
	var bystander: Enemy = load("res://scenes/enemies/grunt.tscn").instantiate()
	bystander.position = Vector2(-150, 0)
	bystander.target = player
	add_child(bystander)
	var hitstop := HitstopController.new()
	add_child(hitstop)
	hitstop.watch(player.combat)
	await wait_physics(2)
	var frozen_on_hit: Array[float] = []
	player.combat.hit_landed.connect(func(_hit: HitData) -> void: frozen_on_hit.append(player.hitstop_left))
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true
	await tick(f)
	while frozen_on_hit.is_empty():
		await tick(f)
	check(frozen_on_hit[0] > 0.0, "attacker frozen by its own heavy hit")
	check(frozen_on_hit[0] <= hitstop.max_hitstop + 0.0001, "hitstop capped")
	check_eq(Engine.time_scale, 1.0, "global time untouched")
	var bystander_start := bystander.global_position
	var phase_time := player.combat.phase_time
	await tick(f, 2)
	check_eq(player.combat.phase_time, phase_time, "attacker combat timers paused while frozen")
	check(bystander.global_position.distance_to(bystander_start) > 1.0, "unrelated enemy keeps moving")
	check(target.hits_taken == 1, "target hit once")
	await tick(f, 20)
	check_eq(player.hitstop_left, 0.0, "hitstop over")


func test_hitstop_requests_do_not_stack() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	player.apply_hitstop(0.08)
	player.apply_hitstop(0.08)
	player.apply_hitstop(0.05)
	check_near(player.hitstop_left, 0.08, 0.0001, "max, not sum")


func test_inputs_during_hitstop_are_kept_and_combo_survives() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 23)   # first light finished, combo window open
	check(player.combat.combo.window_open, "combo window open")
	player.apply_hitstop(0.5)   # much longer than the 0.35 s combo window
	await tick(f, 10)
	await tick(light(f))        # click while frozen
	await tick(f, 25)
	check_eq(player.combat.combo.path, [&"sword_light_1", &"sword_light_2"] as Array[StringName], "click during freeze continued the combo")
