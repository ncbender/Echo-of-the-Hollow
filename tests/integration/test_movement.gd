extends GameplayTestCase
## Movement: 8 directions, diagonal speed, aim independence, collision.

const DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
	Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
]


func test_moves_in_eight_directions_at_configured_speed() -> void:
	spawn_player()
	var speed := player.movement.config.move_speed
	for raw in DIRECTIONS:
		player.position = Vector2.ZERO
		player._locomotion_velocity = Vector2.ZERO
		await tick(frame(raw.normalized()), 3)
		var start := player.position
		await tick(frame(raw.normalized()), 30)
		var moved := player.position - start
		check_near(moved.length(), speed * 30 * FRAME, 0.5, "distance for %s" % raw)
		check_near(moved.normalized().angle_to(raw.normalized()), 0.0, 0.01, "direction for %s" % raw)


func test_diagonal_is_not_faster() -> void:
	spawn_player()
	var speed := player.movement.config.move_speed
	# Raw, unnormalized diagonal input must still be clamped.
	await tick(frame(Vector2(1, 1)), 20)
	check(player.velocity.length() <= speed + 0.01, "diagonal speed %.2f <= %.2f" % [player.velocity.length(), speed])
	check_near(player.velocity.length(), speed, 0.01, "diagonal reaches full speed")


func test_reaches_full_speed_immediately() -> void:
	spawn_player()
	await tick(frame(Vector2.RIGHT), 3)
	check_near(player.velocity.length(), player.movement.config.move_speed, 0.01, "full speed after 3 ticks")
	await tick(frame(Vector2.ZERO), 3)
	check_eq(player.velocity, Vector2.ZERO, "stops within 3 ticks")


func test_aim_is_independent_of_movement() -> void:
	spawn_player()
	await tick(frame(Vector2.RIGHT, Vector2.LEFT), 20)
	check(player.velocity.x > 170.0, "moves right while aiming left")
	check_eq(player.aim_direction, Vector2.LEFT, "aim stays left")
	await tick(frame(Vector2.RIGHT, Vector2.UP), 1)
	check_eq(player.aim_direction, Vector2.UP, "aim follows input instantly")


func test_collides_with_obstacles() -> void:
	spawn_player()
	add_wall(Vector2(40, 0), Vector2(16, 64))
	await wait_physics(2)
	await tick(frame(Vector2.RIGHT), 60)
	# Wall face at x=32, body radius 6.
	check(player.position.x <= 26.1, "stopped by wall (x=%.2f)" % player.position.x)
	check(player.position.x > 24.0, "reached the wall (x=%.2f)" % player.position.x)
	# Sliding along the wall still works.
	await tick(frame(Vector2(1, 1).normalized()), 20)
	check(player.position.y > 20.0, "slides along wall (y=%.2f)" % player.position.y)
