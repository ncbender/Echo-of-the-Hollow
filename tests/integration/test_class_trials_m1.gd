extends TestCase
## Class Trials 2.0 M1 (docs/CLASS_TRIALS_2_0_M1.md): story re-evaluation after
## loading (no soft-lock for old states), the one-trial rule (a class needs its
## OWN completed trial), the class choice panel's locked state and the story /
## save consistency with 0-3 completed trials. Saves are synthetic dictionaries
## (Character.to_dict -> from_dict) - no file is written or read.

const TRIALS := {&"warrior": &"trial_warrior", &"arcanist": &"trial_arcanist", &"shadowrunner": &"trial_shadowrunner"}
## Story events up to "The Whispering Stone", step 1 (walk the echoes).
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro",
		&"enter:whispering_stone"]

## The panel asks the session for a milestone save: it is redirected here and
## dropped again (no GameMap is running, so nothing is written).
const PROFILE := "user://test_saves/class_trials_m1/slot_1.save.json"

var db: GameDatabase
var character: Character
var session: SessionState
var _previous_path: String
var _progressed: Array = []


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	if session != null and session.save_path != PROFILE:
		_previous_path = session.save_path
		session.save_path = PROFILE
	character = CharacterFactory.create_new(db)
	_progressed.clear()
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)


func after_each() -> void:
	if session == null:
		return
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path


func _on_progressed(quest_id: StringName, step: int, finished: bool) -> void:
	_progressed.append([quest_id, step, finished])


## Completes a trial through the real service (temporary class, objectives).
func _walk(trial_id: StringName) -> void:
	check_eq(PrologueService.begin_trial(character, trial_id), "", "begin %s" % trial_id)
	for objective in (db.trials[trial_id] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check(not character.classes.in_trial(), "%s ended after its objectives" % trial_id)


func _reload(source: Character) -> Character:
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())), db, warnings)
	check(loaded != null, "synthetic save loads")
	return loaded


## Old state: the class was chosen, but the story still waits at "walk the echoes"
## (counter never reached the step's amount while it was active). No trial can be
## started any more - only re-evaluation can move the story on.
func _stuck_with_choice(trials: Array[StringName], counter: int) -> Character:
	for trial_id in trials:
		character.prologue.completed_trials.append(trial_id)
	character.world.set_flag(&"count.trial_complete", counter)
	character.world.set_flag(&"count.class_chosen", 1)
	character.classes.unlock(&"warrior")
	character.classes.set_active(&"warrior")
	character.prologue.chosen_class = &"warrior"
	character.prologue.stage = PrologueState.Stage.COMPLETED
	return character


# --- Phase A: soft-lock -------------------------------------------------------

func test_stuck_story_with_chosen_class_recovers_on_load() -> void:
	_stuck_with_choice([&"trial_warrior", &"trial_arcanist", &"trial_shadowrunner"], 3)
	check(StoryService.at_step(character, &"the_whispering_stone", 1), "precondition: story waits at the echoes")
	check(PrologueService.can_begin_trial(character, &"trial_warrior") != "", "precondition: no trial can be started")
	var loaded := _reload(character)
	check(StoryService.at_step(loaded, &"the_whispering_stone", 3), "steps 1 and 2 settled: waystone step active")
	check(loaded.world.has_flag(&"prologue.first_class_selected"), "class choice flag set")
	check_eq(loaded.prologue.chosen_class, &"warrior", "chosen class kept")
	check(WaystoneService.activate(loaded, db.waystones[&"whispering_stone"]) == "", "waystone can be awakened")
	check(StoryService.is_completed(loaded, &"the_whispering_stone"), "quest completes")
	check(StoryService.is_active(loaded, &"the_first_binding"), "the first binding follows")


func test_resettle_is_idempotent_and_silent() -> void:
	_stuck_with_choice([&"trial_warrior", &"trial_arcanist", &"trial_shadowrunner"], 3)
	var loaded := _reload(character)
	loaded.quests.story_progressed.connect(_on_progressed)
	var before := JSON.stringify(loaded.to_dict())
	for i in 3:
		check(StoryService.resettle(loaded).is_empty(), "nothing moves a second time")
	check_eq(JSON.stringify(loaded.to_dict()), before, "state unchanged by repeated re-evaluation")
	check(_progressed.is_empty(), "no story signal (no milestone save)")
	var again := _reload(loaded)
	check_eq(JSON.stringify(again.to_dict()), JSON.stringify(loaded.to_dict()), "save/load round trip stable")


