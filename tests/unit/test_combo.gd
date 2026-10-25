extends GameplayTestCase
## Combo tree: chains, restarts, timeout, pause during charge, aim per step,
## unlockable nodes and robustness against arbitrary input.

const MASTERY := &"mastery.one_handed_sword.1"


func test_light_light_light_chain() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	step_combat(combat, light(f))
	check_eq(combat.combo.path, [&"sword_light_1", &"sword_light_2", &"sword_light_3"] as Array[StringName], "L-L-L path")
	check_eq(combat.current_attack.id, &"sword_light_3", "third attack running")


func test_light_light_heavy_chain() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	step_combat(combat, heavy_down(f))
	check_eq(combat.state, CombatComponent.State.CHARGING, "charging after L-L")
	check_eq(combat.charging_attack.id, &"sword_llh_crush", "L-L-H resolves to crush")
	step_combat(combat, heavy_up(f))
	check_eq(combat.combo.path, [&"sword_light_1", &"sword_light_2", &"sword_llh_crush"] as Array[StringName], "L-L-H path")


func test_light_heavy_chain() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 12)
	step_combat(combat, heavy_down(f))
	step_combat(combat, heavy_up(f))
	check_eq(combat.current_attack.id, &"sword_lh_thrust", "L-H resolves to thrust")
	check_eq(combat.combo.path.size(), 2, "L-H path length")


func test_restart_after_last_node() -> void:
	var combat := new_combat()
	var f := frame()
	for i in 3:
		step_combat(combat, light(f))
		step_combat(combat, f, 22)
	step_combat(combat, light(f))
	# Mastery node locked: the 4th light restarts the combo.
	check_eq(combat.current_attack.id, &"sword_light_1", "combo restarted at root")
	check_eq(combat.combo.path, [&"sword_light_1"] as Array[StringName], "path restarted")


func test_mastery_unlock_adds_combo_node() -> void:
	var combat := new_combat()
	combat.set_unlocked(MASTERY, true)
	var f := frame()
	for i in 3:
		step_combat(combat, light(f))
		step_combat(combat, f, 22)
	step_combat(combat, light(f))
	check_eq(combat.current_attack.id, &"sword_light_4_mastery", "unlocked 4th node")
	check_eq(combat.combo.path.size(), 4, "path length 4")


func test_heavy_after_finisher_restarts_at_root_heavy() -> void:
	var combat := new_combat()
	var f := frame()
	for i in 3:
		step_combat(combat, light(f))
		step_combat(combat, f, 22)
	step_combat(combat, heavy_down(f))
	check_eq(combat.charging_attack.id, &"sword_heavy", "no L-L-L-H node -> root heavy")


func test_combo_window_and_timeout() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 40)   # finished at ~23 ticks, window 0.35 s still open
	check_eq(combat.state, CombatComponent.State.IDLE, "idle in combo window")
	step_combat(combat, light(f))
	check_eq(combat.current_attack.id, &"sword_light_2", "continues within window")

	var late := new_combat()
	step_combat(late, light(f))
	step_combat(late, f, 50)     # window expired at ~44 ticks
	check(late.combo.current == null, "combo reset after timeout")
	step_combat(late, light(f))
	check_eq(late.current_attack.id, &"sword_light_1", "restarts after timeout")


func test_heavy_charge_pauses_combo_window() -> void:
	var combat := new_combat()
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 40)   # ~4 ticks of window left
	step_combat(combat, heavy_down(f))
	step_combat(combat, f, 30)   # hold 0.5 s, far beyond the remaining window
	check(combat.combo.current != null, "combo kept alive while charging")
	step_combat(combat, heavy_up(f))
	check_eq(combat.current_attack.id, &"sword_lh_thrust", "charge resolved as L-H")
	check_eq(combat.charge_tier, 1, "0.5 s hold -> empowered")


func test_each_step_uses_new_aim_and_locks_it() -> void:
	var combat := new_combat()
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	step_combat(combat, light(f))
	check_eq(combat.attack_direction, Vector2.RIGHT, "first step aims right")
	f.aim_direction = Vector2.DOWN
	step_combat(combat, f, 5)
	check_eq(combat.attack_direction, Vector2.RIGHT, "direction locked during the attack")
	step_combat(combat, f, 7)
	f.aim_direction = Vector2.UP
	step_combat(combat, light(f))
	check_eq(combat.current_attack.id, &"sword_light_2", "second step started")
	check_eq(combat.attack_direction, Vector2.UP, "second step uses new aim")


func test_random_input_never_breaks_state() -> void:
	var combat := new_combat()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var f := frame()
	var held := false
	for i in 3000:
		f.aim_direction = Vector2.from_angle(rng.randf() * TAU)
		var roll := rng.randf()
		if roll < 0.08:
			light(f)
		elif roll < 0.12 and not held:
			heavy_down(f)
			held = true
		elif roll < 0.16 and held:
			heavy_up(f)
			held = false
		elif roll < 0.18 and combat.can_dash_cancel():
			combat.cancel(&"dash")
		step_combat(combat, f)
		if not _state_consistent(combat, i):
			return
	f.heavy_held = false
	step_combat(combat, f, 180)
	check_eq(combat.state, CombatComponent.State.IDLE, "settles to idle")
	check(combat.combo.current == null, "combo resets after inputs stop")


func _state_consistent(combat: CombatComponent, tick: int) -> bool:
	var ok := true
	match combat.state:
		CombatComponent.State.IDLE:
			ok = combat.current_attack == null and combat.charging_attack == null \
				and combat.phase == CombatComponent.Phase.NONE
		CombatComponent.State.CHARGING:
			ok = combat.charging_attack != null and combat.current_attack == null
		CombatComponent.State.ATTACKING:
			ok = combat.current_attack != null and combat.phase != CombatComponent.Phase.NONE
	# Every recorded path must follow the tree links.
	var path := combat.combo.path
	for j in range(1, path.size()):
		var previous := SWORD.get_attack(path[j - 1])
		var next := SWORD.get_attack(path[j])
		if previous.get_follow_up_id(next.input_type) != next.id:
			ok = false
	if not ok:
		fail("inconsistent state at tick %d: state=%d phase=%d path=%s" % [tick, combat.state, combat.phase, path])
	return ok
