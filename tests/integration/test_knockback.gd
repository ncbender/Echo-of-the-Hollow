extends GameplayTestCase
## Knockback (Combat Polish 0.2): distance-based KnockbackMotion, per-attack weapon
## profiles, enemy resistance tiers, walls, no double application.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const GREATSWORD: WeaponFamily = LEGACY_GREATSWORD
const GRUNT_CONFIG: EnemyConfig = preload("res://data/enemies/grunt_config.tres")
const WARDEN_CONFIG: EnemyConfig = preload("res://data/enemies/grove_warden_config.tres")


func _spawn_enemy(at: Vector2, resistance: float = 0.0) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0   # passive dummy with real enemy physics
	enemy.config.move_speed = 0.0
	enemy.config.knockback_resistance = resistance
	add_child(enemy)
	return enemy


func _hit(knockback: Vector2, poise: float = 0.0) -> HitData:
	var hit := HitData.new()
	hit.knockback = knockback
	hit.poise_damage = poise
	return hit


func _settle(count: int = 60) -> void:
	await tick(frame(), count)


## Real player attack against a standard grunt; returns the enemy's displacement.
func _attack_push(weapon: WeaponFamily, heavy: bool) -> float:
	spawn_legacy_player()
	player.set_weapon_family(weapon)
	var enemy := _spawn_enemy(Vector2(24, 0))
	await wait_physics(2)
	var start := enemy.global_position.x
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	if heavy:
		f.heavy_pressed = true   # tap: uncharged heavy
	else:
		f = light(f)
	await tick(f)
	await _settle()
	check(enemy.health.health < enemy.health.max_health, "%s hit landed" % ("heavy" if heavy else "light"))
	check_near(enemy.knockback.last_traveled, enemy.global_position.x - start, 0.05, "debug distance matches real motion")
	return enemy.global_position.x - start


func test_one_handed_sword_light() -> void:
	var light_push: float = await _attack_push(SWORD, false)
	check_near(light_push, 6.0, 0.3, "sword light pushes 6 px")


func test_one_handed_sword_heavy() -> void:
	check_near(await _attack_push(SWORD, true), 18.0, 0.3, "sword heavy pushes 18 px")


func test_two_handed_sword_light() -> void:
	check_near(await _attack_push(GREATSWORD, false), 12.0, 0.3, "greatsword light pushes 12 px")


func test_two_handed_sword_heavy() -> void:
	check_near(await _attack_push(GREATSWORD, true), 35.0, 0.3, "greatsword heavy pushes 35 px")


func test_weapon_profiles_are_ordered() -> void:
	for weapon: WeaponFamily in [SWORD, GREATSWORD]:
		var light_root := weapon.get_attack(weapon.root_light)
		var heavy_root := weapon.get_attack(weapon.root_heavy)
		check(light_root.knockback < heavy_root.knockback, "%s: light < heavy" % weapon.id)
		for attack in weapon.attacks:
			check(attack.knockback > 0.0 and attack.knockback <= 60.0, "%s knockback in px range (%.1f)" % [attack.id, attack.knockback])
	check(GREATSWORD.get_attack(GREATSWORD.root_light).knockback > SWORD.get_attack(SWORD.root_light).knockback, "greatsword light > sword light")
	check(GREATSWORD.get_attack(GREATSWORD.root_heavy).knockback > SWORD.get_attack(SWORD.root_heavy).knockback, "greatsword heavy > sword heavy")


func test_resistance_tiers_scale_distance() -> void:
	spawn_legacy_player(Vector2(-200, 0))
	var expected := {-0.5: 30.0, 0.0: 20.0, 0.5: 10.0, 0.8: 4.0, 1.0: 0.0}
	var enemies := {}
	var y := -80.0
	for resistance: float in expected:
		enemies[resistance] = _spawn_enemy(Vector2(0, y), resistance)
		y += 40.0
	await wait_physics(2)
	for resistance: float in expected:
		var enemy: Enemy = enemies[resistance]
		enemy.set_meta(&"start", enemy.global_position.x)
		enemy.hurtbox.receive_hit(_hit(Vector2(20, 0), 5.0))
	await _settle()
	for resistance: float in expected:
		var enemy: Enemy = enemies[resistance]
		var moved: float = enemy.global_position.x - enemy.get_meta(&"start")
		check_near(moved, expected[resistance], 0.3, "resistance %.1f -> %.1f px (moved %.2f)" % [resistance, expected[resistance], moved])
		check_near(enemy.health.poise, enemy.health.max_poise - 5.0, 0.01, "poise damage independent of resistance %.1f" % resistance)


