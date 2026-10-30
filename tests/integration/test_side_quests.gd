extends TestCase
## Region 1 Side Quests 1.0 (docs/SIDE_QUESTS_1_0.md): The Lost Hunter, What the Roots Keep and
## Embers of Shelter - started by a story event (StoryQuestDefinition.start_event_id, never a quest
## chain, never step 0), crafting reported as craft:<recipe> only after a finished craft, every find
## and reward claimed once (full bag: nothing lost, nothing early), save/load and old saves, and the
## main quest untouched. Real scenes through SessionState.travel(); only user://test_saves/.

const DIR := "user://test_saves/side_quests"
const PROFILE := DIR + "/slot_1.save.json"
const MAIN := &"the_first_signs"
const HUNTER := &"the_lost_hunter"
const ROOTS := &"what_the_roots_keep"
const EMBERS := &"embers_of_shelter"
const SIDE_QUESTS: Array[StringName] = [HUNTER, ROOTS, EMBERS]
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
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE) + [DIR + "/roundtrip.save.json"]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## Finished prologue (Mara's return heard), the_first_signs at step 0, the main-way fights cleared.
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
	for dialogue_id: StringName in [&"mara_welcome", &"mara_return", &"edrin_intro", &"edrin_threat"]:
		character.world.set_flag(StringName("dialogue.%s" % dialogue_id))
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"arcanist"
	StoryService.start(character, MAIN)
	for encounter_id: StringName in [&"wf_road_husks", &"tw_bend_wolves", &"tw_heart_watch", &"chapel_yard"]:
		character.world.set_flag(StringName("encounter.%s" % encounter_id))
	return character


func _reload(character: Character) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok() and loaded.warnings.is_empty(), "loaded cleanly %s %s" % [loaded.errors, loaded.warnings])
	return loaded.character


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


func _settle() -> void:   # StoryConditional refreshes deferred after a flag change
	for i in 3:
		await get_tree().process_frame


func _mara() -> NpcDefinition:
	return db.npcs[&"mara"]


## Reads a dialogue to its end (the HUD path calls the same DialogueService.finish).
func _finish(character: Character, dialogue_id: StringName) -> bool:
	var dialogue := DialogueService.pick(character, _mara())
	if not check(dialogue != null and dialogue.id == dialogue_id, "Mara offers %s (got %s)" % [dialogue_id, dialogue.id if dialogue else &"none"]):
		return false
	DialogueService.finish(character, dialogue)
	return true


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


func _kill_encounter(encounter: Encounter) -> void:
	encounter.start()
	for enemy in encounter.enemies.duplicate():
		var hit := HitData.new()
		hit.damage = 100000.0
		enemy.hurtbox.receive_hit(hit)


func _gold(character: Character) -> int:
	return character.inventory.count(&"gold_coin")


# --- data -----------------------------------------------------------------------------------------

func test_quest_data_and_start_events_are_valid() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	check(DialogueService.validate_data(db).is_empty(), "dialogue data valid")
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var starts := {HUNTER: &"talk:mara_lost_hunter", ROOTS: &"interact:roots_keep_marker", EMBERS: &"interact:shelter_ledger"}
	for quest_id in SIDE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests.get(quest_id)
		if not check(quest != null, "%s loaded" % quest_id):
			continue
		check_eq(quest.start_event_id, starts[quest_id], "%s start event" % quest_id)
		check_eq(quest.chapter, "Side Quest", "%s is a side quest" % quest_id)
		for other: StoryQuestDefinition in db.story_quests.values():
			check(not quest_id in other.next_quest_ids, "%s is in no quest chain (%s)" % [quest_id, other.id])
	check_eq([db.story_quests[HUNTER].turn_in_gold, QuestRewardService.reward_items(db.story_quests[HUNTER])], [40, {&"cured_leather": 2}], "Lost Hunter reward")
	check_eq([db.story_quests[EMBERS].turn_in_gold, QuestRewardService.reward_items(db.story_quests[EMBERS])], [30, {&"duskleaf": 4}], "Embers reward")
	check(not QuestRewardService.has_reward(db.story_quests[ROOTS]), "What the Roots Keep pays only through its cache")
	# a quest whose start event also finishes step 0 is rejected
	var quest: StoryQuestDefinition = db.story_quests[ROOTS]
	var start := quest.start_event_id
	quest.start_event_id = quest.steps[0].objectives[0].event_id
	check(StoryService.validate_data(db).size() > 0, "start event = step 0 event is reported")
	quest.start_event_id = start
	# main quest data unchanged
	var main: StoryQuestDefinition = db.story_quests[MAIN]
	check(main.start_event_id == &"" and main.steps.size() == 6 and main.next_quest_ids.size() == 1 and main.next_quest_ids.has(&"beyond_the_roots"), "The First Signs unchanged")


