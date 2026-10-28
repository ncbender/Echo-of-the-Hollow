extends TestCase
## Grove Warden Rare R2 (docs/GROVE_WARDEN_RARE_R2.md): the boss entitlement and the
## Warden's Cache. Claim = defeat flag AND no claim flag (derived), one Rare from the
## existing reward table rolled only at claim time (origin found), full bag / trial keep
## the claim open without a roll, never a second item, save/load and old saves, the one
## milestone save after the kill, the loot feed showing the instance rarity. Synthetic
## characters and fixed seeds; files only under user://test_saves/grove_warden_r2/.

const R := ItemDefinition.Rarity
const BOSS := &"whisper_forest_grove_warden"
const DEFEATED := &"defeated.whisper_forest_grove_warden"
const CLAIMED := &"boss_reward.whisper_forest_grove_warden"
const REWARD := "res://data/loot/grove_warden_rare_reward.tres"
const FOREST := "res://scenes/maps/whisper_forest.tscn"
const PROFILE := "user://test_saves/grove_warden_r2/slot_1.save.json"
const MODELS := [&"iron_sword", &"steel_greatsword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear",
	&"oak_staff", &"oak_wand", &"hunting_bow", &"leather_cap", &"wanderer_coat", &"oak_shield"]
const WEAPONS := [&"iron_sword", &"steel_greatsword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear",
	&"oak_staff", &"oak_wand", &"hunting_bow"]
const ARMOUR_AFFIXES := [&"furious", &"guarded", &"keen", &"vital"]

var db: GameDatabase
var table: EquipmentLootTable
var character: Character
var session: SessionState
var _previous: Character
var _previous_path: String
var _critical_saves: int = 0


func before_each() -> void:
	db = GameDatabase.get_default()
	table = load(REWARD) as EquipmentLootTable
	character = CharacterFactory.create_new(db)
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	_critical_saves = 0


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	if session.saves.save_started.is_connected(_on_save_started):
		session.saves.save_started.disconnect(_on_save_started)
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _claim(seed_value: int, claimed: Array[ItemInstance] = []) -> String:
	return BossRewardService.claim(character, BOSS, table, _rng(seed_value), claimed)


func _reload(source: Character) -> Character:
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())), db, warnings)
	check(loaded != null, "synthetic save loads")
	return loaded


func _fill_bag() -> void:
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1, ItemInstance.ORIGIN_FOUND)


func _equipment_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for item in character.inventory.items():
		ids.append(item.instance_id)
	return ids


func _on_save_started(kind: SaveCoordinator.Kind) -> void:
	if kind == SaveCoordinator.Kind.CRITICAL:
		_critical_saves += 1


func _open_forest() -> GameMap:
	character.world.map_id = &"whisper_forest"
	session.set_character(character)
	get_tree().change_scene_to_file(FOREST)
	var map: GameMap = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 5:   # let arrival milestones (story steps) write first
		await get_tree().process_frame
	return map


func _cache(map: GameMap) -> BossRewardCache:
	var found := map.find_children("*", "BossRewardCache", true, false)
	return found[0] if not found.is_empty() else null


func _warden(map: GameMap) -> Enemy:
	for node in map.find_children("*", "Enemy", true, false):
		if (node as Enemy).persistent_id == BOSS and not node.is_queued_for_deletion():
			return node
	return null


## A seed of the real reward table whose roll is `model` (deterministic search).
func _seed_for(model: StringName) -> int:
	for seed_value in 1000:
		var item := EquipmentLoot.roll(table, db, _rng(seed_value))
		if item != null and item.definition_id == model:
			return seed_value
	return -1


# --- claim contract (synthetic) -------------------------------------------------------------------

