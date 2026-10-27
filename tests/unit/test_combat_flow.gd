extends GameplayTestCase
## Combat Flow 1.5 state machine on a bare CombatComponent with a family built
## here (one-handed sword reference timings): mastery-gated paths, one buffered
## input, transition at 75 % of the recovery, too-early / locked / full-buffer
## inputs are dropped, buffer cleared at recovery end, no hidden combos at
## level 1, defensive cancel windows, burden on the recovery only, phase
## movement, frame-rate independence, instant heavies.

const QUICK := [0.14, 0.11, 0.30]
const HEAVY := [0.27, 0.14, 0.44]
const PATHS := {"LLL": 2, "LLH": 4, "LHL": 6, "HLL": 9, "LHH": 11, "HLH": 14, "HHL": 17, "HHH": 20}

var results: Array[String] = []


func before_each() -> void:
	super.before_each()
	results.clear()
	started_attacks.clear()


static func make_family() -> WeaponFamily:
	var family := WeaponFamily.new()
	family.id = &"test_flow"
	family.display_name = "Test Flow"
	var nodes := {}
	for path: String in PATHS:
		var definition := ComboPathDefinition.new()
		definition.inputs = path
		definition.unlock_level = PATHS[path]
		definition.display_name = "Path " + path
		family.combo_paths.append(definition)
		for length in range(1, 4):
			nodes[path.left(length)] = true
	for sequence: String in nodes:
		var attack := AttackDefinition.new()
		attack.id = StringName("t_" + sequence.to_lower())
		attack.weapon_family_id = family.id
		attack.combo_input = sequence
		attack.display_name = "Path " + sequence if PATHS.has(sequence) else sequence
		var heavy := sequence.right(1) == "H"
		var timing: Array = HEAVY if heavy else QUICK
		attack.input_type = AttackDefinition.InputType.HEAVY if heavy else AttackDefinition.InputType.LIGHT
		attack.startup = timing[0]
		attack.active = timing[1]
		attack.recovery = timing[2]
		attack.windup_move = 0.65 if heavy else 0.8
		attack.active_move = 0.5 if heavy else 0.7
		if sequence.length() == 1:
			attack.flow_role = AttackDefinition.FlowRole.BASE_HEAVY if heavy else AttackDefinition.FlowRole.BASE_QUICK
		elif PATHS.has(sequence):
			attack.flow_role = AttackDefinition.FlowRole.HEAVY_FINISHER if heavy else AttackDefinition.FlowRole.QUICK_FINISHER
		else:
			attack.flow_role = AttackDefinition.FlowRole.COMBO_STEP
		family.attacks.append(attack)
	return family


func flow_combat(level: int) -> CombatComponent:
	var combat := new_combat(make_family())
	combat.mastery_level = level
	combat.flow_input.connect(func(symbol: String, result: StringName) -> void: results.append("%s:%s" % [symbol, result]))
	return combat


## Advances `combat` by `seconds` in steps of `delta` (no input).
func run(combat: CombatComponent, seconds: float, delta: float = FRAME) -> void:
	var f := frame()
	var left := seconds
	while left > 0.000001:
		var step := minf(delta, left)
		combat.step(step, f, f.aim_direction)
		left -= step


func press(combat: CombatComponent, symbol: String, delta: float = FRAME) -> void:
	var f := frame()
	if symbol == "L":
		f.light_pressed = true
	else:
		f.heavy_pressed = true
		f.heavy_held = true
	combat.step(delta, f, f.aim_direction)


func test_data_family_is_valid() -> void:
	check_eq(make_family().validate().size(), 0, "test family validates: %s" % [make_family().validate()])


func test_level_one_only_base_attacks() -> void:
	var combat := flow_combat(1)
	press(combat, "L")
	check_eq(combat.current_attack.combo_input, "L", "quick started")
	run(combat, 0.40)
	press(combat, "L")   # inside the would-be combo window
	check(results.back() == "L:locked", "no L-L before level 2: %s" % results.back())
	check_eq(combat.current_attack.combo_input, "L", "the quick runs on")
	run(combat, 0.3)
	check_eq(combat.state, CombatComponent.State.IDLE, "recovery over, chain closed")
	press(combat, "L")
	check_eq(started_attacks, [&"t_l", &"t_l"] as Array[StringName], "only a NEW press after the recovery starts a new single attack")
	run(combat, 0.6)
	press(combat, "H")
	check_eq(combat.current_attack.combo_input, "H", "heavy starts instantly on RMB down")
	check_eq(combat.state, CombatComponent.State.ATTACKING, "no charging state")


