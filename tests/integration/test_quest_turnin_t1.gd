extends TestCase
## NPC Quest Turn-ins 1.0 T1 (docs/NPC_QUEST_TURNINS_1_0_T1.md): the one 60 gold reward of
## "The First Binding". A live completion registers the entitlement; resettle, migrations
## and historical completed entries never do (R-B). Claim = entitled + completed + not
## claimed + no trial; gold and claimed flag change together; never twice. Saves are
## synthetic dictionaries (Character.to_dict -> from_dict); milestone requests go to
## user://test_saves/quest_turnin_t1/ and are dropped (no GameMap runs, nothing is written).

const QUEST := &"the_first_binding"
const ENTITLED := &"quest_reward_entitled.the_first_binding"
const CLAIMED := &"quest_reward_claimed.the_first_binding"
const GOLD := &"gold_coin"
const PROFILE := "user://test_saves/quest_turnin_t1/slot_1.save.json"
## Story events up to "The Whispering Stone", step 1 (as in test_class_trials_m1).
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro",
		&"enter:whispering_stone"]
const BINDING := [&"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]

var db: GameDatabase
var character: Character
var session: SessionState
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	if session.save_path != PROFILE:
		_previous_path = session.save_path
		session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path


func _reload(source: Character) -> Character:
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())), db, warnings)
	check(loaded != null, "synthetic save loads")
	return loaded


## The real prologue chain up to "The First Binding" being active (trial, choice, waystone).
func _to_the_binding() -> void:
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	for objective in (db.trials[&"trial_warrior"] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "class chosen")
	StoryService.notify(character, &"waystone:whispering_stone")
	check(StoryService.at_step(character, QUEST, 0), "The First Binding active at step 0")


func _complete_binding() -> void:
	for event: StringName in BINDING:
		StoryService.notify(character, event)


func _pending_saves() -> int:
	return session.saves._auto_pending.size()


# --- entitlement --------------------------------------------------------------------------------

func test_live_completion_registers_the_claim_and_keeps_the_story_contract() -> void:
	_to_the_binding()
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check_eq(quest.steps.size(), 3, "three steps unchanged")
	var events: Array = quest.steps.map(func(step: StoryStep) -> StringName: return step.objectives[0].event_id)
	check_eq(events, BINDING, "objectives and order unchanged")
	check_eq(quest.next_quest_ids, [&"the_first_signs"] as Array[StringName], "successor unchanged")
	check_eq(quest.turn_in_gold, 60, "60 gold")
	check_eq(quest.turn_in_npc_id, &"edrin", "turn-in at Edrin")
	var gold := character.inventory.count(GOLD)
	for event: StringName in BINDING.slice(0, 2):
		StoryService.notify(character, event)
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no claim before completion")
	check_eq(QuestRewardService.claim(character, QUEST), "There is no reward waiting for you.", "claim refused before completion")
	var dialogue: DialogueDefinition = null
	for candidate in (db.npcs[&"edrin"] as NpcDefinition).dialogues:
		if candidate.id == &"edrin_threat":
			dialogue = candidate
	check(DialogueService.pick(character, db.npcs[&"edrin"]) == dialogue, "Edrin offers the final talk")
	DialogueService.finish(character, dialogue)   # the real completing path
	check(StoryService.is_completed(character, QUEST), "quest completed as before")
	check(character.world.has_flag(&"prologue.completed"), "prologue.completed set as before")
	check(StoryService.is_active(character, &"the_first_signs"), "successor started as before")
	check(character.world.has_flag(ENTITLED), "entitlement registered")
	check(not character.world.flags.has(CLAIMED), "not claimed")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "pending")
	check_eq(character.inventory.count(GOLD), gold, "completion alone gives no gold")
	# replaying the final events / dialogue: still one entitlement, no gold
	DialogueService.finish(character, dialogue)
	StoryService.notify(character, &"talk:edrin_threat")
	check_eq(character.world.get_flag(ENTITLED), true, "entitlement unchanged")
	check_eq(character.inventory.count(GOLD), gold, "no gold from dialogue repeats")
	check(DialogueService.pick(character, db.npcs[&"edrin"]) == null, "Edrin has no further dialogue")
	StoryService.tracker_lines(character)
	check_eq(character.inventory.count(GOLD), gold, "no gold from tracker / journal reads")


