extends GameplayTestCase
## Parry Timing Cue 1.0 (docs/PARRY_TIMING_CUE_1_0.md): the whole chain with the real player and real enemies -
## an elite's / boss's parryable attack starts, the cue flashes, the player presses Shift `r` seconds later, and the
## real hit is parried by the real DefenseComponent. Too early and too late presses are not (the cue is a moment, not
## a promise). No cue for normal enemies, non-parryable attacks, a stagger or death; one cue per attack; data unchanged.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const HUSK := "res://data/enemies/hardened_husk.tres"
const GRUNT := "res://data/enemies/grunt_config.tres"
const SENTINEL := "res://data/enemies/rootbound_sentinel.tres"
const SENTINEL_ATTACKS := "res://data/enemies/sentinel_attacks.tres"
const WARDEN := "res://data/enemies/grove_warden_config.tres"
const WARDEN_ATTACKS := "res://data/enemies/grove_warden_attacks.tres"
## Reaction times after the cue that must parry (inside the band REACTION +- window / 2 of every guard).
const GOOD_REACTIONS: Array[float] = [0.13, 0.16, 0.19, 0.22, 0.25]


func _enemy(config_path: String, attacks_path: String = "") -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.config = load(config_path)
	if attacks_path != "":
		enemy.attacks = load(attacks_path)
	enemy.position = Vector2(22, 0)
	enemy.target = player
	add_child(enemy)
	return enemy


func _view(enemy: Enemy) -> EnemyView:
	return enemy.get_node("View") as EnemyView


## One duel: the enemy attacks once; Shift is pressed `reaction` s after the cue (never without a cue). Returns
## {cued, parried, cues, window, lead}.
func _duel(config_path: String, attacks_path: String, reaction: float) -> Dictionary:
	spawn_player()
	var parried := [false]
	player.defense.parried.connect(func(_hit: HitData) -> void: parried[0] = true)
	var enemy := _enemy(config_path, attacks_path)
	var view := _view(enemy)
	await wait_physics(1)
	var cue_tick := -1
	var press_tick := -1
	var first_attack := -1
	for i in 240:
		var f := frame(Vector2.ZERO, Vector2.RIGHT)
		if press_tick >= 0 and i == press_tick:
			f.defend_pressed = true
		f.defend_held = press_tick >= 0 and i >= press_tick and i < press_tick + 4
		await tick(f)
		if first_attack < 0 and enemy.combat.state == CombatComponent.State.ATTACKING:
			first_attack = enemy.combat.attack_instance
		if cue_tick < 0 and view.cue_count > 0:
			cue_tick = i
			press_tick = i + seconds_to_ticks(reaction)
		if first_attack >= 0 and (enemy.combat.attack_instance != first_attack or enemy.combat.phase == CombatComponent.Phase.RECOVERY):
			break
	var result := {"cued": cue_tick >= 0, "parried": parried[0], "cues": view.cue_count,
		"window": ParryCue.window_of(player), "lead": ParryCue.lead(ParryCue.window_of(player))}
	enemy.queue_free()
	player.queue_free()
	await wait_physics(1)
	return result


## The Hardened Husk's swipe (elite): parried for every reaction in the band; a press right at the cue (window over
## before the hit) and one after the hit are not.
func test_husk_swipe_cue_then_real_parry() -> void:
	for reaction in GOOD_REACTIONS:
		var duel: Dictionary = await _duel(HUSK, "", reaction)
		check(duel.cued and duel.cues == 1, "%.2f s: one cue for the swipe" % reaction)
		check(duel.parried, "%.2f s after the cue: the real hit is parried (window %.2f, lead %.3f)" % [reaction, duel.window, duel.lead])
	var early: Dictionary = await _duel(HUSK, "", 0.0)
	check(early.cued and not early.parried, "pressed on the cue frame: the window closes before the hit")
	var late: Dictionary = await _duel(HUSK, "", 0.4)
	check(late.cued and not late.parried, "0.40 s: after the hit, too late")


## A boss: the Rootbound Sentinel's strike (parryable) - cue and a real parry.
func test_boss_strike_cue_then_real_parry() -> void:
	for reaction: float in [0.16, 0.22]:
		var duel: Dictionary = await _duel(SENTINEL, SENTINEL_ATTACKS, reaction)
		check(duel.cued and duel.parried, "Sentinel strike, %.2f s: cue and parry" % reaction)


