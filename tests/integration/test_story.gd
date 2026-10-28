extends TestCase
## Persistent prologue foundation: data-driven story quests (steps + event
## objectives), stable prologue flags, quest chain, mid-prologue save/load,
## milestone saves on story progress, temporary trials (never saved; death or
## loading resets, restart possible; completed trials are kept).

const DIR := "user://test_saves/story"
const PROFILE := DIR + "/slot_1.save.json"

## The whole prologue as story events, in order (quest, step after the event).
const WALKTHROUGH := [
	[&"reach:road_signpost", &"a_road_forgotten", 1],
	[&"encounter:road_ambush", &"a_road_forgotten", 2],
	[&"reach:cart_site", &"the_broken_cart", 0],
	[&"encounter:cart_attack", &"the_broken_cart", 1],
	[&"talk:mara_cart", &"the_broken_cart", 2],
	[&"interact:supply_crate", &"the_broken_cart", 2],
	[&"interact:supply_crate", &"the_broken_cart", 3],
	[&"encounter:cart_second_wave", &"the_broken_cart", 4],
	[&"talk:mara_road_end", &"shelter_among_the_trees", 0],
	[&"enter:home_base", &"shelter_among_the_trees", 1],
	[&"talk:mara_welcome", &"shelter_among_the_trees", 2],
	[&"restore:old_smithy", &"shelter_among_the_trees", 3],
	[&"talk:edrin_intro", &"the_whispering_stone", 0],
	[&"enter:whispering_stone", &"the_whispering_stone", 1],
]

var db: GameDatabase
var character: Character
var session: SessionState
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	_clean()


func after_each() -> void:
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


func _walk(until: int) -> void:
	for index in until:
		var event: Array = WALKTHROUGH[index]
		StoryService.notify(character, event[0])
		check(StoryService.at_step(character, event[1], event[2]), "after %s: %s at step %d (is %s step %d)" % [
			event[0], event[1], event[2], character.quests.state(event[1]), character.quests.step(event[1])])


func _complete_trials() -> void:
	for trial_id: StringName in [&"trial_warrior", &"trial_arcanist", &"trial_shadowrunner"]:
		PrologueService.begin_trial(character, trial_id)
		var trial: TrialDefinition = db.trials[trial_id]
		for objective in trial.objectives:
			PrologueService.record(character, objective.kind, objective.target_id, objective.amount)


func _reload() -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "loaded cleanly %s" % [loaded.warnings])
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX]:
		DirAccess.remove_absolute(path + suffix)
	return loaded.character


func test_story_data_is_valid_and_chained() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	var chain: Array[StringName] = []
	var quest_id := StoryService.FIRST_QUEST
	while quest_id != &"":
		chain.append(quest_id)
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		quest_id = quest.next_quest_ids[0] if not quest.next_quest_ids.is_empty() else &""
	check_eq(chain, [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone",
		&"the_first_binding", &"the_first_signs", &"beyond_the_roots"] as Array[StringName], "five prologue quests, then the main quests")
	var names: Array = chain.map(func(id: StringName) -> String: return (db.story_quests[id] as StoryQuestDefinition).display_name)
	check_eq(names, ["A Road Forgotten", "The Broken Cart", "Shelter Among the Trees", "The Whispering Stone",
		"The First Binding", "The First Signs", "Beyond the Roots"], "English quest names")
	check_eq((db.story_quests[&"the_first_signs"] as StoryQuestDefinition).chapter, "The Roots Remember", "main quest")


func test_new_journey_starts_the_prologue() -> void:
	check(character.world.has_flag(&"prologue.started"), "prologue.started")
	check(StoryService.at_step(character, &"a_road_forgotten", 0), "first quest active")
	check_eq(character.quests.active_ids().size(), 1, "only the first quest")
	check(StoryService.tracker_lines(character)[0].contains("A Road Forgotten"), "HUD tracker line")


