extends GameplayTestCase
## Class Foundation E: Shadowrunner vertical slice with the real data - focus
## gains, Weak Points from finishers and Expose Weakness, Execution consuming
## them, Shadowstep as a skill movement (walls, no dash charge, no iFrames, dash
## unchanged), talents, class switching and save/load.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const SAVE := "user://test_saves/shadowrunner.save.json"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var dispatched: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(&"shadowrunner")
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
	bridge.stat_modifier.rng.seed = 11
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void: dispatched.append(hit))


func _level(level: int) -> void:
	var definition := db.get_class_def(&"shadowrunner")
	var needed := -character.classes.get_xp(&"shadowrunner")
	for l in range(character.classes.get_level(&"shadowrunner"), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(&"shadowrunner", needed)


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _cast(skill_id: StringName, aim: Vector2 = Vector2.RIGHT, wait: int = 20) -> void:
	var slot := character.builds.get_build(&"shadowrunner").slot_of(skill_id)
	check(slot >= 0, "%s is slotted" % skill_id)
	var f := frame(Vector2.ZERO, aim)
	f.ability_slot = slot
	await tick(f)
	await tick(frame(Vector2.ZERO, aim), wait)


func _lll() -> void:
	var f := frame()
	for i in 3:
		await tick(light(f))
		await tick(f, 14)


func test_shadowrunner_data() -> void:
	var definition := db.get_class_def(&"shadowrunner")
	check(definition != null and definition.playable, "shadowrunner defined")
	check_eq(definition.resource.id, &"focus", "uses focus")
	check_eq(definition.innate_effects.size(), 2, "weak point mechanic as class effects")
	for tree_id in definition.talent_tree_ids:
		check(db.talent_trees[tree_id].validate(db.rules.talent_rules()).is_empty(), "%s valid" % tree_id)
	var skills := db.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == &"shadowrunner")
	check(skills.size() >= 6, "six+ skills (%d)" % skills.size())


func test_finishers_expose_weak_points_and_precise_hits_build_focus() -> void:
	_bind()
	var dummy := _dummy(Vector2(22, 0))
	await wait_physics(2)
	await _lll()
	var status := StatusComponent.of(dummy)
	check(status.has(&"weak_point"), "light finisher exposed a Weak Point")
	var focus := bridge.class_runtime.pool
	var before := focus.value
	dispatched.clear()
	await tick(light(frame()))
	await tick(frame(), 14)
	if check(dispatched.size() == 1, "one hit"):
		check(&"weak_point_hit" in dispatched[0].tags, "precise hit on the Weak Point")
	check(focus.value - before >= 5.0 + 10.0 - 0.01, "precise hit gives extra focus (%.1f)" % (focus.value - before))


func test_execution_consumes_weak_point_and_costs_focus() -> void:
	_level(8)
	_bind()
	var dummy := _dummy(Vector2(24, 0))
	await wait_physics(2)
	await _cast(&"expose_weakness")
	check(StatusComponent.of(dummy).has(&"weak_point"), "Expose Weakness applies a Weak Point")
	var focus := bridge.class_runtime.pool
	check(focus.value >= 15.0, "Expose Weakness grants focus (%.1f)" % focus.value)
	focus.gain(100.0)
	var before := focus.value
	await _cast(&"execution")
	var hits := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"execution")
	if check(hits.size() == 1, "execution landed"):
		check(&"consumed_weak_point" in hits[0].tags, "Weak Point consumed")
		check(hits[0].damage >= 26.0 + 40.0 - 0.01, "+40 damage from the Weak Point (%.1f)" % hits[0].damage)
	check(not StatusComponent.of(dummy).has(&"weak_point"), "gone after the execution")
	check(focus.value <= before - 40.0 + 25.0, "40 focus spent (gains from the hit aside)")
	dispatched.clear()
	bridge.class_runtime.cooldowns.clear()
	focus.gain(100.0)
	await _cast(&"execution")
	var plain := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"execution")
	if check(plain.size() == 1, "second execution"):
		check(not &"consumed_weak_point" in plain[0].tags, "no weak point - no bonus")


