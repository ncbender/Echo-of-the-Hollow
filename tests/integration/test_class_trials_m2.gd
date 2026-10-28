extends TestCase
## Class Trials 2.0 M2 (docs/CLASS_TRIALS_2_0_M2.md): the Heart of the Stone as
## the trial hub - three trial paths to their own placeholder grounds (real scene
## changes through SessionState.travel), the return to the altar, saves on the
## grounds resolving to the altar, and that travelling alone never chooses a
## class, completes a trial, starts a trial or hands out anything. The old
## pedestals keep working. Saves only under user://test_saves/.

const DIR := "user://test_saves/class_trials_m2"
const PROFILE := DIR + "/slot_1.save.json"
const SAVE := DIR + "/synthetic.save.json"
const GROUNDS := {&"warrior": &"broken_bastion", &"arcanist": &"shattered_sanctum", &"shadowrunner": &"veiled_passage"}
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro"]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	session.set_character(character)
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE) + [SAVE]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			return current
	fail("%s not reached" % map_id)
	return null


func _open(map_id: StringName, spawn_id: StringName) -> GameMap:
	character.world.map_id = map_id
	session.travel(map_id, spawn_id, false)
	return await _await_map(map_id)


func _open_altar() -> ClassChoicePanel:
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	var panel := map.hud.class_choice_panel
	check(panel.visible, "the stone answers")
	return panel


func _walk(trial_id: StringName) -> void:
	PrologueService.begin_trial(character, trial_id)
	for objective in (db.trials[trial_id] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)


## Everything travelling must never touch.
func _snapshot() -> Dictionary:
	var data := character.to_dict()
	return {"prologue": data.prologue, "classes": data.classes, "class_builds": data.class_builds, "loadouts": data.loadouts,
		"inventory": data.inventory, "stash": data.stash, "mastery": data.mastery, "armor_mastery": data.armor_mastery,
		"consumables": data.consumables, "quests": data.quests}


func test_trial_grounds_data() -> void:
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var stone: GameMap = load((db.maps[&"whispering_stone"] as MapDefinition).scene_path).instantiate()
	check(stone.find_spawn(&"heart") != null, "the altar has the return spawn 'heart'")
	stone.free()
	for class_id: StringName in GROUNDS:
		var trial := PrologueService.trial_for_class(db, class_id)
		check_eq(trial.map_id, GROUNDS[class_id], "%s leads to %s" % [trial.id, GROUNDS[class_id]])
		var map_def: MapDefinition = db.maps.get(trial.map_id)
		if not check(map_def != null, "%s registered" % trial.map_id):
			continue
		check(not map_def.show_on_map, "%s is not drawn on the world map" % map_def.id)
		check(map_def.resume_map_id == &"whispering_stone" and map_def.resume_spawn_id == &"heart", "%s resumes at the altar" % map_def.id)
		var scene: GameMap = load(map_def.scene_path).instantiate()
		check_eq(scene.map_id, map_def.id, "scene declares %s" % map_def.id)
		check(scene.find_spawn(trial.entry_spawn_id) != null, "%s entry spawn" % map_def.id)
		var exits: Array = scene.find_children("*", "MapTransition", true, false)
		check(exits.size() == 1 and exits[0].target_map_id == &"whispering_stone" and exits[0].target_spawn_id == &"heart",
			"%s: one way back to the Heart of the Stone" % map_def.id)
		check(scene.get_node_or_null("TrainingArea") != null and scene.get_node_or_null("TrialArea") != null, "%s: room for M3" % map_def.id)
		for type: String in ["Enemy", "Encounter", "ResourceNode", "Readable", "ItemPickup", "TrialStation", "Waystone", "Checkpoint"]:
			check(scene.find_children("*", type, true, false).is_empty(), "%s: no %s (no enemies, loot or progress)" % [map_def.id, type])
		scene.free()


func test_each_path_travels_and_returns_without_progress() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	var before := _snapshot()
	var mastery_before: Dictionary = character.mastery.to_dict()
	for class_id: StringName in GROUNDS:
		var panel := await _open_altar()
		var visit := panel.find_child("Visit_%s" % class_id, true, false) as Button
		if not check(visit != null and not visit.disabled, "%s trial path offered" % class_id):
			return
		check(visit.text != (panel.find_child("Choose_%s" % class_id, true, false) as Button).text, "path differs from the choice")
		check_eq(panel.visit(class_id), "", "%s: travel accepted" % class_id)
		check(panel.visit(class_id) != "", "%s: a second request is ignored (one transition)" % class_id)
		var grounds := await _await_map(GROUNDS[class_id])
		if grounds == null:
			return
		check_eq(grounds.player.global_position, grounds.find_spawn(&"default").global_position, "%s: entered at the entry spawn" % class_id)
		check(not character.classes.in_trial(), "%s: travelling starts no trial" % class_id)
		check(character.world.map_id == &"whispering_stone" and character.world.spawn_id == &"heart", "%s: saved location is the altar" % class_id)
		check_eq(character.prologue.chosen_class, &"", "%s: no class chosen" % class_id)
		var exit := grounds.get_node("ToHeart") as MapTransition
		exit._on_body_entered(grounds.player)
		exit._on_body_entered(grounds.player)   # a re-entering body never asks twice
		var stone := await _await_map(&"whispering_stone")
		if stone == null:
			return
		check_eq(stone.player.global_position, stone.find_spawn(&"heart").global_position, "%s: back at the Heart of the Stone" % class_id)
	check_eq(_snapshot(), before, "travelling changed nothing (prologue, classes, builds, loadouts, items, xp, quests)")
	check_eq(character.mastery.to_dict(), mastery_before, "no mastery XP")
	check(StoryService.at_step(character, &"the_whispering_stone", 1), "story still waits for an echo")


