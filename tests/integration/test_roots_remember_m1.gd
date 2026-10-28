extends TestCase
## Chapter 1 "The Roots Remember" M1 (docs/ROOTS_REMEMBER_M1.md): the_first_signs continues
## from its old step 0, the Whisper Forest east exit opens only after prologue.completed, the
## Tangled Wood (transitions both ways, examination, per-visit encounters), save/load, legacy
## step-0 saves and StoryService.resettle. Real maps only through SessionState.travel().

const DIR := "user://test_saves/roots_m1"
const PROFILE := DIR + "/slot_1.save.json"
const QUEST := &"the_first_signs"
const ENTER := &"enter:tangled_wood"
const EXAMINE := &"interact:tangled_roots"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
## Counters and one-time flags a long-running pre-M1 save may carry.
const HISTORIC := {
	"count.enter:whisper_forest": 37, "count.enter:home_base": 21, "count.enter:whispering_stone": 6,
	"count.encounter:road_side_wolves": 5, "count.encounter:shrine_side_wolves": 4, "count.interact:supply_crate": 2,
	"count.waystone:whispering_stone": 3, "count.talk:edrin_threat": 1, "count.trial_complete": 3, "count.class_chosen": 1,
	"defeated.whisper_forest_grove_warden": true, "boss_reward.whisper_forest_grove_warden": true,
	"encounter.cart_attack": true, "read.memory_three_stood": true,
}

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
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	var paths := SaveSlots.all_paths(PROFILE)
	paths.append(DIR + "/roundtrip.save.json")
	for path in paths:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## A character whose prologue is finished: every prologue quest completed, the class chosen, the
## Edrin reward still pending, the_first_signs active at step 0 (as StoryService leaves it).
func _finished_prologue() -> Character:
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
	character.prologue.completed_trials = [&"trial_arcanist"] as Array[StringName]
	character.prologue.chosen_class = &"arcanist"
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	character.world.set_flag(QuestRewardService.claimed_flag(&"the_broken_cart"))
	StoryService.start(character, QUEST)
	return character


func _reload(character: Character) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "loaded cleanly %s %s" % [loaded.errors, loaded.warnings])
	return loaded.character


## Writes `payload` as a real v15 save file and loads it (the load runs StoryService.resettle).
func _load_payload(payload: Dictionary) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.write_payload(payload, path), OK, "payload written")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded %s" % [loaded.errors])
	return loaded.character


func _step_text(character: Character) -> String:
	var step := StoryService.current_step(character, QUEST)
	return step.description if step != null else ""


func _travel(map_id: StringName, spawn_id: StringName) -> GameMap:
	check(session.travel(map_id, spawn_id, false), "travel to %s accepted" % map_id)
	return await _await_map(map_id)


func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _walk(map: GameMap, from: Vector2, direction: Vector2) -> void:
	map.player.global_position = from
	map.player.reset_physics_interpolation()
	var input := InputFrame.new()
	input.move = direction
	map.player.feed_input(input)


## Static bodies (walls, roots, resource nodes) overlapping a player-sized circle at `at`.
func _blocked_at(map: GameMap, at: Vector2) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits := map.get_world_2d().direct_space_state.intersect_shape(query)
	return hits.filter(func(hit: Dictionary) -> bool: return hit.collider is StaticBody2D)


# --- data ---------------------------------------------------------------------------------------

