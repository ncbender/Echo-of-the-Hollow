extends TestCase
## Chapter 1 Rare Reward 1.0 (docs/CHAPTER_1_RARE_REWARD_1_0.md): the guaranteed Rare belongs to the
## Rootbound Sentinel (Sentinel's Cache in Warden's Rest, BossRewardService, existing table rolled only at
## claim time); the Warden's Cache in the Whisper Forest is a one-time StoryPickup of 2 Iron Ingots. The
## frozen legacy claim boss_reward.whisper_forest_grove_warden closes the Sentinel's Cache (one Rare per
## character) and the Warden's Cache (no second reward). Full bag, trial, save/load, synthetic v15 states
## A-E, milestone saves, interaction range. Fixed seeds; files only under user://test_saves/chapter1_rare/.

const R := ItemDefinition.Rarity
const BOSS := &"wardens_rest_rootbound_sentinel"
const DEFEATED := &"defeated.wardens_rest_rootbound_sentinel"
const CLAIMED := &"boss_reward.wardens_rest_rootbound_sentinel"
const WARDEN := &"whisper_forest_grove_warden"
const WARDEN_DEFEATED := &"defeated.whisper_forest_grove_warden"
const LEGACY := &"boss_reward.whisper_forest_grove_warden"
const WARDEN_CACHE_TAKEN := &"pickup.whisper_forest_wardens_cache"
const TAKEN: Array[StringName] = [LEGACY]
const REWARD := "res://data/loot/grove_warden_rare_reward.tres"
const DIR := "user://test_saves/chapter1_rare"
const PROFILE := DIR + "/slot_1.save.json"
const MODELS := [&"iron_sword", &"steel_greatsword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear",
	&"oak_staff", &"oak_wand", &"hunting_bow", &"leather_cap", &"wanderer_coat", &"oak_shield"]
const QUEST := &"the_first_signs"
const EVENTS: Array[StringName] = [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone",
	&"enter:wardens_rest", &"interact:wardens_rest_watchstone"]
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]

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
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = PROFILE
	session.saves.reset()
	_critical_saves = 0
	_clean()


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	if session.saves.save_started.is_connected(_on_save_started):
		session.saves.save_started.disconnect(_on_save_started)
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous)


func _clean() -> void:
	var paths := SaveSlots.all_paths(PROFILE)
	paths.append(DIR + "/roundtrip.save.json")
	for path in paths:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _claim(seed_value: int, claimed: Array[ItemInstance] = []) -> String:
	return BossRewardService.claim(character, BOSS, table, _rng(seed_value), claimed, TAKEN)


## A real save file round trip (current version, v15).
func _reload(source: Character) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.save_to(source, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded %s" % [loaded.errors])
	return loaded.character


func _fill_bag() -> void:
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1, ItemInstance.ORIGIN_FOUND)


func _instance_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for item in character.inventory.items():
		ids.append(item.instance_id)
	return ids


func _rares() -> int:
	var count := 0
	for item in character.inventory.items():
		if item.rarity == R.RARE:
			count += 1
	return count


func _on_save_started(kind: SaveCoordinator.Kind) -> void:
	if kind == SaveCoordinator.Kind.CRITICAL:
		_critical_saves += 1


func _open(map_id: StringName, path: String) -> GameMap:
	character.world.map_id = map_id
	session.set_character(character)
	get_tree().change_scene_to_file(path)
	var map: GameMap = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 5:   # let arrival milestones write first
		await get_tree().process_frame
	return map


func _open_rest() -> GameMap:
	return await _open(&"wardens_rest", "res://scenes/maps/wardens_rest.tscn")


func _open_forest() -> GameMap:
	return await _open(&"whisper_forest", "res://scenes/maps/whisper_forest.tscn")


func _cache(map: GameMap) -> BossRewardCache:
	return map.get_node_or_null("SentinelCache") as BossRewardCache


func _warden_cache(map: GameMap) -> StoryPickup:
	return map.get_node_or_null("WardensCache") as StoryPickup


func _kill(enemy: Enemy) -> void:
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	enemy.health.apply_hit(lethal)


## Finished prologue, the_first_signs at `step` (5 = Sentinel defeated, watchstone examined).
func _story_at(step: int) -> Character:
	var c := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		c.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			c.world.set_flag(quest.completion_flag)
		for quest_step in quest.steps:
			if quest_step.completion_flag != &"":
				c.world.set_flag(quest_step.completion_flag)
	c.prologue.stage = PrologueState.Stage.COMPLETED
	c.prologue.completed_trials = [&"trial_arcanist"] as Array[StringName]
	c.prologue.chosen_class = &"arcanist"
	StoryService.start(c, QUEST)
	if step >= 5:
		c.world.set_flag(DEFEATED)
	for event: StringName in EVENTS.slice(0, step):
		StoryService.notify(c, event)
	check(StoryService.at_step(c, QUEST, step), "set up at step %d" % step)
	return c


