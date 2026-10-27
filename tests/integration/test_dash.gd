extends GameplayTestCase
## Dash: charges, regeneration, iFrames, direction, chaining.


func _new_dash() -> DashComponent:
	var dash := DashComponent.new()
	dash.config = DashConfig.new()
	add_child(dash)
	return dash


func _step(dash: DashComponent, seconds: float) -> void:
	for i in seconds_to_ticks(seconds):
		dash.step(FRAME)


func test_dash_consumes_exactly_one_charge() -> void:
	var dash := _new_dash()
	check_eq(dash.charges, 2, "starts full")
	check(dash.try_start(Vector2.RIGHT), "dash starts")
	check_eq(dash.charges, 1, "one charge used")


func test_no_dash_without_charges() -> void:
	var dash := _new_dash()
	dash.try_start(Vector2.RIGHT)
	_step(dash, 0.3)
	dash.try_start(Vector2.RIGHT)
	_step(dash, 0.3)
	check_eq(dash.charges, 0, "both charges used")
	check(not dash.can_dash(), "cannot dash at 0 charges")
	check(not dash.try_start(Vector2.RIGHT), "try_start refuses at 0 charges")


func test_cannot_dash_while_dashing() -> void:
	var dash := _new_dash()
	dash.try_start(Vector2.RIGHT)
	_step(dash, 0.1)
	check(not dash.try_start(Vector2.LEFT), "no dash during dash")
	check_eq(dash.charges, 1, "charge not spent by refused dash")


func test_charges_regenerate_sequentially() -> void:
	var dash := _new_dash()
	dash.try_start(Vector2.RIGHT)
	_step(dash, 0.3)
	dash.try_start(Vector2.RIGHT)
	_step(dash, 0.3)
	# 0.6 s have passed since the first dash; 1.9 s more completes the first charge.
	_step(dash, 1.85)
	check_eq(dash.charges, 0, "first charge not yet back at 2.45 s")
	_step(dash, 0.1)
	check_eq(dash.charges, 1, "first charge back at 2.55 s")
	_step(dash, 2.3)
	check_eq(dash.charges, 1, "second charge not yet back (sequential)")
	_step(dash, 0.25)
	check_eq(dash.charges, 2, "second charge back after another 2.5 s")
	_step(dash, 3.0)
	check_eq(dash.charges, 2, "never exceeds max")


func test_iframes_cover_first_180ms_only() -> void:
	var dash := _new_dash()
	dash.try_start(Vector2.RIGHT)
	check(dash.is_invulnerable(), "invulnerable at dash start")
	_step(dash, 10 * FRAME)
	check(dash.is_invulnerable(), "invulnerable at 167 ms")
	_step(dash, FRAME)
	check(not dash.is_invulnerable(), "vulnerable at 183 ms")
	check(dash.is_dashing(), "still dashing after iframes")
	_step(dash, 7 * FRAME)
	check(not dash.is_dashing(), "dash over at 300 ms")


# --- Dash direction: WASD first, else facing (mouse), UI/UX Polish 1.1 --------

func _dash_with(move: Vector2, aim: Vector2) -> InputFrame:
	spawn_legacy_player()
	await wait_physics(1)
	var f := frame(move, aim)
	await tick(dash_press(f))
	return f


func test_dash_follows_wasd_in_all_four_directions() -> void:
	for move: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var f := await _dash_with(move, Vector2(0.6, 0.8))   # mouse somewhere else
		check(player.dash.is_dashing(), "dash started (%s)" % move)
		check_eq(player.dash.direction, move, "dash follows WASD %s" % move)
		check_eq(player.dash.charges, 1, "one charge spent (%s)" % move)
		await tick(f, seconds_to_ticks(0.3) - 1)
		check_near(player.global_position.dot(move), player.dash.config.distance, 1.0, "full, unchanged distance %s" % move)
		player.queue_free()
		await wait_physics(1)


func test_dash_follows_wasd_diagonals_normalized() -> void:
	for move: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		await _dash_with(move, Vector2.RIGHT)
		check_near(player.dash.direction.length(), 1.0, 0.0001, "normalized %s" % move)
		check_near(player.dash.direction.angle_to(move), 0.0, 0.0001, "diagonal %s" % move)
		player.queue_free()
		await wait_physics(1)


func test_wasd_beats_a_different_mouse_direction() -> void:
	var f := await _dash_with(Vector2.DOWN, Vector2.UP)
	check_eq(player.dash.direction, Vector2.DOWN, "WASD down wins over the mouse up")
	await tick(f, seconds_to_ticks(0.3) - 1)
	check(player.global_position.y > player.dash.config.distance - 5.0, "moved down the full distance (y=%.1f)" % player.global_position.y)


func test_dash_without_move_input_goes_to_aim() -> void:
	var f := await _dash_with(Vector2.ZERO, Vector2.LEFT)
	await tick(f, seconds_to_ticks(0.3) - 1)
	check_eq(player.dash.direction, Vector2.LEFT, "dash left")
	check_near(player.global_position.x, -player.dash.config.distance, 1.0, "covers the unchanged dash distance")
	check_near(player.global_position.y, 0.0, 0.01, "straight line")