func test_quest_data_extends_the_existing_stub() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check_eq([quest.display_name, quest.chapter], ["The First Signs", "The Roots Remember"], "same quest, same chapter")
	check_eq(quest.steps.size(), 3, "reach, examine, M2 placeholder")
	check(quest.open_ended, "still open-ended: M1 never completes the quest")
	check(quest.next_quest_ids.is_empty(), "no successor quest")
	check(not QuestRewardService.has_reward(quest), "no turn-in reward")
	var first := quest.steps[0].objectives
	check(first.size() == 1 and first[0].event_id == ENTER and not first[0].cumulative and first[0].amount == 1,
		"step 0: enter the new map, counted live only")
	var second := quest.steps[1].objectives
	check(second.size() == 1 and second[0].event_id == EXAMINE and second[0].cumulative and second[0].amount == 1,
		"step 1: the one-time examination (new id, cumulative)")
	check(quest.steps[2].objectives.is_empty(), "step 2: placeholder without objective")
	check_eq([quest.steps[0].completion_flag, quest.steps[1].completion_flag],
		[&"chapter1.tangled_wood_reached", &"chapter1.roots_examined"], "step flags")
	# the new ids belong to M1 alone: no other quest waits for them
	for other: StoryQuestDefinition in db.story_quests.values():
		if other.id == QUEST:
			continue
		for step in other.steps:
			for objective in step.objectives:
				check(not objective.event_id in [ENTER, EXAMINE], "%s does not use the M1 events" % other.id)
	var binding: StoryQuestDefinition = db.story_quests[&"the_first_binding"]
	check_eq(binding.next_quest_ids, [QUEST] as Array[StringName], "prologue chain unchanged")
	check_eq(binding.completion_flag, &"prologue.completed", "prologue completion flag unchanged")


func test_map_data_and_region() -> void:
	var map_def: MapDefinition = db.maps.get(&"tangled_wood")
	if not check(map_def != null, "map definition"):
		return
	check_eq(map_def.region_id, &"hollow_outskirts", "region")
	check(&"tangled_wood" in (db.regions[&"hollow_outskirts"] as RegionDefinition).map_ids, "listed in the region")
	check(&"tangled_wood" in (db.maps[&"whisper_forest"] as MapDefinition).neighbors, "world map: forest -> wood")
	check_eq(map_def.map_cell, Vector2i(2, 1), "east of the Whisper Forest")
	for waystone in WaystoneService.all(db):
		check(waystone.map_id != &"tangled_wood", "no waystone in M1 (%s)" % waystone.id)
	check(not (db.waystones[&"chapel_waystone"] as WaystoneDefinition).available, "Chapel Waystone still unavailable")
	check(not (db.waystones[&"wardens_rest"] as WaystoneDefinition).available, "Warden's Rest still unavailable")


# --- quest flow ---------------------------------------------------------------------------------

func test_prologue_completion_hands_out_the_first_task() -> void:
	var character := _finished_prologue()
	character.quests.entries.erase(QUEST)
	character.world.flags.erase(&"prologue.completed")
	character.world.flags.erase(QuestRewardService.entitled_flag(&"the_first_binding"))
	character.quests.entries[&"the_first_binding"] = {"state": "active", "step": 2, "progress": {}}
	StoryService.notify(character, &"talk:edrin_threat")
	check(character.world.has_flag(&"prologue.completed"), "prologue completed live")
	check(StoryService.at_step(character, QUEST, 0), "the_first_signs starts at step 0")
	check(_step_text(character).contains("Follow the Whisper Forest east"), "the first playable task: %s" % _step_text(character))
	check_eq(QuestRewardService.state(character, &"the_first_binding"), QuestRewardService.PENDING, "Edrin's reward untouched")
	var lines := StoryService.tracker_lines(character)
	check(lines.size() >= 2 and lines[0] == "The Roots Remember: The First Signs", "tracker headline %s" % [lines])


func test_steps_advance_once_on_their_own_events() -> void:
	var character := _finished_prologue()
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	for event: StringName in [&"enter:whisper_forest", &"enter:home_base", &"encounter:road_side_wolves", &"talk:edrin_threat",
			&"interact:supply_crate", &"encounter:tangled_path_husks", EXAMINE]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, 0), "only entering the Tangled Wood finishes step 0")
	StoryService.notify(character, ENTER)
	check(StoryService.at_step(character, QUEST, 2), "examined before arriving: the cumulative goal is already met")
	check_eq(progressed, [[QUEST, 1, false], [QUEST, 2, false]], "two live step events, no completion")

	character = _finished_prologue()
	progressed.clear()
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	StoryService.notify(character, ENTER)
	check(StoryService.at_step(character, QUEST, 1), "arrived")
	check(character.world.has_flag(&"chapter1.tangled_wood_reached"), "arrival flag")
	check(_step_text(character).contains("Search it"), "examine task: %s" % _step_text(character))
	StoryService.notify(character, ENTER)
	check(StoryService.at_step(character, QUEST, 1), "entering again changes nothing")
	StoryService.notify(character, EXAMINE)
	check(StoryService.at_step(character, QUEST, 2), "examined")
	check(character.world.has_flag(&"chapter1.roots_examined"), "examination flag")
	check(_step_text(character).contains("future update"), "M2 placeholder visible: %s" % _step_text(character))
	for event: StringName in [ENTER, EXAMINE, &"enter:home_base", &"talk:edrin_threat"]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, 2) and not StoryService.is_completed(character, QUEST), "never completes in M1")
	check_eq(progressed, [[QUEST, 1, false], [QUEST, 2, false]], "each step reported exactly once")


