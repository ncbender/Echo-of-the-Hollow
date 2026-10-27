extends TestCase
## Hollowwood Loot Integration 1.0 (docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md): equipment drops
## of the repeatable Hollow Grunt group (7 % per kill) and the two repeatable wolf encounters
## (15 % per cleared encounter). Statistics use fixed seeds; lifecycle tests use the real maps.
## Files only under user://test_saves/.

const DIR := "user://test_saves/hollowwood_loot"
const PROFILE := DIR + "/slot_1.save.json"
const R := ItemDefinition.Rarity
const GRUNT_LOOT := "res://data/loot/hollow_grunt_equipment.tres"
const WOLF_LOOT := "res://data/loot/hollowwood_wolves_equipment.tres"
const GRUNT_ITEMS := [&"iron_sword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear", &"leather_cap", &"wanderer_coat"]
const WOLF_ITEMS := [&"steel_greatsword", &"oak_staff", &"oak_wand", &"hunting_bow", &"oak_shield"]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	session.set_character(character)
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE) + [DIR + "/loot.save.json"]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _table(path: String) -> EquipmentLootTable:
	return load(path) as EquipmentLootTable


## Same table with a guaranteed drop (pool, rarity and level statistics per dropped item).
func _always(path: String) -> EquipmentLootTable:
	var table := _table(path).duplicate() as EquipmentLootTable
	table.chance = 1.0
	return table


func _drops(table: EquipmentLootTable, draws: int, seed_value: int) -> Array[ItemInstance]:
	var rng := _rng(seed_value)
	var result: Array[ItemInstance] = []
	for i in draws:
		var item := EquipmentLoot.roll(table, db, rng)
		if item != null:
			result.append(item)
	return result


# --- Tables and statistics --------------------------------------------------------------------

func test_tables_hold_the_approved_values() -> void:
	var grunt := _table(GRUNT_LOOT)
	check(grunt.validate(db).is_empty(), "grunt table valid: %s" % [grunt.validate(db)])
	check_near(grunt.chance, 0.07, 0.000001, "grunt 7 %")
	check_eq(grunt.item_ids, GRUNT_ITEMS as Array[StringName], "grunt models")
	check_eq(grunt.rarity_weights, {0: 75.0, 1: 25.0}, "grunt Normal 75 / Magic 25")
	check_eq([grunt.source_level, grunt.level_spread], [5, 2], "grunt level 5, item level 3-7")
	var wolves := _table(WOLF_LOOT)
	check(wolves.validate(db).is_empty(), "wolf table valid: %s" % [wolves.validate(db)])
	check_near(wolves.chance, 0.15, 0.000001, "wolves 15 %")
	check_eq(wolves.item_ids, WOLF_ITEMS as Array[StringName], "wolf models")
	check_eq(wolves.rarity_weights, {0: 60.0, 1: 40.0}, "wolves Normal 60 / Magic 40")
	check_eq([wolves.source_level, wolves.level_spread], [10, 2], "wolf level 10, item level 8-12")
	check_eq(grunt.tier_weights.resource_path, "res://data/loot/hollowwood_early_tiers.tres", "approved early tier table")


func test_drop_chance_per_event() -> void:
	# sigma = sqrt(p(1-p)/n): 0.0018 (grunt) and 0.0025 (wolves) -> tolerance about 3.5 sigma
	var draws := 20000
	check_near(_drops(_table(GRUNT_LOOT), draws, 11).size() / float(draws), 0.07, 0.0065, "grunt drop chance 7 %")
	check_near(_drops(_table(WOLF_LOOT), draws, 12).size() / float(draws), 0.15, 0.009, "wolf drop chance 15 %")