func test_save_on_trial_grounds_loads_at_the_altar() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	session.travel(&"veiled_passage", &"default", false)
	if await _await_map(&"veiled_passage") == null:
		return
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved on the grounds (test path)")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok(), "loads")
	check(loaded.character.world.map_id == &"whispering_stone" and loaded.character.world.spawn_id == &"heart", "the save resumes at the altar")
	check(not loaded.character.classes.in_trial(), "no orphaned trial")
	# an older/synthetic save that names the grounds directly
	var data := character.to_dict()
	data.world["map_id"] = "broken_bastion"
	data.world["spawn_id"] = "default"
	var warnings: PackedStringArray = []
	var synthetic := Character.from_dict(JSON.parse_string(JSON.stringify(data)), db, warnings)
	check(synthetic.world.map_id == &"whispering_stone" and synthetic.world.spawn_id == &"heart", "synthetic grounds save resolves to the altar")
	check_eq(synthetic.classes.active_class_id, &"basic_adventurer", "no trial class after loading")
	session.set_character(synthetic)
	character = synthetic
	session.travel(synthetic.world.map_id, synthetic.world.spawn_id, false)
	var stone := await _await_map(&"whispering_stone")
	if stone != null:
		check_eq(stone.player.global_position, stone.find_spawn(&"heart").global_position, "loaded at the Heart of the Stone")


func test_paths_closed_during_a_pedestal_trial_and_after_the_choice() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "old pedestal trial")
	for class_id: StringName in GROUNDS:
		check(PrologueService.can_visit_grounds(character, PrologueService.trial_for_class(db, class_id).id) != "", "%s path closed during a trial" % class_id)
	var panel := await _open_altar()
	check((panel.find_child("Visit_arcanist", true, false) as Button).disabled, "button disabled during a trial")
	check(panel.visit(&"arcanist") != "", "panel refuses during a trial")
	check(map.map_id == &"whispering_stone" and not session.is_traveling(), "no transition")
	# a running trial never follows the player onto the grounds (not a trial map)
	session.travel(&"broken_bastion", &"default", false)
	if await _await_map(&"broken_bastion") == null:
		return
	check(not character.classes.in_trial(), "trial ended on the grounds (nothing permanent)")
	check(character.prologue.completed_trials.is_empty(), "left trial does not count")
	session.travel(&"whispering_stone", &"heart", false)
	if await _await_map(&"whispering_stone") == null:
		return
	_walk(&"trial_warrior")
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "warrior chosen at the altar")
	panel = await _open_altar()
	check(panel.find_children("Visit_*", "Button", true, false).is_empty(), "no trial paths after the choice")
	check(PrologueService.can_visit_grounds(character, &"trial_arcanist") != "", "service refuses too")


func test_old_pedestals_and_m1_rules_unchanged() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	for node_name: String in ["TrialWarrior", "TrialArcanist", "TrialShadowrunner"]:
		check(map.get_node_or_null(node_name) is TrialStation, "%s pedestal still there" % node_name)
	check(&"whispering_stone" in db.rules.trial_map_ids, "pedestal trials still run at the stone")
	for class_id: StringName in GROUNDS:
		check(not GROUNDS[class_id] in db.rules.trial_map_ids, "%s grounds are not a trial map yet (M3)" % class_id)
	_walk(&"trial_arcanist")
	check_eq(PrologueService.can_choose(character, &"arcanist"), "", "own trial opens arcanist")
	check(PrologueService.can_choose(character, &"warrior") != "", "warrior stays locked")
	check(StoryService.at_step(character, &"the_whispering_stone", 2), "one echo moves the story (M1)")
	var reloaded := Character.from_dict(JSON.parse_string(JSON.stringify(character.to_dict())), db, PackedStringArray())
	check(StoryService.at_step(reloaded, &"the_whispering_stone", 2) and StoryService.resettle(reloaded).is_empty(), "no soft-lock, no double settle")
