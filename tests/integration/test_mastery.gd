extends GameplayTestCase
## Weapon Mastery 1.4: XP curve, level ups, max level; levels unlock combo
## paths (never passive stats); XP only from kills, split by the weapon damage
## each family contributed (not per hit, not only the last hit); no XP from
## whiffs or training targets; progress per family survives class changes.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const SWORD_ID := &"one_handed_sword"
const GREAT_ID := &"two_handed_sword"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	super.before_each()
	db = GameDatabase.get_default()
	character = Character.new(db)
	started_attacks.clear()


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


func _grunt(at: Vector2) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	return enemy


func _hit(family_id: StringName, target: Node, damage: float, instance: int) -> HitData:
	var hit := HitData.new()
	hit.attack = (db.weapons[family_id] as WeaponFamily).node("L")
	hit.target = target
	hit.damage = damage
	hit.attack_instance_id = instance
	return hit


func test_database_loads_without_errors() -> void:
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	for family_id: StringName in db.weapons:
		check(db.get_track(family_id) != null, "mastery track for %s" % family_id)
		check_eq(db.get_track(family_id).max_level, 20, "%s: levels 1-20" % family_id)
	check_eq(db.weapons.size(), 9, "nine weapon families")


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


func test_levels_unlock_paths_through_the_bridge() -> void:
	_bind()
	track_player_attacks()
	var unlocked: Array[String] = []
	character.mastery.path_unlocked.connect(func(_f: StringName, path: ComboPathDefinition) -> void: unlocked.append(path.inputs))
	check_eq(player.combat.mastery_level, 1, "level 1 at start")
	await perform_path("LLL")
	check_eq(started_attacks.size(), 1, "level 1: L-L-L does not exist yet (one base attack)")
	started_attacks.clear()
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 4))
	check_eq(unlocked, ["LLL", "LLH"], "level 2 and 4 announce their paths")
	check_eq(player.combat.mastery_level, 4, "combat gates follow the level")
	await perform_path("LLH")
	check_eq(started_attacks.back(), &"sword_llh_crush", "L-L-H (Guard Splitter) runs at level 4")
	started_attacks.clear()
	await perform_path("LHL")
	check_eq(started_attacks.size(), 1, "L-H-L still locked (level 6)")


func test_mastery_gives_no_passive_stats() -> void:
	_bind()
	var before := character.get_stats().duplicate()
	var attack := (db.weapons[SWORD_ID] as WeaponFamily).node("L")
	var damage := attack.damage
	character.mastery.add_xp(SWORD_ID, 10_000_000)
	check_eq(character.mastery.get_level(SWORD_ID), 20, "level 20")
	check_eq(character.get_stats(), before, "no stat changes at all from mastery")
	check_eq(attack.damage, damage, "attack data unchanged")
	check_near(player.combat.attack_speed, 1.0, 0.0001, "no attack speed bonus")
	check_near(player.combat.recovery_multiplier, 1.0, 0.0001, "no recovery bonus")


func test_hits_and_whiffs_give_no_mastery_xp() -> void:
	_bind()
	var enemy := _grunt(Vector2(22, 0))
	var landed: Array[HitData] = []
	player.combat.hit_landed.connect(func(h: HitData) -> void: landed.append(h))
	await wait_physics(2)
	await perform_path("L")
	check_eq(landed.size(), 1, "one hit")
	check(not enemy.health.is_dead(), "enemy alive")
	check_eq(character.mastery.get_xp(SWORD_ID), 0, "no XP per hit")
	check(bridge.rewards.contribution(enemy, SWORD_ID) > 0.0, "the hit counts as contribution")
	enemy.queue_free()
	for i in 4:
		await perform_path("L")
	check_eq(character.mastery.get_xp(SWORD_ID), 0, "no XP for whiffs")


func test_training_dummy_gives_no_mastery_xp() -> void:
	_bind()
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(22, 0)
	add_child(dummy)
	dummy.health.max_health = 30.0
	dummy.health.reset()
	await wait_physics(2)
	for i in 6:
		await perform_path("L")
	check(dummy.hits_taken >= 3, "hits landed (%d)" % dummy.hits_taken)
	check_eq(character.mastery.get_xp(SWORD_ID) + character.mastery.get_level(SWORD_ID), 1, "no mastery XP from training")