func _check_pool(items: Array[ItemInstance], models: Array, magic_share: float, low: int, high: int, label: String) -> void:
	var by_model := {}
	var magic := 0
	for item in items:
		by_model[item.definition_id] = by_model.get(item.definition_id, 0) + 1
		if item.rarity == R.MAGIC:
			magic += 1
		elif item.rarity != R.NORMAL:
			fail("%s: rarity %d outside Normal/Magic" % [label, item.rarity])
			return
		if item.item_level < low or item.item_level > high:
			fail("%s: item level %d outside %d-%d" % [label, item.item_level, low, high])
			return
		if item.quantity != 1 or item.origin != ItemInstance.ORIGIN_FOUND:
			fail("%s: one found instance per drop" % label)
			return
	check_eq(by_model.size(), models.size(), "%s: every model reachable (%s)" % [label, by_model])
	for model: StringName in models:
		check_near(by_model.get(model, 0) / float(items.size()), 1.0 / models.size(), 0.025, "%s: %s equal weight" % [label, model])
	check_near(magic / float(items.size()), magic_share, 0.03, "%s: Magic share" % label)


func test_grunt_pool_rarity_and_levels() -> void:
	var items := _drops(_always(GRUNT_LOOT), 3000, 21)
	check_eq(items.size(), 3000, "one item per successful roll")
	_check_pool(items, GRUNT_ITEMS, 0.25, 3, 7, "grunt")
	var levels := {}
	for item in items:
		levels[item.item_level] = true
	check_eq(levels.size(), 5, "item levels 3, 4, 5, 6, 7 all occur")


func test_wolf_pool_rarity_and_levels() -> void:
	var items := _drops(_always(WOLF_LOOT), 3000, 22)
	_check_pool(items, WOLF_ITEMS, 0.40, 8, 12, "wolves")


func test_affixes_follow_rarity_tiers_and_rules() -> void:
	var items := _drops(_always(GRUNT_LOOT), 3000, 31) + _drops(_always(WOLF_LOOT), 3000, 32)
	var magic_counts := {}
	var magic := 0
	var t4 := 0
	var high_level_affixes := 0
	for item in items:
		var definition := db.get_item(item.definition_id)
		if item.rarity == R.NORMAL and not item.affixes.is_empty():
			fail("Normal item with affixes")
			return
		if item.rarity == R.MAGIC:
			magic += 1
			magic_counts[item.affixes.size()] = magic_counts.get(item.affixes.size(), 0) + 1
		var seen := {}
		for entry in item.affixes:
			var affix: AffixDefinition = db.affixes.get(StringName(str(entry.affix)))
			var tier := int(entry.tier)
			if affix == null or not affix.rollable or not affix.id in definition.generation_affixes or not affix.allows_slot(definition.slot_kind):
				fail("%s: affix %s not allowed" % [item.definition_id, entry.affix])
				return
			if seen.has(affix.group) or (affix.exclusion_group != &"" and seen.has(affix.exclusion_group)):
				fail("%s: duplicate or excluded affix %s" % [item.definition_id, item.affixes])
				return
			seen[affix.group] = true
			if affix.exclusion_group != &"":
				seen[affix.exclusion_group] = true
			if not definition.is_weapon() and affix.scope == AffixDefinition.Scope.LOCAL:
				fail("local affix on %s" % item.definition_id)
				return
			if item.item_level < 10 and tier != 5:
				fail("item level %d rolled T%d (only T5 below 10)" % [item.item_level, tier])
				return
			if item.item_level >= 10:
				high_level_affixes += 1
				if tier == 4:
					t4 += 1
				elif tier != 5:
					fail("item level %d rolled T%d (only T5/T4)" % [item.item_level, tier])
					return
	check(high_level_affixes > 800, "enough affixes at item level 10-12 (%d)" % high_level_affixes)
	check_near(t4 / float(high_level_affixes), 0.25, 0.04, "item level 10-12: T4 25 %")
	check_eq(magic_counts.keys().size(), 3, "Magic: 1-3 affixes (%s)" % magic_counts)
	for count: int in {1: 0.4, 2: 0.4, 3: 0.2}:
		check_near(magic_counts.get(count, 0) / float(magic), {1: 0.4, 2: 0.4, 3: 0.2}[count], 0.035, "Magic %d affixes" % count)