func test_level_gates_follow_paths() -> void:
	for level in [1, 2, 4, 6, 9, 11, 14, 17, 20]:
		var family := make_family()
		for path: String in PATHS:
			var open: bool = level >= int(PATHS[path])
			check_eq(family.allows(path, level), open, "Lv%d %s" % [level, path])
		check_eq(family.allows("HH", level), level >= 17, "Lv%d H-H prefix" % level)
		check_eq(family.allows("LH", level), level >= 6, "Lv%d L-H prefix" % level)
		check_eq(family.allows("LL", level), level >= 2, "Lv%d L-L prefix" % level)


func test_level_two_lll_and_locked_third_heavy() -> void:
	var combat := flow_combat(2)
	press(combat, "L")
	run(combat, 0.33)
	press(combat, "L")
	check(results.back() == "L:buffered", "L-L buffered: %s" % results.back())
	run(combat, 0.2)
	check_eq(combat.chain, "LL", "L-L running")
	run(combat, 0.33)
	press(combat, "H")
	check(results.back() == "H:locked", "L-L-H locked until level 4")
	run(combat, 0.3)
	check_eq(combat.state, CombatComponent.State.IDLE, "chain closed")
	check_eq(started_attacks, [&"t_l", &"t_ll"] as Array[StringName], "the locked input started nothing")
	# the same at level 4
	combat = flow_combat(4)
	started_attacks.clear()
	press(combat, "L")
	run(combat, 0.33)
	press(combat, "L")
	run(combat, 0.53)
	press(combat, "H")
	run(combat, 0.2)
	check_eq(combat.chain, "LLH", "level 4: L-L-H")


func test_transition_exactly_at_75_percent_of_recovery() -> void:
	var combat := flow_combat(2)
	var delta := 0.001
	press(combat, "L", delta)
	check_near(combat.transition_time(), 0.14 + 0.11 + 0.30 * 0.75, 0.0001, "transition = windup + active + 75 % recovery")
	check_near(combat.accept_from(), 0.475 - 0.18, 0.0001, "accept from transition - 180 ms")
	run(combat, 0.290, delta)
	press(combat, "L", delta)
	check(results.back() == "L:too_early", "4 ms before the window: dropped (%s)" % results.back())
	run(combat, 0.005, delta)
	press(combat, "L", delta)
	check(results.back() == "L:buffered", "inside the window: buffered")
	press(combat, "L", delta)
	check(results.back() == "L:locked" or results.back() == "L:buffer_full", "second input not queued: %s" % results.back())
	var elapsed := combat.attack_clock()
	while combat.chain == "L":
		run(combat, delta, delta)
		elapsed += delta
	check_near(elapsed - combat.attack_clock(), 0.475, 0.0015, "transitioned at 475 ms")


func test_late_input_transitions_immediately_and_buffer_clears() -> void:
	var combat := flow_combat(2)
	press(combat, "L")
	run(combat, 0.50)
	check_eq(combat.phase, CombatComponent.Phase.RECOVERY, "past the transition point")
	press(combat, "L")
	check_eq(combat.chain, "LL", "input after the transition point continues at once")
	# a buffered input that never transitions because the chain cannot continue
	combat = flow_combat(2)
	press(combat, "H")
	run(combat, 0.75)
	press(combat, "L")
	check(results.back() == "L:locked", "H-L locked at level 2")
	run(combat, 0.4)
	check_eq(combat.state, CombatComponent.State.IDLE, "recovery ended")
	check_eq(combat.buffered, "", "buffer empty at chain end")
	run(combat, 0.3)
	check_eq(combat.state, CombatComponent.State.IDLE, "nothing replays a dropped input")


func test_one_press_is_one_step() -> void:
	var combat := flow_combat(20)
	press(combat, "L")
	run(combat, 0.33)
	press(combat, "L")
	press(combat, "H")
	press(combat, "L")
	run(combat, 1.5)
	check_eq(started_attacks, [&"t_l", &"t_ll"] as Array[StringName], "three presses inside one window: only one step")
	check_eq(combat.state, CombatComponent.State.IDLE, "no autoplay to a finisher")


func test_full_paths_at_level_twenty() -> void:
	for path: String in PATHS:
		var combat := flow_combat(20)
		started_attacks.clear()
		for index in path.length():
			press(combat, path[index])
			run(combat, 0.5 if path[index] == "L" else 0.78)
		check_eq(started_attacks.size(), 3, "%s: three steps" % path)
		check_eq(String(started_attacks.back()), "t_" + path.to_lower(), "%s ends on its finisher" % path)


