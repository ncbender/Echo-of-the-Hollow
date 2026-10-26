extends GameplayTestCase
## Class system: unlock, activation rules, separate levels, shared mastery,
## class stats applied to the player, class resource (rage).

const ADVENTURER := &"basic_adventurer"
const WARRIOR := &"warrior"

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	# Class stat tests use a character without gear (starting gear adds stats).
	for slot: int in EquipSlot.Slot.values():
		character.equipment.unequip(slot)


func _bind() -> PlayerProgressionBridge:
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	return bridge


func test_new_character_starts_as_basic_adventurer() -> void:
	check_eq(character.classes.active_class_id, ADVENTURER, "starting class")
	check(character.classes.is_unlocked(ADVENTURER), "adventurer unlocked")
	check(not character.classes.is_unlocked(WARRIOR), "warrior locked")


func test_locked_class_cannot_be_activated() -> void:
	check(character.switch_class(WARRIOR, true) != "", "switch refused")
	check_eq(character.classes.active_class_id, ADVENTURER, "still adventurer")
	check(not character.classes.set_active(WARRIOR), "low-level activation refused too")
	check(character.switch_class(&"no_such_class", true) != "", "unknown class refused")


func test_unlock_and_switch_only_in_safe_zone() -> void:
	check(character.classes.unlock(WARRIOR), "unlock works")
	check(not character.classes.unlock(WARRIOR), "second unlock is a no-op")
	check(character.switch_class(WARRIOR, false) != "", "refused outside a class station")
	check_eq(character.switch_class(WARRIOR, true), "", "allowed at station")
	check_eq(character.classes.active_class_id, WARRIOR, "warrior active")


func test_separate_class_levels_and_shared_mastery() -> void:
	character.classes.unlock(WARRIOR)
	var adventurer_def := db.get_class_def(ADVENTURER)
	character.add_class_xp(adventurer_def.xp_to_next(1) + 5)
	character.mastery.add_xp(&"one_handed_sword", 50)
	check_eq(character.classes.get_level(ADVENTURER), 2, "adventurer level 2")
	character.switch_class(WARRIOR, true)
	check_eq(character.classes.get_level(WARRIOR), 1, "warrior starts at level 1")
	check_eq(character.mastery.get_xp(&"one_handed_sword"), 50, "mastery shared across classes")
	character.add_class_xp(30)
	check_eq(character.classes.get_xp(WARRIOR), 30, "warrior XP separate")
	check_eq(character.classes.get_xp(ADVENTURER), 5, "adventurer XP untouched")
	check_eq(character.classes.add_xp(&"unknown", 10), 0, "XP to unknown class ignored")


func test_class_stats_resolve_and_update() -> void:
	check_eq(character.get_stat(Stats.MAX_HEALTH), 100.0, "adventurer level 1 health")
	check_eq(character.get_stat(Stats.ARMOR), 0.0, "adventurer armor")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	check_eq(character.get_stat(Stats.MAX_HEALTH), 120.0, "warrior health")
	check_eq(character.get_stat(Stats.ARMOR), 10.0, "warrior armor")
	check_eq(character.get_stat(Stats.POISE_DAMAGE), 5.0, "warrior poise bonus")
	var warrior := db.get_class_def(WARRIOR)
	character.add_class_xp(warrior.xp_to_next(1) + warrior.xp_to_next(2))
	check_eq(character.classes.get_level(WARRIOR), 3, "warrior level 3")
	check_eq(character.get_stat(Stats.MAX_HEALTH), 128.0, "per-level health")
	check_eq(character.get_stat(Stats.ARMOR), 12.0, "per-level armor")
	character.switch_class(ADVENTURER, true)
	check_eq(character.get_stat(Stats.MAX_HEALTH), 100.0, "switching back removes warrior stats")


func test_bridge_applies_class_stats_to_player() -> void:
	var bridge := _bind()
	check_eq(player.health.max_health, 100.0, "player max health from stats")
	check_eq(player.incoming_damage_multiplier, 1.0, "no armor")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	check_eq(player.health.max_health, 120.0, "updated on class switch")
	check_near(player.incoming_damage_multiplier, 100.0 / 110.0, 0.0001, "armor reduces incoming damage")
	var hit := HitData.new()
	hit.damage = 11.0
	player.hurtbox.receive_hit(hit)
	check_near(player.health.health, 120.0 - 10.0, 0.01, "incoming damage reduced by armor")
	check(bridge.resource_pool != null and bridge.resource_pool.definition.id == &"rage", "warrior has rage")


func test_outgoing_hits_neutral_for_adventurer_and_poise_bonus_for_warrior() -> void:
	_bind()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 24)
	var light_1 := SWORD.get_attack(&"sword_light_1")
	check_near(hits[0].damage, light_1.damage, 0.001, "adventurer: unchanged combat damage")
	check_near(hits[0].poise_damage, light_1.poise_damage, 0.001, "adventurer: unchanged poise")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	await tick(f, 30)
	await tick(light(f))
	await tick(f, 24)
	check_near(hits[1].poise_damage, light_1.poise_damage * 1.05, 0.001, "warrior: +5% poise damage")


func test_rage_builds_and_decays() -> void:
	var bridge := _bind()
	check(bridge.resource_pool == null, "adventurer has no class resource")
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 10)
	var rage := bridge.resource_pool
	check_near(rage.value, rage.definition.gain_per_hit_dealt, 0.001, "rage from hit dealt")
	for i in seconds_to_ticks(rage.definition.regen_delay + 2.0):
		bridge._physics_process(FRAME)
	check(rage.value < rage.definition.gain_per_hit_dealt, "rage decays after the delay")
	check(rage.value >= 0.0, "never negative")


func test_rebinding_does_not_duplicate_connections() -> void:
	var bridge := _bind()
	bridge.bind(player, character)
	bridge.bind(player, character)
	var messages: Array[String] = []
	bridge.message.connect(func(text: String) -> void: messages.append(text))
	character.add_class_xp(db.get_class_def(ADVENTURER).xp_to_next(1))
	check_eq(messages.size(), 1, "one level-up message after three binds")
	check_eq(player.combat.modifiers.count(bridge.stat_modifier), 1, "stat modifier registered once")


func test_class_serialization_roundtrip_and_fallback() -> void:
	character.classes.unlock(WARRIOR)
	character.switch_class(WARRIOR, true)
	character.add_class_xp(150)
	var data := character.classes.to_dict()
	var restored := CharacterClasses.new(db)
	var warnings: PackedStringArray = []
	restored.from_dict(data, warnings)
	check_eq(restored.active_class_id, WARRIOR, "active class restored")
	check_eq(restored.get_level(WARRIOR), character.classes.get_level(WARRIOR), "level restored")
	check_eq(restored.get_xp(WARRIOR), character.classes.get_xp(WARRIOR), "xp restored")
	var broken := {"active": "warrior", "progress": {"warrior": {"unlocked": false}, "basic_adventurer": {"unlocked": true}, "necromancer": {"unlocked": true}}}
	restored.from_dict(broken, warnings)
	check_eq(restored.active_class_id, ADVENTURER, "locked active class falls back to an unlocked one")
	check(restored.to_dict().progress.has("necromancer"), "unknown class preserved")
