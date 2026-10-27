extends GameplayTestCase
## Bow (Combat Flow 1.5): LMB = Quick Shot (L), LMB while RMB is held = Precision
## Shot (P), RMB alone never shoots; tap combos per unlock level; Flowing Draw
## from mastery 10 (hold >= 250 ms, the first shot counts as shot 1, three shots,
## mandatory closing recovery, next cycle only while still held, release stops);
## taps are never reclassified as Flowing Draw; arrows leave only at the fire
## event and survive RMB changes; Precision Stance walks at 65 %.

const UNLOCKS := {"LL": 2, "LP": 4, "PL": 6, "LLP": 9, "PLP": 14, "LPL": 17, "PLLP": 20}

var bow: WeaponFamily
var fired: Array[StringName] = []


func before_each() -> void:
	super.before_each()
	bow = GameDatabase.get_default().weapons[&"bow"]
	fired.clear()
	started_attacks.clear()


func _spawn(level: int) -> void:
	spawn_player()
	player.set_weapon_family(bow)
	player.combat.mastery_level = level
	track_player_attacks()
	player.combat.projectile_fired.connect(func(attack: AttackDefinition, _projectile: Node2D) -> void: fired.append(attack.id))


func _despawn() -> void:
	player.queue_free()
	await get_tree().physics_frame


## One tick with LMB / RMB levels; `press` = new LMB down edge this tick.
func _t(lmb: bool, rmb: bool, press: bool = false, rmb_press: bool = false, count: int = 1) -> void:
	var f := frame()
	f.light_held = lmb
	f.heavy_held = rmb
	f.light_pressed = press
	f.heavy_pressed = rmb_press
	await tick(f)
	if count > 1:
		f.light_pressed = false
		f.heavy_pressed = false
		await tick(f, count - 1)


func _idle_until_neutral() -> void:
	var guard := 0
	while player.combat.is_busy() and guard < 400:
		await _t(false, false)
		guard += 1


func test_quick_precision_and_rmb_only() -> void:
	_spawn(1)
	await _t(false, true, false, true, 30)
	check_eq(started_attacks.size(), 0, "RMB alone: Precision Stance, no attack")
	check(player.combat.in_precision_stance(), "stance active while RMB is held")
	await _t(true, true, true)
	check_eq(player.combat.current_attack.combo_input, "P", "LMB while RMB held = Precision Shot")
	check_eq(fired.size(), 0, "no arrow during the windup")
	await _idle_until_neutral()
	check_eq(fired, [bow.node("P").id] as Array[StringName], "one arrow at the fire event")
	await _t(true, false, true)
	check_eq(player.combat.current_attack.combo_input, "L", "LMB without RMB = Quick Shot")
	await _t(false, true, false, true)   # RMB down during the quick shot
	await _idle_until_neutral()
	check_eq(started_attacks.size(), 2, "an RMB change during a shot starts no second attack")
	check_eq(fired.size(), 2, "and removes no arrow")


func test_tap_combos_follow_unlock_levels() -> void:
	for path: String in UNLOCKS:
		for level in [UNLOCKS[path] - 1, UNLOCKS[path]]:
			_spawn(level)
			await perform_path(path)
			var full := started_attacks.size() == path.length()
			check_eq(full, level >= int(UNLOCKS[path]), "%s at level %d: %s" % [path, level, "runs" if full else "stops"])
			if full:
				check_eq(started_attacks.back(), bow.node(path).id, "%s ends on %s" % [path, bow.node(path).display_name])
				check_eq(fired.size(), path.length(), "%s: one arrow per shot" % path)
			fired.clear()
			started_attacks.clear()
			await _despawn()


func test_level_one_tap_fires_once_per_press() -> void:
	_spawn(9)
	await _t(true, false, true)
	await _t(true, false, false, false, 90)   # held 1.5 s below level 10
	await _idle_until_neutral()
	check_eq(started_attacks.size(), 1, "holding below level 10: exactly one Quick Shot")
	check(not player.combat.flowing_draw, "no Flowing Draw before level 10")


