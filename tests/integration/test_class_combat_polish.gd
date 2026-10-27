extends GameplayTestCase
## Class Combat Polish 0.3: Shadowrunner Focus regenerates passively (no Focus
## from normal hits), Focused Strikes talent procs only on direct weapon hits,
## and movement skills are no free dashes any more: Shadowstep and Blade Rush are
## target-bound gap closers (refused without a reachable target, nothing spent),
## Shadow Strike / Piercing Lunge are short attack lunges. Dash unchanged.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const BOSS_CONFIG: EnemyConfig = preload("res://data/enemies/grove_warden_config.tres")
const SAVE := "user://test_saves/class_combat_polish.save.json"
## Passive Shadowrunner Focus regeneration per second (Combat Defense & Feedback 0.4).
const REGEN := 6.0

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var dispatched: Array[HitData] = []
var messages: Array[String] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	for class_id: StringName in [&"shadowrunner", &"warrior"]:
		character.classes.unlock(class_id)
	character.switch_class(&"shadowrunner", true)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	player.set_weapon_family(SWORD)   # legacy engine: these class / effect checks use the pre-1.5 sword timings (Combat Flow: test_flow_integration)
	bridge.stat_modifier.rng.seed = 5
	bridge.effects.rng.seed = 5
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void: dispatched.append(hit))
	bridge.message.connect(func(text: String) -> void: messages.append(text))


