extends GameplayTestCase
## Combat Flow 1.5 on the real player (data families): defensive cancel windows
## (dash / parry refused before them, nothing stored, no charge spent), walking
## share per family and phase, burden on the recovery only with dash and parry
## unchanged, attack movement against walls, side steps, aim fixed per step,
## skills / drinks only in neutral, stun / UI clear the buffer.

var db: GameDatabase


func before_each() -> void:
	super.before_each()
	db = GameDatabase.get_default()
	hits.clear()
	started_attacks.clear()


func family(id: StringName) -> WeaponFamily:
	return db.weapons[id]


func _spawn(id: StringName = &"one_handed_sword", level: int = 20) -> void:
	spawn_player()
	player.set_weapon_family(family(id))
	player.combat.mastery_level = level
	track_player_attacks()


func _press(symbol: String, move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.RIGHT) -> InputFrame:
	var f := frame(move, aim)
	if symbol == "L":
		f.light_pressed = true
	elif symbol == "H":
		f.heavy_pressed = true
	return f


func _until(condition: Callable, f: InputFrame, limit: int = 240) -> void:
	var guard := 0
	while not condition.call() and guard < limit:
		await tick(f)
		guard += 1


func test_dash_refused_until_the_cancel_window_and_never_stored() -> void:
	_spawn()
	await tick(_press("L"))
	var charges := player.dash.charges
	var f := frame()
	await tick(dash_press(frame()))
	check(not player.dash.is_dashing(), "windup is committed: no dash")
	check_eq(player.dash.charges, charges, "no charge spent")
	await _until(func() -> bool: return player.combat.phase == CombatComponent.Phase.ACTIVE, f)
	await tick(dash_press(frame()))
	check(not player.dash.is_dashing(), "active is committed: no dash")
	await _until(func() -> bool: return player.combat.can_dash_cancel(), f)
	await tick(f, 3)
	check(not player.dash.is_dashing(), "no phantom dash from the early presses when the window opens")
	await tick(dash_press(frame()))
	check(player.dash.is_dashing(), "dash inside the window (50 % of the quick recovery)")
	check_eq(player.combat.state, CombatComponent.State.IDLE, "the attack ended")
	check_eq(player.combat.buffered, "", "and its buffer")


func test_parry_follows_the_same_window() -> void:
	_spawn()
	await tick(_press("H"))
	var f := frame()
	var shift := frame()
	shift.defend_pressed = true
	shift.defend_held = true
	await tick(shift)
	check(not player.defense.is_defending(), "no parry in the heavy windup")
	var held := frame()
	held.defend_held = true
	await _until(func() -> bool: return player.combat.can_dash_cancel(), held)
	await tick(held, 2)
	check(not player.defense.is_defending(), "holding Shift from before the window starts nothing")
	var recovery := player.combat.current_attack.recovery * player.combat.recovery_multiplier
	check(player.combat.phase_time >= recovery * 0.65 - 0.02, "heavy window opens at 65 % of the recovery")
	shift = frame()
	shift.defend_pressed = true
	shift.defend_held = true
	await tick(shift)
	check(player.defense.is_defending(), "a new press inside the window parries")
	check_eq(player.combat.state, CombatComponent.State.IDLE, "the defense cancelled the attack")
	await tick(f)


func test_dash_values_and_parry_window_unchanged_by_burden() -> void:
	_spawn()
	var config := player.dash.config
	player.combat.recovery_multiplier = 1.08
	player.move_speed_multiplier = 0.92
	var start := player.global_position
	await tick(dash_press(frame()))
	check(player.dash.is_invulnerable(), "iFrames at dash start")
	await tick(frame(), 30)
	check_near(player.global_position.distance_to(start), config.distance, 3.0, "dash distance unchanged under Heavy burden")
	check_eq(config.max_charges, 2, "two charges")
	check_near(config.iframe_duration, 0.18, 0.0001, "180 ms iFrames")
	check_near(config.recharge_time, 2.5, 0.0001, "2.5 s recharge")
	var profile := player.defense.profile()
	check_near(profile.parry_window, family(&"one_handed_sword").defense_profile.parry_window, 0.0001, "parry window unchanged")


func test_burden_table_matches_the_design() -> void:
	var rules := db.rules.armor_rules()
	check_eq(Array(rules.tier_starts), [15, 26, 38], "Light 0-14, Balanced 15-25, Burdened 26-37, Heavy 38+")
	check_eq(Array(rules.tier_move_penalty), [0.0, 2.0, 5.0, 8.0], "walking 100 / 98 / 95 / 92 %")
	check_eq(Array(rules.tier_recovery_penalty), [0.0, 2.0, 5.0, 8.0], "recovery x1.00 / 1.02 / 1.05 / 1.08")
	for tier in 4:
		_spawn()
		var recovery := 1.0 + rules.tier_recovery_penalty[tier] / 100.0
		player.combat.recovery_multiplier = recovery
		await tick(_press("L"))
		var timing := family(&"one_handed_sword").node("L")
		check_near(player.combat.transition_time(), timing.startup + timing.active + timing.recovery * recovery * 0.75, 0.0001, "tier %d: transition on the lengthened recovery" % tier)
		check_near(player.combat.defense_cancel_time(), timing.startup + timing.active + timing.recovery * recovery * 0.5, 0.0001, "tier %d: cancel window on the lengthened recovery" % tier)
		player.queue_free()
		await get_tree().physics_frame