func test_claim_gives_exactly_60_gold_once_and_one_milestone_save() -> void:
	_to_the_binding()
	_complete_binding()
	var gold := character.inventory.count(GOLD)
	var saves := _pending_saves()
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(GOLD), gold + 60, "exactly 60 gold")
	check(character.world.has_flag(CLAIMED), "claimed flag")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.CLAIMED, "claimed state")
	check_eq(_pending_saves(), saves + 1, "one milestone save requested")
	check(session.saves._critical_pending, "as a critical (milestone) save")
	check_eq(QuestRewardService.claim(character, QUEST, session), "You were already rewarded.", "second claim refused")
	check_eq(character.inventory.count(GOLD), gold + 60, "no extra gold")
	check_eq(_pending_saves(), saves + 1, "no second save")


func test_trial_blocks_the_claim() -> void:
	_to_the_binding()
	_complete_binding()
	var gold := character.inventory.count(GOLD)
	# a running trial session (the guard is the same in every claim: classes.in_trial)
	character.prologue.stage = PrologueState.Stage.IN_PROGRESS
	character.classes.begin_trial(&"warrior", 1)
	check(character.classes.in_trial(), "trial running")
	check_eq(QuestRewardService.claim(character, QUEST, session), "Finish or leave the current trial first.", "refused")
	check_eq(character.inventory.count(GOLD), gold, "no gold")
	check(not character.world.flags.has(CLAIMED), "no claimed flag")
	check_eq(_pending_saves(), 0, "no save")
	character.classes.end_trial()
	character.prologue.stage = PrologueState.Stage.COMPLETED
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claim outside the trial")
	check_eq(character.inventory.count(GOLD), gold + 60, "60 gold")


func test_failed_credit_sets_no_flag_and_keeps_no_gold() -> void:
	_to_the_binding()
	_complete_binding()
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	var gold := character.inventory.count(GOLD)
	quest.turn_in_gold = Inventory.CURRENCY_ROOM + 1   # more than any stack can take: add_item refuses
	var error := QuestRewardService.claim(character, QUEST, session)
	quest.turn_in_gold = 60
	check_eq(error, "The reward could not be handed over.", "credit failed")
	check_eq(character.inventory.count(GOLD), gold, "no gold kept")
	check(not character.world.flags.has(CLAIMED), "no claimed flag")
	check_eq(_pending_saves(), 0, "no save")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "claim still pending")


# --- save / load and old saves (R-B) -------------------------------------------------------------

func test_pending_and_claimed_survive_save_and_load_in_one_snapshot() -> void:
	_to_the_binding()
	_complete_binding()
	var loaded := _reload(character)
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.PENDING, "pending after load")
	character = loaded
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed after load")
	var payload := character.to_dict()
	check_eq((payload.world.flags as Dictionary).get(String(CLAIMED)), true, "claimed flag in the snapshot")
	var saved_gold := 0
	for entry: Dictionary in payload.inventory:
		if str(entry.get("def", "")) == String(GOLD):
			saved_gold += int(entry.get("qty", 0))
	check_eq(saved_gold, gold + 60, "the 60 gold in the same snapshot")
	var again := _reload(character)
	check_eq(QuestRewardService.state(again, QUEST), QuestRewardService.CLAIMED, "claimed after load")
	check_eq(again.inventory.count(GOLD), gold + 60, "gold kept")
	check_eq(QuestRewardService.claim(again, QUEST), "You were already rewarded.", "no claim after load")
	check(StoryService.resettle(again).is_empty() and StoryService.resettle(again).is_empty(), "repeated resettle moves nothing")
	check_eq(QuestRewardService.state(again, QUEST), QuestRewardService.CLAIMED, "still claimed")


