extends GameplayTestCase
## Class Foundation F: temporary class trials, the one permanent starting class
## choice, class unlock quests, save/load around all of it and the v3 -> v4
## migration. Trials must never unlock a class, keep talents/skills/resources
## or create items.

const TEST_SAVE := "user://test_saves/prologue.save.json"
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const K := TrialObjective.Kind

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)


func _complete(trial_id: StringName) -> void:
	check_eq(PrologueService.begin_trial(character, trial_id), "", "begin %s" % trial_id)
	var trial: TrialDefinition = db.trials[trial_id]
	for objective in trial.objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check(character.prologue.has_completed_trial(trial_id), "%s completed" % trial_id)
	check(not character.classes.in_trial(), "trial ended on completion")


func _inventory_snapshot() -> Array:
	return character.inventory.to_array()


func test_prologue_data() -> void:
	check_eq(db.rules.prologue_class_ids, [&"warrior", &"arcanist", &"shadowrunner"] as Array[StringName], "three prologue classes")
	for class_id in db.rules.prologue_class_ids:
		var trial := PrologueService.trial_for_class(db, class_id)
		check(trial != null and not trial.objectives.is_empty(), "%s has a trial with objectives" % class_id)
		check(TalentService.validate_allocation(db, class_id, trial.trial_level, trial.talents).is_empty(), "%s trial build valid" % class_id)
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner", &"guardian", &"soulbinder"]:
		var quests := db.quests.values().filter(func(q: ClassQuestDefinition) -> bool: return q.class_id == class_id)
		check_eq(quests.size(), 1, "one unlock quest for %s" % class_id)
	check(not db.get_class_def(&"guardian").playable and not db.get_class_def(&"soulbinder").playable, "Guardian/Soulbinder prepared only")
	check(db.maps.has(&"prologue"), "prologue map registered")


func test_new_character_starts_as_basic_adventurer() -> void:
	check_eq(character.classes.active_class_id, &"basic_adventurer", "basic adventurer")
	check_eq(character.prologue.stage, PrologueState.Stage.NOT_STARTED, "prologue not started")
	for class_id in db.rules.prologue_class_ids:
		check(not character.classes.is_unlocked(class_id), "%s locked" % class_id)


func test_trial_is_temporary() -> void:
	var items_before := _inventory_snapshot()
	var loadout_before := character.equipment.to_dict()
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial started")
	check_eq(character.classes.active_class_id, &"warrior", "playing the warrior")
	check(not character.classes.is_unlocked(&"warrior"), "warrior NOT unlocked by the trial")
	check_eq(character.classes.get_level(&"warrior"), 12, "trial level")
	check_eq(character.builds.get_build().slots[0], &"furious_strike", "trial skills on the bar")
	check(not character.builds.get_build().talents.is_empty(), "trial talents active")
	check(character.equipment.get_item(EquipSlot.Slot.MAIN_HAND) != null, "trial uses the existing weapon (reference copy)")
	check(character.switch_class(&"basic_adventurer", true) != "", "no class switching during a trial")
	var payload := character.to_dict()
	check_eq(payload.classes.active, "basic_adventurer", "a save during the trial stores the real class")
	check(not payload.class_builds.has("warrior"), "no warrior build saved")
	check(not payload.loadouts.has("warrior"), "no warrior loadout saved")
	check(not payload.classes.progress.has("warrior"), "no warrior progress saved")
	PrologueService.end_trial(character, false)
	check_eq(character.classes.active_class_id, &"basic_adventurer", "back to the adventurer")
	check(not character.classes.is_unlocked(&"warrior"), "still locked")
	check_eq(_inventory_snapshot(), items_before, "inventory unchanged (no demo items)")
	check_eq(character.equipment.to_dict(), loadout_before, "loadouts unchanged")
	check(not character.prologue.has_completed_trial(&"trial_warrior"), "left trial does not count")
	check(not character.to_dict().class_builds.has("warrior"), "nothing of the trial left")
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "a left trial can be entered again")


