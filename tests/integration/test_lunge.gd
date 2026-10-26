extends GameplayTestCase
## Attack lunge (AttackDefinition.lunge_distance): direction, distance, cancel,
## no drift afterwards, walls, dash priority.


## Sword copy whose first light attack has `lunge` px of lunge.
func _sword_with_lunge(lunge: float) -> WeaponFamily:
	var weapon: WeaponFamily = SWORD.duplicate()
	var attacks: Array[AttackDefinition] = []
	for attack in SWORD.attacks:
		attacks.append(attack.duplicate())   # never touch the shared preloaded data
	weapon.attacks = attacks
	weapon.get_attack(&"sword_light_1").lunge_distance = lunge
	return weapon


func _attack_duration_ticks(attack: AttackDefinition) -> int:
	return seconds_to_ticks(attack.total_duration()) + 2


func test_lunge_moves_along_attack_direction_by_its_distance() -> void:
	spawn_player()
	await wait_physics(1)
	var attack := SWORD.get_attack(&"sword_light_1")
	var f := frame(Vector2.ZERO, Vector2.UP)
	await tick(light(f), _attack_duration_ticks(attack))
	check_near(player.global_position.y, -attack.lunge_distance, 0.2, "moved %.1f px up" % attack.lunge_distance)
	check_near(player.global_position.x, 0.0, 0.01, "no sideways motion")


func test_lunge_distance_is_configurable() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(20.0))
	await wait_physics(1)
	await tick(light(frame(Vector2.ZERO, Vector2.RIGHT)), _attack_duration_ticks(SWORD.get_attack(&"sword_light_1")))
	check_near(player.global_position.x, 20.0, 0.2, "20 px lunge")


func test_zero_lunge_is_stationary() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(0.0))
	await wait_physics(1)
	await tick(light(frame(Vector2.ZERO, Vector2.RIGHT)), _attack_duration_ticks(SWORD.get_attack(&"sword_light_1")))
	check_near(player.global_position.length(), 0.0, 0.01, "no movement")


func test_lunge_direction_fixed_at_attack_start() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(20.0))
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	f.aim_direction = Vector2.DOWN   # turning the mouse mid-attack
	await tick(f, _attack_duration_ticks(SWORD.get_attack(&"sword_light_1")))
	check_near(player.global_position.x, 20.0, 0.2, "lunge kept the start direction")
	check_near(player.global_position.y, 0.0, 0.01, "aim change did not steer the lunge")


func test_no_motion_after_the_attack_ends() -> void:
	spawn_player()
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f), _attack_duration_ticks(SWORD.get_attack(&"sword_light_1")))
	var rest := player.global_position
	await tick(f, 30)
	check_eq(player.global_position, rest, "standing still after the attack")
	check_eq(player.combat.get_lunge_velocity(), Vector2.ZERO, "no lunge velocity")


func test_hit_reaction_cancel_stops_lunge() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(30.0))
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f), 3)
	var hit := HitData.new()
	hit.reaction = HitReaction.Type.STUN
	player.hurtbox.receive_hit(hit)
	var at_cancel := player.global_position
	await tick(f, 30)
	check_eq(player.combat.state, CombatComponent.State.IDLE, "attack cancelled by the stun")
	check_near(player.global_position.distance_to(at_cancel), 0.0, 0.01, "lunge ended with the cancel")


func test_dash_cancel_replaces_lunge_with_dash() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(30.0))
	await wait_physics(1)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f), 3)
	f.aim_direction = Vector2.UP
	await tick(dash_press(f))
	var dash_speed := player.dash.config.distance / player.dash.config.duration
	check_near(player.velocity.length(), dash_speed, 0.01, "only dash velocity (no lunge on top)")
	check_near(player.velocity.x, 0.0, 0.01, "no lunge component")


func test_lunge_does_not_pass_walls() -> void:
	spawn_player()
	player.set_weapon_family(_sword_with_lunge(40.0))
	add_wall(Vector2(24, 0), Vector2(16, 120))   # face at x = 16
	await wait_physics(2)
	await tick(light(frame(Vector2.ZERO, Vector2.RIGHT)), _attack_duration_ticks(SWORD.get_attack(&"sword_light_1")))
	check(player.global_position.x < 16.0, "stopped at the wall (x=%.1f)" % player.global_position.x)
