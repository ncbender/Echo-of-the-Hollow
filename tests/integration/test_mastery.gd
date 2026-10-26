extends GameplayTestCase
## Weapon mastery: XP, level ups, max level, combo locks/unlocks, XP exploit guards.

const GREATSWORD: WeaponFamily = preload("res://data/weapons/two_handed_sword.tres")
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const SWORD_ID := &"one_handed_sword"
const GREAT_ID := &"two_handed_sword"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	db = GameDatabase.get_default()
	character = Character.new(db)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)


func _xp_to_level(family: StringName, level: int) -> int:
	var track := db.get_track(family)
	var total := 0
	for l in range(1, level):
		total += track.xp_to_next(l)
	return total


func test_database_loads_without_errors() -> void:
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	check(db.get_track(SWORD_ID) != null and db.get_track(GREAT_ID) != null, "tracks for both families")
	check_eq(db.get_track(SWORD_ID).max_level, 20, "max level 20")


func test_level_up_and_carry_over() -> void:
	var levels: Array[int] = []
	character.mastery.leveled_up.connect(func(_f: StringName, l: int) -> void: levels.append(l))
	var track := db.get_track(SWORD_ID)
	check_eq(character.mastery.add_xp(SWORD_ID, track.xp_to_next(1) + 7), 1, "one level gained")
	check_eq(character.mastery.get_level(SWORD_ID), 2, "level 2")
	check_eq(character.mastery.get_xp(SWORD_ID), 7, "excess XP carried over")
	check_eq(levels, [2] as Array[int], "leveled_up emitted once")
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 6) - _xp_to_level(SWORD_ID, 2) - 7)
	check_eq(levels, [2, 3, 4, 5, 6] as Array[int], "one signal per level for multi-level gains")


func test_max_level_caps() -> void:
	character.mastery.add_xp(SWORD_ID, 10_000_000)
	check_eq(character.mastery.get_level(SWORD_ID), 20, "capped at max level")
	check_eq(character.mastery.get_xp(SWORD_ID), 0, "no XP stored at max")
	check(character.mastery.is_max_level(SWORD_ID), "is_max_level")
	check_eq(character.mastery.add_xp(SWORD_ID, 50), 0, "no further levels")
	check_eq(character.mastery.get_level(GREAT_ID), 1, "other family untouched")


func test_invalid_xp_ignored() -> void:
	check_eq(character.mastery.add_xp(SWORD_ID, -50), 0, "negative XP ignored")
	check_eq(character.mastery.add_xp(&"unknown_family", 500), 0, "unknown family ignored")
	check_eq(character.mastery.get_xp(SWORD_ID), 0, "nothing stored")


func test_technique_locked_until_mastery_level() -> void:
	_bind()
	track_player_attacks()
	var f := frame()
	for i in 4:
		await tick(light(f))
		await tick(f, 22)
	check_eq(started_attacks[3], &"sword_light_1", "locked: 4th light restarts the combo")
	started_attacks.clear()
	check(not player.combat.combo.unlocks.has(&"mastery.one_handed_sword.1"), "locked at level 1")
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 3))
	check(player.combat.combo.unlocks.has(&"mastery.one_handed_sword.1"), "unlocked via signal at level 3")
	await tick(f, 60)
	for i in 4:
		await tick(light(f))
		await tick(f, 22)
	check_eq(started_attacks, [&"sword_light_1", &"sword_light_2", &"sword_light_3", &"sword_light_4_mastery"] as Array[StringName], "fourth light is the mastery technique")


func test_locked_node_not_executable_and_base_combos_intact() -> void:
	var combat := new_combat(GREATSWORD)
	var f := frame()
	for i in 4:
		step_combat(combat, light(f))
		step_combat(combat, f, 30)
	check_eq(started_attacks, [&"greatsword_light_1", &"greatsword_light_2", &"greatsword_light_3", &"greatsword_light_1"] as Array[StringName], "locked 4th node restarts the combo")
	combat.set_unlocked(&"mastery.two_handed_sword.1", true)
	started_attacks.clear()
	step_combat(combat, f, 60)
	for i in 4:
		step_combat(combat, light(f))
		step_combat(combat, f, 30)
	check_eq(started_attacks[3], &"greatsword_light_4_mastery", "unlocked greatsword technique")