func test_resettle_never_touches_unfinished_steps() -> void:
	var loaded := _reload(character)
	check(StoryService.at_step(loaded, &"the_whispering_stone", 1), "no trial: still at the echoes")
	check(not loaded.world.has_flag(&"prologue.first_class_selected"), "no choice flag")


# --- Phase B/C: one-trial rule, service and panel -----------------------------

func _choosable(target: Character) -> Array[StringName]:
	var result: Array[StringName] = []
	for class_id: StringName in TRIALS:
		if PrologueService.can_choose(target, class_id) == "":
			result.append(class_id)
	return result


func _panel(target: Character) -> ClassChoicePanel:
	var panel := ClassChoicePanel.new()
	add_child(panel)
	panel.open(target, null)
	return panel


func _button(panel: ClassChoicePanel, class_id: StringName) -> Button:
	return panel.find_child("Choose_%s" % class_id, true, false) as Button


func _check_panel(panel: ClassChoicePanel, expected: Array[StringName]) -> void:
	check_eq(panel.choosable_classes(), expected, "panel lists exactly %s" % [expected])
	for class_id: StringName in TRIALS:
		var button := _button(panel, class_id)
		check(button != null, "%s card visible" % class_id)
		if button == null:
			continue
		check_eq(button.disabled, not class_id in expected, "%s button state" % class_id)
		if not class_id in expected:
			check(button.text.begins_with("Locked"), "%s shows a locked state: %s" % [class_id, button.text])


func test_no_trial_no_class() -> void:
	check(_choosable(character).is_empty(), "no trial: nothing choosable")
	for class_id: StringName in TRIALS:
		check(PrologueService.choose_starting_class(character, class_id) != "", "%s refused" % class_id)
	check(not character.prologue.is_completed(), "nothing chosen")
	var panel := _panel(character)
	_check_panel(panel, [] as Array[StringName])
	panel.queue_free()


func test_each_single_trial_opens_only_its_class() -> void:
	for class_id: StringName in TRIALS:
		before_each()
		_walk(TRIALS[class_id])
		var expected: Array[StringName] = [class_id]
		check_eq(_choosable(character), expected, "only %s choosable" % class_id)
		var panel := _panel(character)
		_check_panel(panel, expected)
		for other: StringName in TRIALS:
			if other != class_id:
				check_eq(panel.choose(other), "Walk the echo of this path first.", "panel refuses %s" % other)
				check(PrologueService.choose_starting_class(character, other) != "", "service refuses %s directly" % other)
		check(not character.prologue.is_completed(), "refusals choose nothing")
		check_eq(panel.choose(class_id), "confirm", "own class: first click asks")
		check_eq(panel.choose(class_id), "", "own class confirmed")
		check_eq(character.prologue.chosen_class, class_id, "chosen_class = %s" % class_id)
		check(character.classes.is_unlocked(class_id) and character.classes.active_class_id == class_id, "%s unlocked and active" % class_id)
		for other: StringName in TRIALS:
			if other != class_id:
				check(not character.classes.is_unlocked(other), "%s stays locked" % other)
		panel.queue_free()


func test_two_and_three_trials() -> void:
	_walk(&"trial_warrior")
	_walk(&"trial_shadowrunner")
	check_eq(_choosable(character), [&"warrior", &"shadowrunner"] as Array[StringName], "two trials: exactly both")
	var panel := _panel(character)
	_check_panel(panel, [&"warrior", &"shadowrunner"] as Array[StringName])
	_walk(&"trial_arcanist")
	panel.rebuild()
	_check_panel(panel, [&"warrior", &"arcanist", &"shadowrunner"] as Array[StringName])
	check_eq(StoryService.counter(character, &"trial_complete"), 3, "three echoes counted")
	panel.queue_free()


func test_other_trials_stay_optional_before_the_choice() -> void:
	_walk(&"trial_arcanist")
	check(StoryService.at_step(character, &"the_whispering_stone", 2), "one trial is enough for the story")
	check_eq(PrologueService.can_begin_trial(character, &"trial_warrior"), "", "another trial may still be walked")
	_walk(&"trial_warrior")
	check(StoryService.at_step(character, &"the_whispering_stone", 2), "an extra trial never skips the choice")
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "warrior chosen")
	check(PrologueService.can_begin_trial(character, &"trial_shadowrunner") != "", "no trial after the choice")
	check(not character.classes.is_unlocked(&"arcanist"), "walked but not chosen: still locked")


