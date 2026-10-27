extends GameplayTestCase
## Class Foundation A2-A4: real Bleeding and Chill statuses (damage over time,
## slows, stacking/refresh, resistances, boss caps, attribution and kill
## credit) and the shared hit dispatch with bounded trigger depth.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const BOSS_CONFIG: EnemyConfig = preload("res://data/enemies/grove_warden_config.tres")

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var dispatched: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	for slot: int in EquipSlot.Slot.values():
		character.equipment.unequip(slot)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	player.set_weapon_family(SWORD)   # legacy engine: these class / effect checks use the pre-1.5 sword timings (Combat Flow: test_flow_integration)
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void: dispatched.append(hit))


func _grunt(at: Vector2, config: EnemyConfig = null) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	if config != null:
		enemy.config = config
	enemy.position = at
	enemy.target = player
	add_child(enemy)
	return enemy


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _idle(ticks: int) -> void:
	await tick(frame(), ticks)


func test_status_data_valid() -> void:
	for status_id: StringName in [&"bleeding", &"chill"]:
		var definition: StatusEffectDefinition = db.statuses.get(status_id)
		check(definition != null and definition.validate().is_empty(), "%s defined and valid" % status_id)
	check(db.statuses[&"bleeding"].damage_per_second > 0.0, "bleeding deals damage over time")
	check(db.statuses[&"chill"].slow_per_stack > 0.0 and db.statuses[&"chill"].damage_per_second == 0.0,
		"chill slows, no damage")


func test_bleeding_ticks_damage_attributed_to_player() -> void:
	_bind()
	var dummy := _dummy(Vector2(80, 0))
	await _idle(2)
	var bleed: StatusEffectDefinition = db.statuses[&"bleeding"]
	check(bridge.apply_status(dummy, &"bleeding"), "bleeding applied")
	var start := dummy.health.health
	await _idle(seconds_to_ticks(1.0))
	var per_tick := bleed.damage_per_second * bleed.tick_interval
	check_near(start - dummy.health.health, per_tick * 2.0, 0.01, "two ticks in one second")
	var ticks := dispatched.filter(func(hit: HitData) -> bool: return hit.source == HitData.Source.STATUS)
	check_eq(ticks.size(), 2, "every tick goes through the character's hit dispatch")
	if not ticks.is_empty():
		check_eq(ticks[0].attacker, player, "damage credited to the player")
		check_eq(ticks[0].damage_type, &"bleed", "bleed damage type")
		check(&"bleeding" in ticks[0].tags and ticks[0].depth == 1, "tagged status hit at depth 1")
	await _idle(seconds_to_ticks(bleed.duration))
	check(not StatusComponent.of(dummy).has(&"bleeding"), "expires after its duration")


func test_bleeding_stacks_and_refreshes() -> void:
	_bind()
	var dummy := _dummy(Vector2(80, 0))
	await _idle(2)
	var status := StatusComponent.of(dummy)
	var bleed: StatusEffectDefinition = db.statuses[&"bleeding"]
	for i in 7:
		bridge.apply_status(dummy, &"bleeding")
	check_eq(status.stacks(&"bleeding"), bleed.max_stacks, "stacks capped at the maximum")
	await _idle(seconds_to_ticks(bleed.duration * 0.5))
	bridge.apply_status(dummy, &"bleeding")
	check_near(status.remaining(&"bleeding"), bleed.duration, 0.001, "a new application renews the duration")
	var chill: StatusEffectDefinition = db.statuses[&"chill"]
	for i in 5:
		bridge.apply_status(dummy, &"chill")
	check_eq(status.stacks(&"chill"), chill.max_stacks, "chill stacks capped")


func test_resistance_and_immunity() -> void:
	_bind()
	var config := (db.statuses.get(&"bleeding") as StatusEffectDefinition)
	var resistant := EnemyConfig.new()
	resistant.status_resistances = {&"bleeding": 0.5, &"chill": 1.0}
	var enemy := _grunt(Vector2(150, 0), resistant)
	await _idle(2)
	check(bridge.apply_status(enemy, &"bleeding"), "resistant enemy can bleed")
	check_near(enemy.status.remaining(&"bleeding"), config.duration * 0.5, 0.001, "duration halved")
	check_near(enemy.status.power(&"bleeding"), 0.5, 0.001, "power halved")
	check(not bridge.apply_status(enemy, &"chill"), "immune enemy refuses chill")
	check(not enemy.status.has(&"chill"), "no chill on the immune enemy")