# --- Lifecycle on the real maps -----------------------------------------------------------------

func _open(map_id: StringName, spawn_id: StringName) -> GameMap:
	character.world.map_id = map_id
	character.world.spawn_id = spawn_id
	session.travel(map_id, spawn_id, false)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			return current
	fail("map %s not loaded" % map_id)
	return null


func _kill(enemy: Enemy) -> void:
	var hit := HitData.new()
	hit.damage = 9999.0
	enemy.hurtbox.receive_hit(hit)
	await get_tree().physics_frame
	await get_tree().process_frame


func _pickups() -> Array[ItemPickup]:
	var result: Array[ItemPickup] = []
	for node in map.find_children("*", "ItemPickup", true, false):
		if not node.is_queued_for_deletion():
			result.append(node as ItemPickup)
	return result


func _equipment_pickups() -> Array[ItemPickup]:
	return _pickups().filter(func(pickup: ItemPickup) -> bool: return pickup.item != null)


func _park_player() -> void:
	map.player.global_position = Vector2(-5000, -5000)   # never touches a drop by accident
	map.player.reset_physics_interpolation()
	await get_tree().physics_frame


func test_grunt_death_rolls_once_and_keeps_fixed_drops() -> void:
	if await _open(&"whisper_forest", &"default") == null:
		return
	var grunts: Array[Enemy] = []
	for name: String in ["GruntA", "GruntB", "GruntC"]:
		var grunt := map.get_node("Enemies/%s" % name) as Enemy
		check(grunt.equipment_loot != null and grunt.equipment_loot.resource_path == GRUNT_LOOT, "%s uses the grunt table" % name)
		grunts.append(grunt)
	var warden := map.get_node("Enemies/GroveWarden") as Enemy
	check(warden.equipment_loot == null, "grove warden: no equipment roll")
	await _park_player()
	var grunt := grunts[0]
	grunt.equipment_loot = _always(GRUNT_LOOT)
	await _kill(grunt)
	var fixed := _pickups().filter(func(pickup: ItemPickup) -> bool: return pickup.item == null)
	var expected := []
	for drop in grunt.config.drops:
		expected.append([drop.item_id, drop.quantity])
	var got := []
	for pickup: ItemPickup in fixed:
		got.append([pickup.item_id, pickup.quantity])
	check_eq(got, expected, "fixed drops (essence, ore, gold) unchanged")
	check_eq(_equipment_pickups().size(), 1, "exactly one equipment drop for the kill")
	map._spawn_drops(grunt)   # a repeated death signal / cleanup
	await get_tree().process_frame
	check_eq(_equipment_pickups().size(), 1, "no second equipment roll for the same death")
	var debug := map.spawn_enemy(Vector2(-4000, -4000))
	check(debug.equipment_loot == null, "debug-spawned grunts never roll equipment")


func test_wolf_encounter_rolls_once_per_clear() -> void:
	if await _open(&"old_road", &"rest") == null:
		return
	var wolves := map.get_node("Encounters/SideWolves") as Encounter
	check(wolves.completion_loot != null and wolves.completion_loot.resource_path == WOLF_LOOT, "road_side_wolves uses the wolf table")
	wolves.completion_loot = _always(WOLF_LOOT)
	map.player.global_position = wolves.global_position
	map.player.reset_physics_interpolation()
	for i in 3:
		await get_tree().physics_frame
	if not check(wolves.running and wolves.enemies.size() == 2, "two wolves fight"):
		return
	await _park_player()
	await _kill(wolves.enemies[0])
	check_eq(_equipment_pickups().size(), 0, "no roll per wolf")
	wolves._on_enemy_defeated(wolves.enemies[0])   # repeated signal of the same wolf
	check(wolves.running, "a repeated signal never counts a wolf twice")
	await _kill(wolves.enemies[1])
	await get_tree().process_frame
	check(wolves.done, "encounter completed")
	check_eq(_equipment_pickups().size(), 1, "exactly one roll for the cleared encounter")
	wolves._on_enemy_defeated(wolves.enemies[1])
	await get_tree().process_frame
	check_eq(_equipment_pickups().size(), 1, "repeated completion callbacks roll nothing")
	var item := _equipment_pickups()[0].item
	check(item.definition_id in WOLF_ITEMS and item.item_level >= 8 and item.item_level <= 12, "wolf pool item")