# --- data and placement ---------------------------------------------------------------------------

func test_placement_data_and_reach() -> void:
	var forest: GameMap = load("res://scenes/maps/whisper_forest.tscn").instantiate()
	check(forest.find_children("*", "BossRewardCache", true, false).is_empty(), "no Rare cache in the Whisper Forest")
	var warden_cache := _warden_cache(forest)
	if check(warden_cache != null, "Warden's Cache kept"):
		check_eq([warden_cache.persistent_id, warden_cache.item_id, warden_cache.quantity, warden_cache.label],
			[&"whisper_forest_wardens_cache", &"iron_ingot", 2, "Warden's Cache"], "materials only")
		check_eq(warden_cache.condition.required_flags, [WARDEN_DEFEATED] as Array[StringName], "after the kill")
		check_eq(warden_cache.condition.forbidden_flags, [LEGACY] as Array[StringName], "closed by the legacy Rare claim")
		check(warden_cache.event_id == &"", "no story event")
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	check(warden.persistent_id == WARDEN and warden.defeat_milestone and warden.equipment_loot == null, "Warden: own milestone, no equipment roll")
	forest.free()
	var rest: GameMap = load("res://scenes/maps/wardens_rest.tscn").instantiate()
	var caches := rest.find_children("*", "BossRewardCache", true, false)
	check_eq(caches.size(), 1, "one reward cache in Warden's Rest")
	var cache := _cache(rest)
	if check(cache != null, "Sentinel's Cache"):
		check(cache.boss_id == BOSS and cache.loot_table == table and cache.label == "Sentinel's Cache", "the existing Rare table")
		check_eq(cache.taken_flags, TAKEN, "legacy claim counts as taken")
		var sentinel := rest.get_node("Enemies/RootboundSentinel") as Enemy
		check(not sentinel.defeat_milestone and sentinel.equipment_loot == null, "milestone from the cache, no extra loot table")
		check(cache.position.distance_to(sentinel.position) <= 140.0, "in the Sentinel's arena")
		var stone := rest.get_node("AfterSentinel/SplitWatchstone") as Node2D
		check(cache.position.distance_to(stone.position) > 100.0, "apart from the Split Watchstone")
		var bounds := rest.camera_bounds
		check(bounds.has_point(cache.position), "inside the map")
	check_eq(table.rarity_weights, {2: 100.0}, "table unchanged: Rare only")
	rest.free()


func test_cache_is_reachable_and_in_interaction_range() -> void:
	character.world.set_flag(DEFEATED)
	var map := await _open_rest()
	if not check(map != null, "Warden's Rest loaded"):
		return
	var cache := _cache(map)
	check(cache.visible, "cache open for a defeated Sentinel")
	check_eq(cache.prompt, "Open Sentinel's Cache", "prompt")
	var space := map.get_world_2d().direct_space_state
	for from: Vector2 in [Vector2(100, 0), Vector2(-200, 0), Vector2(200, 180)]:
		var ray := PhysicsRayQueryParameters2D.create(from, cache.global_position, 1)
		check(space.intersect_ray(ray).is_empty(), "no wall between %s and the cache" % from)
	var shape := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	shape.transform = Transform2D(0.0, cache.global_position)
	shape.collision_mask = 1
	check(space.intersect_shape(shape).is_empty(), "the player fits on the cache")
	map.player.global_position = cache.global_position + Vector2(0, 40)
	for i in 4:
		await get_tree().physics_frame
	check(Interactable.find_active(get_tree()) != cache, "out of range at 40 px")
	map.player.global_position = cache.global_position + Vector2(0, 12)
	for i in 4:
		await get_tree().physics_frame
	check(Interactable.find_active(get_tree()) == cache, "in range at 12 px")


# --- claim contract -------------------------------------------------------------------------------

func test_no_claim_before_the_sentinel_falls() -> void:
	var before := _instance_ids()
	check(not BossRewardService.has_claim(character, BOSS, TAKEN), "no claim without the defeat flag")
	check_eq(_claim(1), "The cache is sealed.", "refused")
	check_eq(_instance_ids(), before, "no item")
	check(not character.world.flags.has(CLAIMED), "no claim flag")
	character.world.set_flag(WARDEN_DEFEATED)
	check(not BossRewardService.has_claim(character, BOSS, TAKEN), "the Grove Warden is no proof")


