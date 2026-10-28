extends SceneTree
## Chapter 1 "The Roots Remember" M4 visual check in a real window (NOT headless):
##   godot --path . --fixed-fps 60 -s res://tests/playtest/roots_m4_visual_check.gd
## 1920x1080 at 100 % and 1280x720 at 150 % UI scale in Haven: Edrin before step 5 (Quest Rewards, "?"),
## at step 5 ("!", the report dialogue line by line), after the report (completed, "?" for the 60 gold),
## the journal (The First Signs completed, Beyond the Roots current), Edrin's Quest Rewards window. Fresh
## test characters, saves only under user://test_saves/. Screenshots and log: tests/output/roots_m4/.

const OUTPUT := "res://tests/output/roots_m4"
const QUEST := &"the_first_signs"
const PASSES: Array = [[Vector2i(1920, 1080), 1.0], [Vector2i(1280, 720), 1.5]]
const EVENTS: Array[StringName] = [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone",
	&"enter:wardens_rest", &"interact:wardens_rest_watchstone"]

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0
var _tag := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/roots_m4_visual/slot_1.save.json"
	for pass_spec: Array in PASSES:
		await _pass(pass_spec[0], pass_spec[1])
	session.settings.reset_to_defaults()
	_log("RESULT: %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("roots_m4_visual_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		for path in SaveSlots.all_paths(session.save_path):
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	quit(0 if failures == 0 else 1)


func _pass(resolution: Vector2i, scale: float) -> void:
	_tag = "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	session.settings.set_ui_scale(scale)
	session.settings.set_reduce_motion(true)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	# 1. before step 5: Quest Rewards, "?"
	var early := _character_at(4)
	await _open_haven(early)
	var edrin := map.get_node("Edrin") as StoryNpc
	_stand_at(edrin)
	await _frames(10)
	_check(edrin.marker() == "?", "step 4: only the pending reward is marked")
	await _shot("01_edrin_step4")
	edrin.interact(map.hud)
	await _frames(10)
	_check(map.hud.quest_reward_panel.visible and not map.hud.dialogue_panel.visible, "step 4: Quest Rewards opens")
	await _shot("02_step4_quest_rewards")
	map.hud.close_windows()
	# 2. step 5: "!", the report
	var character := _character_at(5)
	await _open_haven(character)
	edrin = map.get_node("Edrin") as StoryNpc
	_stand_at(edrin)
	await _frames(10)
	_check(edrin.marker() == "!", "step 5: the story marker")
	await _shot("03_edrin_step5_marker")
	edrin.interact(map.hud)
	await _frames(10)
	_check(map.hud.dialogue_panel.visible, "step 5: the report opens")
	var shots := {0: "04a_report_line1", 3: "04b_report_line4", 5: "04c_report_line6"}
	for index in 6:
		if shots.has(index):
			await _frames(5)
			await _shot(shots[index])
		map.hud.dialogue_panel.advance()
		await _frames(2)
	await _frames(10)
	_check(StoryService.is_completed(character, QUEST) and StoryService.at_step(character, &"beyond_the_roots", 0), "completed, successor active")
	_check(edrin.marker() == "?", "after the report: the 60 gold remain")
	await _shot("05_after_report_tracker")
	# 3. journal
	map.hud.toggle_journal()
	await _frames(10)
	_check(map.hud.journal_panel.visible, "journal open")
	await _shot("06_journal")
	var card := map.hud.journal_panel.find_child("Story_the_first_signs", true, false) as Control
	_check(card != null and card.find_parent("*") != null and map.hud.journal_panel.find_children("*", "Label", true, false).any(
		func(label: Label) -> bool: return label.text == "Completed" and card.is_ancestor_of(label)), "journal: The First Signs listed as Completed")
	var scroll := map.hud.journal_panel._scroll
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(10)
	await _shot("06b_journal_completed")
	map.hud.toggle_journal()
	await _frames(5)
	# 4. Edrin's service still there
	edrin.interact(map.hud)
	await _frames(10)
	_check(map.hud.quest_reward_panel.visible and not map.hud.dialogue_panel.visible, "after the report: Quest Rewards opens")
	await _shot("07_after_report_quest_rewards")
	map.hud.close_windows()


func _character_at(step: int) -> Character:
	var character := CharacterFactory.create_new(session.database)
	for quest_id: StringName in [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees", &"the_whispering_stone", &"the_first_binding"]:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for quest_step in quest.steps:
			if quest_step.completion_flag != &"":
				character.world.set_flag(quest_step.completion_flag)
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	character.world.set_flag(QuestRewardService.claimed_flag(&"the_broken_cart"))
	character.world.set_flag(&"dialogue.edrin_threat")
	StoryService.start(character, QUEST)
	if step >= 5:
		character.world.set_flag(&"defeated.wardens_rest_rootbound_sentinel")
	for event: StringName in EVENTS.slice(0, step):
		StoryService.notify(character, event)
	return character


func _open_haven(character: Character) -> void:
	character.world.map_id = &"home_base"
	character.world.spawn_id = &"default"
	session.set_character(character)
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(10)


func _stand_at(npc: Node2D) -> void:
	map.player.feed_input(InputFrame.new())
	map.player.global_position = npc.global_position + Vector2(0, 18)
	map.player.reset_physics_interpolation()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s_%s.png" % [_tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
	_log("%s %s %s" % ["PASS" if ok else "FAIL", _tag, text])


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)