# --- The Lost Hunter -------------------------------------------------------------------------------

func test_lost_hunter_starts_only_at_mara_after_the_prologue() -> void:
	var early := CharacterFactory.create_new(db)
	StoryService.begin_prologue(early)
	var picked := DialogueService.pick(early, _mara())
	check(picked == null or picked.id != &"mara_lost_hunter", "no offer during the prologue")
	var character := _character()
	check_eq(character.quests.state(HUNTER), "", "not started")
	check(DialogueService.has_story_dialogue(character, _mara()), "Mara shows '!' for the offer")
	if not _finish(character, &"mara_lost_hunter"):
		return
	check(StoryService.at_step(character, HUNTER, 0), "started at step 0 (the start never counts as a step)")
	check(StoryService.at_step(character, MAIN, 0), "the main quest did not move")
	check_eq(DialogueService.pick(character, _mara()).id, &"mara_lost_hunter_hint", "afterwards Mara only gives the way")
	StoryService.notify(character, &"talk:mara_lost_hunter")
	check(StoryService.at_step(character, HUNTER, 0), "a second start event changes nothing")
	var loaded := _reload(character)
	check(StoryService.at_step(loaded, HUNTER, 0), "the started quest survives save/load")
	# the prologue return dialogue keeps its priority over the offer
	var returning := _character()
	returning.quests.entries[&"the_first_binding"] = {"state": "active", "step": 1, "progress": {}}
	returning.world.flags.erase(&"dialogue.mara_return")
	check_eq(DialogueService.pick(returning, _mara()).id, &"mara_return", "story dialogues of the prologue come first")


func test_lost_hunter_trail_den_and_horn_in_the_forest() -> void:
	var character := _character()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var clues := forest.get_node("LostHunter/Clues") as StoryConditional
	var horn := forest.get_node("LostHunter/Horn") as StoryPickup
	var den := forest.get_node("Encounters/LostHunterDen") as Encounter
	check(not clues.is_active() and not horn.visible and not den.can_start(), "nothing of the quest before Mara asks")
	_finish(character, &"mara_lost_hunter")
	await _settle()
	check(clues.is_active() and clues.visible, "camp and tracks appear once the quest is known")
	(forest.get_node("LostHunter/Clues/Camp") as Readable).interact(forest.hud)
	check(StoryService.at_step(character, HUNTER, 1), "camp found")
	check(not den.can_start(), "the den waits for the tracks")
	for name: String in ["TrackA", "TrackB", "TrackB", "TrackC"]:   # one track read twice
		(forest.get_node("LostHunter/Clues/" + name) as Readable).interact(forest.hud)
	forest.hud.close_windows()
	check(StoryService.at_step(character, HUNTER, 2), "three tracks: the den")
	check_eq(StoryService.counter(character, &"interact:lost_hunter_track"), 3, "each track counted once")
	check(den.can_start() and den.persistent, "the den fight is one-time and open now")
	var configs: Array = den.get_children().map(func(spawn: EncounterSpawn) -> StringName: return spawn.config.id)
	configs.sort()
	check_eq(configs, [&"hardened_husk", &"hollowfang_wolf"], "existing enemies only")
	_kill_encounter(den)
	await _settle()
	check(StoryService.at_step(character, HUNTER, 3), "den cleared")
	check(horn.visible, "the horn lies in the den")
	var bag := character.inventory.to_array()
	check_eq(horn.take(), "", "horn recovered")
	check_eq(character.inventory.to_array(), bag, "the horn takes no bag slot")
	check(StoryService.at_step(character, HUNTER, 4), "back to Mara")
	check(horn.take() != "", "no second horn")
	check_eq(session.save_game(), OK, "saved in the forest")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	forest = await _await_map(&"whisper_forest")
	if forest == null:
		return
	await _settle()
	check(StoryService.at_step(session.character, HUNTER, 4), "progress restored")
	check(not (forest.get_node("Encounters/LostHunterDen") as Encounter).can_start(), "the den stays clear")
	check(not (forest.get_node("LostHunter/Horn") as StoryPickup).visible, "the horn stays taken")


