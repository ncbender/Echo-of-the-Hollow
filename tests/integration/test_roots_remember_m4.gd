extends TestCase
## Chapter 1 "The Roots Remember" M4 (docs/ROOTS_REMEMBER_M4.md): Edrin's report completes the_first_signs
## exactly once (step 5, new live event), the open outlook quest beyond_the_roots starts once, no quest
## reward, Edrin's dialogue priority and Quest Rewards service (the_first_binding's 60 gold), saves on steps
## 0-5, resettle. Real Haven for the NPC; files only under user://test_saves/roots_m4/.

const DIR := "user://test_saves/roots_m4"
const PROFILE := DIR + "/slot_1.save.json"
const QUEST := &"the_first_signs"
const NEXT := &"beyond_the_roots"
const REPORT := &"edrin_first_signs_report"
const REPORT_EVENT := &"talk:edrin_first_signs_report"
const EVENTS: Array[StringName] = [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone",
	&"enter:wardens_rest", &"interact:wardens_rest_watchstone"]
const DEFEATED := &"defeated.wardens_rest_rootbound_sentinel"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
## Counters and one-time flags a long-running save may carry - including other Edrin talks.
const HISTORIC := {
	"count.talk:edrin_threat": 1, "count.talk:edrin_intro": 1, "count.enter:home_base": 40, "count.enter:whisper_forest": 25,
	"count.enter:tangled_wood": 6, "count.enter:chapel": 5, "count.enter:wardens_rest": 4, "count.encounter:chapel_yard": 4,
	"dialogue.edrin_threat": true, "dialogue.edrin_intro": true, "count.trial_complete": 3,
	"defeated.whisper_forest_grove_warden": true, "boss_reward.whisper_forest_grove_warden": true,
}

var db: GameDatabase
var session: SessionState
var map: GameMap
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


## Finished prologue (class chosen, Edrin's 60 gold still pending, Mara's reward claimed), the_first_signs at `step`.
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
	character.world.set_flag(&"dialogue.edrin_threat")
	StoryService.start(character, QUEST)
	if step >= 5:
		character.world.set_flag(DEFEATED)
	for event: StringName in EVENTS.slice(0, step):
		StoryService.notify(character, event)
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


func _edrin_def() -> NpcDefinition:
	return db.npcs[&"edrin"]


func _report() -> DialogueDefinition:
	return _edrin_def().dialogues[0]


func _offered(character: Character) -> StringName:
	var dialogue := DialogueService.pick(character, _edrin_def())
	return dialogue.id if dialogue != null else &""


func _unchanged(character: Character) -> void:
	check_eq(character.prologue.chosen_class, &"arcanist", "class choice kept")
	check_eq(character.prologue.completed_trials, [&"trial_arcanist"] as Array[StringName], "trials kept")
	check_eq(QuestRewardService.state(character, &"the_broken_cart"), QuestRewardService.CLAIMED, "Mara's reward still claimed")
	for quest_id: StringName in [QUEST, NEXT]:
		check_eq(QuestRewardService.state(character, quest_id), QuestRewardService.NONE, "%s: no reward state" % quest_id)
		check(not character.world.has_flag(QuestRewardService.entitled_flag(quest_id)) and not character.world.has_flag(QuestRewardService.claimed_flag(quest_id)),
			"%s: no reward flags" % quest_id)
	check(not WaystoneService.is_active(character, &"chapel_waystone") and not character.world.has_flag(&"waystone.chapel_waystone"), "Chapel Waystone dormant")
	check(not WaystoneService.is_active(character, &"wardens_rest"), "Warden's Rest waystone dormant")


func _open_haven(character: Character) -> void:
	character.world.map_id = &"home_base"
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	map = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 3:
		await get_tree().process_frame


func _read_to_the_end() -> void:
	for i in 20:
		if not map.hud.dialogue_panel.visible:
			return
		map.hud.dialogue_panel.advance()


# --- data ---------------------------------------------------------------------------------------