func test_data_tiers_grunt_standard_warden_boss() -> void:
	check_near(GRUNT_CONFIG.knockback_taken(), 1.0, 0.0001, "grunt = standard enemy")
	check_near(WARDEN_CONFIG.knockback_taken(), 0.0, 0.0001, "Grove Warden boss: no positional knockback")
	var forest: Node = load("res://scenes/maps/whisper_forest.tscn").instantiate()
	check_eq((forest.get_node("Enemies/GroveWarden") as Enemy).config, WARDEN_CONFIG, "warden uses the boss config")
	check_eq((forest.get_node("Enemies/GruntA") as Enemy).config, GRUNT_CONFIG, "grunts use the standard config")
	forest.free()


func test_one_hit_pushes_exactly_once() -> void:
	spawn_legacy_player()
	var enemy := _spawn_enemy(Vector2(24, 0))
	await wait_physics(2)
	var start := enemy.global_position.x
	var pushes := [0]
	enemy.hurtbox.hit_received.connect(func(_hit_data: HitData) -> void: pushes[0] += 1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await _settle(80)   # the whole swing incl. recovery
	check_eq(pushes[0], 1, "one hit per swing")
	check_near(enemy.global_position.x - start, SWORD.get_attack(&"sword_light_1").knockback, 0.3, "single distance, not doubled")


func test_overlapping_hits_add_distances_not_speeds() -> void:
	spawn_legacy_player(Vector2(-200, 0))
	var enemy := _spawn_enemy(Vector2(0, 0))
	await wait_physics(2)
	enemy.hurtbox.receive_hit(_hit(Vector2(10, 0)))
	await tick(frame(), 2)
	enemy.hurtbox.receive_hit(_hit(Vector2(10, 0)))
	await _settle()
	check_near(enemy.global_position.x, 20.0, 0.3, "two 10 px hits = 20 px")


func test_wall_absorbs_knockback_without_storing_it() -> void:
	spawn_legacy_player(Vector2(-200, 0))
	add_wall(Vector2(40, 0), Vector2(16, 120))   # face at x = 32
	var enemy := _spawn_enemy(Vector2(16, 0))
	await wait_physics(2)
	var previous := enemy.global_position
	enemy.hurtbox.receive_hit(_hit(Vector2(60, 0)))
	for i in 40:
		await tick(frame())
		check(enemy.global_position.distance_to(previous) < 9.0, "no jump (tick %d)" % i)
		previous = enemy.global_position
	check(enemy.global_position.x <= 32.0 - 6.0 + 0.5, "stopped in front of the wall (x=%.1f)" % enemy.global_position.x)
	check(not enemy.knockback.is_active(), "rest of the push absorbed, nothing stored")
	check(enemy.knockback.last_traveled < 12.0, "debug shows the shortened distance (%.1f)" % enemy.knockback.last_traveled)


func test_knockback_does_not_push_other_enemies() -> void:
	spawn_legacy_player(Vector2(-200, 0))
	var front := _spawn_enemy(Vector2(0, 0))
	var behind := _spawn_enemy(Vector2(16, 0))
	await wait_physics(2)
	var behind_start := behind.global_position
	front.hurtbox.receive_hit(_hit(Vector2(30, 0)))
	await _settle()
	check(behind.global_position.distance_to(behind_start) < 0.5, "enemy behind not shoved")
	check(front.global_position.distance_to(behind.global_position) >= 11.5, "no overlap")


func test_enemy_ai_does_not_cancel_the_push() -> void:
	spawn_legacy_player(Vector2(-30, 0))
	var enemy: Enemy = GRUNT_SCENE.instantiate()   # real chasing grunt
	enemy.position = Vector2(0, 0)
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	add_child(enemy)
	await wait_physics(2)
	var start := enemy.global_position.x
	enemy.hurtbox.receive_hit(_hit(Vector2(18, 0)))
	while enemy.knockback.is_active():
		await tick(frame())
	check_near(enemy.global_position.x - start, 18.0, 0.3, "full distance although the grunt chases the player")


func test_player_receives_enemy_knockback_once() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var hit := _hit(Vector2(-13, 0))
	hit.reaction = HitReaction.Type.KNOCKBACK
	player.hurtbox.receive_hit(hit)
	await _settle()
	var expected := 13.0 * player.reaction.config.knockback_multiplier
	check_near(player.global_position.x, -expected, 0.3, "player pushed %.1f px (reaction multiplier applied once)" % expected)