func test_historical_completion_gives_no_claim() -> void:
	_to_the_binding()
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "completed", "step": 3, "progress": {}}   # completed before T1
	payload.world.flags["prologue.completed"] = true
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(loaded, QUEST), "historically completed")
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.NONE, "no entitlement")
	var gold := loaded.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(loaded, QUEST), "There is no reward waiting for you.", "no claim")
	check_eq(loaded.inventory.count(GOLD), gold, "no gold")
	# claimed flag without entitlement (contradictory): nothing either
	loaded.world.set_flag(CLAIMED)
	check_eq(QuestRewardService.claim(loaded, QUEST), "You were already rewarded.", "claimed without entitlement: refused")
	check_eq(loaded.inventory.count(GOLD), gold, "still no gold")
	# entitlement without a completed quest (edited save): no claim
	var odd := CharacterFactory.create_new(db)
	odd.world.set_flag(ENTITLED)
	check_eq(QuestRewardService.state(odd, QUEST), QuestRewardService.NONE, "entitlement without completion: none")
	check(QuestRewardService.claim(odd, QUEST) != "", "refused")
	# a missing claimed flag alone is no claim
	check_eq(QuestRewardService.state(CharacterFactory.create_new(db), QUEST), QuestRewardService.NONE, "fresh character: none")


func test_v4_migrated_completion_gives_no_claim() -> void:
	var payload: Dictionary = CharacterFactory.create_new(db).to_dict()
	payload.erase("quests")
	(payload.world as Dictionary).erase("waystones")
	payload.prologue = {"stage": "completed", "completed_trials": ["trial_warrior"], "chosen_class": "warrior"}
	var errors: PackedStringArray = []
	var migrated: Variant = SaveMigrations.migrate(payload, 4, errors)
	if not check(migrated is Dictionary and errors.is_empty(), "v4 -> current migrates: %s" % [errors]):
		return
	check_eq(str((migrated.quests as Dictionary)[String(QUEST)].state), "completed", "migration writes completed")
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(migrated)), db, warnings)
	check(loaded.world.has_flag(&"prologue.completed"), "migration sets prologue.completed")
	check(not loaded.world.flags.has(ENTITLED), "no entitlement from the migration")
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.NONE, "no retroactive claim")


func test_resettle_reconstructing_a_completion_registers_no_claim() -> void:
	_to_the_binding()
	for event: StringName in BINDING.slice(0, 2):
		StoryService.notify(character, event)
	# last step met but never settled live (as after a lowered amount): resettle completes it on load
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "active", "step": 2, "progress": {"0": 1.0}}
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(loaded, QUEST), "resettle still completes the quest (M1 fix)")
	check(loaded.world.has_flag(&"prologue.completed"), "story flag reconstructed")
	check(StoryService.is_active(loaded, &"the_first_signs"), "successor started")
	check(not loaded.world.flags.has(ENTITLED), "no entitlement from the reconstruction")
	check(StoryService.resettle(loaded).is_empty(), "a second resettle moves nothing")
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.NONE, "no claim")


func test_other_rewards_never_touch_the_quest_reward() -> void:
	_to_the_binding()   # includes the M4 class choice
	check_eq(PrologueService.claim_class_reward(character, RandomNumberGenerator.new()), "", "M4 claim")
	character.world.set_flag(BossRewardService.defeat_flag(&"whisper_forest_grove_warden"))
	check_eq(BossRewardService.claim(character, &"whisper_forest_grove_warden", load("res://data/loot/grove_warden_rare_reward.tres"),
			RandomNumberGenerator.new()), "", "Warden's Cache claim")
	check(not character.world.flags.has(ENTITLED) and not character.world.flags.has(CLAIMED), "no quest reward flags")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no claim")


func test_reward_data_is_validated() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	quest.turn_in_npc_id = &"nobody"
	var errors := QuestRewardService.validate_quest(db, quest)
	quest.turn_in_npc_id = &"edrin"
	check(not errors.is_empty(), "unknown turn-in npc reported")
	for other: StoryQuestDefinition in db.story_quests.values():
		if other.id != QUEST:
			check_eq(other.turn_in_gold, 0, "%s has no reward" % other.id)