func test_no_claim_before_the_kill() -> void:
	var before := _equipment_ids()
	check(not BossRewardService.has_claim(character, BOSS), "no claim without the defeat flag")
	check_eq(_claim(1), "The cache is sealed.", "claim refused")
	check_eq(_equipment_ids(), before, "no item")
	check(not character.world.flags.has(CLAIMED), "no claim flag")
	character.world.set_flag(DEFEATED, false)
	check(not BossRewardService.has_claim(character, BOSS), "a false defeat flag is no proof")


func test_claim_before_class_choice_gives_one_rare_found_level_20() -> void:
	check(not character.prologue.is_completed(), "prologue running (no class chosen)")
	character.world.set_flag(DEFEATED)
	check(BossRewardService.has_claim(character, BOSS), "claim derived from the defeat flag")
	var reward_before := character.prologue.class_reward
	var claimed: Array[ItemInstance] = []
	check_eq(_claim(7, claimed), "", "claimed")
	if not check_eq(claimed.size(), 1, "exactly one item"):
		return
	var item := claimed[0]
	check(character.inventory.has(item.instance_id), "item in the bag")
	check_eq(item.rarity, R.RARE, "instance rarity Rare")
	check_eq(item.item_level, 20, "item level 20")
	check_eq(item.origin, ItemInstance.ORIGIN_FOUND, "origin found")
	check(item.definition_id in MODELS, "one of the twelve models")
	check_eq(character.world.get_flag(CLAIMED), true, "claim flag set")
	check(not BossRewardService.has_claim(character, BOSS), "claim closed")
	check_eq(character.prologue.class_reward, reward_before, "M4 class reward untouched")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "no class change")


func test_full_bag_rolls_nothing_and_keeps_the_claim() -> void:
	character.world.set_flag(DEFEATED)
	_fill_bag()
	var before := _equipment_ids()
	var rng := _rng(11)
	var state := rng.state
	var claimed: Array[ItemInstance] = []
	check_eq(BossRewardService.claim(character, BOSS, table, rng, claimed), "Your bag is full. Make room to open the cache.", "refused")
	check_eq(rng.state, state, "no roll happened")
	check(claimed.is_empty(), "no instance")
	check_eq(_equipment_ids(), before, "bag unchanged")
	check(not character.world.flags.has(CLAIMED), "no claim flag")
	check(BossRewardService.has_claim(character, BOSS), "claim stays open")
	# make room: exactly one claim
	character.inventory.remove_instance(before[before.size() - 1])
	check_eq(_claim(11, claimed), "", "claim after making room")
	check_eq(claimed.size(), 1, "one item")
	var after := _equipment_ids()
	check_eq(after.size(), before.size(), "one slot freed, one filled")
	# second claim: nothing
	rng = _rng(12)
	state = rng.state
	check_eq(BossRewardService.claim(character, BOSS, table, rng, claimed), "The cache is empty.", "second claim refused")
	check_eq(rng.state, state, "no second roll")
	check_eq(claimed.size(), 1, "still one item")
	check_eq(_equipment_ids(), after, "bag unchanged")


func test_trial_blocks_the_claim() -> void:
	character.world.set_flag(DEFEATED)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial running")
	var before := character.inventory.items().size()
	check_eq(_claim(3), "Finish or leave the current trial first.", "refused in a trial")
	check_eq(character.inventory.items().size(), before, "bag unchanged")
	check(not character.world.flags.has(CLAIMED), "flag unchanged")
	PrologueService.end_trial(character, false)
	check_eq(_claim(3), "", "claim after the trial")


func test_failed_hand_over_keeps_the_claim_and_duplicates_nothing() -> void:
	character.world.set_flag(DEFEATED)
	var item := EquipmentLoot.roll(table, db, _rng(5))
	check_eq(character.inventory.add_instance(item), "", "a copy already in the bag")
	var count := character.inventory.items().size()
	check(BossRewardService.hand_over(character, BOSS, item) != "", "duplicate instance refused")
	check_eq(character.inventory.items().size(), count, "no second instance")
	check(not character.world.flags.has(CLAIMED), "no claim flag after a failed insert")
	check(BossRewardService.has_claim(character, BOSS), "claim stays open")
	var broken := EquipmentLoot.roll(table, db, _rng(6))
	broken.instance_id = ""
	check(BossRewardService.hand_over(character, BOSS, broken) != "", "invalid instance refused")
	check_eq(character.inventory.items().size(), count, "nothing kept")
	check(not character.world.flags.has(CLAIMED), "still no claim flag")
	# the snapshot never shows the claim flag without its item
	var payload := character.to_dict()
	check(not (payload.world.flags as Dictionary).has(String(CLAIMED)), "save holds no claim flag")