func test_chill_slows_enemy_locomotion_only() -> void:
	_bind()
	var free := _grunt(Vector2(-200, -40))
	var chilled := _grunt(Vector2(-200, 40))
	await _idle(2)
	for i in 3:
		bridge.apply_status(chilled, &"chill")
	check_near(chilled.status.move_multiplier(), 0.55, 0.001, "3 stacks: 45 % slower")
	var a := free.global_position
	var b := chilled.global_position
	await _idle(20)
	var free_moved := free.global_position.distance_to(a)
	var chilled_moved := chilled.global_position.distance_to(b)
	check(chilled_moved < free_moved * 0.7, "chilled enemy is slower (%.1f vs %.1f)" % [chilled_moved, free_moved])
	check_eq(Engine.time_scale, 1.0, "global time untouched")
	check_eq(player.combat.attack_speed, 1.0, "player unaffected")


func test_boss_slow_cap() -> void:
	_bind()
	var boss := _grunt(Vector2(150, 0), BOSS_CONFIG)
	await _idle(2)
	for i in 3:
		bridge.apply_status(boss, &"chill")
	check_near(boss.status.move_multiplier(), 1.0 - BOSS_CONFIG.max_slow, 0.001, "boss slow capped at %.2f" % BOSS_CONFIG.max_slow)


func test_weapon_hits_roll_status_chances() -> void:
	_bind()
	var dummy := _dummy(Vector2(22, 0))
	await wait_physics(2)
	var f := frame()
	await tick(light(f))
	await tick(f, 30)
	check(not StatusComponent.of(dummy).has(&"bleeding"), "no bleed chance - no bleeding")
	var mods: Array[StatModifier] = [StatModifier.make(Stats.BLEED_CHANCE, 100.0), StatModifier.make(Stats.CHILL_CHANCE, 100.0)]
	character.set_runtime_modifiers(&"test", mods)
	await tick(light(f))
	await tick(f, 30)
	check(StatusComponent.of(dummy).has(&"bleeding"), "100 % bleed chance applies bleeding")
	check(StatusComponent.of(dummy).has(&"chill"), "100 % chill chance applies chill")
	var blood := db.materials[&"blood_steel"] as MaterialDefinition
	check(blood.imprint_modifiers.any(func(m: StatModifier) -> bool: return m.stat == Stats.BLEED_CHANCE),
		"Bloodsteel imprint grants a real bleed chance")


func test_status_kill_gives_class_xp_once() -> void:
	_bind()
	var enemy := _grunt(Vector2(200, 0))
	await _idle(2)
	enemy.config = enemy.config.duplicate()
	enemy.config.move_speed = 0.0
	enemy.health.health = 2.0
	var rewards: Array[StringName] = []
	bridge.rewards.rewarded.connect(func(kind: StringName, _amount: int) -> void: rewards.append(kind))
	bridge.apply_status(enemy, &"bleeding", 1.0, 5)
	await _idle(seconds_to_ticks(1.0))
	check(enemy.health.is_dead(), "bleeding killed the enemy")
	var kills := dispatched.filter(func(hit: HitData) -> bool: return hit.killed)
	check_eq(kills.size(), 1, "one killing tick")
	check_eq(rewards, [&"kill_class"] as Array[StringName], "kill by bleeding credits the class kill reward")
	if not kills.is_empty():
		bridge.rewards.reward_kill(kills[0])
	check_eq(rewards.size(), 1, "never rewarded twice")


## An effect that answers every hit with a triggered hit: the runner must stop
## after MAX_TRIGGER_DEPTH instead of recursing forever.
class EchoEffect:
	extends ItemEffect
	var seen: int = 0

	func on_hit_landed(hit: HitData, runner: ItemEffectRunner, _key: String) -> void:
		seen += 1
		var echo := HitData.new()
		echo.source = HitData.Source.TRIGGERED
		echo.depth = hit.depth + 1
		runner.dispatch_hit(echo)


func test_trigger_chains_are_bounded_and_sources_filtered() -> void:
	var runner := ItemEffectRunner.new()
	var echo := EchoEffect.new()
	echo.hit_sources = 0b1111
	var weapon_only := EchoEffect.new()   # default: direct hits only
	runner.active.append({"effect": echo, "key": "echo"})
	runner.active.append({"effect": weapon_only, "key": "weapon"})
	var direct := HitData.new()
	runner.dispatch_hit(direct)
	# direct hit + the two triggered echoes (depth 1); their echoes (depth 2) are dropped
	check_eq(echo.seen, 3, "trigger chain stops at MAX_TRIGGER_DEPTH")
	check_eq(weapon_only.seen, 1, "weapon-only effect ignores triggered hits")
	var skill := HitData.new()
	skill.source = HitData.Source.SKILL
	runner.dispatch_hit(skill)
	check_eq(weapon_only.seen, 1, "weapon-only effect ignores skill hits")