func test_resettle_never_skips_or_completes() -> void:
	var character := _finished_prologue()
	for flag: String in HISTORIC:
		character.world.set_flag(StringName(flag), HISTORIC[flag])
	for i in 3:
		check(StoryService.resettle(character).is_empty(), "resettle %d: nothing moves at step 0" % i)
	check(StoryService.at_step(character, QUEST, 0), "historic counters skip nothing")
	StoryService.notify(character, ENTER)
	StoryService.notify(character, EXAMINE)
	character.world.set_flag(StringName(StoryService.COUNTER_PREFIX + String(ENTER)), 99)
	character.world.set_flag(StringName(StoryService.COUNTER_PREFIX + String(EXAMINE)), 99)
	for i in 3:
		check(StoryService.resettle(character).is_empty(), "resettle %d at the placeholder: nothing" % i)
	check(StoryService.at_step(character, QUEST, 2) and StoryService.is_active(character, QUEST), "placeholder stays active")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no reward state")


# --- saves --------------------------------------------------------------------------------------

func test_legacy_step_zero_save_gets_the_same_first_task() -> void:
	var reference := _finished_prologue()
	var payload := reference.to_dict()
	(payload.quests as Dictionary)[String(QUEST)] = {"state": "active", "step": 0, "progress": {}}   # the old stub entry
	var flags: Dictionary = (payload.world as Dictionary).flags
	for flag: String in HISTORIC:
		flags[flag] = HISTORIC[flag]
	var loaded := _load_payload(payload)
	if loaded == null:
		return
	check(StoryService.at_step(loaded, QUEST, 0), "still step 0 after loading (resettle ran)")
	check(_step_text(loaded).contains("Follow the Whisper Forest east"), "same first task as a new player")
	check_eq(loaded.quests.active_ids().count(QUEST), 1, "no duplicate activation")
	check(not StoryService.start(loaded, QUEST) or StoryService.at_step(loaded, QUEST, 0), "start() does not re-initialise")
	check_eq(loaded.prologue.chosen_class, &"arcanist", "class choice kept")
	check_eq(loaded.prologue.completed_trials, [&"trial_arcanist"] as Array[StringName], "trials kept")
	check_eq(QuestRewardService.state(loaded, &"the_first_binding"), QuestRewardService.PENDING, "Edrin reward still pending")
	check_eq(QuestRewardService.state(loaded, &"the_broken_cart"), QuestRewardService.CLAIMED, "Mara reward still claimed")
	check(loaded.world.has_flag(&"defeated.whisper_forest_grove_warden"), "historic boss flag kept")
	StoryService.notify(loaded, ENTER)
	check(StoryService.at_step(loaded, QUEST, 1), "the legacy save continues normally")


func test_save_load_after_each_step() -> void:
	var character := _finished_prologue()
	StoryService.notify(character, ENTER)
	var loaded := _reload(character)
	check(StoryService.at_step(loaded, QUEST, 1), "arrival survives save/load")
	check_eq(StoryService.counter(loaded, ENTER), 1, "counter saved")
	StoryService.notify(loaded, EXAMINE)
	var again := _reload(loaded)
	check(StoryService.at_step(again, QUEST, 2), "examination survives save/load")
	check(again.world.has_flag(&"chapter1.roots_examined"), "flag saved")
	check_eq(again.prologue.chosen_class, &"arcanist", "class choice kept")
	check_eq(QuestRewardService.state(again, &"the_first_binding"), QuestRewardService.PENDING, "reward flags kept")
	# a save made while the examination counter ran ahead of the step settles silently on load
	var behind := _finished_prologue()
	StoryService.notify(behind, ENTER)
	var payload := behind.to_dict()
	(payload.world as Dictionary).flags["count." + String(EXAMINE)] = 1
	var settled := _load_payload(payload)
	check(StoryService.at_step(settled, QUEST, 2), "resettle catches up the cumulative examination")
	check(StoryService.is_active(settled, QUEST), "and stops at the placeholder")