func test_direction_rule_in_isolation() -> void:
	check_eq(DashComponent.direction_for(Vector2(0, -1), Vector2.RIGHT), Vector2(0, -1), "WASD first")
	check_eq(DashComponent.direction_for(Vector2.ZERO, Vector2.RIGHT), Vector2.RIGHT, "no WASD -> facing")
	check_eq(DashComponent.direction_for(Vector2(0.05, 0), Vector2.UP), Vector2.UP, "tiny stick noise counts as no movement")
	check_near(DashComponent.direction_for(Vector2(2, 2), Vector2.UP).length(), 1.0, 0.0001, "normalized")
	check_eq(DashConfig.new().max_charges, 2, "charges unchanged")



func test_dash_direction_is_normalized_for_diagonal_aim() -> void:
	await _dash_with(Vector2.ZERO, Vector2(3, -1))
	check_near(player.dash.direction.length(), 1.0, 0.0001, "normalized")
	check_near(player.dash.direction.angle_to(Vector2(3, -1)), 0.0, 0.0001, "towards the cursor")


func test_dash_direction_stays_fixed_when_aim_moves() -> void:
	var f := await _dash_with(Vector2.ZERO, Vector2.RIGHT)
	for aim: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2(-1, 1)]:
		f.aim_direction = aim.normalized()
		f.move = -aim
		await tick(f, 4)
		check_eq(player.dash.direction, Vector2.RIGHT, "direction unchanged after aiming %s" % aim)
	check_near(player.global_position.y, 0.0, 0.01, "no sideways drift during the dash")


func test_invalid_aim_uses_last_valid_facing() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	await tick(frame(Vector2.ZERO, Vector2.UP))   # last valid facing: up
	var f := frame(Vector2.ZERO, Vector2.ZERO)   # no WASD, cursor on the character -> no aim
	f.aim_direction = Vector2.ZERO
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash still possible")
	check_eq(player.dash.direction, Vector2.UP, "last valid facing used")


func test_dash_cancels_light_attack() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var cancelled: Array[StringName] = []
	player.combat.attack_cancelled.connect(func(_a: AttackDefinition, reason: StringName) -> void: cancelled.append(reason))
	var f := frame(Vector2.ZERO, Vector2.DOWN)
	await tick(light(f), 3)
	check_eq(player.combat.state, CombatComponent.State.ATTACKING, "attacking")
	f.aim_direction = Vector2.LEFT
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash cancelled the light attack")
	check_eq(cancelled, [&"dash"] as Array[StringName], "cancel reason dash")
	check_eq(player.dash.direction, Vector2.LEFT, "dash towards the current aim")
	check_eq(player.combat.get_lunge_velocity(), Vector2.ZERO, "no lunge after the cancel")


func test_dash_cancels_heavy_charge() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var reasons: Array[StringName] = []
	player.combat.charge_cancelled.connect(func(reason: StringName) -> void: reasons.append(reason))
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(heavy_down(f), 10)
	check_eq(player.combat.state, CombatComponent.State.CHARGING, "charging")
	f.aim_direction = Vector2.UP
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash out of the charge")
	check_eq(reasons, [&"dash"] as Array[StringName], "charge cancelled")
	check_eq(player.dash.direction, Vector2.UP, "dash towards the aim")
	await tick(f, 20)
	check_eq(player.combat.state, CombatComponent.State.IDLE, "no heavy released after the dash")


func test_player_without_charges_cannot_dash() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	player.dash.charges = 0
	await tick(dash_press(frame(Vector2.ZERO, Vector2.RIGHT)))
	check(not player.dash.is_dashing(), "no dash at 0 charges")
	check_near(player.global_position.x, 0.0, 0.01, "not moved")


func test_dash_into_wall_stops_at_the_wall() -> void:
	spawn_legacy_player()
	add_wall(Vector2(60, 0), Vector2(16, 120))   # face at x = 52
	await wait_physics(2)
	var f := frame(Vector2.RIGHT, Vector2.LEFT)   # WASD towards the wall, mouse away
	await tick(dash_press(f), seconds_to_ticks(0.3))
	check(player.global_position.x < 52.0, "stopped in front of the wall (x=%.1f)" % player.global_position.x)
	check(player.global_position.x > 30.0, "dash went towards the wall")


func test_player_dash_buffered_but_not_infinite() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var f := frame(Vector2.RIGHT)
	f.dash_pressed = true
	await tick(f, 15)
	f.dash_pressed = true   # pressed 50 ms before the first dash ends -> buffered
	await tick(f, 4)
	check(player.dash.is_dashing(), "buffered second dash started")
	check_eq(player.dash.charges, 0, "both charges spent")
	await tick(f, 18)
	f.dash_pressed = true
	await tick(f, 1)
	check(not player.dash.is_dashing(), "third dash refused without charges")