func test_item_and_claim_flag_share_one_snapshot_through_save_and_load() -> void:
	character.world.set_flag(DEFEATED)
	var pending := _reload(character)
	check(BossRewardService.has_claim(pending, BOSS), "claim survives save/load")
	character = pending
	var claimed: Array[ItemInstance] = []
	check_eq(_claim(21, claimed), "", "claimed after load")
	var payload := character.to_dict()
	var ids: Array = (payload.inventory as Array).map(func(entry: Dictionary) -> String: return str(entry.get("id", "")))
	check_eq((payload.world.flags as Dictionary).get(String(CLAIMED)), true, "flag in the snapshot")
	check(claimed[0].instance_id in ids, "item in the same snapshot")
	var loaded := _reload(character)
	check(not BossRewardService.has_claim(loaded, BOSS), "claimed after load")
	var again := loaded.inventory.find(claimed[0].instance_id)
	if check(again != null, "item kept"):
		check_eq(again.rarity, R.RARE, "rarity kept")
		check_eq(again.item_level, 20, "level kept")
		check_eq(again.affixes.size(), claimed[0].affixes.size(), "affixes kept (never rolled again)")
	character = loaded
	check_eq(_claim(22), "The cache is empty.", "no claim after load")


func test_old_saves_get_the_claim_only_with_a_real_defeat_flag() -> void:
	var old := CharacterFactory.create_new(db)
	old.world.set_flag(DEFEATED)
	var with_flag := old.to_dict()
	(with_flag.prologue as Dictionary).erase("class_reward")   # a v14 payload
	var errors: PackedStringArray = []
	var migrated: Variant = SaveMigrations.migrate(with_flag, 14, errors)
	check(migrated is Dictionary and errors.is_empty(), "v14 -> current migrates: %s" % [errors])
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(migrated)), db, warnings)
	check(BossRewardService.has_claim(loaded, BOSS), "old save with the defeat flag: claim open")
	character = loaded
	check_eq(_claim(31), "", "old save claims once")
	var without := CharacterFactory.create_new(db).to_dict()
	(without.prologue as Dictionary).erase("class_reward")
	migrated = SaveMigrations.migrate(without, 14, errors)
	loaded = Character.from_dict(JSON.parse_string(JSON.stringify(migrated)), db, warnings)
	check(not BossRewardService.has_claim(loaded, BOSS), "old save without the defeat flag: no claim")
	# quest progress, a chosen class or visits are no proof
	loaded.world.set_flag(&"prologue.haven_discovered")
	loaded.world.set_map_value(&"whisper_forest", "visits", 9)
	check(not BossRewardService.has_claim(loaded, BOSS), "no heuristic claim")


