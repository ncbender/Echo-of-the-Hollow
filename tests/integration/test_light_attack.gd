extends GameplayTestCase
## Light attacks: one click = one attack, no auto-repeat, buffer, hit windows.


func test_one_click_is_one_attack() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 120)   # 2 s without further clicks (button "held")
	check_eq(started_attacks.size(), 1, "exactly one attack per click")
	check_eq(combat.state, CombatComponent.State.IDLE, "back to idle")


func test_buffered_click_chains_on_recovery() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 4)
	step_combat(combat, light(f))   # tick 5, 80 ms before recovery starts -> buffered
	check_eq(started_attacks.size(), 1, "buffered, not started during startup/active")
	step_combat(combat, f, 6)
	check_eq(started_attacks, [&"sword_light_1", &"sword_light_2"] as Array[StringName], "buffered click executed")


func test_too_early_click_expires() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, light(f))   # tick 1, ~150 ms before recovery: outside the 120 ms buffer
	step_combat(combat, f, 60)
	check_eq(started_attacks.size(), 1, "expired buffered click does not fire")


func test_multiple_clicks_never_queue_more_than_one() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	for i in 5:
		step_combat(combat, light(f))   # mashing during startup/active
	step_combat(combat, f, 20)
	check(started_attacks.size() <= 2, "mashing queues at most one follow-up (got %d)" % started_attacks.size())


func test_hitbox_only_active_in_active_phase_and_hits_once() -> void:
	spawn_legacy_player()
	track_player_attacks()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	var saw_active := false
	for i in 30:
		var combat := player.combat
		var in_active := combat.state == CombatComponent.State.ATTACKING and combat.phase == CombatComponent.Phase.ACTIVE
		check_eq(player.get_node("AttackHitbox").is_active(), in_active, "hitbox active only in active phase (tick %d)" % i)
		if combat.phase == CombatComponent.Phase.STARTUP:
			check_eq(hits.size(), 0, "no hit during startup")
		saw_active = saw_active or in_active
		await tick(f)
	check(saw_active, "active phase observed")
	check_eq(hits.size(), 1, "one swing hits the target exactly once")
	check_eq(hits[0].attack.id, &"sword_light_1", "hit from first light")


func test_each_swing_hits_again() -> void:
	spawn_legacy_player()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 12)
	await tick(light(f))
	await tick(f, 12)
	check_eq(hits.size(), 2, "two swings, two hits")
	check(hits[0].attack_instance_id != hits[1].attack_instance_id, "hits belong to different swings")


func test_no_hit_outside_arc() -> void:
	spawn_legacy_player()
	add_target(Vector2(-22, 0))   # behind the player
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 25)
	check_eq(hits.size(), 0, "target behind the player is not hit")


func test_light_attack_reduces_movement() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	# Move down, attack right: the lunge is perpendicular, so velocity.y shows the multiplier.
	var f := frame(Vector2.DOWN, Vector2.RIGHT)
	await tick(f, 5)
	await tick(light(f), 3)
	var expected := player.movement.config.move_speed * SWORD.get_attack(&"sword_light_1").move_multiplier
	check_near(player.velocity.y, expected, 0.5, "85 % move speed during light attack")
