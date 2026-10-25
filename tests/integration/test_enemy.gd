extends GameplayTestCase
## Melee enemy: chase, telegraph, attack, dodge, stagger, death, debug spawning.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const GRUNT_ATTACKS: WeaponFamily = preload("res://data/enemies/grunt_attacks.tres")

var enemy: Enemy


func _spawn_enemy(at: Vector2) -> Enemy:
	enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	add_child(enemy)
	return enemy


func _idle(ticks: int) -> void:
	await tick(frame(Vector2.ZERO, Vector2.RIGHT), ticks)


func _until_enemy_state(state: Enemy.State, limit: int = 240) -> bool:
	for i in limit:
		if enemy.state == state:
			return true
		await _idle(1)
	return enemy.state == state


func test_enemy_data_is_valid() -> void:
	check(GRUNT_ATTACKS.validate().is_empty(), "grunt attacks validate: %s" % [GRUNT_ATTACKS.validate()])
	var swipe := GRUNT_ATTACKS.get_attack(GRUNT_ATTACKS.root_light)
	check(swipe.startup >= 0.3, "telegraph (startup) is readable: %.2fs" % swipe.startup)


func test_enemy_chases_player() -> void:
	spawn_player()
	_spawn_enemy(Vector2(150, 0))
	await _idle(2)
	var start := enemy.global_position.distance_to(player.global_position)
	await _idle(60)
	var now := enemy.global_position.distance_to(player.global_position)
	check(now < start - 50.0, "enemy closes in (%.1f -> %.1f)" % [start, now])


func test_telegraph_precedes_damage() -> void:
	spawn_player()
	_spawn_enemy(Vector2(40, 0))
	check(await _until_enemy_state(Enemy.State.TELEGRAPH), "enemy telegraphs")
	var hp := player.health.health
	var telegraph_ticks := 0
	while enemy.state == Enemy.State.TELEGRAPH:
		check_eq(player.health.health, hp, "no damage during telegraph")
		telegraph_ticks += 1
		await _idle(1)
	check(telegraph_ticks >= seconds_to_ticks(0.4), "telegraph lasts %d ticks" % telegraph_ticks)
	await _idle(10)
	var swipe := GRUNT_ATTACKS.get_attack(&"grunt_swipe")
	check_near(player.health.health, hp - swipe.damage, 0.01, "player takes exactly one swipe")


func test_dash_iframes_avoid_enemy_attack() -> void:
	spawn_player()
	_spawn_enemy(Vector2(40, 0))
	check(await _until_enemy_state(Enemy.State.TELEGRAPH), "enemy telegraphs")
	while enemy.combat.phase == CombatComponent.Phase.STARTUP and \
			enemy.combat.phase_time < enemy.combat.current_attack.startup - 3 * FRAME:
		await _idle(1)
	var hp := player.health.health
	await tick(dash_press(frame(Vector2.ZERO, Vector2.RIGHT)))   # no input: dash backwards
	await _idle(30)
	check_eq(player.health.health, hp, "dodged the swipe")


func test_enemy_takes_damage_and_dies() -> void:
	spawn_player()
	_spawn_enemy(Vector2(24, 0))
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0   # keep it passive for this test
	var defeated := [false]
	enemy.defeated.connect(func(_e: Enemy) -> void: defeated[0] = true)
	await _idle(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	var guard := 0
	while not enemy.health.is_dead() and guard < 40:
		guard += 1
		f.aim_direction = (enemy.global_position - player.global_position).normalized()
		await tick(light(f))
		await tick(f, 24)
	check(enemy.health.is_dead(), "enemy died")
	check(defeated[0], "defeated signal")
	check_eq(enemy.state, Enemy.State.DEAD, "dead state")
	check(not enemy.hurtbox.receive_hit(HitData.new()), "corpse takes no hits")
	await _idle(seconds_to_ticks(enemy.config.despawn_delay) + 3)
	check(not is_instance_valid(enemy), "corpse removed")


func test_hit_reaction_knockback() -> void:
	spawn_player()
	_spawn_enemy(Vector2(24, 0))
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	await _idle(2)
	var before := enemy.global_position.x
	await tick(light(frame(Vector2.ZERO, Vector2.RIGHT)))
	await _idle(24)
	var after_light := enemy.global_position.x
	check(after_light > before + 1.5, "light nudges (%.1f -> %.1f)" % [before, after_light])
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true   # tap: normal heavy
	await tick(f)
	await _idle(40)
	check(enemy.global_position.x > after_light + 10.0, "heavy knocks back clearly (%.1f -> %.1f)" % [after_light, enemy.global_position.x])


func test_poise_break_cancels_telegraph_without_ghost_hit() -> void:
	spawn_player()
	_spawn_enemy(Vector2(30, 0))
	check(await _until_enemy_state(Enemy.State.TELEGRAPH), "enemy telegraphs")
	var hp := player.health.health
	var hit := HitData.new()
	hit.poise_damage = 1000.0
	enemy.hurtbox.receive_hit(hit)
	check_eq(enemy.state, Enemy.State.STAGGERED, "staggered")
	check_eq(enemy.combat.state, CombatComponent.State.IDLE, "attack cancelled")
	await _idle(40)
	check_eq(player.health.health, hp, "cancelled swipe never hits")
	await _idle(30)
	check(enemy.state != Enemy.State.STAGGERED, "recovers from stagger")


func test_arena_debug_spawn() -> void:
	var arena: Node2D = load("res://scenes/arena/test_arena.tscn").instantiate()
	add_child(arena)
	await wait_physics(1)
	var spawned: Enemy = arena.call(&"spawn_enemy", Vector2(100, -100))
	check(spawned != null and spawned.get_parent() == arena.get_node("Enemies"), "enemy spawned under Enemies")
	check(spawned.target == arena.get_node("Player"), "enemy targets the player")
	await wait_physics(5)
	check(is_instance_valid(spawned) and spawned.is_inside_tree(), "spawned enemy runs")
	arena.queue_free()