func test_lost_hunter_return_reward_once_and_full_bag() -> void:
	var character := _character()
	_finish(character, &"mara_lost_hunter")
	for event: StringName in [&"interact:lost_hunter_camp", &"interact:lost_hunter_track", &"interact:lost_hunter_track", &"interact:lost_hunter_track",
			&"encounter:lost_hunter_den"]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, HUNTER, 3), "at the horn")
	check_eq(QuestRewardService.state(character, HUNTER), QuestRewardService.NONE, "no reward before the quest is done")
	check(QuestRewardService.claim(character, HUNTER) != "", "nothing to claim yet")
	StoryService.notify(character, &"interact:lost_hunter_horn")
	if not _finish(character, &"mara_lost_hunter_return"):
		return
	check(StoryService.is_completed(character, HUNTER), "completed at Mara")
	check(character.world.has_flag(&"lost_hunter.completed"), "completion flag")
	check_eq(QuestRewardService.state(character, HUNTER), QuestRewardService.PENDING, "reward waiting at Mara")
	var gold := _gold(character)
	_fill_bag(character)
	check_eq(QuestRewardService.claim(character, HUNTER), QuestRewardService.BAG_FULL, "full bag: refused")
	check(_gold(character) == gold and character.inventory.count(&"cured_leather") == 0, "nothing paid on a full bag")
	check_eq(QuestRewardService.state(character, HUNTER), QuestRewardService.PENDING, "still pending")
	_free_slots(character, 1)
	check_eq(QuestRewardService.claim(character, HUNTER), "", "claimed")
	check(_gold(character) == gold + 40 and character.inventory.count(&"cured_leather") == 2, "40 gold and 2 cured leather")
	check(QuestRewardService.claim(character, HUNTER) != "", "no second claim")
	check_eq(_gold(character), gold + 40, "gold paid once")
	var loaded := _reload(character)
	check(StoryService.is_completed(loaded, HUNTER) and QuestRewardService.state(loaded, HUNTER) == QuestRewardService.CLAIMED, "claimed after loading")
	check(QuestRewardService.claim(loaded, HUNTER) != "", "no claim after loading")
	StoryService.notify(loaded, &"talk:mara_lost_hunter")
	check(StoryService.is_completed(loaded, HUNTER), "a completed quest never restarts")
	var dialogue := DialogueService.pick(loaded, _mara())
	check(dialogue == null or not dialogue.id in [&"mara_lost_hunter", &"mara_lost_hunter_hint", &"mara_lost_hunter_return"], "Mara has nothing left about Tobin")


# --- What the Roots Keep ---------------------------------------------------------------------------

