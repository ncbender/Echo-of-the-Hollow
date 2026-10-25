extends GameplayTestCase
## Physical separation of player and enemies, knockback against walls, crowds.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const MIN_DISTANCE := 11.5   # 6 + 6 body radii minus collision margin


func _spawn_enemy(at: Vector2, passive: bool = false) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	if passive:
		enemy.config.attack_range = 0.0
		enemy.config.move_speed = 0.0
	enemy.config.stop_distance = 0.0   # walk straight into the player
	return enemy


func test_enemy_cannot_walk_into_or_push_player() -> void:
	spawn_player()
	var enemy := _spawn_enemy(Vector2(60, 0))
	enemy.config.attack_range = 0.0
	await wait_physics(1)
	var start := player.global_position
	for i in 120:
		await tick(frame())
		if enemy.global_position.distance_to(player.global_position) < MIN_DISTANCE:
			fail("overlap at tick %d (%.2f)" % [i, enemy.global_position.distance_to(player.global_position)])
			return
	check(player.global_position.distance_to(start) < 0.5, "player not pushed (moved %.2f)" % player.global_position.distance_to(start))


func test_player_cannot_walk_through_enemy() -> void:
	spawn_player()
	var enemy := _spawn_enemy(Vector2(40, 0), true)
	await wait_physics(2)
	var enemy_start := enemy.global_position
	await tick(frame(Vector2.RIGHT), 60)
	check(player.global_position.x < enemy.global_position.x - MIN_DISTANCE + 0.5, "player stopped before enemy (x=%.1f)" % player.global_position.x)
	check(enemy.global_position.distance_to(enemy_start) < 0.5, "enemy not pushed by player")


func test_dash_into_enemy_does_not_penetrate() -> void:
	spawn_player()
	var enemy := _spawn_enemy(Vector2(50, 0), true)
	await wait_physics(2)
	var f := frame(Vector2.RIGHT)
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash started")
	for i in 20:
		await tick(f)
		check(player.global_position.distance_to(enemy.global_position) >= MIN_DISTANCE, "no overlap during dash (tick %d)" % i)


func test_knockback_stops_at_walls_without_jumps() -> void:
	spawn_player()
	add_wall(Vector2(60, 0), Vector2(16, 120))   # face at x = 52
	var enemy := _spawn_enemy(Vector2(30, 0), true)
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true
	await tick(f)
	var previous := enemy.global_position
	for i in 60:
		await tick(frame(Vector2.ZERO, Vector2.RIGHT))
		var step := enemy.global_position.distance_to(previous)
		check(step < 9.0, "no position jump (%.2f px in one tick)" % step)
		previous = enemy.global_position
	check(enemy.health.health < enemy.health.max_health, "heavy hit landed")
	check(enemy.global_position.x <= 52.0 - 6.0 + 0.5, "enemy stays in front of the wall (x=%.1f)" % enemy.global_position.x)


func test_several_enemies_do_not_stack() -> void:
	spawn_player()
	var enemies: Array[Enemy] = []
	for at: Vector2 in [Vector2(80, 0), Vector2(80, 10), Vector2(90, -10), Vector2(-80, 5)]:
		var enemy := _spawn_enemy(at)
		enemy.config.attack_range = 0.0
		enemies.append(enemy)
	await tick(frame(), 150)
	for i in enemies.size():
		check(enemies[i].global_position.distance_to(player.global_position) >= MIN_DISTANCE, "enemy %d not inside player" % i)
		for j in range(i + 1, enemies.size()):
			var d := enemies[i].global_position.distance_to(enemies[j].global_position)
			check(d >= MIN_DISTANCE, "enemies %d/%d separated (%.2f)" % [i, j, d])