# --- real maps ----------------------------------------------------------------------------------

func test_east_exit_is_closed_during_the_prologue() -> void:
	var character := CharacterFactory.create_new(db)
	StoryService.begin_prologue(character)
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var roots := forest.get_node("EastRoots") as StoryConditional
	var path := forest.get_node("EastPath") as StoryConditional
	var exit := forest.get_node("EastPath/ToTangledWood") as MapTransition
	check(roots.is_visible_in_tree() and roots.can_process(), "root barrier present")
	check(not path.visible and not exit.can_process(), "transition disabled")
	_walk(forest, Vector2(290, -156), Vector2.RIGHT)
	for i in 90:
		await get_tree().physics_frame
	check(get_tree().current_scene == forest and not session.is_traveling(), "no map change")
	check(forest.player.global_position.x < 320.0, "the roots block the way (x = %.1f)" % forest.player.global_position.x)
	check(character.world.has_flag(&"hint.east_roots"), "the existing hint explains the barrier")
	check_eq(StoryService.counter(character, ENTER), 0, "the Tangled Wood was never entered")


func test_transitions_both_ways_after_the_prologue() -> void:
	var character := _finished_prologue()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	check(not forest.get_node("EastRoots").visible, "barrier gone")
	check((forest.get_node("EastPath/ToTangledWood") as MapTransition).can_process(), "transition active")
	_walk(forest, Vector2(290, -156), Vector2.RIGHT)
	var wood := await _await_map(&"tangled_wood")
	if wood == null:
		return
	check(wood.player.global_position.distance_to(wood.find_spawn(&"from_forest").global_position) < 1.0, "arrived at the west entrance")
	check(StoryService.at_step(character, QUEST, 1), "arrival advanced the quest")
	_walk(wood, Vector2(-300, 0), Vector2.LEFT)
	forest = await _await_map(&"whisper_forest")
	if forest == null:
		return
	var back := forest.find_spawn(&"from_tangled").global_position
	check(forest.player.global_position.distance_to(back) < 1.0, "returned next to the east exit")
	check_eq(character.world.spawn_id, &"from_tangled", "location saved as the east spawn")
	# repeated map changes: no further story progress, visits counted
	wood = await _travel(&"tangled_wood", &"from_forest")
	forest = await _travel(&"whisper_forest", &"from_tangled")
	wood = await _travel(&"tangled_wood", &"from_forest")
	check(StoryService.at_step(character, QUEST, 1), "still waiting for the examination")
	check_eq(StoryService.counter(character, ENTER), 3, "three arrivals counted")
	check_eq(int(character.world.get_map_value(&"tangled_wood", "visits", 0)), 3, "visits")
	await _travel(&"home_base", &"from_forest")
	check(StoryService.at_step(character, QUEST, 1), "back in Haven: unchanged")


func test_spawns_are_free_and_away_from_the_warden() -> void:
	session.set_character(_finished_prologue())
	var forest := await _travel(&"whisper_forest", &"from_tangled")
	if forest == null:
		return
	var spawn := forest.find_spawn(&"from_tangled").global_position
	check(_blocked_at(forest, spawn).is_empty(), "forest east spawn is free of walls and nodes")
	for node in forest.find_children("*", "ResourceNode", true, false):
		check(spawn.distance_to((node as Node2D).global_position) > 22.0 + 7.0, "no gather prompt on arrival (%s)" % node.name)
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	check(spawn.distance_to(warden.global_position) > warden.config.aggro_range,
		"returning never wakes the Grove Warden (%.0f px)" % spawn.distance_to(warden.global_position))
	check(spawn.distance_to(Vector2(290, -156)) > 0.0 and Vector2(290, -156).distance_to(warden.global_position) > warden.config.aggro_range,
		"the approach to the exit stays out of the Warden's reach")
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	for point: SpawnPoint in wood.find_children("*", "SpawnPoint", true, false):
		check(_blocked_at(wood, point.global_position).is_empty(), "wood spawn %s is free" % point.spawn_id)
	for name: String in ["TwistedRoots", "GnawedRoots"]:
		check(_blocked_at(wood, wood.get_node(name).global_position).is_empty(), "%s reachable (not inside a wall)" % name)