func test_roots_keep_marker_marks_seal_and_cache() -> void:
	var character := _character()
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	var seal := wood.get_node("RootsKeep/Seal") as StoryConditional
	var cache := wood.get_node("RootsKeep/Cache") as Readable
	var guardians := wood.get_node("Encounters/RootsKeepGuardians") as Encounter
	check(seal.is_active() and not guardians.can_start(), "sealed, no guardians before the marks")
	# the sealed cache cannot be reached on foot
	wood.player.global_position = cache.global_position + Vector2(70, -40)
	wood.player.reset_physics_interpolation()
	var frame := InputFrame.new()
	for i in 90:
		frame.move = (cache.global_position - wood.player.global_position).normalized()
		wood.player.feed_input(frame)
		await get_tree().physics_frame
	wood.player.feed_input(InputFrame.new())
	await get_tree().physics_frame
	check(not cache.player_inside, "the roots keep the cache out of reach")
	(wood.get_node("RootsKeep/KnottedMarker") as Readable).interact(wood.hud)
	check(StoryService.at_step(character, ROOTS, 0), "the marker starts the quest at step 0")
	for name: String in ["MarkNorth", "MarkHollow", "MarkHollow", "MarkGrove"]:
		(wood.get_node("RootsKeep/" + name) as Readable).interact(wood.hud)
	wood.hud.close_windows()
	await _settle()
	check(StoryService.at_step(character, ROOTS, 1), "three marks: find the cache")
	check(character.world.has_flag(&"roots_keep.marks_found") and not seal.is_active(), "the seal opens")
	wood.player.global_position = wood.find_spawn(&"from_forest").global_position   # away from the grove
	wood.player.reset_physics_interpolation()
	await get_tree().physics_frame
	check(guardians.can_start() and guardians.persistent, "optional one-time guardians wake")
	wood.get_node("Encounters").queue_free()   # the cache never needs the fight
	await get_tree().process_frame
	wood.player.global_position = cache.global_position + Vector2(70, -40)
	wood.player.reset_physics_interpolation()
	for i in 90:
		frame.move = (cache.global_position - wood.player.global_position).normalized()
		wood.player.feed_input(frame)
		await get_tree().physics_frame
	wood.player.feed_input(InputFrame.new())
	for i in 3:
		await get_tree().physics_frame
	check(cache.player_inside, "the cache is reached once the seal is open")
	# full bag: nothing taken, nothing marked, no completion
	var gold := _gold(character)
	_fill_bag(character)
	cache.interact(wood.hud)
	wood.hud.close_windows()
	check(not cache.is_read() and _gold(character) == gold and character.inventory.count(&"iron_ingot") == 0, "full bag: nothing taken")
	check(StoryService.at_step(character, ROOTS, 1), "full bag: not completed")
	_free_slots(character, 2)
	cache.interact(wood.hud)
	wood.hud.close_windows()
	check(cache.is_read() and StoryService.is_completed(character, ROOTS), "cache opened, quest completed")
	check(_gold(character) == gold + 25 and character.inventory.count(&"iron_ingot") == 2 and character.inventory.count(&"duskleaf") == 2,
		"25 gold, 2 iron ingots, 2 duskleaf")
	cache.interact(wood.hud)
	wood.hud.close_windows()
	check(_gold(character) == gold + 25 and character.inventory.count(&"iron_ingot") == 2, "no second cache claim")
	check(not character.world.has_flag(&"encounter.roots_keep_guardians"), "completed without the optional fight")
	check(StoryService.at_step(character, MAIN, 1), "the main quest only saw the arrival")
	var loaded := _reload(character)
	check(StoryService.is_completed(loaded, ROOTS) and loaded.world.has_flag(&"read.roots_keep_cache"), "completion and claim saved")


func test_roots_keep_marks_before_the_marker_still_count() -> void:
	var character := _character()
	for i in 3:
		StoryService.notify(character, &"interact:roots_keep_mark")
	check_eq(character.quests.state(ROOTS), "", "marks alone start nothing")
	StoryService.notify(character, &"interact:roots_keep_marker")
	check(StoryService.at_step(character, ROOTS, 1), "the marks read earlier count at once (cumulative)")
	check(character.world.has_flag(&"roots_keep.marks_found"), "seal flag")


func test_roots_keep_guardians_are_optional_and_one_time() -> void:
	var character := _character()
	character.world.set_flag(&"roots_keep.marks_found")
	session.set_character(character)
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	var guardians := wood.get_node("Encounters/RootsKeepGuardians") as Encounter
	_kill_encounter(guardians)
	check(character.world.has_flag(guardians.cleared_flag()), "cleared for good")
	check_eq(character.quests.state(ROOTS), "", "the fight never starts or advances the quest")
	wood = await _travel(&"tangled_wood", &"from_chapel")
	if wood == null:
		return
	check(not (wood.get_node("Encounters/RootsKeepGuardians") as Encounter).can_start(), "not back on a later visit")


# --- Embers of Shelter -----------------------------------------------------------------------------