func test_quest_and_dialogue_data() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	check(DialogueService.validate_data(db).is_empty(), "dialogue data valid: %s" % [DialogueService.validate_data(db)])
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check_eq(quest.steps.size(), 6, "no new steps")
	for index in 5:
		check_eq(quest.steps[index].objectives[0].event_id, EVENTS[index], "step %d unchanged" % index)
	check_eq(quest.steps.map(func(step: StoryStep) -> StringName: return step.completion_flag).slice(0, 5),
		[&"chapter1.tangled_wood_reached", &"chapter1.roots_examined", &"chapter1.chapel_waystone_examined",
		&"chapter1.wardens_rest_reached", &"chapter1.watchstone_examined"], "step flags 0-4 unchanged")
	var report := quest.steps[5].objectives
	check(report.size() == 1 and report[0].event_id == REPORT_EVENT and not report[0].cumulative and report[0].amount == 1,
		"step 5: Edrin's report, counted live only (never from a counter)")
	check(not quest.open_ended and quest.completion_flag == &"chapter1.the_first_signs_completed", "completable, with a flag")
	check_eq(quest.next_quest_ids, [NEXT] as Array[StringName], "exactly one successor")
	check(not QuestRewardService.has_reward(quest) and quest.turn_in_npc_id == &"", "no quest reward")
	var next: StoryQuestDefinition = db.story_quests.get(NEXT)
	if check(next != null, "successor exists"):
		check(next.open_ended and next.steps.size() == 1 and next.steps[0].objectives.is_empty(), "open placeholder, no objective")
		check(next.next_quest_ids.is_empty() and not QuestRewardService.has_reward(next), "no further successor, no reward")
		check(next.steps[0].description.contains("not yet available"), "says the next part is not available yet")
	check_eq((db.story_quests[&"the_first_binding"] as StoryQuestDefinition).turn_in_gold, 60, "Edrin's 60 gold unchanged")
	var dialogue := _report()
	check_eq(dialogue.id, REPORT, "the report comes first in Edrin's list")
	check(not dialogue.repeatable and dialogue.event_id == REPORT_EVENT, "one-time, reports the new event")
	check(dialogue.condition.quest_id == QUEST and dialogue.condition.quest_state == "active"
		and dialogue.condition.min_step == 5 and dialogue.condition.max_step == 5, "offered exactly at step 5 of an active quest")
	check_eq(_edrin_def().dialogues.map(func(d: DialogueDefinition) -> StringName: return d.id),
		[REPORT, &"edrin_threat", &"edrin_intro", &"edrin_early", &"edrin_shrine_hint"], "the earlier dialogues stay, in order")
	check_eq(_edrin_def().service, &"quest_rewards", "Edrin's service unchanged")
	for npc: NpcDefinition in db.npcs.values():
		for other in npc.dialogues:
			check(other.id == REPORT or other.event_id != REPORT_EVENT, "%s does not reuse the report event" % other.id)


# --- unlock, completion, successor --------------------------------------------------------------

func test_report_only_at_step_five() -> void:
	for step in 5:
		var character := _character_at(step)
		character.world.set_flag(DEFEATED)   # a defeat alone never unlocks it
		check(_offered(character) != REPORT, "not offered at step %d" % step)
	var ready := _character_at(5)
	check_eq(_offered(ready), REPORT, "offered at step 5")
	check(DialogueService.has_story_dialogue(ready, _edrin_def()), "marked as story dialogue (!)")


func test_completion_happens_once_and_starts_one_successor() -> void:
	var character := _character_at(5)
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	# nothing but the finished report completes it
	for event: StringName in [&"enter:home_base", &"talk:edrin_threat", &"talk:edrin_intro", &"interact:wardens_rest_watchstone",
			&"enter:wardens_rest", &"talk:mara_return"]:
		StoryService.notify(character, event)
	for i in 3:
		check(StoryService.resettle(character).is_empty(), "resettle %d before the talk" % i)
	check(StoryService.at_step(character, QUEST, 5) and progressed.is_empty(), "still step 5")
	DialogueService.finish(character, _report())
	check(StoryService.is_completed(character, QUEST), "the_first_signs completed")
	check(character.world.has_flag(&"chapter1.the_first_signs_completed"), "completion flag")
	check(StoryService.at_step(character, NEXT, 0), "Beyond the Roots active at step 0")
	check_eq(progressed, [[QUEST, 6, true]], "one live completion event")
	check(_offered(character) != REPORT, "the report is not offered again")
	# a repeated finish (e.g. a stale window) changes nothing
	DialogueService.finish(character, _report())
	for i in 3:
		check(StoryService.resettle(character).is_empty(), "resettle %d after the talk" % i)
	check_eq(progressed, [[QUEST, 6, true]], "no second completion")
	check_eq(character.quests.entries.keys().count(NEXT), 1, "the successor exists once")
	check(StoryService.at_step(character, NEXT, 0) and not StoryService.is_completed(character, NEXT), "the successor never completes")
	var lines := StoryService.tracker_lines(character)
	check(lines.size() == 2 and lines[0] == "Main Quest: Beyond the Roots" and lines[1].contains("not yet available"), "tracker %s" % [lines])
	check_eq(QuestRewardService.state(character, &"the_first_binding"), QuestRewardService.PENDING, "Edrin's 60 gold still pending")
	_unchanged(character)


# --- saves --------------------------------------------------------------------------------------

