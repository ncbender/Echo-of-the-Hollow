extends TestCase
## Chapter 1 "The Roots Remember" M2 (docs/ROOTS_REMEMBER_M2.md): the Chapel east of the Tangled
## Wood, the dormant Chapel Waystone as a one-time examination (no fast travel, no waystone state),
## the_first_signs step 2 (chapel) and step 3 (placeholder), M1 saves on steps 0/1/2, resettle,
## route topology behind the prologue gate. Real maps only through SessionState.travel().

const DIR := "user://test_saves/roots_m2"
const PROFILE := DIR + "/slot_1.save.json"
const QUEST := &"the_first_signs"
const ENTER := &"enter:tangled_wood"
const ROOTS := &"interact:tangled_roots"
const WAYSTONE := &"interact:chapel_waystone"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
## Counters and one-time flags a long-running save may carry (prologue, M1, boss, cache, trials).
const HISTORIC := {
	"count.enter:whisper_forest": 37, "count.enter:home_base": 21, "count.enter:whispering_stone": 6,
	"count.encounter:road_side_wolves": 5, "count.encounter:shrine_side_wolves": 4, "count.waystone:whispering_stone": 3,
	"count.encounter:tangled_path_husks": 8, "count.encounter:tangled_hollow_wolves": 3, "count.trial_complete": 3,
	"defeated.whisper_forest_grove_warden": true, "boss_reward.whisper_forest_grove_warden": true,
	"read.tangled_gnawed_roots": true, "hint.east_roots": true,
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


## Finished prologue (class chosen, Edrin reward pending, Mara reward claimed), the_first_signs at `step`.
func _character_at(step: int) -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for quest_step in quest.steps:
			if quest_step.completion_flag != &"":
				character.world.set_flag(quest_step.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.completed_trials = [&"trial_arcanist"] as Array[StringName]
	character.prologue.chosen_class = &"arcanist"
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	character.world.set_flag(QuestRewardService.claimed_flag(&"the_broken_cart"))
	StoryService.start(character, QUEST)
	for event: StringName in [ENTER, ROOTS, WAYSTONE].slice(0, step):
		StoryService.notify(character, event)
	if step >= 2:
		character.world.set_flag(&"read.tangled_twisted_roots")
	check(StoryService.at_step(character, QUEST, step), "set up at step %d" % step)
	return character


func _load_payload(payload: Dictionary) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.write_payload(payload, path), OK, "payload written")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded %s" % [loaded.errors])
	return loaded.character


func _reload(character: Character) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "loaded cleanly %s %s" % [loaded.errors, loaded.warnings])
	return loaded.character


func _step_text(character: Character) -> String:
	var step := StoryService.current_step(character, QUEST)
	return step.description if step != null else ""


func _untouched_state(character: Character) -> void:
	check_eq(character.prologue.chosen_class, &"arcanist", "class choice kept")
	check_eq(character.prologue.completed_trials, [&"trial_arcanist"] as Array[StringName], "trials kept")
	check_eq(QuestRewardService.state(character, &"the_first_binding"), QuestRewardService.PENDING, "Edrin reward pending")
	check_eq(QuestRewardService.state(character, &"the_broken_cart"), QuestRewardService.CLAIMED, "Mara reward claimed")
	check(not WaystoneService.is_active(character, &"chapel_waystone"), "Chapel Waystone not awake")
	check(not character.world.has_flag(&"waystone.chapel_waystone"), "no waystone flag")
	check_eq(StoryService.counter(character, &"waystone:chapel_waystone"), 0, "no waystone story event")
	check(not StoryService.is_completed(character, QUEST), "quest never completes")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no quest reward")


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