func test_flowing_draw_cycle() -> void:
	_spawn(10)
	await _t(true, false, true)
	await _t(true, false, false, false, 10)   # 167 ms: below the threshold
	check(not player.combat.flowing_draw, "below 250 ms: not yet")
	await _t(true, false, false, false, 6)    # 267 ms
	check(player.combat.flowing_draw, "held past 250 ms: Flowing Draw")
	check_eq(started_attacks.size(), 1, "the first Quick Shot is shot 1 (not fired twice)")
	var guard := 0
	while started_attacks.size() < 3 and guard < 200:
		await _t(true, false)
		guard += 1
	check_eq(started_attacks.size(), 3, "shots 2 and 3 follow automatically")
	check(player.combat.final_recovery, "shot 3 closes with a full recovery")
	var recovery_end := 0
	guard = 0
	while started_attacks.size() == 3 and guard < 200:
		await _t(true, false)
		guard += 1
		recovery_end += 1
	var shot := bow.node("L")
	var full_shot_ticks := seconds_to_ticks(shot.startup + shot.active + shot.recovery)
	check(recovery_end >= full_shot_ticks - 1, "next cycle only after shot 3's complete recovery (%d ticks >= %d)" % [recovery_end, full_shot_ticks - 1])
	check_eq(started_attacks.size(), 4, "still held: the next three-shot cycle starts")
	await _t(false, false)   # release
	await _idle_until_neutral()
	await _t(false, false, false, false, 60)
	check_eq(started_attacks.size(), 4, "release: no further automatic shots, the running one ended regularly")
	await _t(false, false, false, false, 2)
	check_eq(fired.size(), 4, "one arrow per shot")


func test_rmb_ends_flowing_draw_without_a_precision_shot() -> void:
	_spawn(20)
	await _t(true, false, true)
	await _t(true, false, false, false, 20)
	check(player.combat.flowing_draw, "flowing")
	await _t(true, true, false, true)
	check(not player.combat.flowing_draw, "RMB (Precision Stance) ends the automatic sequence")
	await _t(true, true, false, false, 80)
	check_eq(started_attacks.size(), 1, "no automatic P and no further shot")


func test_taps_are_never_flowing_draw() -> void:
	_spawn(20)
	await _t(true, false, true, false, 6)     # 100 ms tap
	await _t(false, false)
	var f := frame()
	var guard := 0
	while player.combat.attack_clock() < player.combat.accept_from() and guard < 100:
		await _t(false, false)
		guard += 1
	await _t(true, false, true, false, 40)    # second press held long: still a manual L-L
	await _t(false, false)
	await _idle_until_neutral()
	check_eq(started_attacks, [bow.node("L").id, bow.node("LL").id] as Array[StringName], "separate presses = Twin Arrow, never reclassified")
	check(not player.combat.flowing_draw, "a held second press starts no Flowing Draw")
	await tick(f)


func test_precision_stance_walks_slower() -> void:
	_spawn(1)
	var f := frame(Vector2.DOWN)
	await tick(f, 6)
	check_near(player.velocity.y, 180.0, 1.0, "full speed")
	f.heavy_held = true
	f.heavy_pressed = true
	await tick(f, 6)
	check_near(player.velocity.y, 180.0 * 0.65, 1.0, "Precision Stance: 65 %")


func test_arrows_survive_a_dash_cancel() -> void:
	_spawn(1)
	add_target(Vector2(200, 0), 10.0)
	await _t(true, false, true)
	var guard := 0
	while fired.is_empty() and guard < 60:
		await _t(false, false)
		guard += 1
	while not player.combat.can_dash_cancel() and guard < 120:
		await _t(false, false)
		guard += 1
	await tick(dash_press(frame()))
	check(player.dash.is_dashing(), "dash cancelled the recovery")
	await _t(false, false, false, false, 40)
	check_eq(hits.size(), 1, "the arrow already in flight still hits")