func _level(class_id: StringName, level: int) -> void:
	var definition := db.get_class_def(class_id)
	var needed := -character.classes.get_xp(class_id)
	for l in range(character.classes.get_level(class_id), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(class_id, needed)


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _grunt(at: Vector2, config: EnemyConfig = null) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	if config != null:
		enemy.config = config
	enemy.position = at
	enemy.target = player
	add_child(enemy)
	return enemy


func _freeze(enemy: Enemy) -> void:
	enemy.config = enemy.config.duplicate()
	enemy.config.move_speed = 0.0
	enemy.config.attack_range = 0.0


func _cast(skill_id: StringName, aim: Vector2, wait: int = 20) -> void:
	var slot := character.builds.get_build().slot_of(skill_id)
	check(slot >= 0, "%s slotted" % skill_id)
	var f := frame(Vector2.ZERO, aim)
	f.ability_slot = slot
	await tick(f)
	await tick(frame(Vector2.ZERO, aim), wait)


# --- Focus ---------------------------------------------------------------------------

func test_focus_data_regenerates_and_has_no_hit_gains() -> void:
	var focus: ClassResourceDefinition = db.get_class_def(&"shadowrunner").resource
	check_eq(focus.regen_per_second, REGEN, "6 focus per second (0.4: was 8)")
	check_eq(focus.start_value, 50.0, "starts at 50")
	check_eq(focus.regen_delay, 0.0, "regenerates in combat too (no delay)")
	check_eq(focus.gain_per_hit_dealt, 0.0, "no focus per hit")
	check(focus.gain_per_tag.is_empty(), "no focus per finisher / weak point / crit")
	check_eq(focus.gain_per_poise_break + focus.gain_per_kill, 0.0, "no focus per poise break or kill")
	check_eq(focus.max_value, 100.0, "maximum 100")


func test_focus_regenerates_idle_and_in_combat_without_hit_gains() -> void:
	_bind()
	for y: float in [-10.0, 10.0]:
		_dummy(Vector2(22, y))
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	pool.spend(pool.value)
	await tick(frame(), 60)
	check_near(pool.value, REGEN, 0.3, "idle: +6 in one second")
	await tick(frame(), 90)
	check_near(pool.value, REGEN * 2.5, 0.3, "idle: +15 after 2.5 s")
	await tick(frame(), 150)
	check_near(pool.value, REGEN * 5.0, 0.4, "idle: +30 after 5 s (linear, delta based)")
	var before := pool.value
	var f := frame(Vector2(0.3, 0.0), Vector2.RIGHT)   # moving and attacking
	for i in 4:
		await tick(light(f))
		await tick(f, 14)
	var seconds := 60.0 / 60.0
	check(dispatched.size() >= 6, "the light chain hit the dummies (%d hits)" % dispatched.size())
	check_near(pool.value - before, REGEN * seconds, 0.3, "in combat: exactly the regeneration, no focus from hits")
	pool.gain(500.0)
	await tick(frame(), 30)
	check_eq(pool.value, pool.max_value(), "never above the maximum")


func test_focus_pauses_while_dead_and_resets_on_class_change() -> void:
	_bind()
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	pool.spend(pool.value)
	var hit := HitData.new()
	hit.damage = 100000.0
	player.hurtbox.receive_hit(hit)
	check(player.health.is_dead(), "player dead")
	await tick(frame(), 30)
	check_eq(pool.value, 0.0, "no regeneration while dead")
	await tick(frame(), seconds_to_ticks(player.respawn_delay) + 5)
	check(not player.health.is_dead(), "respawned")
	await tick(frame(), 30)
	check(pool.value > 3.0, "regenerates again after the respawn (%.1f)" % pool.value)
	character.switch_class(&"warrior", true)
	check_eq(bridge.class_runtime.pool.definition.id, &"rage", "warrior: rage pool")
	character.switch_class(&"shadowrunner", true)
	check_eq(bridge.class_runtime.pool.value, 50.0, "fresh focus pool starts at 50 (not saved, not carried over)")


func test_focused_strikes_procs_only_on_direct_weapon_hits() -> void:
	_level(&"shadowrunner", 20)
	var talents := {&"sr_bs_hands": 5, &"sr_bs_dance": 3}
	check(TalentService.validate_allocation(db, &"shadowrunner", 20, talents).is_empty(), "valid build")
	character.builds.get_build().talents = talents
	character.builds.notify()
	var node: TalentNodeDefinition = db.talent_nodes[&"sr_bs_dance"]
	check_eq(node.display_name, "Focused Strikes", "Dancing Blades became Focused Strikes")
	var effect := node.effects[0] as HitTriggerEffect
	check_eq(effect.chance, 0.25, "data-driven 25% chance")
	check(effect.once_per_swing, "at most once per swing")
	_bind()
	for y: float in [-12.0, 0.0, 12.0]:
		_dummy(Vector2(24, y))
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	var key := "talent:sr_bs_dance:0"
	effect.chance = 1.0   # deterministic for the test, restored below
	pool.spend(pool.value)
	var regen_before := pool.value
	dispatched.clear()
	await tick(light(frame()))
	await tick(frame(), 14)
	var swing_hits := dispatched.filter(func(h: HitData) -> bool: return h.is_direct()).size()
	check(swing_hits >= 2, "one swing hit several dummies (%d)" % swing_hits)
	check_eq(bridge.effects.source_state(key).get("triggers", 0), 1, "one proc per swing, not per target")
	check_near(pool.value - regen_before, 9.0 + REGEN * 15.0 / 60.0, 0.3, "3 ranks x 3 bonus focus + regeneration")
	for source: HitData.Source in [HitData.Source.SKILL, HitData.Source.TRIGGERED, HitData.Source.STATUS]:
		var other := HitData.new()
		other.source = source
		other.depth = 1 if source != HitData.Source.SKILL else 0
		other.attack_instance_id = 999 + source
		bridge.effects.dispatch_hit(other)
	check_eq(bridge.effects.source_state(key).get("triggers", 0), 1, "skill, essence/triggered and status hits never proc")
	effect.chance = 0.25


# --- Shadowstep ------------------------------------------------------------------------

func test_shadowstep_needs_a_target_and_spends_nothing_without_one() -> void:
	_level(&"shadowrunner", 5)
	_bind()
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	var focus := pool.value
	var start := player.global_position
	await _cast(&"shadowstep", Vector2.RIGHT, 1)
	check_eq(bridge.class_runtime.cooldown_left(&"shadowstep"), 0.0, "no cooldown without a target")
	check_near(pool.value, focus + REGEN * 2.0 / 60.0, 0.05, "no focus spent")
	check_eq(player.global_position, start, "no movement")
	check(messages.any(func(m: String) -> bool: return m.contains("No enemy")), "reason shown: %s" % [messages])
	_dummy(Vector2(-90, 0))   # behind the aim: outside the cone
	_dummy(Vector2(200, 0))   # in front, but out of range
	await wait_physics(2)
	await _cast(&"shadowstep", Vector2.RIGHT, 1)
	check_eq(bridge.class_runtime.cooldown_left(&"shadowstep"), 0.0, "targets behind or out of range do not count")


func test_shadowstep_closes_in_without_dash_charge_or_iframes() -> void:
	_level(&"shadowrunner", 5)
	_bind()
	var target := _dummy(Vector2(100, 10))
	await wait_physics(2)
	var charges := player.dash.charges
	var pool := bridge.class_runtime.pool
	var focus := pool.value
	var slot := character.builds.get_build().slot_of(&"shadowstep")
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.ability_slot = slot
	await tick(f)
	var invulnerable := false
	for i in 20:
		invulnerable = invulnerable or player.hurtbox.is_invulnerable()
		await tick(frame(Vector2.ZERO, Vector2.RIGHT))
	var gap := player.global_position.distance_to(target.global_position)
	check(gap < 24.0 and gap > 10.0, "arrived right in front of the target (gap %.1f)" % gap)
	check_eq(player.dash.charges, charges, "no dash charge used")
	check(not invulnerable, "no invulnerability")
	check(pool.value < focus, "focus spent")
	check(bridge.class_runtime.cooldown_left(&"shadowstep") > 0.0, "cooldown started")
	check(StatusComponent.of(target).has(&"weak_point"), "arrival hit exposed a Weak Point")
	var arrival := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"shadowstep")
	check_eq(arrival.size(), 1, "exactly one arrival hit")
	check_near(character.get_stat(Stats.CRIT_CHANCE), 5.0 + 15.0, 0.001, "crit buff after arriving")
	await tick(dash_press(frame(Vector2.ZERO, Vector2.LEFT)))
	check(player.dash.is_dashing(), "Space dash still works")
	check_eq(player.dash.direction, Vector2.LEFT, "dash towards the aim")