# --- Phase D: story and save consistency --------------------------------------

func test_save_load_with_zero_to_three_trials() -> void:
	var order: Array[StringName] = [&"trial_shadowrunner", &"trial_warrior", &"trial_arcanist"]
	for count in 4:
		before_each()
		for index in count:
			_walk(order[index])
		var loaded := _reload(character)
		check_eq(loaded.prologue.completed_trials, character.prologue.completed_trials, "%d trials kept" % count)
		check_eq(_choosable(loaded), _choosable(character), "%d trials: same choices after load" % count)
		check(StoryService.at_step(loaded, &"the_whispering_stone", 1 if count == 0 else 2), "%d trials: story step" % count)
		if count > 0:
			check_eq(PrologueService.choose_starting_class(loaded, (db.trials[order[0]] as TrialDefinition).class_id), "", "first walked class choosable after load")
			check(StoryService.at_step(loaded, &"the_whispering_stone", 3), "choice settles the step")
			var again := _reload(loaded)
			check(StoryService.at_step(again, &"the_whispering_stone", 3), "no soft-lock after the choice and a reload")
			check(again.world.has_flag(&"prologue.first_class_selected"), "waystone condition met")


func test_old_saves_with_one_or_two_trials_resettle() -> void:
	for size in [1, 2]:
		before_each()
		var trials: Array[StringName] = []
		trials.assign([&"trial_warrior", &"trial_arcanist"].slice(0, size))
		# old rules: the step waited for three echoes, so it is still active with 1-2 counted
		for trial_id in trials:
			character.prologue.completed_trials.append(trial_id)
		character.world.set_flag(&"count.trial_complete", size)
		var payload: Dictionary = character.to_dict()
		payload.quests["the_whispering_stone"] = {"state": "active", "step": 1, "progress": {}}
		var warnings: PackedStringArray = []
		var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
		check(StoryService.at_step(loaded, &"the_whispering_stone", 2), "%d old trials: on to the choice" % size)
		check(not loaded.prologue.is_completed(), "re-evaluation never chooses a class")
		check_eq(loaded.prologue.completed_trials, trials, "trial ids unchanged")
		check(StoryService.resettle(loaded).is_empty(), "a second re-evaluation moves nothing")
		check_eq(StoryService.counter(loaded, &"trial_complete"), size, "counter not inflated")
		check_eq(StoryService.counter(loaded, &"class_chosen"), 0, "no choice event invented")
		_stuck_with_choice([] as Array[StringName], size)   # same, but the class was already chosen
		payload = character.to_dict()
		payload.quests["the_whispering_stone"] = {"state": "active", "step": 1, "progress": {}}
		var chosen := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
		check(StoryService.at_step(chosen, &"the_whispering_stone", 3), "%d old trials + chosen class: waystone step" % size)
		check(chosen.world.has_flag(&"prologue.first_class_selected"), "waystone condition met")


func test_completed_prologue_is_untouched_by_resettle() -> void:
	_walk(&"trial_warrior")
	PrologueService.choose_starting_class(character, &"warrior")
	StoryService.notify(character, &"waystone:whispering_stone")
	for event: StringName in [&"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]:
		StoryService.notify(character, event)
	check(StoryService.is_completed(character, &"the_first_binding"), "prologue chain done")
	var before := JSON.stringify(character.to_dict().quests)
	var loaded := _reload(character)
	check_eq(JSON.stringify(loaded.to_dict().quests), before, "finished quests unchanged by loading")
	check(loaded.world.has_flag(&"prologue.completed"), "prologue.completed kept")


func test_trial_ids_and_equip_rights_unchanged() -> void:
	for class_id: StringName in TRIALS:
		var trial := PrologueService.trial_for_class(db, class_id)
		check(trial != null and trial.id == TRIALS[class_id], "%s keeps trial id %s" % [class_id, TRIALS[class_id]])
		check((db.get_class_def(class_id) as ClassDefinition).allowed_weapon_families.is_empty(), "%s: every weapon family allowed" % class_id)
	var step: StoryStep = (db.story_quests[&"the_whispering_stone"] as StoryQuestDefinition).steps[1]
	check_eq(step.objectives[0].event_id, &"trial_complete", "story still counts trial_complete")
	check_eq(step.objectives[0].amount, 1, "one echo is enough")