func test_sentinel_gives_exactly_one_rare() -> void:
	character.world.set_flag(DEFEATED)
	var claimed: Array[ItemInstance] = []
	check_eq(_claim(7, claimed), "", "claimed")
	if not check_eq(claimed.size(), 1, "exactly one item"):
		return
	var item := claimed[0]
	check(character.inventory.has(item.instance_id), "in the bag")
	check(item.rarity == R.RARE and item.item_level == 20 and item.origin == ItemInstance.ORIGIN_FOUND, "Rare, ilvl 20, found")
	check(item.definition_id in MODELS, "from the existing pool")
	var same := EquipmentLoot.roll(table, db, _rng(7))
	check(same.definition_id == item.definition_id and same.affixes == item.affixes, "the existing EquipmentLoot pipeline")
	check_eq(character.world.get_flag(CLAIMED), true, "claim flag")
	var rng := _rng(8)
	var state := rng.state
	check_eq(BossRewardService.claim(character, BOSS, table, rng, claimed, TAKEN), "The cache is empty.", "second claim refused")
	check_eq(rng.state, state, "no second roll")
	check_eq(_rares(), 1, "one Rare")


func test_full_and_partly_full_bag_keep_the_claim_open() -> void:
	character.world.set_flag(DEFEATED)
	_fill_bag()
	var before := _instance_ids()
	var rng := _rng(11)
	var state := rng.state
	var claimed: Array[ItemInstance] = []
	check_eq(BossRewardService.claim(character, BOSS, table, rng, claimed, TAKEN), "Your bag is full. Make room to open the cache.", "full bag")
	check(rng.state == state and claimed.is_empty() and _instance_ids() == before, "nothing rolled, bag unchanged")
	check(not character.world.flags.has(CLAIMED) and BossRewardService.has_claim(character, BOSS, TAKEN), "claim open")
	var saved := _reload(character)
	check(BossRewardService.has_claim(saved, BOSS, TAKEN), "open claim survives save/load with a full bag")
	# one free slot (partly full bag): exactly one claim
	character.inventory.remove_instance(before[before.size() - 1])
	check_eq(character.inventory.free_slots(), 1, "one free slot")
	check_eq(_claim(11, claimed), "", "claim with one free slot")
	check_eq(claimed.size(), 1, "one item")
	check_eq(character.inventory.free_slots(), 0, "the slot is used")


func test_trial_and_failed_hand_over_set_no_flag() -> void:
	character.world.set_flag(DEFEATED)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial running")
	check_eq(_claim(3), "Finish or leave the current trial first.", "refused in a trial")
	check(not character.world.flags.has(CLAIMED), "no flag")
	PrologueService.end_trial(character, false)
	var item := EquipmentLoot.roll(table, db, _rng(5))
	check_eq(character.inventory.add_instance(item), "", "a copy already in the bag")
	check(BossRewardService.hand_over(character, BOSS, item) != "", "duplicate instance refused")
	check(not character.world.flags.has(CLAIMED), "no claim flag without an item")
	check(not (character.to_dict().world.flags as Dictionary).has(String(CLAIMED)), "no flag in the snapshot")


func test_save_after_claim_and_load_before_claim() -> void:
	character.world.set_flag(DEFEATED)
	var before_claim := _reload(character)
	check(BossRewardService.has_claim(before_claim, BOSS, TAKEN), "load before claim: open")
	character = before_claim
	var claimed: Array[ItemInstance] = []
	check_eq(_claim(21, claimed), "", "claimed after load")
	var loaded := _reload(character)
	check(not BossRewardService.has_claim(loaded, BOSS, TAKEN), "load after claim: closed")
	var again := loaded.inventory.find(claimed[0].instance_id)
	if check(again != null, "item kept"):
		check(again.rarity == R.RARE and again.affixes == claimed[0].affixes and again.item_level == 20, "never rolled again")
	character = loaded
	check_eq(_claim(22), "The cache is empty.", "no claim after load")
	check_eq(_rares(), 1, "still one Rare")


# --- map: Sentinel kill, cache, milestone saves ---------------------------------------------------