func test_shadowstep_never_passes_walls() -> void:
	_level(&"shadowrunner", 5)
	_bind()
	add_wall(Vector2(50, 0), Vector2(10, 80))
	_dummy(Vector2(100, 0))
	await wait_physics(2)
	var focus := bridge.class_runtime.pool.value
	var start := player.global_position
	await _cast(&"shadowstep", Vector2.RIGHT, 20)
	check_eq(bridge.class_runtime.cooldown_left(&"shadowstep"), 0.0, "blocked path: refused")
	check(bridge.class_runtime.pool.value >= focus, "nothing spent")
	check(player.global_position.distance_to(start) < 0.5, "no movement through the wall")
	check(messages.any(func(m: String) -> bool: return m.contains("blocked")), "reason shown")


func test_shadowstep_against_grunt_and_boss() -> void:
	_level(&"shadowrunner", 5)
	_bind()
	for config: EnemyConfig in [null, BOSS_CONFIG]:
		var enemy := _grunt(player.global_position + Vector2(90, 0), config)
		_freeze(enemy)
		await wait_physics(3)
		bridge.class_runtime.cooldowns.clear()
		bridge.class_runtime.pool.gain(100.0)
		dispatched.clear()
		await _cast(&"shadowstep", Vector2.RIGHT, 20)
		var gap := player.global_position.distance_to(enemy.global_position)
		check(gap < 26.0, "%s: closed in (gap %.1f)" % ["boss" if config else "grunt", gap])
		check(dispatched.any(func(h: HitData) -> bool: return h.skill_id == &"shadowstep" and h.target == enemy), "arrival hit on the enemy")
		enemy.queue_free()
		await tick(frame(), 40)