func test_reward_rolls_follow_the_existing_table_and_roller() -> void:
	check_eq(table.item_ids.size(), 12, "twelve models")
	check_eq(table.rarity_weights, {2: 100.0}, "Rare only")
	check(table.source_level == 20 and table.level_spread == 0, "item level 20")
	check_eq(table.tier_weights.weights_for(20), {5: 75.0, 4: 25.0}, "T5 75 / T4 25")
	check_eq(ItemCreation.AFFIX_COUNTS[R.RARE], {3: 60.0, 4: 40.0}, "Rare 3/4 = 60/40")
	var counts := {}
	var tiers := {}
	var models := {}
	var keen_on_armour := false
	for seed_value in 60:
		character = CharacterFactory.create_new(db)
		character.world.set_flag(DEFEATED)
		var claimed: Array[ItemInstance] = []
		check_eq(_claim(seed_value, claimed), "", "seed %d claims" % seed_value)
		var item := claimed[0]
		var same := EquipmentLoot.roll(table, db, _rng(seed_value))
		check(item.definition_id == same.definition_id and item.affixes.size() == same.affixes.size(),
				"seed %d: same pipeline as EquipmentLoot.roll" % seed_value)
		var definition := db.get_item(item.definition_id)
		models[item.definition_id] = true
		counts[item.affixes.size()] = true
		check(item.rarity == R.RARE and item.item_level == 20 and item.origin == ItemInstance.ORIGIN_FOUND, "seed %d: Rare ilvl 20 found" % seed_value)
		check(item.essences.is_empty() and item.sockets.is_empty(), "seed %d: no essences" % seed_value)
		var seen := {}
		for entry in item.affixes:
			var affix_id := StringName(str(entry.get("affix", "")))
			var affix: AffixDefinition = db.affixes.get(affix_id)
			check(affix != null and affix_id in definition.generation_affixes, "seed %d: %s from the model pool" % [seed_value, affix_id])
			check(not seen.has(affix_id), "seed %d: no duplicate %s" % [seed_value, affix_id])
			seen[affix_id] = true
			if affix != null:
				var tier_def := affix.tier_of(entry)
				var tier := tier_def.tier if tier_def != null else 0
				tiers[tier] = true
				check(tier == 4 or tier == 5, "seed %d: %s tier %d" % [seed_value, affix_id, tier])
			if item.definition_id in WEAPONS:
				check(affix_id != &"thundering", "seed %d: no Thundering on %s" % [seed_value, item.definition_id])
			else:
				check(affix_id in ARMOUR_AFFIXES, "seed %d: armour affix %s" % [seed_value, affix_id])
				keen_on_armour = keen_on_armour or affix_id == &"keen"
	check(counts.has(3) and counts.has(4), "3 and 4 affixes reached: %s" % [counts.keys()])
	check(tiers.has(4) and tiers.has(5), "T4 and T5 reached: %s" % [tiers.keys()])
	check(keen_on_armour, "Keen rolled on an armour piece")
	for model: StringName in models:
		check(model in MODELS, "%s in the reward pool" % model)


func test_wanderer_coat_is_a_rare_instance_and_the_feed_says_rare() -> void:
	var seed_value := _seed_for(&"wanderer_coat")
	if not check(seed_value >= 0, "a seed rolls wanderer_coat"):
		return
	character.world.set_flag(DEFEATED)
	var claimed: Array[ItemInstance] = []
	check_eq(_claim(seed_value, claimed), "", "claimed")
	var definition := db.get_item(&"wanderer_coat")
	check_eq(definition.rarity, R.MAGIC, "the definition stays Magic")
	check_eq(claimed[0].effective_rarity(definition), R.RARE, "the instance is Rare")


# --- map: kill, milestone save, cache -------------------------------------------------------------