func test_quest_extends_from_index_two() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check(quest.steps.size() >= 4, "reach, roots, chapel, then later milestones (M3 extends from index 3)")
	var steps := quest.steps
	check(steps[0].objectives.size() == 1 and steps[0].objectives[0].event_id == ENTER and not steps[0].objectives[0].cumulative,
		"step 0 unchanged")
	check(steps[1].objectives.size() == 1 and steps[1].objectives[0].event_id == ROOTS and steps[1].objectives[0].cumulative,
		"step 1 unchanged")
	check_eq([steps[0].completion_flag, steps[1].completion_flag], [&"chapter1.tangled_wood_reached", &"chapter1.roots_examined"],
		"M1 step flags unchanged")
	var chapel := steps[2].objectives
	check(chapel.size() == 1 and chapel[0].event_id == WAYSTONE and chapel[0].cumulative and chapel[0].amount == 1,
		"step 2: one-time chapel examination (new id, cumulative)")
	check_eq(steps[2].completion_flag, &"chapter1.chapel_waystone_examined", "step 2 flag")
	check(steps[-1].objectives.is_empty(), "last step: placeholder without objective")
	check(steps[3].description.contains("east") and steps[-1].description.contains("future update"), "the trail leads on east")
	check(quest.open_ended and quest.next_quest_ids.is_empty(), "stays open, no successor")
	check(not QuestRewardService.has_reward(quest), "no turn-in reward")
	for other: StoryQuestDefinition in db.story_quests.values():
		if other.id == QUEST:
			continue
		for step in other.steps:
			for objective in step.objectives:
				check(objective.event_id != WAYSTONE, "%s does not use the chapel event" % other.id)


func test_map_data_waystones_and_route_topology() -> void:
	var map_def: MapDefinition = db.maps.get(&"chapel")
	if not check(map_def != null, "chapel map definition"):
		return
	check_eq([map_def.region_id, map_def.map_cell, map_def.display_name], [&"hollow_outskirts", Vector2i(3, 1), "The Chapel"], "map data")
	check(&"chapel" in (db.regions[&"hollow_outskirts"] as RegionDefinition).map_ids, "in the region")
	check(&"chapel" in (db.maps[&"tangled_wood"] as MapDefinition).neighbors, "world map: wood -> chapel")
	var chapel_stone: WaystoneDefinition = db.waystones[&"chapel_waystone"]
	check(not chapel_stone.available and chapel_stone.map_id == &"" and not chapel_stone.starts_active, "Chapel Waystone definition unchanged")
	check(not (db.waystones[&"wardens_rest"] as WaystoneDefinition).available, "Warden's Rest unchanged")
	var character := _character_at(2)
	character.world.waystones.append(&"home_base")
	check(WaystoneService.travel_error(character, &"home_base", &"chapel_waystone", false) != "", "no fast travel to the chapel")
	# every way into the Tangled Wood and the Chapel, across all maps
	var into := {&"tangled_wood": [], &"chapel": []}
	for other: MapDefinition in db.maps.values():
		var scene: GameMap = load(other.scene_path).instantiate()
		for transition: MapTransition in scene.find_children("*", "MapTransition", true, false):
			if into.has(transition.target_map_id):
				var gate := transition.get_parent() as StoryConditional
				var gated := gate != null and gate.condition != null and &"prologue.completed" in gate.condition.required_flags
				(into[transition.target_map_id] as Array).append([other.id, gated])
		for node in scene.find_children("*", "Waystone", true, false):
			check(other.id != &"chapel", "no Waystone node in the chapel")
		scene.free()
	var chapel_ways: Array = into[&"chapel"]
	check(chapel_ways.size() == 2 and [&"tangled_wood", false] in chapel_ways and [&"wardens_rest", false] in chapel_ways, "the chapel is reached only from the Tangled Wood (or from Warden's Rest beyond it)")
	var wood_ways: Array = into[&"tangled_wood"]
	wood_ways.sort()
	check_eq(wood_ways, [[&"chapel", false], [&"whisper_forest", true]], "the wood is entered only behind the prologue gate (or from the chapel)")


# --- quest flow and saves -----------------------------------------------------------------------