func test_hits_give_mastery_xp_once_per_swing() -> void:
	_bind()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(22, 0)
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	var landed: Array[HitData] = []
	player.combat.hit_landed.connect(func(h: HitData) -> void: landed.append(h))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 24)
	check_eq(landed.size(), 1, "one hit")
	check_eq(character.mastery.get_xp(SWORD_ID), db.rules.mastery_xp_per_hit, "per-hit XP")
	# The same event delivered twice (e.g. duplicate callback) must not pay twice.
	player.combat.hit_landed.emit(landed[0])
	check_eq(character.mastery.get_xp(SWORD_ID), db.rules.mastery_xp_per_hit, "duplicate event ignored")


func test_clicks_without_hits_give_nothing() -> void:
	_bind()
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	for i in 6:
		await tick(light(f))
		await tick(f, 20)
	check_eq(character.mastery.get_xp(SWORD_ID), 0, "no XP for whiffs")
	check_eq(character.mastery.get_level(SWORD_ID), 1, "still level 1")


func test_training_dummy_xp_is_reduced_and_capped() -> void:
	_bind()
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(22, 0)
	add_child(dummy)
	dummy.health.max_health = 100000.0
	dummy.health.reset()
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 24)
	check_eq(character.mastery.get_xp(SWORD_ID), floori(db.rules.mastery_xp_per_hit * db.rules.training_xp_multiplier), "reduced XP")
	for i in 60:
		await tick(light(f))
		await tick(f, 24)
	check(dummy.hits_taken >= 60, "many hits landed (%d)" % dummy.hits_taken)
	check_eq(_total_xp(SWORD_ID), db.rules.training_xp_cap_per_target, "capped per training target")


func test_kill_rewards_once_and_switch_keeps_progress() -> void:
	_bind()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(22, 0)
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	var guard := 0
	while not enemy.health.is_dead() and guard < 40:
		guard += 1
		f.aim_direction = (enemy.global_position - player.global_position).normalized()
		await tick(light(f))
		await tick(f, 24)
	var sword_xp := _total_xp(SWORD_ID)
	check(enemy.health.is_dead(), "enemy killed")
	check(sword_xp >= enemy.config.mastery_xp_reward, "kill reward included (%d XP)" % sword_xp)
	# Switching weapons keeps sword progress and routes new XP to the greatsword.
	player.set_weapon_family(GREATSWORD)
	check_eq(_total_xp(SWORD_ID), sword_xp, "sword progress kept after switch")
	bridge.debug_add_mastery_xp(30)
	check_eq(character.mastery.get_xp(GREAT_ID), 30, "XP goes to the equipped family")
	check_eq(_total_xp(SWORD_ID), sword_xp, "sword progress still unchanged")


func test_mastery_serialization_roundtrip_and_clamping() -> void:
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 4) + 12)
	var data := character.mastery.to_dict()
	var restored := WeaponMastery.new(db)
	var warnings: PackedStringArray = []
	restored.from_dict(data, warnings)
	check_eq(restored.get_level(SWORD_ID), 4, "level restored")
	check_eq(restored.get_xp(SWORD_ID), 12, "xp restored")
	var broken := {"one_handed_sword": {"level": 999, "xp": -5}, "spears": {"level": 3, "xp": 1}}
	restored.from_dict(broken, warnings)
	check_eq(restored.get_level(SWORD_ID), 20, "level clamped to max")
	check_eq(restored.get_xp(SWORD_ID), 0, "xp clamped")
	check(restored.to_dict().has("spears"), "unknown family preserved for re-save")


func _total_xp(family: StringName) -> int:
	return _xp_to_level(family, character.mastery.get_level(family)) + character.mastery.get_xp(family)