func test_completing_trials_and_choosing_exactly_one() -> void:
	_complete(&"trial_warrior")
	check(PrologueService.choose_starting_class(character, &"warrior") != "", "choice needs all three trials")
	_complete(&"trial_arcanist")
	_complete(&"trial_shadowrunner")
	check_eq(character.prologue.completed_trials.size(), 3, "three trials done")
	check(PrologueService.choose_starting_class(character, &"guardian") != "", "guardian is not a prologue choice")
	check_eq(PrologueService.choose_starting_class(character, &"arcanist"), "", "arcanist chosen")
	check(character.classes.is_unlocked(&"arcanist"), "arcanist unlocked")
	check_eq(character.classes.active_class_id, &"arcanist", "arcanist active")
	check(not character.classes.is_unlocked(&"warrior") and not character.classes.is_unlocked(&"shadowrunner"), "others stay locked")
	check(character.prologue.is_completed(), "prologue complete")
	check(PrologueService.choose_starting_class(character, &"warrior") != "", "the choice never runs twice")
	check(PrologueService.begin_trial(character, &"trial_warrior") != "", "no trials after the prologue")
	check_eq(SaveSystem.save_to(character, TEST_SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(TEST_SAVE, db)
	check(loaded.ok(), "loaded")
	var restored := loaded.character
	check_eq(restored.classes.active_class_id, &"arcanist", "choice survives save/load")
	check(not restored.classes.is_unlocked(&"warrior") and not restored.classes.is_unlocked(&"shadowrunner"), "still locked after load")
	check(restored.prologue.is_completed() and restored.prologue.chosen_class == &"arcanist", "prologue state restored")


func test_save_and_load_between_trials() -> void:
	_complete(&"trial_warrior")
	PrologueService.begin_trial(character, &"trial_arcanist")
	PrologueService.record(character, K.SKILL_HITS, &"arcane_bolt", 2.0)
	check_eq(SaveSystem.save_to(character, TEST_SAVE), OK, "saved during a trial")
	var restored := SaveSystem.load_from(TEST_SAVE, db).character
	check_eq(restored.classes.active_class_id, &"basic_adventurer", "loading returns to the state before the trial")
	check(not restored.classes.in_trial(), "no trial after load")
	check(restored.prologue.has_completed_trial(&"trial_warrior"), "completed trial kept")
	check(not restored.prologue.has_completed_trial(&"trial_arcanist"), "unfinished trial not counted")
	check_eq(restored.prologue.stage, PrologueState.Stage.IN_PROGRESS, "prologue in progress")


func test_trial_objectives_from_real_combat() -> void:
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	check_eq(PrologueService.begin_trial(character, &"trial_arcanist"), "", "arcanist trial")
	check_eq(bridge.class_runtime.pool.definition.id, &"mana", "trial class resource")
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(40, 0)
	add_child(dummy)
	await wait_physics(2)
	for i in 3:
		var f := frame()
		f.ability_slot = 0   # Arcane Bolt
		await tick(f)
		await tick(frame(), 30)
	check_near(character.prologue.trial_progress.get(0, 0.0), 3.0, 0.001, "three bolt hits counted")
	check(character.prologue.trial_progress.get(1, 0.0) >= 2.0, "marks counted")
	var pulse := frame()
	pulse.ability_slot = 1   # Mana Pulse detonates the marks
	await tick(pulse)
	await tick(frame(), 10)
	check(character.prologue.has_completed_trial(&"trial_arcanist"), "trial completed through real combat")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "back to the adventurer")
	check(bridge.class_runtime.pool == null, "trial mana gone (adventurer has no resource)")


func test_class_quest_unlocks_a_second_class() -> void:
	check(QuestService.start(character, &"unlock_warrior") != "", "quests need the finished prologue")
	for trial_id: StringName in [&"trial_warrior", &"trial_arcanist", &"trial_shadowrunner"]:
		_complete(trial_id)
	PrologueService.choose_starting_class(character, &"shadowrunner")
	check(QuestService.start(character, &"unlock_guardian") != "", "guardian quest only prepared")
	check(QuestService.start(character, &"unlock_shadowrunner") != "", "chosen class needs no quest")
	check_eq(QuestService.start(character, &"unlock_warrior"), "", "warrior quest taken")
	check(QuestService.turn_in(character, &"unlock_warrior", true).contains("not complete"), "objectives first")
	for i in 8:
		PrologueService.record(character, K.KILLS, &"", 1.0)
	check(QuestService.turn_in(character, &"unlock_warrior", true).contains("Missing"), "deliveries checked")
	character.inventory.add_item(&"hollow_essence", 3)
	character.inventory.add_item(&"gold_coin", 25)
	check(QuestService.turn_in(character, &"unlock_warrior", false) != "", "only at a class station")
	check_eq(SaveSystem.save_to(character, TEST_SAVE), OK, "saved mid-quest")
	var restored := SaveSystem.load_from(TEST_SAVE, db).character
	check_eq(restored.quests.progress(&"unlock_warrior", 0), 8.0, "quest progress survives save/load")
	check_eq(QuestService.turn_in(restored, &"unlock_warrior", true), "", "turned in")
	check(restored.classes.is_unlocked(&"warrior"), "warrior unlocked by its quest")
	check(not restored.classes.is_unlocked(&"arcanist"), "arcanist still locked")
	check_eq(restored.inventory.count(&"gold_coin"), 5, "20 gold delivered")
	check_eq(restored.inventory.count(&"hollow_essence"), 0, "essence delivered")
	check(QuestService.start(restored, &"unlock_warrior") != "", "not repeatable")


func test_migration_v3_to_v4() -> void:
	var old := {"classes": {"active": "warrior", "progress": {"basic_adventurer": {"unlocked": true, "level": 3, "xp": 0},
		"warrior": {"unlocked": true, "level": 5, "xp": 10}}}, "inventory": [{"id": "itm_1", "def": "iron_sword", "qty": 1, "ilvl": 1, "quality": 0}]}
	var errors: PackedStringArray = []
	var upgraded: Dictionary = SaveMigrations.migrate(old.duplicate(true), 3, errors)
	check(errors.is_empty(), "migrates")
	check_eq(upgraded.prologue.stage, "completed", "old warrior unlock counts as the prologue choice")
	check_eq(upgraded.prologue.chosen_class, "warrior", "chosen class kept")
	check_eq(upgraded.class_builds, {}, "empty builds")
	check_eq(upgraded.inventory, old.inventory, "items untouched")
	var warnings: PackedStringArray = []
	var restored := Character.from_dict(upgraded, db, warnings)
	check(restored.classes.is_unlocked(&"warrior"), "nothing unlocked is locked again")
	check_eq(restored.classes.get_level(&"warrior"), 5, "level kept")
	check_eq(TalentService.points_total(restored, &"warrior"), 0, "points from level (none before 10)")
	var fresh: Dictionary = SaveMigrations.migrate({"classes": {"active": "basic_adventurer", "progress": {}}}, 3, errors)
	check_eq(fresh.prologue.stage, "not_started", "untouched characters start the prologue")
	check_eq(SaveSystem.VERSION, 4, "current save version")


func test_prologue_map_flow() -> void:
	var session := SessionState.find(get_tree())
	var previous_character := session.character
	var previous_path := session.save_path
	session.save_path = TEST_SAVE
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/prologue.tscn")
	var map: GameMap = null
	for i in 300:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.map_id == &"prologue" and map.is_node_ready() and not session.is_traveling():
			break
	if check(map != null and map.map_id == &"prologue", "prologue map loaded"):
		var station := map.get_node("TrialShadowrunner") as TrialStation
		map.player.feed_input(InputFrame.new())
		map.player.global_position = station.global_position
		for i in 4:
			await get_tree().physics_frame
		check(station.player_inside, "player at the shadowrunner pedestal")
		station.interact(map.hud)
		check_eq(character.classes.active_class_id, &"shadowrunner", "trial started from the pedestal")
		await get_tree().physics_frame
		check_eq(map.get_node("Enemies").get_child_count(), 3, "trial enemies spawned")
		check(map.hud.objectives.visible, "objectives shown")
		station.interact(map.hud)
		check(not character.classes.in_trial(), "G again leaves the trial")
		station.interact(map.hud)
		check(character.classes.in_trial(), "re-entered")
		session.travel(&"home_base", &"from_prologue", false)
		for i in 300:
			await get_tree().process_frame
			var home := get_tree().current_scene as GameMap
			if home != null and home.map_id == &"home_base" and home.is_node_ready() and not session.is_traveling():
				break
		check(not character.classes.in_trial(), "leaving the prologue map aborts the trial")
		check_eq(character.classes.active_class_id, &"basic_adventurer", "adventurer again")
	get_tree().unload_current_scene()
	await get_tree().process_frame
	session.save_path = previous_path
	session.set_character(previous_character)