func test_defense_cancel_windows() -> void:
	var cases := [["L", 1, 0.50], ["H", 1, 0.65]]
	for case: Array in cases:
		var combat := flow_combat(case[1])
		press(combat, case[0])
		check(not combat.can_dash_cancel(), "%s windup committed" % case[0])
		check(combat.refuses_defense_input(), "%s dash refused in windup" % case[0])
		while combat.phase != CombatComponent.Phase.RECOVERY:
			run(combat, 0.001, 0.001)
		check(not combat.can_dash_cancel(), "%s recovery start committed" % case[0])
		var recovery: float = combat.current_attack.recovery
		run(combat, recovery * float(case[2]) - 0.003, 0.001)
		check(not combat.can_dash_cancel(), "%s just before %d %%" % [case[0], roundi(float(case[2]) * 100)])
		run(combat, 0.004, 0.001)
		check(combat.can_dash_cancel(), "%s open at %d %% of the recovery" % [case[0], roundi(float(case[2]) * 100)])
	# combo step 55 %, finishers 65 % / 75 % (ratios by role)
	var combat := flow_combat(20)
	var family := combat.weapon
	check_near(combat.defense_cancel_ratio(family.node("LL")), 0.55, 0.0001, "combo step 55 %")
	check_near(combat.defense_cancel_ratio(family.node("LLL")), 0.65, 0.0001, "quick finisher 65 %")
	check_near(combat.defense_cancel_ratio(family.node("LLH")), 0.75, 0.0001, "heavy finisher 75 %")
	check(not combat.allows_other_action() or combat.state == CombatComponent.State.IDLE, "skills only in neutral")
	press(combat, "L")
	check(not combat.allows_other_action(), "no skill or drink cancel during an attack")


func test_burden_lengthens_only_the_recovery() -> void:
	var combat := flow_combat(2)
	combat.recovery_multiplier = 1.08
	press(combat, "L", 0.001)
	check_near(combat.transition_time(), 0.14 + 0.11 + 0.30 * 1.08 * 0.75, 0.0001, "transition on the lengthened recovery")
	check_near(combat.defense_cancel_time(), 0.25 + 0.30 * 1.08 * 0.5, 0.0001, "cancel window on the lengthened recovery")
	check_near(combat.current_total_duration(), 0.14 + 0.11 + 0.324, 0.0001, "windup and active unchanged")
	combat.recovery_multiplier = 1.0
	check_near(combat.current_total_duration(), 0.574, 0.0001, "snapshot at attack start: a change mid-attack does not apply")


func test_phase_movement_factors() -> void:
	var combat := flow_combat(1)
	check_near(combat.get_move_multiplier(), 1.0, 0.0001, "neutral 100 %")
	press(combat, "L", 0.001)
	check_near(combat.get_move_multiplier(), 0.8, 0.0001, "windup factor")
	run(combat, 0.15, 0.001)
	check_near(combat.get_move_multiplier(), 0.7, 0.0001, "active factor")
	run(combat, 0.11 + 0.10, 0.001)
	check_near(combat.get_move_multiplier(), 0.8, 0.0001, "first half of the recovery keeps the windup factor")
	run(combat, 0.115, 0.001)
	check_near(combat.get_move_multiplier(), 0.9, 0.005, "three quarters: halfway back to 100 %")


func test_frame_rate_independent_transition() -> void:
	var clocks: Array[float] = []
	for delta: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		var combat := flow_combat(2)
		press(combat, "L", delta)
		var elapsed := 0.0
		var pressed := false
		var f := frame()
		while combat.chain != "LL" and elapsed < 2.0:
			if not pressed and combat.attack_clock() >= 0.31:
				f.light_pressed = true
				pressed = true
			combat.step(delta, f, f.aim_direction)
			f.clear_edges()
			elapsed += delta
		clocks.append(elapsed - combat.attack_clock())
	for clock in clocks:
		check_near(clock, 0.475, 0.0005, "L-L transition at 475 ms at every frame rate (%s)" % [clocks])


func test_cancel_clears_the_chain_and_buffer() -> void:
	var combat := flow_combat(2)
	press(combat, "L")
	run(combat, 0.33)
	press(combat, "L")
	check_eq(combat.buffered, "LL", "buffered")
	run(combat, 0.02)
	combat.cancel(&"stun")
	check_eq(combat.buffered, "", "stun clears the buffer")
	check_eq(combat.chain, "", "and the chain")
	run(combat, 0.5)
	check_eq(started_attacks.size(), 1, "no phantom attack after the cancel")
