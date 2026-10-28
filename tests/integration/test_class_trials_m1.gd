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

var db: GameDatabase
var character: Character
var _progressed: Array = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	_progressed.clear()
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)


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
