extends GameplayTestCase
## Crafting phase F: Stormcaller Fang evolution - item XP from real enemy hits
## (separate from weapon mastery, main hand only, no training XP), stage
## requirements and costs, permanent mutation choice, combat effect, save/load.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const S := EquipSlot.Slot
const SAVE := "user://test_saves/evolution.save.json"

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var rng := RandomNumberGenerator.new()
var landed: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	character.mastery.add_xp(&"one_handed_sword", 400)   # Combat Flow: mastery 4 unlocks L-L-H
	bridge.bind(player, character)
	player.combat.hit_landed.connect(func(hit: HitData) -> void: landed.append(hit))


func _fang(equip: bool = true) -> ItemInstance:
	var fang := character.inventory.add_item(&"stormcaller_fang")[0]
	if equip:
		check_eq(character.equipment.equip(fang.instance_id, S.MAIN_HAND), "", "fang equipped")
	return fang


func _enemy(at: Vector2) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	add_child(enemy)
	enemy.health.max_health = 100000.0
	enemy.health.max_poise = 100000.0
	enemy.health.reset()
	return enemy


func _evolve(item: ItemInstance, mutation: StringName = &"") -> CraftingService.Result:
	var request := CraftingRequest.make(CraftingOps.EVOLVE, item)
	request.mutation_id = mutation
	return CraftingService.execute(character, request, rng)


func _swing_lights(count: int) -> void:
	for i in count:
		await perform_path("L", Vector2.RIGHT, 2)


func test_only_marked_items_evolve() -> void:
	var blade := character.inventory.add_item(&"forged_blade")[0]
	check("does not support" in _evolve(blade).error, "craftable base cannot evolve")
	var oath := character.inventory.add_item(&"crushing_oath")[0]
	check("protected" in _evolve(oath).error, "unique cannot evolve")


func test_item_xp_from_real_enemies_only_and_separate_from_mastery() -> void:
	_bind()
	var fang := _fang()
	_enemy(Vector2(24, 0))
	await wait_physics(2)
	var mastery_before := character.mastery.get_xp(&"one_handed_sword") + character.mastery.get_level(&"one_handed_sword") * 1000
	await _swing_lights(3)
	check_eq(fang.evolution_xp(), 3, "1 item XP per accepted hit on an enemy")
	check(character.mastery.get_xp(&"one_handed_sword") + character.mastery.get_level(&"one_handed_sword") * 1000 > mastery_before, "weapon mastery still progresses normally")
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(-24, 0)
	add_child(dummy)
	await wait_physics(2)
	await perform_path("L", Vector2.LEFT, 2)
	check_eq(fang.evolution_xp(), 3, "training dummy gives no item XP")


func test_unequipped_items_do_not_learn() -> void:
	_bind()
	var fang := _fang(false)
	character.equipment.equip(character.inventory.add_item(&"iron_sword")[0].instance_id, S.MAIN_HAND)
	_enemy(Vector2(24, 0))
	await wait_physics(2)
	await _swing_lights(2)
	check_eq(fang.evolution_xp(), 0, "only the main-hand item learns")


func test_stage_two_requires_xp_and_resources() -> void:
	var fang := _fang()
	var result := _evolve(fang)
	check(not result.ok and "item XP" in result.error, "XP requirement explained: %s" % result.error)
	fang.evolution = {"stage": 1, "xp": 60, "path": ""}
	result = _evolve(fang)
	check(not result.ok and "Iron Ore" in result.error, "resources required: %s" % result.error)
	character.inventory.add_item(&"iron_ore", 5)
	character.inventory.add_item(&"hollow_essence", 2)
	var before := character.get_stat(Stats.PHYSICAL_DAMAGE)
	check(_evolve(fang).ok, "evolved to stage 2")
	check_eq(fang.evolution_stage(), 2, "stage 2")
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE) - before, 6.0, 0.001, "stage bonus active")
	check_eq(character.inventory.count(&"iron_ore"), 0, "costs paid")


func test_stage_three_needs_a_permanent_mutation_choice() -> void:
	var fang := _fang()
	fang.evolution = {"stage": 2, "xp": 150, "path": ""}
	character.inventory.add_item(&"hollow_essence", 3)
	var result := _evolve(fang)
	check(not result.ok and "mutation" in result.error, "choice required: %s" % result.error)
	result = _evolve(fang, &"steadfast")
	check(not result.ok and "Awakening Stone" in result.error, "awakening stone required: %s" % result.error)
	character.inventory.add_item(&"awakening_stone")
	var armor := character.get_stat(Stats.ARMOR)
	check(_evolve(fang, &"steadfast").ok, "evolved with Steadfast")
	check_eq(fang.evolution_path(), &"steadfast", "path stored")
	check_near(character.get_stat(Stats.ARMOR) - armor, 40.0, 0.001, "mutation stat active")
	character.inventory.add_item(&"awakening_stone")
	check("fully evolved" in _evolve(fang, &"storm_charge").error, "path cannot be changed (no respec)")


func test_storm_charge_changes_combat() -> void:
	_bind()
	var fang := _fang()
	_enemy(Vector2(24, 0))
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	var finisher := func() -> HitData:
		await perform_path("LLH", Vector2.RIGHT, 20)
		for index in range(landed.size() - 1, -1, -1):
			if landed[index].attack.id == &"sword_llh_crush":
				return landed[index]
		return null
	var before: HitData = await finisher.call()
	fang.evolution = {"stage": 3, "xp": 200, "path": "storm_charge"}
	character.notify_item_changed(fang.instance_id)
	check(bridge.effects.has_effect(&"storm_charge"), "mutation effect active")
	await tick(f, 40)
	var after: HitData = await finisher.call()
	if not check(before != null and after != null, "both finishers landed"):
		return
	check(&"storm_charge" in after.tags, "storm charge applied")
	check(after.damage > before.damage * 1.29, "heavy finisher damage +30 %% or more incl. stage 2 bonuses (%.1f -> %.1f)" % [before.damage, after.damage])


func test_evolution_survives_save_load() -> void:
	var fang := _fang()
	fang.evolution = {"stage": 3, "xp": 175, "path": "storm_charge"}
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	character = SaveSystem.load_from(SAVE, db).character
	var loaded := character.inventory.find(fang.instance_id)
	check_eq(loaded.evolution_stage(), 3, "stage kept")
	check_eq(loaded.evolution_xp(), 175, "item XP kept")
	check_eq(loaded.evolution_path(), &"storm_charge", "mutation path kept")
	_bind()
	check(bridge.effects.has_effect(&"storm_charge"), "mutation effect rebuilt after load")