func test_embers_start_from_the_new_ledger_even_after_the_old_note() -> void:
	var character := _character()
	character.world.set_flag(&"read.chapel_faded_note")   # an old save that already read the note
	character.quests.entries[MAIN] = {"state": "active", "step": 3, "progress": {}}
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	var found := chapel.get_node("EmbersOfShelter/Found") as StoryConditional
	check(not found.is_active(), "the hearth box waits for the ledger")
	(chapel.get_node("FadedNote") as Readable).interact(chapel.hud)
	check_eq(character.quests.state(EMBERS), "", "the old note starts nothing")
	(chapel.get_node("EmbersOfShelter/Ledger") as Readable).interact(chapel.hud)
	chapel.hud.close_windows()
	await _settle()
	check(StoryService.at_step(character, EMBERS, 0), "the ledger starts the quest")
	check(found.is_active(), "the hearth box appears")
	var box := chapel.get_node("EmbersOfShelter/Found/HearthBox") as Readable
	_fill_bag(character)
	box.interact(chapel.hud)
	chapel.hud.close_windows()
	check(not box.is_read() and StoryService.at_step(character, EMBERS, 0), "full bag: nothing taken, no progress")
	_free_slots(character, 2)
	box.interact(chapel.hud)
	box.interact(chapel.hud)
	chapel.hud.close_windows()
	check(character.inventory.count(&"duskleaf") == 2 and character.inventory.count(&"timber") == 2, "2 duskleaf and 2 timber, once")
	check(StoryService.at_step(character, EMBERS, 1), "brew the draught")
	check(StoryService.at_step(character, MAIN, 3), "the main quest did not move")
	var loaded := _reload(character)
	check(StoryService.at_step(loaded, EMBERS, 1) and loaded.world.has_flag(&"read.shelter_hearth_box"), "progress and claim saved")


func test_embers_count_only_a_real_ember_draught_craft() -> void:
	var character := _character()
	var recipe: ProfessionRecipeDefinition = db.profession_recipes[&"al_ember_draught"]
	check_eq(recipe.output_item_id, &"ember_draught", "the existing recipe")
	check_eq(ProfessionService.station_of(db, recipe), &"alchemists_cottage", "brewed at the Alchemist's Cottage")
	check(character.professions.knows(&"al_ember_draught"), "known from the start")
	var station := &"alchemists_cottage"
	# a craft before the quest step never counts later
	character.inventory.add_item(&"duskleaf", 2)
	character.inventory.add_item(&"timber", 1)
	check_eq(ProfessionService.craft(character, &"al_ember_draught", station).error, "", "brewed before the quest")
	StoryService.notify(character, &"interact:shelter_ledger")
	StoryService.notify(character, &"interact:shelter_hearth_box")
	check(StoryService.at_step(character, EMBERS, 1), "at the brewing step")
	var counter := StoryService.counter(character, &"craft:al_ember_draught")
	# failed crafts: no materials, wrong station - no event
	check(ProfessionService.craft(character, &"al_ember_draught", station).error != "", "no materials: refused")
	character.inventory.add_item(&"duskleaf", 4)
	character.inventory.add_item(&"timber", 1)
	character.inventory.add_item(&"flax_fiber", 2)
	check(ProfessionService.craft(character, &"al_ember_draught", &"old_smithy").error != "", "wrong station: refused")
	check_eq(StoryService.counter(character, &"craft:al_ember_draught"), counter, "failed crafts report nothing")
	# another recipe does not count
	check_eq(ProfessionService.craft(character, &"al_quickstep_tincture", station).error, "", "another recipe brewed")
	check(StoryService.at_step(character, EMBERS, 1), "the wrong recipe does not count")
	check_eq(StoryService.counter(character, &"craft:al_quickstep_tincture"), 1, "it reports its own event")
	# the real craft
	var draughts := character.inventory.count(&"ember_draught")
	check_eq(ProfessionService.craft(character, &"al_ember_draught", station).error, "", "brewed")
	check_eq(character.inventory.count(&"ember_draught"), draughts + 1, "a real Ember Draught in the bag")
	check(StoryService.at_step(character, EMBERS, 2), "tell Mara")
	if not _finish(character, &"mara_embers"):
		return
	check(StoryService.is_completed(character, EMBERS), "completed once")
	var gold := _gold(character)
	var leaf := character.inventory.count(&"duskleaf")
	check_eq(QuestRewardService.claim(character, EMBERS), "", "claimed at Mara")
	check(_gold(character) == gold + 30 and character.inventory.count(&"duskleaf") == leaf + 4, "30 gold and 4 duskleaf")
	check(QuestRewardService.claim(character, EMBERS) != "", "no second claim")
	ProfessionService.craft(character, &"al_ember_draught", station)
	check(StoryService.is_completed(character, EMBERS) and character.quests.entries.size() == PROLOGUE_QUESTS.size() + 2,
		"later crafts change nothing (%d quests)" % character.quests.entries.size())