func test_chapel_step_advances_once() -> void:
	var character := _character_at(2)
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	check(_step_text(character).contains("east past the Tangled Wood"), "chapel task: %s" % _step_text(character))
	for event: StringName in [&"enter:chapel", ENTER, ROOTS, &"encounter:chapel_yard", &"interact:supply_crate", &"waystone:whispering_stone"]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, 2), "only the waystone examination finishes step 2")
	StoryService.notify(character, WAYSTONE)
	check(StoryService.at_step(character, QUEST, 3), "step 3")
	check(character.world.has_flag(&"chapter1.chapel_waystone_examined"), "flag")
	check(_step_text(character).contains("east"), "the trail leads on east: %s" % _step_text(character))
	for i in 3:
		StoryService.notify(character, WAYSTONE)
		check(StoryService.resettle(character).is_empty(), "resettle %d at the placeholder" % i)
	check(StoryService.at_step(character, QUEST, 3), "stays at the placeholder")
	check_eq(progressed, [[QUEST, 3, false]], "exactly one live step event, no completion")
	var lines := StoryService.tracker_lines(character)
	check(lines.size() == 2 and lines[1].contains("east"), "tracker: headline + one line, no counter/fake task %s" % [lines])
	_untouched_state(character)


func test_early_examination_catches_up_without_soft_lock() -> void:
	var character := _character_at(1)
	StoryService.notify(character, WAYSTONE)   # chapel visited before the Twisted Roots
	check(StoryService.at_step(character, QUEST, 1), "step 1 still waits for the roots")
	StoryService.notify(character, ROOTS)
	check(StoryService.at_step(character, QUEST, 3), "the earlier examination counts: straight to the placeholder")
	var behind := _character_at(2)
	var payload := behind.to_dict()
	(payload.world as Dictionary).flags["count." + String(WAYSTONE)] = 1
	var loaded := _load_payload(payload)
	check(StoryService.at_step(loaded, QUEST, 3), "resettle catches up a counted examination")


func test_m1_saves_on_steps_0_1_2() -> void:
	for step in 3:
		var payload := _character_at(step).to_dict()
		var flags: Dictionary = (payload.world as Dictionary).flags
		for flag: String in HISTORIC:
			flags[flag] = HISTORIC[flag]
		if step >= 1:
			flags["count." + String(ENTER)] = 12
		if step >= 2:
			flags["count." + String(ROOTS)] = 1
		var loaded := _load_payload(payload)
		if loaded == null:
			return
		check(StoryService.at_step(loaded, QUEST, step), "M1 save on step %d loads on step %d" % [step, step])
		for i in 3:
			check(StoryService.resettle(loaded).is_empty(), "step %d: resettle %d moves nothing" % [step, i])
		check(StoryService.at_step(loaded, QUEST, step), "historic counters skip nothing (step %d)" % step)
		check_eq(loaded.quests.active_ids().count(QUEST), 1, "one entry")
		_untouched_state(loaded)
		check(loaded.world.has_flag(&"defeated.whisper_forest_grove_warden"), "boss state kept")
		# and each continues normally
		for event: StringName in [ENTER, ROOTS, WAYSTONE].slice(step):
			StoryService.notify(loaded, event)
		check(StoryService.at_step(loaded, QUEST, 3), "step %d save reaches the placeholder" % step)


func test_save_load_after_the_chapel_step() -> void:
	var character := _character_at(2)
	var again := _reload(character)
	check(StoryService.at_step(again, QUEST, 2), "step 2 survives save/load")
	StoryService.notify(again, WAYSTONE)
	var after := _reload(again)
	check(StoryService.at_step(after, QUEST, 3), "step 3 survives save/load")
	check(after.world.has_flag(&"chapter1.chapel_waystone_examined"), "flag saved")
	_untouched_state(after)


# --- real maps ----------------------------------------------------------------------------------

func test_prologue_players_cannot_reach_the_wood() -> void:
	var character := CharacterFactory.create_new(db)
	StoryService.begin_prologue(character)
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	check(not (forest.get_node("EastPath/ToTangledWood") as MapTransition).can_process(), "forest exit closed during the prologue")
	_walk(forest, Vector2(290, -156), Vector2.RIGHT)
	for i in 60:
		await get_tree().physics_frame
	check(get_tree().current_scene == forest, "no map change")