## No cue: a normal grunt (it stays parryable), the Grove Warden (swipe block-only, slam undefendable), the husk's
## block-only slam; the husk cues its swipe and not its slam.
func test_no_cue_where_it_does_not_belong() -> void:
	var grunt: Dictionary = await _duel(GRUNT, "", 0.19)
	check(not grunt.cued, "normal grunt: no cue")
	spawn_player()
	var parried := [false]
	player.defense.parried.connect(func(_hit: HitData) -> void: parried[0] = true)
	var enemy := _enemy(GRUNT)
	for i in 120:   # a normal grunt stays parryable: Shift held from the start of its swipe
		var f := frame()
		if enemy.combat.state == CombatComponent.State.ATTACKING and enemy.combat.phase == CombatComponent.Phase.STARTUP \
				and ParryCue.time_to_hit(enemy.combat) <= 0.1 and player.defense.state == DefenseComponent.State.IDLE and not parried[0]:
			f.defend_pressed = true
			f.defend_held = true
		await tick(f)
		if parried[0]:
			break
	check(parried[0] and _view(enemy).cue_count == 0, "a normal grunt is still parried - without any cue")
	enemy.queue_free()
	player.queue_free()
	await wait_physics(1)
	# Grove Warden: two attacks (block-only swipe, undefendable slam) - no cue
	spawn_player()
	var warden := _enemy(WARDEN, WARDEN_ATTACKS)
	var kinds := {}
	for i in 600:
		await tick(frame())
		if warden.combat.state == CombatComponent.State.ATTACKING:
			kinds[warden.combat.current_attack.id] = true
		if kinds.size() >= 2:
			break
	check(kinds.size() >= 2 and _view(warden).cue_count == 0, "Grove Warden swipe and slam: no cue (%s)" % [kinds.keys()])
	warden.queue_free()
	player.queue_free()
	await wait_physics(1)
	# the husk: swipe cued, slam not
	spawn_player()
	var husk := _enemy(HUSK)
	var cued_ids := {}
	var seen := {}
	var last_count := 0
	for i in 600:
		await tick(frame())
		if husk.combat.state == CombatComponent.State.ATTACKING:
			seen[husk.combat.current_attack.id] = true
		if _view(husk).cue_count > last_count:
			last_count = _view(husk).cue_count
			cued_ids[husk.combat.current_attack.id] = true
		if seen.has(&"husk_slam") and husk.combat.state != CombatComponent.State.ATTACKING:
			break
	check(seen.has(&"husk_swipe") and seen.has(&"husk_slam"), "the husk used swipe and slam")
	check(cued_ids.has(&"husk_swipe") and not cued_ids.has(&"husk_slam"), "only the swipe is cued (%s)" % [cued_ids.keys()])
	husk.queue_free()


## One cue per attack (no repeat over the startup ticks), none after a stagger or for a dead enemy, and never a late
## flash for a moment already gone.
func test_lifecycle() -> void:
	spawn_player()
	var husk := _enemy(HUSK)
	var view := _view(husk)
	var emitted: Array[int] = []
	view.parry_cue.connect(func(instance: int) -> void: emitted.append(instance))
	for i in 240:
		await tick(frame())
		if view.cue_count > 0 and husk.combat.phase != CombatComponent.Phase.STARTUP:
			break
	check_eq(emitted.size(), 1, "one cue for one attack")
	check(view.cue_visible() or view.cue_count == 1, "the flash ran")
	husk.queue_free()
	player.queue_free()
	await wait_physics(1)
	# staggered in the startup before the cue: no cue for that attack
	spawn_player()
	husk = _enemy(HUSK)
	view = _view(husk)
	for i in 240:
		await tick(frame())
		if husk.state == Enemy.State.TELEGRAPH:
			break
	var breaker := HitData.new()
	breaker.poise_damage = 9999.0
	husk.hurtbox.receive_hit(breaker)
	for i in 20:
		await tick(frame())
	check_eq(view.cue_count, 0, "staggered before the moment: no cue")
	# killed during the next startup: no cue, no flash
	for i in 240:
		await tick(frame())
		if husk.state == Enemy.State.TELEGRAPH:
			break
	var before := view.cue_count
	var kill := HitData.new()
	kill.damage = 99999.0
	husk.health.apply_hit(kill)
	for i in 40:
		await tick(frame())
	check(view.cue_count == before and not view.cue_visible(), "dead: no cue, no flash")
	husk.queue_free()
	player.queue_free()
	await wait_physics(1)
	# an attack first observed after its moment: no late flash
	spawn_player()
	husk = _enemy(HUSK)
	view = _view(husk)
	view.set_physics_process(false)
	for i in 240:
		await tick(frame())
		if husk.state == Enemy.State.TELEGRAPH and ParryCue.time_to_hit(husk.combat) < ParryCue.lead(ParryCue.window_of(player)) - ParryCue.LATE - 0.02:
			break
	view.set_physics_process(true)
	await tick(frame())
	check_eq(view.cue_count, 0, "a missed moment is not flashed afterwards")
	husk.queue_free()


## The data the cue reads stays as it was: flags, startups, active times of the content's attacks; the ranks.
func test_data_unchanged() -> void:
	var expected := {&"grunt_swipe": [3, 0.45, 0.1], &"grunt_slam": [7, 0.7, 0.12], &"husk_swipe": [3, 0.45, 0.1], &"husk_slam": [1, 0.7, 0.12],
		&"warden_swipe": [1], &"warden_slam": [0], &"sentinel_strike": [3], &"sentinel_root_slam": [1]}
	for path: String in ["res://data/enemies/grunt_attacks.tres", "res://data/enemies/hardened_husk_attacks.tres", WARDEN_ATTACKS, SENTINEL_ATTACKS]:
		for attack: AttackDefinition in (load(path) as WeaponFamily).attacks:
			var values: Array = expected[attack.id]
			check_eq(attack.defense_flags, int(values[0]), "%s flags" % attack.id)
			if values.size() > 1:
				check(is_equal_approx(attack.startup, values[1]) and is_equal_approx(attack.active, values[2]), "%s timings" % attack.id)
	for pair: Array in [[HUSK, 1], [GRUNT, 0], [SENTINEL, 2], [WARDEN, 2], ["res://data/enemies/sanctum_warden.tres", 2],
			["res://data/enemies/bastion_guardian.tres", 2], ["res://data/enemies/passage_alpha.tres", 2]]:
		check_eq((load(pair[0]) as EnemyConfig).rank, pair[1], "%s rank" % String(pair[0]).get_file())
