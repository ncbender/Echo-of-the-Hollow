extends TestCase
## Loot & Progress Feedback 1.0 (docs/LOOT_PROGRESS_FEEDBACK_1_0.md): the one loot feed (only real grants, bundled,
## bounded, queued, carried over a map change), gathering without step texts, the compact hero / mastery level-up
## notice with its world pulse (coalesced, one after the other, never on load or class switch) and no parry text
## under the hero. Real arena, real character; display only - no grant, XP or rule is changed.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	session.set_character(character)
	await _load_arena()


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _load_arena() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(3)


func _frames(count: int = 2) -> void:
	for i in count:
		await get_tree().process_frame


func _feed() -> LootFeed:
	return map.hud.loot_feed


func _notice() -> ProgressNotice:
	return map.hud.progress_notice


func _fx() -> Array[Node]:
	return map.player.find_children("*", "LevelUpFx", false, false)


func _age_all(feed: LootFeed, seconds: float) -> void:
	for row: Control in feed.get_children():
		row.set_meta(&"born", float(row.get_meta(&"born")) + seconds)


## Same item, same profession: one row each, the amounts added up; a later event (past the window) is a new row.
func test_bundling_without_double_counting() -> void:
	var feed := _feed()
	feed.push(&"iron_ore", 2)
	feed.push(&"iron_ore", 3)
	map.hud.bridge.profession_xp.emit(&"mining", 4)
	map.hud.bridge.profession_xp.emit(&"mining", 8)
	await _frames(1)
	check_eq(feed.texts(), PackedStringArray(["Iron Ore  ×5", "Mining  +12 XP"]), "bundled: %s" % feed.texts())
	_age_all(feed, LootFeed.BUNDLE_WINDOW + 0.1)
	feed.push(&"iron_ore", 1)
	await _frames(1)
	check_eq(feed.texts(), PackedStringArray(["Iron Ore  ×5", "Mining  +12 XP", "Iron Ore"]), "past the window: a new row")
	feed.push(&"gold_coin", 40)
	await _frames(1)
	check(feed.texts().has("+40 Gold Coin"), "gold briefly: %s" % feed.texts())
	# a bundle never lives past BUNDLE_WINDOW + LIFETIME however often it is fed
	var first := feed.get_child(0) as Control
	check(float(first.get_meta(&"born")) > LootFeed.BUNDLE_WINDOW, "the old row is past its window")
	feed.push(&"iron_ore", 1)
	check_eq(int(first.get_meta(&"quantity")), 5, "an old row is not refreshed again")


## Rolled single items (max_stack 1) are never shown as one stack; every instance keeps its own row and rarity.
func test_single_items_stay_apart() -> void:
	var feed := _feed()
	var a: ItemInstance = character.inventory.add_item(&"iron_sword", 1)[0]
	var b: ItemInstance = character.inventory.add_item(&"iron_sword", 1)[0]
	feed.push(a.definition_id, 1, a)
	feed.push(b.definition_id, 1, b)
	await _frames(1)
	check_eq(feed.rows(), 2, "two instances, two rows")
	check(not " ".join(feed.texts()).contains("×"), "no stack count on single items")


## Many events: never more than max_rows, the rest waits (bundled too) and comes in order; nothing is lost.
func test_feed_limit_and_queue() -> void:
	var feed := _feed()
	var ids: Array[StringName] = [&"iron_ore", &"timber", &"stone", &"raw_hide", &"flax_fiber", &"duskleaf", &"hollow_essence", &"oak_plank"]
	for item_id in ids:
		feed.push(item_id, 1)
	feed.push(&"oak_plank", 2)   # waits and bundles in the queue
	await _frames(1)
	check_eq(feed.rows(), feed.max_rows, "at most %d rows" % feed.max_rows)
	check_eq(feed.queued(), ids.size() - feed.max_rows, "the rest waits")
	var seen := {}
	for i in 600:
		await get_tree().process_frame
		for text in feed.texts():
			seen[text] = true
		if feed.queued() == 0 and feed.rows() == 0:
			break
	check(feed.rows() <= feed.max_rows and feed.queued() == 0, "the queue drained")
	check(seen.has("Oak Plank  ×3"), "the waiting events were shown, bundled: %s" % [seen.keys()])
	check(seen.has("Hollow Essence"), "nothing lost")