# --- Other movement skills -----------------------------------------------------------

func test_blade_rush_is_a_target_bound_charge() -> void:
	character.switch_class(&"warrior", true)
	_level(&"warrior", 5)
	_bind()
	await wait_physics(2)
	bridge.class_runtime.pool.gain(100.0)
	var rage := bridge.class_runtime.pool.value
	await _cast(&"blade_rush", Vector2.RIGHT, 1)
	check_eq(bridge.class_runtime.cooldown_left(&"blade_rush"), 0.0, "no target: no charge")
	check(bridge.class_runtime.pool.value >= rage - 0.5, "no rage spent")
	var target := _dummy(Vector2(95, 0))
	var grazed := _dummy(Vector2(50, 16))   # beside the path (a body IN the path blocks the charge)
	await wait_physics(2)
	await _cast(&"blade_rush", Vector2.RIGHT, 25)
	var hits := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"blade_rush")
	check(hits.any(func(h: HitData) -> bool: return h.target == target), "arrival strike on the target")
	check(hits.any(func(h: HitData) -> bool: return h.target == grazed), "enemy beside the path grazed")
	check(player.global_position.distance_to(target.global_position) < 24.0, "ended in front of the target")


func test_lunges_are_short_and_strike_on_arrival() -> void:
	_bind()
	var dummy := _dummy(Vector2(46, 0))
	await wait_physics(2)
	var start := player.global_position
	await _cast(&"shadow_strike", Vector2.RIGHT, 20)
	check_near(player.global_position.x - start.x, 24.0, 1.0, "Shadow Strike lunges 24 px (was a 50 px dart)")
	check(StatusComponent.of(dummy).has(&"weak_point"), "the strike after the lunge exposed a Weak Point")
	var params := ClassRuntime.new()
	params.character = character
	var long := SkillModDefinition.new()
	long.range_multiplier = 3.0
	var lunge := (db.skills[&"shadow_strike"] as SkillDefinition).actions[0] as MoveAction
	var stretched := SkillParams.resolve(db.skills[&"shadow_strike"], [long] as Array[SkillModDefinition])
	check_eq(lunge.travel(stretched), MoveAction.MAX_LUNGE, "skill lunges are capped (no free dash through mods)")
	var pierce := db.skill_mods[&"furious_lunge"] as SkillModDefinition
	check_eq((pierce.replace_actions[0] as MoveAction).distance, 36.0, "Piercing Lunge = sword thrust length")


func test_no_skill_moves_freely_further_than_a_lunge() -> void:
	for skill: SkillDefinition in db.skills.values():
		for action in skill.actions:
			if action is MoveAction:
				check((action as MoveAction).distance <= MoveAction.MAX_LUNGE, "%s: free movement only as a short lunge" % skill.id)
	for mod: SkillModDefinition in db.skill_mods.values():
		for action in mod.replace_actions + mod.extra_actions:
			if action is MoveAction:
				check((action as MoveAction).distance <= MoveAction.MAX_LUNGE, "%s: free movement only as a short lunge" % mod.id)
	for skill_id: StringName in [&"shadowstep", &"blade_rush"]:
		check((db.skills[skill_id] as SkillDefinition).actions[0] is GapCloserAction, "%s is a gap closer" % skill_id)


func test_save_load_and_focus_not_persisted() -> void:
	_level(&"shadowrunner", 20)
	character.builds.get_build().talents = {&"sr_bs_hands": 5, &"sr_bs_dance": 2}
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "loads cleanly: %s" % [loaded.warnings])
	check_eq(loaded.character.builds.get_build(&"shadowrunner").rank(&"sr_bs_dance"), 2, "Focused Strikes ranks kept (same node id)")
	check(not loaded.character.to_dict().has("focus"), "focus value is runtime only")
