extends GameplayTestCase
## Knockback x lunge x combo windows (Combat Polish 0.2): regular combo hits must
## keep reaching a standard enemy without walking; finishers may push it away.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const GREATSWORD: WeaponFamily = LEGACY_GREATSWORD

var hit_ids: Array[StringName] = []


func _spawn_enemy(at: Vector2, passive: bool = true) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	if passive:
		enemy.config.attack_range = 0.0
		enemy.config.move_speed = 0.0
	add_child(enemy)
	enemy.hurtbox.hit_received.connect(func(hit: HitData) -> void: hit_ids.append(hit.attack.id))
	return enemy


## Presses each input ("L" light, "H" heavy tap) as soon as the combo allows it
## (no move input, aim fixed), then lets the last attack finish.
func _chain(inputs: String, f: InputFrame) -> void:
	for input in inputs:
		var guard := 0
		while guard < 120:
			var combat := player.combat
			if combat.state == CombatComponent.State.IDLE:
				break
			if combat.state == CombatComponent.State.ATTACKING and combat.phase == CombatComponent.Phase.RECOVERY \
					and combat.phase_time >= combat.current_attack.chain_delay:
				break
			guard += 1
			await tick(f)
		if input == "L":
			await tick(light(f))
		else:
			f.heavy_pressed = true
			await tick(f)
	while player.combat.state != CombatComponent.State.IDLE:
		await tick(f)


func _combo_against_standard_enemy(weapon: WeaponFamily, inputs: String, start_distance: float) -> Enemy:
	spawn_legacy_player()
	player.set_weapon_family(weapon)
	var enemy := _spawn_enemy(Vector2(start_distance, 0))
	await wait_physics(2)
	await _chain(inputs, frame(Vector2.ZERO, Vector2.RIGHT))
	return enemy


func test_sword_lll_all_hits_connect() -> void:
	await _combo_against_standard_enemy(SWORD, "LLL", 24.0)
	check_eq(hit_ids, [&"sword_light_1", &"sword_light_2", &"sword_light_3"] as Array[StringName], "L-L-L all hit")


func test_greatsword_lll_all_hits_connect() -> void:
	await _combo_against_standard_enemy(GREATSWORD, "LLL", 34.0)
	check_eq(hit_ids, [&"greatsword_light_1", &"greatsword_light_2", &"greatsword_light_3"] as Array[StringName], "L-L-L all hit")


func test_sword_llh_finisher_connects() -> void:
	var enemy := await _combo_against_standard_enemy(SWORD, "LLH", 24.0)
	check_eq(hit_ids, [&"sword_light_1", &"sword_light_2", &"sword_llh_crush"] as Array[StringName], "L-L-H all hit")
	check(enemy.knockback.last_offset.length() >= 29.0, "finisher pushes clearly (%.1f px)" % enemy.knockback.last_offset.length())


func test_greatsword_llh_finisher_connects() -> void:
	await _combo_against_standard_enemy(GREATSWORD, "LLH", 34.0)
	check_eq(hit_ids, [&"greatsword_light_1", &"greatsword_light_2", &"greatsword_llh_whirl"] as Array[StringName], "L-L-H all hit")


func test_sword_lh_connects() -> void:
	await _combo_against_standard_enemy(SWORD, "LH", 24.0)
	check_eq(hit_ids, [&"sword_light_1", &"sword_lh_thrust"] as Array[StringName], "L-H both hit")


func test_greatsword_lh_connects() -> void:
	await _combo_against_standard_enemy(GREATSWORD, "LH", 34.0)
	check_eq(hit_ids, [&"greatsword_light_1", &"greatsword_lh_overhead"] as Array[StringName], "L-H both hit")


func test_charged_heavy_hits_with_heavy_knockback() -> void:
	spawn_legacy_player()
	var enemy := _spawn_enemy(Vector2(26, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(heavy_down(f), 50)
	check_eq(player.combat.state, CombatComponent.State.CHARGING, "charging")
	check(player.combat.get_charge_tier_preview() > 0, "charged above tier 0")
	await tick(heavy_up(f))
	while player.combat.state != CombatComponent.State.IDLE:
		await tick(f)
	check_eq(hit_ids, [&"sword_heavy"] as Array[StringName], "charged heavy hit")
	check_near(enemy.knockback.last_offset.length(), SWORD.get_attack(&"sword_heavy").knockback, 0.01, "charge tier does not multiply knockback")


func test_dash_cancel_then_new_combo_hits() -> void:
	spawn_legacy_player()
	var enemy := _spawn_enemy(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f), 3)
	f.aim_direction = Vector2.LEFT
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash-cancelled the first swing")
	await tick(f, 30)
	# walk back into range and start a fresh combo
	f.aim_direction = Vector2.RIGHT
	f.move = Vector2.RIGHT
	while enemy.global_position.x - player.global_position.x > 24.0:
		await tick(f)
	f.move = Vector2.ZERO
	var before := hit_ids.size()
	await _chain("LL", f)
	check_eq(hit_ids.size() - before, 2, "fresh L-L after the dash hits twice")
	check_eq(hit_ids[hit_ids.size() - 2], &"sword_light_1", "combo restarted at L1")


func test_weapon_switch_changes_knockback_profile() -> void:
	spawn_legacy_player()
	var enemy := _spawn_enemy(Vector2(30, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await _chain("L", f)
	check_near(enemy.knockback.last_offset.length(), 6.0, 0.01, "sword light 6 px")
	await tick(f, 30)
	check(player.set_weapon_family(GREATSWORD), "switched to greatsword")
	await _chain("L", f)
	check_near(enemy.knockback.last_offset.length(), 12.0, 0.01, "greatsword light 12 px")


func test_one_swing_pushes_two_enemies_once_each() -> void:
	spawn_legacy_player()
	var upper := _spawn_enemy(Vector2(20, -12))
	var lower := _spawn_enemy(Vector2(20, 12))
	await wait_physics(2)
	var upper_start := upper.global_position
	var lower_start := lower.global_position
	await _chain("L", frame(Vector2.ZERO, Vector2.RIGHT))
	await tick(frame(), 30)
	check_eq(hit_ids.size(), 2, "both hit once")
	check_near(upper.global_position.distance_to(upper_start), 6.0, 0.5, "upper pushed 6 px")
	check_near(lower.global_position.distance_to(lower_start), 6.0, 0.5, "lower pushed 6 px")


func test_standing_light_combos_kill_an_active_grunt() -> void:
	spawn_legacy_player()
	var enemy := _spawn_enemy(Vector2(26, 0), false)   # real AI: chases and attacks
	await wait_physics(2)
	var f := frame()
	var swings := 0
	var dead := [false]
	enemy.defeated.connect(func(_e: Enemy) -> void: dead[0] = true)
	while not dead[0] and swings < 30:
		f.aim_direction = (enemy.global_position - player.global_position).normalized()
		player.health.heal(1000.0)   # independent of enemy damage
		await _chain("LLL", f)
		swings += 3
	check(dead[0], "grunt killed by standing combos")
	check(hit_ids.size() >= swings * 0.6, "most swings connected (%d hits / %d swings)" % [hit_ids.size(), swings])