func test_full_prologue_walkthrough() -> void:
	_walk(WALKTHROUGH.size())
	for flag: StringName in [&"prologue.road_cleared", &"prologue.mara_rescued", &"prologue.supplies_recovered",
			&"prologue.cart_defended", &"prologue.haven_discovered", &"prologue.smithy_restored", &"prologue.shrine_reached"]:
		check(character.world.has_flag(flag), "flag %s" % flag)
	check(not character.world.has_flag(&"prologue.first_class_selected"), "no class chosen yet")
	_complete_trials()
	check(StoryService.at_step(character, &"the_whispering_stone", 2), "three echoes walked")
	check_eq(PrologueService.choose_starting_class(character, &"arcanist"), "", "class chosen")
	check(StoryService.at_step(character, &"the_whispering_stone", 3), "now the waystone")
	StoryService.notify(character, &"waystone:whispering_stone")
	check(StoryService.at_step(character, &"the_first_binding", 0), "return to Haven")
	for event: StringName in [&"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]:
		StoryService.notify(character, event)
	check(character.world.has_flag(&"prologue.completed"), "prologue.completed")
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		check(StoryService.is_completed(character, quest_id), "%s completed" % quest_id)
	check(StoryService.at_step(character, &"the_first_signs", 0), "main quest stub active")
	StoryService.notify(character, &"enter:home_base")
	check(StoryService.is_active(character, &"the_first_signs"), "the stub never completes")


func test_events_only_count_for_the_current_step() -> void:
	StoryService.notify(character, &"talk:mara_cart")
	StoryService.notify(character, &"encounter:cart_attack")
	check(StoryService.at_step(character, &"a_road_forgotten", 0), "future events do not skip steps")
	_walk(4)
	check(StoryService.at_step(character, &"the_broken_cart", 1), "the early talk did not count")
	# cumulative: a crate picked up before its step still counts
	StoryService.notify(character, &"interact:supply_crate")
	StoryService.notify(character, &"talk:mara_cart")
	check(StoryService.at_step(character, &"the_broken_cart", 2), "at the crate step")
	check_eq(StoryService.objective_value(character, &"the_broken_cart", 0), 1, "earlier crate counted")
	StoryService.notify(character, &"talk:mara_cart")
	check_eq(StoryService.counter(character, &"talk:mara_cart"), 3, "events are counted in the world state")


func test_save_and_load_at_every_prologue_step() -> void:
	for index in WALKTHROUGH.size():
		var event: Array = WALKTHROUGH[index]
		StoryService.notify(character, event[0])
		var expected := character.quests.to_dict()
		var flags := character.world.flags.duplicate()
		character = _reload()
		check_eq(character.quests.to_dict(), expected, "quest state after %s" % event[0])
		check_eq(character.world.flags, flags, "flags after %s" % event[0])
	check(StoryService.at_step(character, &"the_whispering_stone", 1), "loaded at the echoes")


func test_trials_are_temporary_completed_ones_are_kept() -> void:
	_walk(WALKTHROUGH.size())
	PrologueService.begin_trial(character, &"trial_warrior")
	var trial: TrialDefinition = db.trials[&"trial_warrior"]
	for objective in trial.objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	PrologueService.begin_trial(character, &"trial_arcanist")
	check(character.classes.in_trial(), "inside the arcanist trial")
	var loaded := _reload()
	check(not loaded.classes.in_trial(), "loading never restores a running trial")
	check_eq(loaded.classes.active_class_id, &"basic_adventurer", "back to Basic Adventurer")
	check(loaded.prologue.has_completed_trial(&"trial_warrior"), "completed trial kept")
	check(not loaded.prologue.has_completed_trial(&"trial_arcanist"), "running trial not counted")
	check_eq(StoryService.counter(loaded, &"trial_complete"), 1, "one echo walked")
	check(StoryService.at_step(loaded, &"the_whispering_stone", 2), "one echo is enough: on to the choice")
	check_eq(PrologueService.begin_trial(loaded, &"trial_arcanist"), "", "the trial can be restarted")
	PrologueService.begin_trial(character, &"trial_warrior")
	PrologueService.end_trial(character, false)
	PrologueService.begin_trial(character, &"trial_warrior")
	for objective in trial.objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(StoryService.counter(character, &"trial_complete"), 1, "repeating a trial counts once")


func test_dying_in_a_trial_ends_it() -> void:
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/prologue.tscn")
	var map: GameMap
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	if not check(map != null and map.bridge != null, "prologue map loaded"):
		return
	check_eq(PrologueService.begin_trial(character, &"trial_shadowrunner"), "", "trial started")
	map.player.health.died.emit()
	check(not character.classes.in_trial(), "death ends the trial")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "Basic Adventurer again")
	check_eq(PrologueService.begin_trial(character, &"trial_shadowrunner"), "", "restart possible")
	PrologueService.end_trial(character, false)


func test_story_progress_triggers_a_milestone_save() -> void:
	session.set_character(character)
	session.saves.periodic_enabled = false
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame
	check(SaveSlots.latest(PROFILE).is_empty(), "nothing saved yet")
	StoryService.notify(character, &"reach:road_signpost")
	await get_tree().process_frame
	await get_tree().process_frame
	var latest := SaveSlots.latest(PROFILE)
	check(not latest.is_empty() and latest.meta.get("kind") == "milestone", "milestone save written: %s" % [latest])
	var loaded := SaveSystem.load_from(latest.path, db)
	check(StoryService.at_step(loaded.character, &"a_road_forgotten", 1), "the save holds the new step")
	session.saves.periodic_enabled = true


func test_migrated_v4_character_continues_at_the_echoes() -> void:
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate({"world": {}, "prologue": {"stage": "in_progress",
		"completed_trials": ["trial_warrior", "trial_arcanist"]}}, 4, errors)
	var warnings: PackedStringArray = []
	var migrated := Character.from_dict(data, db, warnings)
	check(StoryService.at_step(migrated, &"the_whispering_stone", 0), "continues at the shrine")
	StoryService.notify(migrated, &"enter:whispering_stone")
	check_eq(StoryService.counter(migrated, &"trial_complete"), 2, "earlier trials count as walked echoes")
	check(StoryService.at_step(migrated, &"the_whispering_stone", 2), "one walked echo is enough: on to the choice")
