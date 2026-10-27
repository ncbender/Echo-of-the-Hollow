extends GameplayTestCase
## Heavy attacks: charge tiers, release, dash cancel, ghost hits, combo continuation.


func _charge_and_release(combat: CombatComponent, hold_ticks: int) -> void:
	var f := frame()
	step_combat(combat, heavy_down(f))
	step_combat(combat, f, hold_ticks - 1)
	step_combat(combat, heavy_up(f))


func test_charge_tiers_by_hold_time() -> void:
	var cases := {6: 0, 14: 0, 16: 1, 41: 1, 43: 2, 120: 2}
	for hold_ticks: int in cases:
		var combat := new_combat()
		_charge_and_release(combat, hold_ticks)
		check_eq(combat.state, CombatComponent.State.ATTACKING, "attacking after release (%d ticks)" % hold_ticks)
		check_eq(combat.charge_tier, cases[hold_ticks], "tier after %d ticks hold" % hold_ticks)
		combat.queue_free()


func test_attack_starts_on_release_only() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, heavy_down(f))
	step_combat(combat, f, 60)
	check_eq(combat.state, CombatComponent.State.CHARGING, "still charging while held")
	check_eq(started_attacks.size(), 0, "no attack while held")
	check_eq(combat.get_charge_tier_preview(), 2, "full charge shown while holding")
	step_combat(combat, heavy_up(f))
	check_eq(started_attacks, [&"sword_heavy"] as Array[StringName], "heavy starts on release")
	check_eq(combat.phase, CombatComponent.Phase.STARTUP, "regular startup after release")


func test_tap_gives_normal_heavy() -> void:
	var combat := new_combat()
	var f := frame()
	f.heavy_pressed = true
	f.heavy_released = true
	f.heavy_held = false
	step_combat(combat, f)
	check_eq(started_attacks, [&"sword_heavy"] as Array[StringName], "tap starts heavy")
	check_eq(combat.charge_tier, 0, "tap is a normal heavy")


func test_charge_reduces_movement() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	var f := frame(Vector2.DOWN, Vector2.RIGHT)
	await tick(heavy_down(f), 10)
	check_near(player.velocity.length(), player.movement.config.move_speed * 0.55, 0.5, "55 % speed while charging")


func test_tier_scales_damage() -> void:
	spawn_legacy_player()
	add_target(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(heavy_down(f))
	await tick(f, 45)
	await tick(heavy_up(f))
	await tick(f, 30)
	if check_eq(hits.size(), 1, "full heavy hits once"):
		var heavy := SWORD.get_attack(&"sword_heavy")
		check_eq(hits[0].charge_tier, 2, "hit carries full tier")
		check_near(hits[0].damage, heavy.damage * 1.9, 0.01, "full-tier damage multiplier")
		check(hits[0].hitstop > heavy.hitstop, "full tier has longer hitstop")


func test_dash_cancels_charge_and_loses_it() -> void:
	spawn_legacy_player()
	track_player_attacks()
	add_target(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(heavy_down(f))
	await tick(f, 24)
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash started from charge")
	check_eq(player.combat.state, CombatComponent.State.IDLE, "charge cancelled")
	await tick(f, 10)
	await tick(heavy_up(f))   # releasing after the cancel must not fire the lost charge
	await tick(f, 40)
	check_eq(started_attacks.size(), 0, "no heavy after cancelled charge")
	check_eq(hits.size(), 0, "no hit after cancelled charge")


func test_dash_in_light_startup_prevents_ghost_hit() -> void:
	spawn_legacy_player()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f), 3)
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "dash cancelled the light attack")
	check_eq(player.combat.state, CombatComponent.State.IDLE, "attack ended")
	check(player.combat.combo.current == null, "dash ended the combo")
	await tick(f, 60)
	check_eq(hits.size(), 0, "no ghost hit after cancel")


func test_heavy_startup_cancel_prevents_ghost_hit() -> void:
	spawn_legacy_player()
	add_target(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true
	await tick(f)   # tap -> heavy startup
	await tick(f, 3)
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "heavy startup is dash-cancelable")
	await tick(f, 60)
	check_eq(hits.size(), 0, "no ghost hit after heavy cancel")


func test_heavy_active_phase_not_cancelable_dash_buffered() -> void:
	spawn_legacy_player()
	add_target(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true
	await tick(f)
	while player.combat.phase != CombatComponent.Phase.ACTIVE:
		await tick(f)
	await tick(dash_press(f))
	check(not player.dash.is_dashing(), "no dash during heavy active phase")
	check_eq(player.combat.phase, CombatComponent.Phase.ACTIVE, "heavy keeps swinging")
	await tick(f, 6)
	check(player.dash.is_dashing(), "buffered dash fires in recovery")
	check_eq(hits.size(), 1, "the heavy hit landed before the dash")


func test_damage_before_cancel_persists_and_no_repeat() -> void:
	spawn_legacy_player()
	track_player_attacks()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	while hits.is_empty():
		await tick(f)
	await tick(dash_press(f))   # cancel during the active window, after the hit
	check(player.dash.is_dashing(), "light active phase is dash-cancelable")
	await tick(f, 60)
	check_eq(hits.size(), 1, "earlier hit stays, nothing repeats")
	check_eq(started_attacks.size(), 1, "attack never re-triggered by the cancel")


func test_heavy_continues_matching_combo() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	_charge_and_release(combat, 50)
	check_eq(started_attacks, [&"sword_light_1", &"sword_lh_thrust"] as Array[StringName], "L then charged H = L-H thrust")
	check_eq(combat.charge_tier, 2, "full tier on combo heavy")