func test_walking_share_per_family_and_phase() -> void:
	for id: StringName in [&"dagger", &"one_handed_sword", &"spear", &"axe", &"mace", &"two_handed_sword", &"staff", &"wand", &"bow"]:
		for symbol in ["L", "P" if family(id).is_bow() else "H"]:
			_spawn(id, 1)
			var attack := family(id).node(symbol)
			var base := player.movement.config.move_speed
			var f := frame(Vector2.DOWN)
			await tick(f, 6)   # full walking speed
			var press := _press("L" if symbol != "H" else "H", Vector2.DOWN)
			if symbol == "P":
				press.heavy_held = true
				f.heavy_held = true
			await tick(press)
			await tick(f, 3)
			var stance := 0.65 if symbol == "P" else 1.0
			check_near(player.velocity.y, base * attack.windup_move * stance, 1.5, "%s %s windup %d %%" % [id, symbol, roundi(attack.windup_move * 100)])
			await _until(func() -> bool: return player.combat.phase == CombatComponent.Phase.ACTIVE, f)
			await tick(f)
			if player.combat.phase == CombatComponent.Phase.ACTIVE:
				check_near(player.velocity.y, base * attack.active_move * stance, 1.5, "%s %s active %d %%" % [id, symbol, roundi(attack.active_move * 100)])
			await _until(func() -> bool: return player.combat.phase == CombatComponent.Phase.RECOVERY, f)
			await tick(f)
			check_near(player.velocity.y, base * attack.windup_move * stance, 1.5, "%s %s recovery start = windup share" % [id, symbol])
			await _until(func() -> bool: return not player.combat.is_busy(), f)
			await tick(f, 2)
			check_near(player.velocity.y, base * stance, 1.5, "%s %s back to full walking" % [id, symbol])
			player.queue_free()
			await get_tree().physics_frame


func test_burden_scales_walking_with_the_phase_factor() -> void:
	_spawn(&"axe", 1)
	player.move_speed_multiplier = 0.92
	var f := frame(Vector2.DOWN)
	await tick(f, 6)
	check_near(player.velocity.y, 180.0 * 0.92, 1.0, "Heavy burden: 92 % walking")
	await tick(_press("L", Vector2.DOWN))
	await tick(f, 3)
	check_near(player.velocity.y, 180.0 * 0.92 * 0.70, 1.5, "burden x windup factor")


func test_lunge_respects_walls_and_side_step_goes_sideways() -> void:
	_spawn(&"spear", 20)
	add_wall(Vector2(30, 0), Vector2(8, 80))
	await wait_physics(2)
	await perform_path("LLH")
	check(player.global_position.x < 30.0 - 8.0, "Driving Thrust stops at the wall (x %.1f)" % player.global_position.x)
	player.queue_free()
	await get_tree().physics_frame
	_spawn(&"dagger", 20)
	await wait_physics(2)
	var start := player.global_position
	await perform_path("LH")
	await perform_path("LHL")
	check(absf(player.global_position.y - start.y) >= 20.0, "Shadow Rhythm: side step %.1f px" % (player.global_position.y - start.y))
	check(not player.dash.is_invulnerable(), "no extra iFrames from the side step")


func test_aim_fixed_during_active_and_sampled_per_step() -> void:
	_spawn(&"one_handed_sword", 2)
	await tick(_press("L", Vector2.ZERO, Vector2.RIGHT))
	var f := frame(Vector2.ZERO, Vector2.UP)
	await _until(func() -> bool: return player.combat.phase == CombatComponent.Phase.ACTIVE, f)
	check_eq(player.combat.attack_direction, Vector2.RIGHT, "the swing keeps its start direction in active")
	check_eq(player.combat.hitbox.direction, Vector2.RIGHT, "the hit sector does not pivot")
	await _until(func() -> bool: return player.combat.attack_clock() >= player.combat.accept_from(), f)
	await tick(_press("L", Vector2.ZERO, Vector2.UP))
	await _until(func() -> bool: return player.combat.chain == "LL", f)
	check_eq(player.combat.attack_direction, Vector2.UP, "the next step samples the new aim")


func test_skills_and_drinks_only_in_neutral() -> void:
	_spawn()
	check(player.can_start_skill(), "neutral: skills and drinks may start")
	await tick(_press("L"))
	var f := frame()
	await _until(func() -> bool: return player.combat.can_dash_cancel(), f)
	check(not player.can_start_skill(), "even inside the defense window: no skill / drink cancel")
	await _until(func() -> bool: return not player.combat.is_busy(), f)
	check(player.can_start_skill(), "neutral again")


func test_stun_and_ui_clear_buffered_inputs() -> void:
	_spawn(&"one_handed_sword", 2)
	await tick(_press("L"))
	var f := frame()
	await _until(func() -> bool: return player.combat.attack_clock() >= player.combat.accept_from(), f)
	await tick(_press("L"))
	check_eq(player.combat.buffered, "LL", "buffered")
	var stun := HitData.new()
	stun.reaction = HitReaction.Type.INTERRUPT
	stun.damage = 1.0
	player.hurtbox.receive_hit(stun)
	await tick(f, 40)
	check_eq(started_attacks.size(), 1, "the stun dropped the buffered step")
	# UI opened while a step is buffered
	await tick(_press("L"))
	await _until(func() -> bool: return player.combat.attack_clock() >= player.combat.accept_from(), f)
	await tick(_press("L"))
	player.input_blocker = func() -> bool: return true
	var blocked := _press("L")
	player.apply_input_block(blocked)
	check_eq(player.combat.buffered, "", "opening a window clears the buffer")
	check(not blocked.light_pressed, "presses into a window never reach combat")
	player.input_blocker = Callable()
	await tick(f, 60)
	check_eq(started_attacks.size(), 2, "no step after the window opened")