func test_embers_real_workbench_in_haven() -> void:
	var character := _character()
	StoryService.notify(character, &"interact:shelter_ledger")
	StoryService.notify(character, &"interact:shelter_hearth_box")
	character.inventory.add_item(&"duskleaf", 2)
	character.inventory.add_item(&"timber", 1)
	session.set_character(character)
	var haven := await _travel(&"home_base", &"from_forest")
	if haven == null:
		return
	var cottage := haven.get_node("Ruins/AlchemistsCottage") as RuinSite
	check(cottage != null and cottage.ruin_id == &"alchemists_cottage", "the cottage stands in Haven")
	check_eq(ProfessionService.craft_error(character, &"al_ember_draught", cottage.ruin_id), "", "the workbench brews in its ruined stage")
	check_eq(ProfessionService.craft(character, &"al_ember_draught", cottage.ruin_id).error, "", "brewed at the cottage")
	check(StoryService.at_step(character, EMBERS, 2), "the quest saw the craft")
	var mara := haven.get_node("Mara") as StoryNpc
	check_eq(mara.marker(), "!", "Mara marks the story talk")


# --- regression ------------------------------------------------------------------------------------

func test_main_quest_and_side_quests_never_touch_each_other() -> void:
	var character := _character()
	for event: StringName in [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone", &"enter:wardens_rest"]:
		StoryService.notify(character, event)
	for quest_id in SIDE_QUESTS:
		check_eq(character.quests.state(quest_id), "", "%s not started by the main quest" % quest_id)
	check(StoryService.at_step(character, MAIN, 4), "main quest advanced as before")
	for event: StringName in [&"talk:mara_lost_hunter", &"interact:roots_keep_marker", &"interact:shelter_ledger",
			&"interact:lost_hunter_camp", &"interact:roots_keep_mark", &"interact:shelter_hearth_box", &"craft:al_ember_draught"]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, MAIN, 4), "side events never move the main quest")
	check_eq(QuestRewardService.state(character, &"the_first_binding"), QuestRewardService.NONE, "Edrin's First Binding entitlement untouched")
	check(not character.world.has_flag(&"boss_reward.whisper_forest_grove_warden"), "Warden's Cache untouched")
	var loaded := _reload(character)
	check_eq(SaveSystem.VERSION, 15, "save version unchanged")
	for quest_id in SIDE_QUESTS:
		check(StoryService.is_active(loaded, quest_id), "%s active after loading" % quest_id)
	check(StoryService.at_step(loaded, MAIN, 4), "main quest restored")


func test_old_v15_save_without_side_quests_loads_and_can_start_them() -> void:
	var character := _character()
	character.world.set_flag(&"read.chapel_faded_note")
	character.world.set_flag(&"pickup.forest_hunters_pack")
	character.world.set_flag(&"dialogue.mara_history")
	var loaded := _reload(character)
	for quest_id in SIDE_QUESTS:
		check_eq(loaded.quests.state(quest_id), "", "%s unknown in the old save" % quest_id)
	check_eq(DialogueService.pick(loaded, _mara()).id, &"mara_lost_hunter", "Mara still offers the hunt (history does not cover it)")
	StoryService.notify(loaded, &"interact:shelter_ledger")
	check(StoryService.is_active(loaded, EMBERS), "Embers still starts after the old note was read")