func test_examining_the_roots_in_the_scene() -> void:
	var character := _finished_prologue()
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	check(StoryService.at_step(character, QUEST, 1), "arrived")
	var roots := wood.get_node("TwistedRoots") as Readable
	check_eq(roots.prompt, "Examine Twisted Roots", "clear interaction prompt")
	check_eq(roots.event_id, EXAMINE, "reports the new event")
	check(not roots.is_read(), "not examined yet")
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	roots.interact(wood.hud)
	roots.interact(wood.hud)
	roots.interact(wood.hud)
	check(StoryService.at_step(character, QUEST, 2), "examined: placeholder step")
	check_eq(StoryService.counter(character, EXAMINE), 1, "one story event despite repeated examination")
	check_eq(progressed, [[QUEST, 2, false]], "one live step event")
	check(roots.is_read(), "remembered")
	var side := wood.get_node("GnawedRoots") as Readable
	check(side.event_id == &"" and side.rewards.is_empty(), "the optional find has no story event and no reward")
	check_eq(session.save_game(), OK, "saved in the Tangled Wood")
	await _travel(&"home_base", &"from_forest")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	wood = await _await_map(&"tangled_wood")
	if wood == null:
		return
	var restored := session.character
	check(StoryService.at_step(restored, QUEST, 2), "progress restored")
	(wood.get_node("TwistedRoots") as Readable).interact(wood.hud)
	check_eq(StoryService.counter(restored, EXAMINE), 1, "no second event after loading")
	check(StoryService.is_active(restored, QUEST), "quest not completed")


func test_encounters_reuse_existing_patterns() -> void:
	var character := _finished_prologue()
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	var husks := wood.get_node("Encounters/PathHusks") as Encounter
	var wolves := wood.get_node("Encounters/HollowWolves") as Encounter
	check(not husks.persistent and not wolves.persistent, "per-visit encounters, never one-time")
	check(husks.condition == null and wolves.condition == null, "no story condition")
	check(husks.completion_loot == null, "husks: no equipment table (like the story husks)")
	check(wolves.completion_loot == load("res://data/loot/hollowwood_wolves_equipment.tres"), "wolves: the existing wolf table")
	for spawn: EncounterSpawn in husks.get_children():
		check_eq(spawn.config.id, &"rootbound_husk", "husk encounter uses Rootbound Husks")
	for spawn: EncounterSpawn in wolves.get_children():
		check_eq(spawn.config.id, &"hollowfang_wolf", "wolf encounter uses Hollowfang Wolves")
	for enemy: Enemy in wood.find_children("*", "Enemy", true, false):
		check(enemy.persistent_id == &"", "no one-time enemy in the Tangled Wood")
	husks.start()
	check_eq(husks.enemies.size(), 2, "two husks")
	for enemy in husks.enemies.duplicate():
		var hit := HitData.new()
		hit.damage = 10000.0
		enemy.hurtbox.receive_hit(hit)
	check(husks.done, "cleared")
	check_eq(StoryService.counter(character, &"encounter:tangled_path_husks"), 1, "encounter event")
	check(StoryService.at_step(character, QUEST, 1), "fighting does not advance the story")
	check(not character.world.has_flag(husks.cleared_flag()), "no persistent clear flag")
	wood = await _travel(&"whisper_forest", &"from_tangled")
	wood = await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	check((wood.get_node("Encounters/PathHusks") as Encounter).can_start(), "husks return on the next visit")
	(wood.get_node("TwistedRoots") as Readable).interact(wood.hud)
	check(StoryService.at_step(character, QUEST, 2), "examination works without clearing any encounter")
