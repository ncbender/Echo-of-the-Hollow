extends TestCase
## Whispering Stone & class choice: the three echoes (data; since Class Trials
## 2.0 M3 they begin at the Heart of the Stone on their own grounds - no pedestals,
## a trial still running ends at the stone), the choice only
## after its own echo (Class Trials 2.0 M1) with confirmation and a milestone save (success shown only
## after the write, failure reported), the waystones (exactly four planned, two
## working, activation line, free travel, never in combat), the return to Haven
## and the main quest stub. Guardian and Soulbinder never appear.

const DIR := "user://test_saves/shrine"
const PROFILE := DIR + "/slot_1.save.json"

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
	for event: StringName in [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
			&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
			&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro"]:
		StoryService.notify(character, event)


func after_each() -> void:
	SaveSystem.fail_next_write = false
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _open(map_id: StringName, spawn_id: StringName) -> GameMap:
	character.world.map_id = map_id
	session.travel(map_id, spawn_id, false)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			return current
	fail("%s not loaded" % map_id)
	return null


func _complete_all_trials() -> void:
	for trial_id: StringName in [&"trial_warrior", &"trial_arcanist", &"trial_shadowrunner"]:
		PrologueService.begin_trial(character, trial_id)
		for objective in (db.trials[trial_id] as TrialDefinition).objectives:
			PrologueService.record(character, objective.kind, objective.target_id, objective.amount)


func _talk(npc: StoryNpc) -> PackedStringArray:
	var lines: PackedStringArray = []
	npc.interact(map.hud)
	while map.hud.dialogue_panel.visible and lines.size() < 20:
		lines.append(map.hud.dialogue_panel.current_text())
		map.hud.dialogue_panel.advance()
	return lines


func test_echo_and_waystone_data() -> void:
	var expected := {
		&"trial_warrior": ["Echo of the Warrior", "Strength is not the blade. It is the will to stand.",
			"A relentless fighter who builds Rage through aggression and overwhelms enemies with powerful strikes."],
		&"trial_arcanist": ["Echo of the Arcanist", "A single spark fades. A pattern endures.",
			"A wielder of arcane power who combines spells, builds magical marks, and unleashes devastating detonations."],
		&"trial_shadowrunner": ["Echo of the Shadowrunner", "A moment is enough, if you know where to strike.",
			"A swift and precise fighter who exploits weak points and strikes when the moment is right."],
	}
	for trial_id: StringName in expected:
		var trial: TrialDefinition = db.trials[trial_id]
		check_eq([trial.display_name, trial.description, trial.choice_text], expected[trial_id], "texts of %s" % trial_id)
		check_eq(trial.enemy_configs.size(), 3, "%s keeps its three variants (developer pedestals)" % trial_id)
	var warrior_kinds: Array = (db.trials[&"trial_warrior"] as TrialDefinition).objectives.map(func(o: TrialObjective) -> int: return o.kind)
	check(TrialObjective.Kind.POISE_BREAKS in warrior_kinds and TrialObjective.Kind.RESOURCE_AT_LEAST in warrior_kinds, "warrior: rage + poise break")
	var shadow_targets: Array = (db.trials[&"trial_shadowrunner"] as TrialDefinition).objectives.map(func(o: TrialObjective) -> StringName: return o.target_id)
	check(&"focus" in shadow_targets and &"shadowstep" in shadow_targets and &"weak_point" in shadow_targets, "shadowrunner: focus, Shadowstep, weak point, execution")
	var ids: Array = WaystoneService.all(db).map(func(w: WaystoneDefinition) -> StringName: return w.id)
	check_eq(ids, [&"haven", &"whispering_stone", &"chapel_waystone", &"wardens_rest"], "exactly the four planned waystones")
	var names: Array = WaystoneService.all(db).map(func(w: WaystoneDefinition) -> String: return w.display_name)
	check_eq(names, ["Haven", "The Whispering Stone", "Chapel Waystone", "Warden's Rest"], "waystone names")
	check_eq(WaystoneService.all(db).filter(func(w: WaystoneDefinition) -> bool: return w.available).size(), 2, "only Haven and the Whispering Stone work")
	check_eq(character.world.waystones, [&"haven"] as Array[StringName], "Haven waystone active from the start")


func test_trials_begin_only_at_the_heart_of_the_stone() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	check(StoryService.at_step(character, &"the_whispering_stone", 1), "the stone reached")
	check(map.find_children("*", "TrialStation", true, false).is_empty(), "no pedestals at the stone any more (Class Trials 2.0 M3)")
	check(not &"whispering_stone" in db.rules.trial_map_ids, "no trial runs at the stone itself")
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	var panel := map.hud.class_choice_panel
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		var begin := panel.find_child("Begin_%s" % class_id, true, false) as Button
		check(begin != null and not begin.disabled, "%s trial begins at the Heart of the Stone" % class_id)
	# a trial still running when the player is back at the stone ends without passing
	PrologueService.begin_trial(character, &"trial_warrior")
	session.travel(&"whispering_stone", &"heart", false)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current != map and current.is_node_ready() and not session.is_traveling():
			break
	check(not character.classes.in_trial(), "back at the stone: the trial ended")
	check(not character.prologue.has_completed_trial(&"trial_warrior"), "and did not pass")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "Basic Adventurer again")