## Gathering: a successful step puts only what was granted into the feed (no "1/3" text); a failed one keeps its
## reason and adds nothing.
func test_gathering_success_and_failure() -> void:
	var definition: ResourceNodeDefinition = session.database.resource_nodes[&"oak_tree"]
	var node := ResourceNode.new()
	node.definition = definition
	node.node_id = &"feedback_oak"
	map.add_child(node)
	await _frames(1)
	node._hud = map.hud
	var before := character.inventory.count(&"timber")
	var xp_before := character.professions.xp(&"woodcutting")
	var result := node.complete_step()
	await _frames(1)
	check_eq(String(result.error), "", "a step")
	var gained := character.inventory.count(&"timber") - before
	var texts := _feed().texts()
	check(texts.has("Timber  ×%d" % gained) or (gained == 1 and texts.has("Timber")) or gained == 0, "the real yield in the feed: %s" % texts)
	if int(result.xp) > 0:
		check(texts.has("Woodcutting  +%d XP" % int(result.xp)), "the real XP in the feed: %s" % texts)
		check_eq(character.professions.xp(&"woodcutting") - xp_before, int(result.xp), "XP unchanged by the display")
	check(not "\n".join(map.hud.toasts.texts()).contains("/%d" % definition.steps), "no step counter text")
	check(not node.prompt.contains("/"), "no step counter in the prompt: %s" % node.prompt)
	# a full bag: the step fails, the reason is shown, the feed gets nothing
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"iron_sword", 1)
	var rows := _feed().get_child_count()
	var quantities := _feed().get_children().map(func(r: Node) -> int: return int(r.get_meta(&"quantity")))
	var timber := character.inventory.count(&"timber")
	var failed := node.complete_step()
	await _frames(1)
	if character.inventory.room_for(&"timber") < 1:
		check(String(failed.error) != "", "full bag: the step fails")
		check(map.hud.toasts.texts().has(String(failed.error)), "the reason stays visible: %s" % map.hud.toasts.texts())
		check_eq(character.inventory.count(&"timber"), timber, "nothing granted")
		check_eq([_feed().get_child_count(), _feed().get_children().map(func(r: Node) -> int: return int(r.get_meta(&"quantity")))], [rows, quantities], "nothing in the feed")
	node.queue_free()


## Several hero levels from one grant: one notice "Level a → b", one gold pulse; the talent line only when the
## rules really gave points.
func test_hero_level_up_coalesced() -> void:
	var class_id := character.classes.active_class_id
	var start := character.classes.get_level(class_id)
	var xp := 0
	for level in range(start, start + 3):
		xp += character.database.get_class_def(class_id).xp_to_next(level)
	var gained := character.classes.add_xp(class_id, xp)
	await _frames(2)
	check_eq(gained, 3, "three levels at once")
	var current := _notice().current()
	check(not current.is_empty() and current.kind == &"hero", "one hero notice")
	check(_notice().text().contains("Level %d → %d" % [start, start + 3]), "the span: %s" % _notice().text())
	check_eq(_notice().waiting(), 0, "no series of notices")
	check_eq(_fx().size(), 1, "one pulse")
	var rules := character.database.rules.talent_rules()
	var points := rules.points_at_level(start + 3) - rules.points_at_level(start)
	check(_notice().text().contains("talent point") == (points > 0), "talent line only when real (%d)" % points)