func test_saves_on_steps_0_to_5() -> void:
	for step in 6:
		var payload := _character_at(step).to_dict()
		var flags: Dictionary = (payload.world as Dictionary).flags
		for flag: String in HISTORIC:
			flags[flag] = HISTORIC[flag]
		if step == 5:
			flags["count." + String(REPORT_EVENT)] = 3   # even a counter of the new talk never completes the quest
		var loaded := _load_payload(payload)
		if loaded == null:
			return
		check(StoryService.at_step(loaded, QUEST, step), "save on step %d loads on step %d" % [step, step])
		for i in 3:
			check(StoryService.resettle(loaded).is_empty(), "step %d: resettle %d moves nothing" % [step, i])
		check(StoryService.at_step(loaded, QUEST, step) and loaded.quests.state(NEXT) == "", "no completion, no successor (step %d)" % step)
		check_eq(_offered(loaded) == REPORT, step == 5, "report offered only on step 5 (step %d)" % step)
		check_eq(QuestRewardService.state(loaded, &"the_first_binding"), QuestRewardService.PENDING, "Edrin's 60 gold pending")
		_unchanged(loaded)


func test_sentinel_and_watchstone_done_early_never_soft_lock() -> void:
	var character := _character_at(4)
	var payload := character.to_dict()
	(payload.world as Dictionary).flags[String(DEFEATED)] = true
	(payload.world as Dictionary).flags["count.interact:wardens_rest_watchstone"] = 1
	(payload.world as Dictionary).flags["read.wardens_rest_watchstone"] = true
	(payload.world as Dictionary).flags["defeated.whisper_forest_grove_warden"] = true
	var loaded := _load_payload(payload)
	check(StoryService.at_step(loaded, QUEST, 5), "M3 catch-up reaches step 5")
	check_eq(_offered(loaded), REPORT, "Edrin's report is available")
	DialogueService.finish(loaded, _report())
	check(StoryService.is_completed(loaded, QUEST), "and completes the quest")
	check(loaded.world.has_flag(DEFEATED) and loaded.world.has_flag(&"defeated.whisper_forest_grove_warden"), "both defeat flags kept")


func test_save_load_before_and_after_the_talk() -> void:
	var before := _reload(_character_at(5))
	check(StoryService.at_step(before, QUEST, 5) and _offered(before) == REPORT, "before: step 5, report offered")
	DialogueService.finish(before, _report())
	var after := _reload(before)
	check(StoryService.is_completed(after, QUEST) and StoryService.at_step(after, NEXT, 0), "after: completed, successor active")
	check(after.world.has_flag(&"dialogue.%s" % REPORT), "talk remembered")
	for i in 3:
		check(StoryService.resettle(after).is_empty(), "resettle %d after loading" % i)
	check(_offered(after) != REPORT, "not offered after loading")
	check_eq(after.quests.entries.keys().count(NEXT), 1, "one successor after loading")
	_unchanged(after)


# --- the real Edrin in Haven ---------------------------------------------------------------------

func test_edrin_story_first_then_service_and_sixty_gold_once() -> void:
	var character := _character_at(5)
	await _open_haven(character)
	var edrin := map.get_node("Edrin") as StoryNpc
	check(edrin.is_present(), "Edrin at the gate")
	check_eq(edrin.marker(), "!", "! for the report (before the pending ?)")
	edrin.interact(map.hud)
	check(map.hud.dialogue_panel.visible and not map.hud.quest_reward_panel.visible, "the report opens first, not the service")
	check(StoryService.at_step(character, QUEST, 5), "opening the talk completes nothing")
	# closing early changes nothing
	map.hud.dialogue_panel.advance()
	map.hud.close_windows()
	check(StoryService.at_step(character, QUEST, 5) and _offered(character) == REPORT, "closed early: still step 5, offered again")
	edrin.interact(map.hud)
	_read_to_the_end()
	check(StoryService.is_completed(character, QUEST) and StoryService.at_step(character, NEXT, 0), "read to the end: completed, successor")
	check_eq(edrin.marker(), "?", "now only the pending 60 gold remains")
	edrin.interact(map.hud)
	check(map.hud.quest_reward_panel.visible and not map.hud.dialogue_panel.visible, "Edrin opens Quest Rewards again")
	var gold := character.inventory.count(&"gold_coin")
	check_eq(map.hud.quest_reward_panel.claim(), "", "the 60 gold claimed")
	check_eq(character.inventory.count(&"gold_coin") - gold, 60, "exactly 60 gold")
	check(map.hud.quest_reward_panel.claim() != "", "no second payout")
	check_eq(character.inventory.count(&"gold_coin") - gold, 60, "still 60")
	map.hud.close_windows()
	check_eq(edrin.marker(), "", "no marker left")
	edrin.interact(map.hud)
	check(map.hud.quest_reward_panel.visible and not map.hud.dialogue_panel.visible, "the service stays reachable")
	_unchanged(character)


func test_edrin_before_step_five_opens_the_service() -> void:
	var character := _character_at(4)
	await _open_haven(character)
	var edrin := map.get_node("Edrin") as StoryNpc
	check_eq(edrin.marker(), "?", "only the pending reward is marked")
	edrin.interact(map.hud)
	check(map.hud.quest_reward_panel.visible and not map.hud.dialogue_panel.visible, "Quest Rewards, no report")
	check(StoryService.at_step(character, QUEST, 4), "no progress")