func test_sentinel_kill_opens_the_cache_once_with_milestones() -> void:
	var map := await _open_rest()
	if not check(map != null, "Warden's Rest loaded"):
		return
	var cache := _cache(map)
	var sentinel := map.get_node_or_null("Enemies/RootboundSentinel") as Enemy
	if not check(cache != null and sentinel != null, "cache and Sentinel placed"):
		return
	check(not cache.visible, "sealed before the kill")
	check_eq(cache.open(), "The cache is sealed.", "no claim before the kill")
	session.saves.save_started.connect(_on_save_started)
	_kill(sentinel)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(DEFEATED), "defeat flag")
	check_eq(_critical_saves, 1, "one milestone save after the kill")
	var written := SaveSystem.load_from(str(session.saves.last_result.get("path", "")), db)
	check(written.ok() and written.character.world.has_flag(DEFEATED), "the save holds the defeat")
	check(cache.visible, "cache open after the kill")
	check(map.find_children("*", "ItemPickup", true, false).all(func(node: Node) -> bool: return (node as ItemPickup).item == null),
		"no equipment on the ground")
	sentinel.defeated.emit(sentinel)
	for i in 5:
		await get_tree().process_frame
	check_eq(_critical_saves, 1, "repeated death signal: no second save")
	var bag := character.inventory.items().size()
	cache.rng.seed = 7
	cache.interact(map.hud)
	for i in 3:
		await get_tree().process_frame
	check_eq(character.inventory.items().size(), bag + 1, "one item")
	check_eq(_rares(), 1, "one Rare")
	check(not cache.visible, "cache gone")
	check_eq(_critical_saves, 2, "milestone save after the claim")
	var feed := map.hud.loot_feed
	if check(feed.rows() >= 1, "loot feed row"):
		check_eq((feed.get_child(feed.rows() - 1).get_child(0).get_child(2) as Label).text, UiTheme.rarity_name(R.RARE), "the feed says Rare")
	for i in 3:
		cache.interact(map.hud)
	check_eq(character.inventory.items().size(), bag + 1, "repeated interaction: nothing more")
	map = await _open_rest()
	check(not _cache(map).visible and map.get_node_or_null("Enemies/RootboundSentinel") == null, "after a reload: cache and Sentinel gone")


func test_full_bag_keeps_the_cache_in_the_world() -> void:
	character.world.set_flag(DEFEATED)
	_fill_bag()
	var map := await _open_rest()
	var cache := _cache(map)
	var pickups := map.find_children("*", "ItemPickup", true, false).size()
	cache.interact(map.hud)
	await get_tree().process_frame
	check(cache.visible, "cache stays")
	check_eq(map.find_children("*", "ItemPickup", true, false).size(), pickups, "nothing dropped into the world")
	check(BossRewardService.has_claim(character, BOSS, TAKEN), "claim open")


# --- Grove Warden: materials, no Rare -------------------------------------------------------------

func test_new_game_grove_warden_gives_no_rare() -> void:
	var map := await _open_forest()
	if not check(map != null, "forest loaded"):
		return
	var cache := _warden_cache(map)
	var warden := map.get_node_or_null("Enemies/GroveWarden") as Enemy
	if not check(cache != null and warden != null, "cache and Warden placed"):
		return
	check(not cache.visible, "hidden before the kill")
	session.saves.save_started.connect(_on_save_started)
	_kill(warden)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(WARDEN_DEFEATED), "defeat flag")
	check_eq(_critical_saves, 1, "the kill keeps its one milestone save")
	check(cache.visible, "cache open after the kill")
	var ingots := character.inventory.count(&"iron_ingot")
	var items := character.inventory.items().size()
	cache.interact(map.hud)
	check_eq(character.inventory.count(&"iron_ingot"), ingots + 2, "2 Iron Ingots")
	check_eq(_rares(), 0, "no Rare")
	check(not cache.visible and character.world.has_flag(WARDEN_CACHE_TAKEN), "taken once")
	check(not character.world.has_flag(LEGACY), "the legacy Rare claim is never set")
	check_eq(cache.take(), "Nothing to recover.", "no second take")
	check(items <= character.inventory.items().size(), "no item lost")
	# the Sentinel's Rare is still open afterwards
	character.world.set_flag(DEFEATED)
	check(BossRewardService.has_claim(character, BOSS, TAKEN), "the Sentinel's Rare stays open")
	var loaded := _reload(character)
	check(loaded.world.has_flag(WARDEN_CACHE_TAKEN) and BossRewardService.has_claim(loaded, BOSS, TAKEN), "both survive save/load")
	map = await _open_forest()
	check(not _warden_cache(map).visible, "no Warden's Cache after a reload")