func test_shadowstep_is_a_skill_not_the_dash() -> void:
	_level(5)
	_bind()
	add_wall(Vector2(80, -60), Vector2(200, 10))
	await wait_physics(2)
	bridge.class_runtime.pool.gain(50.0)
	var start := player.global_position
	var charges := player.dash.charges
	var slot := character.builds.get_build(&"shadowrunner").slot_of(&"shadowstep")
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.ability_slot = slot
	await tick(f)
	var invulnerable := false
	for i in 10:
		invulnerable = invulnerable or player.hurtbox.is_invulnerable()
		await tick(frame(Vector2.ZERO, Vector2.RIGHT))
	check_near(player.global_position.x - start.x, 80.0, 3.0, "Shadowstep moves 80 px towards the aim")
	check_eq(player.dash.charges, charges, "no dash charge used")
	check(not player.dash.is_dashing(), "not a dash")
	check(not invulnerable, "no invulnerability frames")
	check_near(character.get_stat(Stats.CRIT_CHANCE), 5.0 + 15.0, 0.001, "+15% crit after the step")
	await tick(frame(), seconds_to_ticks(3.2))
	check_near(character.get_stat(Stats.CRIT_CHANCE), 5.0, 0.001, "buff expired")
	# walls stop it
	bridge.class_runtime.cooldowns.clear()
	var before_wall := player.global_position
	var up := frame(Vector2.ZERO, Vector2.UP)
	up.ability_slot = slot
	await tick(up)
	await tick(frame(Vector2.ZERO, Vector2.UP), 12)
	check(player.global_position.y > -60.0 + 5.0, "the wall stops Shadowstep (y = %.1f)" % player.global_position.y)
	check(before_wall.y - player.global_position.y < 80.0, "shorter than the full distance")
	# the normal dash is unchanged: two charges, aim direction
	await tick(dash_press(frame(Vector2.ZERO, Vector2.DOWN)))
	check(player.dash.is_dashing(), "Space still dashes")
	check_eq(player.dash.direction, Vector2.DOWN, "dash in aim direction")
	check_eq(player.dash.charges, player.dash.config.max_charges - 1, "dash uses its own charges")


func test_class_switch_swaps_mechanics() -> void:
	_bind()
	check(bridge.effects.has_effect(&"sr_expose_on_finisher"), "shadowrunner mechanic active")
	character.classes.unlock(&"warrior")
	check_eq(character.switch_class(&"warrior", true), "", "switched to warrior")
	check(not bridge.effects.has_effect(&"sr_expose_on_finisher"), "mechanic removed")
	check_eq(bridge.class_runtime.pool.definition.id, &"rage", "warrior resource")
	check_eq(character.builds.get_build().slots[0], &"furious_strike", "warrior skills on the bar")
	character.switch_class(&"shadowrunner", true)
	check_eq(bridge.class_runtime.pool.definition.id, &"focus", "back to focus")
	check_eq(character.builds.get_build().slots[0], &"shadow_strike", "own skill bar restored")


func test_assassin_talents_and_save_load() -> void:
	_level(14)
	var talents := {&"sr_as_precision": 3, &"sr_as_eye": 2}
	check(TalentService.validate_allocation(db, &"shadowrunner", 14, talents).is_empty(), "valid")
	character.builds.get_build().talents = talents
	character.builds.notify()
	check_near(character.get_stat(Stats.CRIT_CHANCE), 5.0 + 6.0, 0.001, "Precision ranks")
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok(), "loaded")
	check_eq(loaded.character.builds.get_build(&"shadowrunner").to_dict(), character.builds.get_build(&"shadowrunner").to_dict(), "build identical")
	check_near(loaded.character.get_stat(Stats.CRIT_CHANCE), 11.0, 0.001, "stats identical")