func test_wood_and_chapel_both_ways() -> void:
	var character := _character_at(2)
	character.world.set_flag(&"defeated.whisper_forest_grove_warden")   # either Warden state: no effect on the route
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	_walk(wood, Vector2(300, 40), Vector2.RIGHT)
	var chapel := await _await_map(&"chapel")
	if chapel == null:
		return
	check(chapel.player.global_position.distance_to(chapel.find_spawn(&"from_tangled").global_position) < 1.0, "arrived at the chapel path")
	check_eq(StoryService.counter(character, &"enter:chapel"), 1, "entered")
	check(StoryService.at_step(character, QUEST, 2), "entering alone is not the task")
	_walk(chapel, Vector2(-300, 0), Vector2.LEFT)
	wood = await _await_map(&"tangled_wood")
	if wood == null:
		return
	check(wood.player.global_position.distance_to(wood.find_spawn(&"from_chapel").global_position) < 1.0, "back at the wood's east edge")
	# repeated changes, then the M1 way out still works
	await _travel(&"chapel", &"from_tangled")
	wood = await _travel(&"tangled_wood", &"from_chapel")
	_walk(wood, Vector2(-300, 0), Vector2.LEFT)
	var forest := await _await_map(&"whisper_forest")
	check(forest != null and forest.player.global_position.distance_to(forest.find_spawn(&"from_tangled").global_position) < 1.0,
		"M1 route back to the Whisper Forest unchanged")
	check(StoryService.at_step(character, QUEST, 2), "map changes changed nothing")


func test_spawns_free_and_no_false_prompts() -> void:
	session.set_character(_character_at(2))
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	for i in 4:
		await get_tree().physics_frame
	check(Interactable.find_active(get_tree()) == null, "no prompt at the chapel arrival")
	for point: SpawnPoint in chapel.find_children("*", "SpawnPoint", true, false):
		check(_blocked_at(chapel, point.global_position).is_empty(), "chapel spawn %s free" % point.spawn_id)
	var names: Array = []
	for node in get_tree().get_nodes_in_group(&"interactable"):
		names.append(String((node as Node).name))
	names.sort()
	check_eq(names, ["ChapelWaystone", "FadedNote"], "the only interactions in the chapel")
	for name: String in ["ChapelWaystone", "FadedNote"]:
		check(_blocked_at(chapel, chapel.get_node(name).global_position).is_empty(), "%s reachable" % name)
	check(chapel.find_children("*", "Checkpoint", true, false).is_empty(), "no rest point")
	check(chapel.find_children("*", "StoryPickup", true, false).is_empty(), "no pickups")
	var exits := chapel.find_children("*", "MapTransition", true, false).filter(func(exit: MapTransition) -> bool: return exit.can_process())
	check(exits.size() == 1 and (exits[0] as MapTransition).target_map_id == &"tangled_wood", "only active exit before the waystone: back west")
	var wood := await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	for i in 4:
		await get_tree().physics_frame
	check(_blocked_at(wood, wood.find_spawn(&"from_chapel").global_position).is_empty(), "wood east spawn free")
	check(Interactable.find_active(get_tree()) == null, "no prompt at the wood's east spawn (Twisted Roots out of reach)")


func test_sealed_way_east_stays_closed() -> void:
	var character := _character_at(2)   # closed until the Chapel Waystone was examined (M3 opens it afterwards)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	_walk(chapel, Vector2(280, -162), Vector2.RIGHT)
	for i in 90:
		await get_tree().physics_frame
	check(get_tree().current_scene == chapel and not session.is_traveling(), "no map change in the east")
	check(chapel.player.global_position.x < 320.0, "roots and stone block the way (x = %.1f)" % chapel.player.global_position.x)
	check(character.world.has_flag(&"hint.chapel_east_way"), "hint explains the closed way")
	check(Interactable.find_active(get_tree()) == null, "no interaction prompt at the sealed way")


