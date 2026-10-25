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


func test_player_dash_follows_move_input() -> void:
	spawn_player()
	await wait_physics(1)
	var f := frame(Vector2.UP, Vector2.RIGHT)
	f.dash_pressed = true
	await tick(f, 1)
	check(player.dash.is_dashing(), "dash started")
	check_eq(player.dash.direction, Vector2.UP, "dash direction from WASD")
	check_eq(player.dash.charges, 1, "one charge spent")


func test_player_dash_without_input_goes_backwards() -> void:
	spawn_player()
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2(1, 1))
	f.dash_pressed = true
	await tick(f, seconds_to_ticks(0.3))
	check_near(player.dash.direction.angle_to(Vector2(-1, -1).normalized()), 0.0, 0.001, "dashes away from aim")
	check_near(player.position.length(), player.dash.config.distance, 1.0, "covers dash distance")


func test_player_dash_buffered_but_not_infinite() -> void:
	spawn_player()
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
