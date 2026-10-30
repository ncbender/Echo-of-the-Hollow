extends TestCase
## Region 1 Gameplay Polish 1.0 (docs/GAMEPLAY_POLISH_1_0.md): the HUD tracker keeps the main quest
## as before and shows each side quest in one compact line (full text stays in the Journal), reward
## hints stay; the tracker fits at 150 % UI scale; What the Roots Keep points to its three areas;
## three optional one-time finds (cloister, hut, north loop) - full bag safe, saved, never twice.
## Only user://test_saves/.

const DIR := "user://test_saves/gameplay_polish"
const PROFILE := DIR + "/slot_1.save.json"
const MAIN := &"the_first_signs"
const SIDE: Array[StringName] = [&"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]

var db: GameDatabase
var session: SessionState
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = PROFILE
	session.saves.reset()
	_clean()


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _character() -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for step in quest.steps:
			if step.completion_flag != &"":
				character.world.set_flag(step.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"arcanist"
	StoryService.start(character, MAIN)
	return character


func _travel(map_id: StringName, spawn_id: StringName) -> GameMap:
	check(session.travel(map_id, spawn_id, false), "travel to %s accepted" % map_id)
	for i in 240:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _fill_bag(character: Character) -> void:
	while character.inventory.free_slots() > 0:
		if character.inventory.add_item(&"iron_sword", 1).is_empty():
			break


func _free_slots(character: Character, count: int) -> void:
	for item in character.inventory.items().duplicate():
		if count <= 0:
			return
		if item.definition_id == &"iron_sword" and character.inventory.takes_slot(item):   # never the worn sword (no bag slot)
			character.inventory.remove_instance(item.instance_id)
			count -= 1


# --- tracker --------------------------------------------------------------------------------------

func test_tracker_main_quest_unchanged_side_quests_one_line_each() -> void:
	var character := _character()
	var main_only := StoryService.tracker_lines(character)
	check_eq(main_only[0], "The Roots Remember: The First Signs", "main quest headline first")
	check(main_only.size() == 2 and main_only[1].contains("Follow the Whisper Forest east"), "main quest: its current goal %s" % [main_only])
	for count in range(1, 4):
		character.quests.entries[SIDE[count - 1]] = {"state": "active", "step": 0, "progress": {}}
		var lines := StoryService.tracker_lines(character)
		check_eq(lines.slice(0, 2), main_only, "%d side quests: the main quest stays first and unchanged" % count)
		check_eq(lines.size(), 2 + 1 + count, "%d side quests: one header + one line each" % count)
		check_eq(lines[2], "Side Quests", "a single header")
		for index in count:
			var quest: StoryQuestDefinition = db.story_quests[SIDE[index]]
			check(lines[3 + index].contains(quest.display_name) and not lines[3 + index].contains(quest.steps[0].description), "%s compact" % quest.id)
	var roots := StoryService.tracker_lines(character)[4]
	check(roots.contains("Find the carved marks 0/3"), "counters stay visible: %s" % roots)
	StoryService.notify(character, &"interact:roots_keep_mark")
	check(StoryService.tracker_lines(character)[4].contains("1/3"), "counter follows the progress")
	# completed side quests leave the tracker
	character.quests.entries[&"embers_of_shelter"] = {"state": "completed", "step": 3, "progress": {}}
	check_eq(StoryService.tracker_lines(character).size(), 2 + 1 + 2, "a completed side quest leaves the tracker")


func test_tracker_with_rewards_fits_at_150_percent_and_journal_keeps_details() -> void:
	var character := _character()
	for quest_id in SIDE:
		character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	session.set_character(character)
	var map := await _travel(&"whisper_forest", &"from_home")
	if map == null:
		return
	for scale: float in [1.0, 1.5]:
		check(session.settings.set_ui_scale(scale), "UI scale %d %%" % int(scale * 100))
		for i in 6:
			await get_tree().process_frame
		var panel := map.hud.objectives as Control
		var text := ""
		for label in panel.find_children("*", "Label", true, false):
			text += (label as Label).text
		check(text.contains("Return to Edrin Vale for your reward"), "%d %%: the reward hint stays" % int(scale * 100))
		check(text.contains("The Lost Hunter") and text.contains("What the Roots Keep") and text.contains("Embers of Shelter"), "all side quests listed")
		var rect := panel.get_global_rect()
		var height := map.get_viewport().get_visible_rect().size.y
		# UI Layout Lock 1.0: under the minimap, the tracker ends above the loot feed area
		var feed_top := height - map.hud.feed_bottom - map.hud.loot_feed.max_rows * GameHud.FEED_ROW
		check(rect.end.y <= feed_top + 0.5, "%d %%: tracker ends at %.0f, above the feed area at %.0f" % [int(scale * 100), rect.end.y, feed_top])
		var feed := map.hud.loot_feed as Control
		check(feed == null or not feed.is_visible_in_tree() or not feed.get_global_rect().intersects(rect), "%d %%: no overlap with the loot feed" % int(scale * 100))
	session.settings.set_ui_scale(1.0)
	map.hud.journal_panel.open(character, "Side Quests")   # side quests have their own page (UI Window Foundation 1.0)
	for i in 3:
		await get_tree().process_frame
	for quest_id in SIDE:   # Main Window Layout Lock 1.0: list | details - each quest's details one click away
		map.hud.journal_panel.select_quest(quest_id)
		for i in 2:
			await get_tree().process_frame
		var journal := ""
		for label in map.hud.journal_panel.find_children("*", "Label", true, false):
			journal += (label as Label).text + "\n"
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		check(journal.contains(quest.steps[0].description), "the Journal keeps the full step text of %s" % quest_id)


# --- What the Roots Keep hints --------------------------------------------------------------------

func test_roots_keep_points_to_its_three_areas() -> void:
	var quest: StoryQuestDefinition = db.story_quests[&"what_the_roots_keep"]
	var step_text := quest.steps[0].description
	for word: String in ["north", "hollow", "sunken grove"]:
		check(step_text.contains(word), "the step names the %s" % word)
	check(not step_text.contains("("), "no coordinates in the quest text")
	check_eq([quest.start_event_id, quest.steps[0].objectives[0].event_id, quest.steps[0].objectives[0].amount, quest.steps[1].objectives[0].event_id],
		[&"interact:roots_keep_marker", &"interact:roots_keep_mark", 3, &"interact:roots_keep_cache"], "events and amounts unchanged")
	var wood: Node = load("res://scenes/maps/tangled_wood.tscn").instantiate()
	var marker := (wood.get_node("RootsKeep/KnottedMarker") as Readable).text
	check(marker.contains("north") and marker.contains("hollow") and marker.contains("sunken grove"), "the marker hints at all three places")
	check((wood.get_node("RootsKeep/MarkNorth") as Readable).text.contains("hollow"), "the north mark leads on to the hollow")
	check((wood.get_node("RootsKeep/MarkHollow") as Readable).text.contains("grove"), "the hollow mark leads on to the grove")
	wood.free()


# --- optional finds --------------------------------------------------------------------------------

func test_three_optional_finds_once_full_bag_safe_and_saved() -> void:
	var finds := [
		[&"chapel", &"from_tangled", "Finds/AlmsBox", {&"gold_coin": 15}],
		[&"tangled_wood", &"from_forest", "Finds/CartSatchel", {&"linen_cloth": 2}],
		[&"wardens_rest", &"from_chapel", "HutFind/Footlocker", {&"oak_plank": 2, &"cured_leather": 1}]]
	var character := _character()
	character.world.set_flag(&"defeated.wardens_rest_rootbound_sentinel")
	session.set_character(character)
	var seen_rewards: Array = []
	for entry: Array in finds:
		var map := await _travel(entry[0], entry[1])
		if map == null:
			return
		var find := map.get_node(entry[2]) as Readable
		check(find.is_visible_in_tree() and find.event_id == &"", "%s: optional, no story event" % entry[2])
		var rewards := {}
		for cost in find.rewards:
			rewards[cost.item_id] = cost.quantity
		check_eq(rewards, entry[3], "%s rewards" % entry[2])
		check(not rewards in seen_rewards, "%s: not the same reward as another find" % entry[2])
		seen_rewards.append(rewards)
		var before := {}
		for item_id: StringName in rewards:
			before[item_id] = character.inventory.count(item_id)
		var needs_slot := rewards.keys().any(func(item_id: StringName) -> bool: return not db.get_item(item_id).is_currency)
		if needs_slot:
			_fill_bag(character)
			find.interact(map.hud)
			map.hud.close_windows()
			var untouched := true
			for item_id: StringName in rewards:
				untouched = untouched and character.inventory.count(item_id) == before[item_id]
			check(untouched and not find.is_read(), "%s: full bag - nothing taken, still closed" % entry[2])
			_free_slots(character, rewards.size())
		else:
			_fill_bag(character)   # coins need no bag slot: a full bag never blocks or loses them
		find.interact(map.hud)
		find.interact(map.hud)
		map.hud.close_windows()
		for item_id: StringName in rewards:
			check_eq(character.inventory.count(item_id), before[item_id] + rewards[item_id], "%s: %s paid once" % [entry[2], item_id])
		check(find.is_read(), "%s: remembered" % entry[2])
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	for i in 240:
		await get_tree().process_frame
		if not session.is_traveling() and get_tree().current_scene is GameMap:
			break
	var restored := session.character
	for flag: StringName in [&"read.chapel_alms_box", &"read.tangled_cart_satchel", &"read.wardens_rest_footlocker"]:
		check(restored.world.has_flag(flag), "%s saved" % flag)
	var gold := restored.inventory.count(&"gold_coin")
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	(chapel.get_node("Finds/AlmsBox") as Readable).interact(chapel.hud)
	chapel.hud.close_windows()
	check_eq(restored.inventory.count(&"gold_coin"), gold, "no second claim after loading")
	for quest_id in SIDE:
		check_eq(restored.quests.state(quest_id), "", "the finds start no quest (%s)" % quest_id)
	check(StoryService.is_active(restored, MAIN) and StoryService.counter(restored, &"interact:tangled_roots") == 0,
		"the main quest moved only by its own map arrivals")


func test_footlocker_waits_for_the_sentinel() -> void:
	var character := _character()
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	check(not (rest.get_node("HutFind") as StoryConditional).is_active(), "closed while the Sentinel stands")
	character.world.set_flag(&"defeated.wardens_rest_rootbound_sentinel")
	for i in 3:
		await get_tree().process_frame
	check((rest.get_node("HutFind") as StoryConditional).is_active(), "open after the defeat")