func test_examining_the_waystone_in_the_scene() -> void:
	var character := _character_at(2)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var stone := chapel.get_node("ChapelWaystone") as Readable
	check_eq(stone.prompt, "Examine Chapel Waystone", "prompt")
	check_eq(stone.look, Readable.Look.WAYSTONE, "dormant waystone look")
	check(stone.rewards.is_empty(), "no reward")
	check(stone.text.contains("silent") and stone.text.contains("east"), "rooted, silent, pulling east")
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	var items := character.inventory.to_array()
	for i in 3:
		stone.interact(chapel.hud)
	check(StoryService.at_step(character, QUEST, 3), "examined: placeholder")
	check_eq(StoryService.counter(character, WAYSTONE), 1, "one event for three examinations")
	check_eq(progressed, [[QUEST, 3, false]], "one live step event")
	check_eq(character.inventory.to_array(), items, "nothing handed out")
	_untouched_state(character)
	check_eq(session.save_game(), OK, "saved in the chapel")
	await _travel(&"tangled_wood", &"from_chapel")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	chapel = await _await_map(&"chapel")
	if chapel == null:
		return
	var restored := session.character
	check(chapel.player.global_position.distance_to(chapel.find_spawn(&"from_tangled").global_position) < 1.0, "loaded at the chapel spawn")
	check(StoryService.at_step(restored, QUEST, 3), "progress restored")
	(chapel.get_node("ChapelWaystone") as Readable).interact(chapel.hud)
	check_eq(StoryService.counter(restored, WAYSTONE), 1, "no second event after loading")
	_untouched_state(restored)


func test_optional_note_is_only_flavour() -> void:
	var character := _character_at(2)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var note := chapel.get_node("FadedNote") as Readable
	check(note.event_id == &"" and note.rewards.is_empty(), "no event, no reward")
	var items := character.inventory.to_array()
	note.interact(chapel.hud)
	check(note.is_read(), "remembered as read")
	check(StoryService.at_step(character, QUEST, 2), "no quest progress from the note")
	check_eq(character.inventory.to_array(), items, "no items")
	check(not character.quests.entries.keys().any(func(id: StringName) -> bool: return not id in PROLOGUE_QUESTS and id != QUEST),
		"no new quest")
	(chapel.get_node("ChapelWaystone") as Readable).interact(chapel.hud)
	check(StoryService.at_step(character, QUEST, 3), "the main step never needs the note")


func test_chapel_encounter_reuses_existing_patterns() -> void:
	var character := _character_at(2)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var encounters := chapel.find_children("*", "Encounter", true, false)
	check_eq(encounters.size(), 1, "one small encounter")
	var yard := chapel.get_node("Encounters/ChapelYard") as Encounter
	check(not yard.persistent and yard.condition == null and yard.completion_loot == null, "per visit, unconditional, no equipment table")
	var configs: Array = yard.get_children().map(func(spawn: EncounterSpawn) -> StringName: return spawn.config.id)
	configs.sort()
	check_eq(configs, [&"hollowfang_wolf", &"rootbound_husk", &"rootbound_husk"], "existing melee enemies only")
	for enemy: Enemy in chapel.find_children("*", "Enemy", true, false):
		check(enemy.persistent_id == &"", "no one-time enemy")
	(chapel.get_node("ChapelWaystone") as Readable).interact(chapel.hud)
	check(StoryService.at_step(character, QUEST, 3), "the waystone needs no cleared encounter")
	yard.start()
	for enemy in yard.enemies.duplicate():
		var hit := HitData.new()
		hit.damage = 10000.0
		enemy.hurtbox.receive_hit(hit)
	check(yard.done and not character.world.has_flag(yard.cleared_flag()), "cleared for this visit only")
	check_eq(StoryService.counter(character, &"encounter:chapel_yard"), 1, "encounter event")
	await _travel(&"tangled_wood", &"from_chapel")
	chapel = await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	check((chapel.get_node("Encounters/ChapelYard") as Encounter).can_start(), "back on the next visit")
	check(StoryService.at_step(character, QUEST, 3), "fighting changed no story step")