func test_choice_only_after_its_own_echo_and_success_after_save() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	var panel := map.hud.class_choice_panel
	check(panel.visible, "the stone answers")
	check_eq(panel.choose(&"arcanist"), "Walk the echo of this path first.", "not before its own echo")
	var cards: Array = panel.find_children("Choose_*", "Button", true, false).map(func(b: Button) -> String: return b.name)
	check_eq(cards, ["Choose_warrior", "Choose_arcanist", "Choose_shadowrunner"], "exactly three paths (no Guardian, no Soulbinder)")
	_complete_all_trials()
	stone.interact(map.hud)
	check(_texts(panel).has(ClassChoicePanel.INTRO), "intro text")
	check_eq(panel.choose(&"arcanist"), "confirm", "first click asks for confirmation")
	check(not character.classes.is_unlocked(&"arcanist"), "nothing chosen yet")
	check_eq(panel.choose(&"arcanist"), "", "confirmed")
	check_eq(panel.save_state, "saving", "success waits for the save")
	check(not panel.status_text().contains("taken root"), "no success text before the save")
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq(panel.save_state, "saved", "milestone save written")
	check(panel.status_text().begins_with("The path of the Arcanist has taken root within you."), "success after the save: %s" % panel.status_text())
	check_eq(character.classes.active_class_id, &"arcanist", "Arcanist active")
	check(not character.classes.is_unlocked(&"warrior") and not character.classes.is_unlocked(&"shadowrunner"), "the others stay locked")
	check(not character.classes.in_trial() and character.prologue.trial_progress.is_empty(), "no trial state left")
	var saved := SaveSystem.load_from(SaveSlots.latest(PROFILE).path, db)
	check(saved.ok() and saved.character.classes.active_class_id == &"arcanist", "the save holds the choice")
	check(StoryService.at_step(character, &"the_whispering_stone", 3), "on to the waystone")


func test_failed_save_after_the_choice_is_reported() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	_complete_all_trials()
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	var panel := map.hud.class_choice_panel
	panel.choose(&"warrior")
	SaveSystem.fail_next_write = true
	panel.choose(&"warrior")
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq(panel.save_state, "save_failed", "failure noticed")
	check(panel.status_text().contains("could not be saved"), "player is told: %s" % panel.status_text())
	check(session.saves._retry_left > 0.0, "the milestone save is retried")


func test_waystone_activation_and_travel() -> void:
	if await _open(&"whispering_stone", &"from_haven") == null:
		return
	var waystone := map.get_node("Waystone") as Waystone
	check(waystone.awaken(map.hud).begins_with("The waystone is cracked"), "silent before a path has taken root")
	_complete_all_trials()
	PrologueService.choose_starting_class(character, &"shadowrunner")
	check_eq(waystone.awaken(map.hud), "", "awakened")
	check_eq(map.hud.dialogue_panel.current_text(), "May the road remember those who return.", "activation line")
	map.hud.dialogue_panel.advance()
	check(&"whispering_stone" in character.world.waystones, "saved as active")
	check(StoryService.at_step(character, &"the_first_binding", 0), "the story moves on")
	map.player.global_position = waystone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemy := map.spawn_enemy(map.player.global_position + Vector2(60, 0))
	waystone.interact(map.hud)
	var panel := map.hud.waystone_panel
	check(panel.visible, "travel window")
	check(panel.find_child("Waystone_chapel_waystone", true, false) != null, "planned waystones listed")
	check(panel.find_child("Waystone_chapel_waystone", true, false).find_child("Travel", true, false) == null, "but not reachable")
	check_eq(panel.travel(&"haven"), "You cannot travel while enemies are near.", "never in combat")
	enemy.queue_free()
	await get_tree().process_frame
	check_eq(panel.travel(&"haven"), "", "free travel")
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == &"home_base" and not session.is_traveling():
			map = current
			break
	check(map.map_id == &"home_base", "arrived in Haven")
	check(map.player.global_position.distance_to(map.find_spawn(&"waystone").global_position) < 2.0, "at the Haven waystone")
	check(StoryService.at_step(character, &"the_first_binding", 1), "returned to Haven")


func test_return_to_haven_and_main_quest() -> void:
	StoryService.notify(character, &"enter:whispering_stone")
	_complete_all_trials()
	PrologueService.choose_starting_class(character, &"warrior")
	StoryService.notify(character, &"waystone:whispering_stone")
	if await _open(&"home_base", &"waystone") == null:
		return
	check_eq(_talk(map.get_node("Mara") as StoryNpc), PackedStringArray(["You left here carrying a sword. You came back carrying something else.",
		"I'm still figuring out what.", "Good. Be worried if you ever stop."]), "Mara on the return")
	var threat := _talk(map.get_node("Edrin") as StoryNpc)
	check(threat.size() == 3 and threat[1].contains("Hollowwood"), "Edrin hints at the threat")
	check(character.world.has_flag(&"prologue.completed"), "prologue complete")
	check(StoryService.at_step(character, &"the_first_signs", 0), "main quest: The First Signs")
	check(StoryService.tracker_lines(character)[0] == "The Roots Remember: The First Signs", "HUD tracker: %s" % StoryService.tracker_lines(character)[0])
	map.hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation)
	map.hud.class_panel.show_page("Classes")
	var texts := " ".join(_texts(map.hud.class_panel))
	check(not texts.contains("Guardian") and not texts.contains("Soulbinder"), "Guardian and Soulbinder do not appear")
	map.hud.class_panel.show_page("Quests")
	texts = " ".join(_texts(map.hud.class_panel))
	check(not texts.contains("Guardian") and not texts.contains("Soulbinder"), "no Guardian/Soulbinder quests either")


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text.strip_edges())
	for button: Button in node.find_children("*", "Button", true, false):
		texts.append(button.text)
	return texts