func test_shrine_wolves_use_the_same_table() -> void:
	var scene := (load("res://scenes/maps/whispering_stone.tscn") as PackedScene).instantiate()
	var wolves := scene.get_node("Encounters/SideWolves") as Encounter
	check(wolves.completion_loot != null and wolves.completion_loot.resource_path == WOLF_LOOT, "shrine_side_wolves uses the wolf table")
	var others := 0
	for node in scene.find_children("*", "Encounter", true, false):
		if node != wolves and (node as Encounter).completion_loot != null:
			others += 1
	check_eq(others, 0, "one-time encounters have no equipment roll")
	scene.free()


func test_pickup_hands_over_the_same_instance_and_survives_save() -> void:
	if await _open(&"whisper_forest", &"default") == null:
		return
	await _park_player()
	var item := ItemCreation.generate(db.get_item(&"iron_mace"), R.MAGIC, db, _rng(5), _table(GRUNT_LOOT).tier_weights, 7, ItemInstance.ORIGIN_FOUND).item
	item.affixes = [db.affixes[&"striking"].roll(db.affixes[&"striking"].get_tier(5), _rng(6), WeaponDamage.reference_of(item, db.get_item(&"iron_mace"), db))] as Array[Dictionary]
	var before := item.to_dict()
	var pickup := map.spawn_item_pickup(item, Vector2(-4900, -4900))
	await get_tree().process_frame
	var full := character.inventory.capacity
	character.inventory.capacity = character.inventory.used_slots()
	check(not pickup.try_pick_up(map.player), "full inventory: stays on the ground")
	check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "pickup kept")
	character.inventory.capacity = full
	check(pickup.try_pick_up(map.player), "picked up")
	check(not pickup.try_pick_up(map.player), "only once")
	var owned := character.inventory.find(item.instance_id)
	check(owned == item, "the very same instance is in the bag")
	check_eq(owned.to_dict() if owned != null else {}, before, "base, rarity, level, affixes and striking flat unchanged")
	var path := DIR + "/loot.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "loads: %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(item.instance_id)
	check_eq(loaded.to_dict() if loaded != null else {}, before, "nothing re-rolled on load")
	var equipment := 0
	for owned_item in result.character.inventory.items():
		if owned_item.item_level == 7 and owned_item.definition_id == &"iron_mace":
			equipment += 1
	check_eq(equipment, 1, "no extra item created by loading")


# --- Crafting regression (shared AffixRoller) ----------------------------------------------------

func test_crafting_forged_level_12_keeps_its_rules() -> void:
	var definition := db.get_item(&"forged_blade")
	var blade := ItemCreation.create(definition, 1, db)
	check_eq(blade.item_level, 12, "forged blade level 12")
	var shares := {}
	var ids := {}
	for entry in AffixPool.compute(blade, definition, null, db):
		var tier := (entry.tier as AffixTier).tier
		shares[tier] = shares.get(tier, 0.0) + entry.probability
		ids[(entry.affix as AffixDefinition).id] = true
	check_near(shares.get(5, 0.0), 0.75, 0.000001, "T5 75 %")
	check_near(shares.get(4, 0.0), 0.25, 0.000001, "T4 25 %")
	check_eq(ids.size(), 11, "same eleven global affixes (no local, executioner allowed on the sword)")
	var keen: AffixDefinition = db.affixes[&"keen"]
	var rng := _rng(3)
	for i in 200:
		var value: float = keen.roll(keen.get_tier(4), rng).flat
		if value < 1.0 or value > 1.5 or not is_equal_approx(value * 10.0, roundf(value * 10.0)):
			fail("keen T4 rolled %s (0.1 steps in 1-1.5)" % value)
			return