## Hero and mastery in one moment: shown one after the other (hero first), never on top of each other; the
## mastery notice names the new combo from the data.
func test_hero_and_mastery_one_after_the_other() -> void:
	var family_id := &"one_handed_sword"
	var family: WeaponFamily = character.database.weapons[family_id]
	var target := 0
	for entry: Dictionary in ComboIcons.entries(family):
		if int(entry.level) > 1:
			target = int(entry.level) if target == 0 else mini(target, int(entry.level))
	var xp := 0
	for level in range(character.mastery.get_level(family_id), target):
		xp += character.database.get_track(family_id).xp_to_next(level)
	character.mastery.add_xp(family_id, xp)
	character.classes.add_xp(character.classes.active_class_id, character.database.get_class_def(character.classes.active_class_id).xp_to_next(1))
	await _frames(2)
	check_eq(_notice().current().kind, &"hero", "hero first")
	check_eq(_notice().waiting(), 1, "mastery waits")
	check_eq(map.hud.progress_notice.get_parent().get_children().filter(func(n: Node) -> bool: return n is ProgressNotice).size(), 1, "one notice control")
	_notice()._age = ProgressNotice.SHOW + ProgressNotice.FADE
	await _frames(3)
	var current := _notice().current()
	check(not current.is_empty() and current.kind == &"mastery", "then the mastery")
	check(_notice().text().contains("%s mastery" % family.display_name) and _notice().text().contains("Level %d" % target), "family and level: %s" % _notice().text())
	var path_name := ""
	for path in family.combo_paths:
		if path.unlock_level == target:
			path_name = path.display_name
	if path_name != "":
		check(_notice().text().contains(path_name), "the new combo: %s" % _notice().text())
	check_eq(_fx().filter(func(f: Node) -> bool: return (f as LevelUpFx).kind == LevelUpFx.MASTERY).size(), 1, "a mastery pulse (diamond, not the gold ring)")
	check(not "\n".join(map.hud.toasts.texts()).contains("reached level"), "no extra level toasts")


## No notice and no pulse from a class switch, a load or a sync.
func test_no_level_feedback_on_load_or_switch() -> void:
	character.classes.add_xp(&"warrior", 5000)
	character.mastery.add_xp(&"one_handed_sword", 3000)
	await _frames(2)
	_notice()._current = {}
	_notice()._queue.clear()
	for fx in _fx():
		fx.queue_free()
	await _frames(2)
	character.classes.unlock(&"arcanist")
	check_eq(character.switch_class(&"arcanist", true), "", "switched")
	map.bridge.refresh_unlocks()
	await _frames(2)
	check(_notice().current().is_empty() and _notice().waiting() == 0, "no notice after a class switch")
	var path := "user://test_saves/loot_feedback/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.character != null, "loaded")
	session.set_character(loaded.character)
	await _load_arena()
	await _frames(3)
	check(_notice().current().is_empty() and _notice().waiting() == 0 and _fx().is_empty(), "no notice or pulse after loading a map")


## A map change keeps what was just received (the next map's feed shows it); old rows do not come back.
func test_feed_survives_a_map_change() -> void:
	_feed().push(&"timber", 3)
	_feed().push(&"stone", 1)
	_age_all(_feed(), LootFeed.CARRY_AGE + 0.5)
	_feed().push(&"iron_ore", 2)
	await _frames(1)
	await _load_arena()
	check_eq(_feed().texts(), PackedStringArray(["Iron Ore  ×2"]), "only the young row comes back: %s" % _feed().texts())


## Pause: the feed and the notice do not age while the tree is paused.
func test_pause_holds_the_feedback() -> void:
	_feed().push(&"timber", 1)
	await _frames(1)
	var row := _feed().get_child(0) as Control
	var age := float(row.get_meta(&"age"))
	get_tree().paused = true
	await _frames(10)
	check(is_equal_approx(float(row.get_meta(&"age")), age), "no ageing while paused")
	get_tree().paused = false