func test_kill_saves_once_and_opens_the_cache() -> void:
	var map := await _open_forest()
	if not check(map != null, "forest loaded"):
		return
	var cache := _cache(map)
	var warden := _warden(map)
	if not check(cache != null and warden != null, "cache and warden placed"):
		return
	check(not cache.visible, "cache hidden before the kill")
	check_eq(cache.open(), "The cache is sealed.", "no claim before the kill")
	var config: EnemyConfig = load("res://data/enemies/grove_warden_config.tres")
	var fixed := {}
	for drop in config.drops:
		fixed[drop.item_id] = drop.quantity
	check_eq(fixed, {&"hollow_essence": 1, &"iron_ore": 2, &"gold_coin": 25}, "fixed boss drops unchanged")
	session.saves.save_started.connect(_on_save_started)
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	warden.health.apply_hit(lethal)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(DEFEATED), "defeat flag set")
	check_eq(_critical_saves, 1, "one milestone save after the kill")
	check_eq(session.saves.last_result.get("ok"), true, "written")
	var written := SaveSystem.load_from(str(session.saves.last_result.get("path", "")), db)
	check(written.ok() and written.character.world.has_flag(DEFEATED), "the save contains the defeat flag")
	check(cache.visible, "cache visible after the kill")
	var dropped := {}
	for node in map.find_children("*", "ItemPickup", true, false):
		var pickup := node as ItemPickup
		check(pickup.item == null, "no generated equipment on the ground")
		dropped[pickup.item_id] = dropped.get(pickup.item_id, 0) + pickup.quantity
	check_eq(dropped, fixed, "the fixed drops lie on the ground, not collected")
	# repeated death signals: no new claim, no second kill save
	warden.defeated.emit(warden)
	warden.health.apply_hit(lethal)
	for i in 5:
		await get_tree().process_frame
	check_eq(_critical_saves, 1, "no second kill save")
	check(not character.world.flags.has(CLAIMED), "no claim flag from death signals")


func test_cache_survives_map_changes_and_claims_once_with_a_rare_feed_row() -> void:
	character.world.set_flag(DEFEATED)   # old save / earlier kill
	var bag := character.inventory.items().size()
	var map := await _open_forest()
	check(_cache(map).visible, "cache visible on arrival")
	map = await _open_forest()   # map change while the claim is open
	var cache := _cache(map)
	check(cache.visible, "cache still there after a map change")
	check_eq(character.inventory.items().size(), bag, "nothing granted or lost by travelling")
	cache.rng.seed = _seed_for(&"wanderer_coat")
	session.saves.save_started.connect(_on_save_started)
	cache.interact(map.hud)
	for i in 3:
		await get_tree().process_frame
	check_eq(character.inventory.items().size(), bag + 1, "one item")
	check(not cache.visible, "cache gone after the claim")
	check_eq(_critical_saves, 1, "milestone save after the claim")
	var feed := map.hud.loot_feed
	if check(feed.rows() >= 1, "loot feed row"):
		var box := feed.get_child(feed.rows() - 1).get_child(0)
		var name_label := box.get_child(1) as Label
		check(name_label.text.begins_with(db.get_item(&"wanderer_coat").display_name), "wanderer_coat row")
		check_eq(name_label.get_theme_color(&"font_color"), UiTheme.rarity_color(R.RARE), "Rare colour")
		check_eq((box.get_child(2) as Label).text, UiTheme.rarity_name(R.RARE), "says Rare, not Magic")
		check_eq((box.get_child(0) as ItemIcon).rarity, R.RARE, "icon pips Rare")
	# definition-only rows (plain pickups) keep the definition rarity
	feed.push(&"wanderer_coat", 1)
	check_eq((feed.get_child(feed.rows() - 1).get_child(0).get_child(2) as Label).text, UiTheme.rarity_name(R.MAGIC), "plain row: definition rarity")
	map = await _open_forest()
	check(not _cache(map).visible, "no cache after the claim and a reload")
	check(_warden(map) == null, "the warden stays gone")
	check_eq(_cache(map).open(), "The cache is empty.", "no second claim")
	check_eq(character.inventory.items().size(), bag + 1, "still one item")


func test_full_bag_keeps_the_cache_in_the_world() -> void:
	character.world.set_flag(DEFEATED)
	_fill_bag()
	var map := await _open_forest()
	var cache := _cache(map)
	var pickups := map.find_children("*", "ItemPickup", true, false).size()
	cache.interact(map.hud)
	await get_tree().process_frame
	check(cache.visible, "cache stays")
	check_eq(map.find_children("*", "ItemPickup", true, false).size(), pickups, "nothing dropped into the world")
	check(BossRewardService.has_claim(character, BOSS), "claim open")