func test_kill_reward_once_for_the_participating_family() -> void:
	_bind()
	var enemy := _grunt(Vector2(22, 0))
	await wait_physics(2)
	var guard := 0
	while not enemy.health.is_dead() and guard < 40:
		guard += 1
		var to_enemy := enemy.global_position - player.global_position
		if to_enemy.length() > 22.0:
			await tick(frame(to_enemy.normalized(), to_enemy.normalized()), 4)   # knockback pushed it away: step closer
			continue
		await perform_path("L", to_enemy.normalized())
	check(enemy.health.is_dead(), "enemy killed")
	check_eq(character.mastery.get_xp(SWORD_ID), enemy.config.mastery_xp_reward, "exactly the kill reward")
	player.combat.hit_landed.emit(_hit(SWORD_ID, enemy, 5.0, 999))
	check_eq(character.mastery.get_xp(SWORD_ID), enemy.config.mastery_xp_reward, "a dead enemy never pays twice")


func test_kill_reward_split_by_contribution_and_skill_kills() -> void:
	_bind()
	var enemy := _grunt(Vector2(200, 0))
	await wait_physics(2)
	player.combat.hit_landed.emit(_hit(SWORD_ID, enemy, 30.0, 1))
	player.combat.hit_landed.emit(_hit(GREAT_ID, enemy, 10.0, 2))
	var lethal := HitData.new()
	lethal.damage = 100000.0
	lethal.target = enemy
	lethal.source = HitData.Source.SKILL
	enemy.health.apply_hit(lethal)
	bridge.rewards.reward_kill(lethal)   # a skill landed the killing blow
	var reward := enemy.config.mastery_xp_reward
	check_eq(character.mastery.get_xp(SWORD_ID), reward * 3 / 4, "sword dealt 75 %% of the weapon damage: %d XP" % (reward * 3 / 4))
	check_eq(character.mastery.get_xp(GREAT_ID), reward / 4, "greatsword 25 %%: %d XP" % (reward / 4))
	var none := _grunt(Vector2(-200, 0))
	await wait_physics(1)
	none.health.apply_hit(lethal)
	lethal.target = none
	bridge.rewards.reward_kill(lethal)
	check_eq(character.mastery.get_xp(SWORD_ID) + character.mastery.get_xp(GREAT_ID), reward, "no weapon took part: no mastery XP")


func test_progress_survives_class_change() -> void:
	_bind()
	character.mastery.add_xp(&"dagger", _xp_to_level(&"dagger", 9))
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 2))
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	check_eq(character.mastery.get_level(&"dagger"), 9, "dagger mastery kept for the warrior")
	check_eq(character.mastery.get_level(SWORD_ID), 2, "sword mastery kept")
	check_eq(player.combat.chain, "", "class change ended any combo")


func test_mastery_serialization_roundtrip_and_clamping() -> void:
	character.mastery.add_xp(SWORD_ID, _xp_to_level(SWORD_ID, 4) + 12)
	character.mastery.add_xp(&"bow", _xp_to_level(&"bow", 10))
	var data := character.mastery.to_dict()
	var restored := WeaponMastery.new(db)
	var warnings: PackedStringArray = []
	restored.from_dict(data, warnings)
	check_eq(restored.get_level(SWORD_ID), 4, "level restored")
	check_eq(restored.get_xp(SWORD_ID), 12, "xp restored")
	check_eq(restored.get_level(&"bow"), 10, "bow level restored")
	var broken := {"one_handed_sword": {"level": 999, "xp": -5}, "spears": {"level": 3, "xp": 1}}
	restored.from_dict(broken, warnings)
	check_eq(restored.get_level(SWORD_ID), 20, "level clamped to max")
	check_eq(restored.get_xp(SWORD_ID), 0, "xp clamped")
	check(restored.to_dict().has("spears"), "unknown family preserved for re-save")