func test_full_bag_keeps_the_warden_cache() -> void:
	character.world.set_flag(WARDEN_DEFEATED)
	_fill_bag()
	var map := await _open_forest()
	var cache := _warden_cache(map)
	check_eq(cache.take(), "Your pack is full.", "refused")
	check(cache.visible and not character.world.has_flag(WARDEN_CACHE_TAKEN), "stays open")
	var carried := character.inventory.items().filter(func(i: ItemInstance) -> bool: return character.inventory.takes_slot(i))
	character.inventory.remove_instance(carried[0].instance_id)   # a bag item (equipped gear takes no slot)
	check_eq(cache.take(), "", "taken with room")
	check_eq(character.inventory.count(&"iron_ingot"), 2, "2 Iron Ingots")


# --- old v15 saves (synthetic) --------------------------------------------------------------------

## A: Grove Warden defeated, old Rare cache not opened. The Rare is not lost: it waits at the Sentinel.
func test_old_save_a_warden_kill_without_claim() -> void:
	character.world.set_flag(WARDEN_DEFEATED)
	character = _reload(character)
	var map := await _open_forest()
	var cache := _warden_cache(map)
	check(cache.visible, "Warden's Cache open (materials)")
	check(not BossRewardService.has_claim(character, BOSS, TAKEN), "no Rare before the Sentinel")
	cache.interact(map.hud)
	check_eq(_rares(), 0, "the Warden's Cache gives no Rare")
	character.world.set_flag(DEFEATED)
	check_eq(_claim(31), "", "the Rare at the Sentinel")
	check_eq(_rares(), 1, "exactly one Rare")


## B: the old guaranteed Rare was taken at the Warden: no second Rare, no extra Warden reward.
func test_old_save_b_rare_already_claimed() -> void:
	character.world.set_flag(WARDEN_DEFEATED)
	character.world.set_flag(LEGACY)
	var item := EquipmentLoot.roll(table, db, _rng(41))
	check_eq(character.inventory.add_instance(item), "", "the old Rare in the bag")
	character.world.set_flag(DEFEATED)
	character = _reload(character)
	check(character.inventory.find(item.instance_id) != null, "the old Rare is kept")
	check(not BossRewardService.has_claim(character, BOSS, TAKEN), "Sentinel's Cache closed")
	check_eq(_claim(42), "The cache is empty.", "no second Rare")
	var forest := await _open_forest()
	check(not _warden_cache(forest).visible, "Warden's Cache stays closed")
	var rest := await _open_rest()
	check(not _cache(rest).visible, "Sentinel's Cache not shown")
	check_eq(_rares(), 1, "still one Rare")
	check(character.world.has_flag(LEGACY) and character.world.has_flag(WARDEN_DEFEATED) and character.world.has_flag(DEFEATED), "flags kept")


## C: Sentinel defeated, Split Watchstone not examined (step 4): the Rare is open, the quest unchanged.
func test_old_save_c_sentinel_kill_before_the_watchstone() -> void:
	character = _story_at(4)
	character.world.set_flag(DEFEATED)
	character = _reload(character)
	var rest := await _open_rest()
	check(_cache(rest).visible, "cache open on arrival")
	check((rest.get_node("AfterSentinel/SplitWatchstone") as Node2D).is_visible_in_tree(), "the watchstone stays")
	_cache(rest).rng.seed = 9
	_cache(rest).interact(rest.hud)
	check_eq(_rares(), 1, "one Rare")
	check(StoryService.at_step(character, QUEST, 4), "quest step unchanged by the claim")
	(rest.get_node("AfterSentinel/SplitWatchstone") as Readable).interact(rest.hud)
	rest.hud.close_windows()
	check(StoryService.at_step(character, QUEST, 5), "the watchstone still moves the quest")


## D: the_first_signs completed: the open Rare is still claimable, nothing is reset.
func test_old_save_d_first_signs_completed() -> void:
	character = _story_at(5)
	StoryService.notify(character, &"talk:edrin_first_signs_report")
	check_eq(character.quests.entries[QUEST].get("state"), "completed", "completed")
	character = _reload(character)
	check(BossRewardService.has_claim(character, BOSS, TAKEN), "claim open")
	check_eq(_claim(51), "", "claimed")
	check_eq(character.quests.entries[QUEST].get("state"), "completed", "still completed")
	check(character.world.has_flag(DEFEATED), "kill kept")


## E: neither boss defeated: both caches sealed.
func test_old_save_e_no_boss_defeated() -> void:
	character = _reload(character)
	check(not BossRewardService.has_claim(character, BOSS, TAKEN), "no Rare")
	var forest := await _open_forest()
	check(not _warden_cache(forest).visible, "Warden's Cache hidden")
	var rest := await _open_rest()
	check(not _cache(rest).visible, "Sentinel's Cache hidden")
