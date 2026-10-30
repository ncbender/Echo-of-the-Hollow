extends TestCase
## Skills & Talents UX 2.0 Phase 5 (docs/SKILLS_TALENTS_UX_2_0.md): the Quests page - the class unlock quests as a
## compact list (name, status, short progress) and the chosen quest's details (objectives with progress,
## deliveries against the bag, requirements, reward, the one allowed action with its reason). Choosing never
## takes, advances or turns in a quest; actions go through the unchanged QuestService at a class station.

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.classes.set_active(&"warrior")
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	panel = map.hud.class_panel


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous_character)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _prologue_done() -> void:
	character.prologue.chosen_class = &"warrior"
	character.prologue.stage = PrologueState.Stage.COMPLETED


func _open_at_station() -> void:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	map.hud.open_class_panel(station)
	panel.show_page("Quests")
	await _frames(4)


func _entry(quest_id: StringName) -> Button:
	return panel.find_child("Quest_%s" % quest_id, true, false) as Button


func _status(quest_id: StringName) -> String:
	return (_entry(quest_id).find_child("QuestStatus", true, false) as Label).text


func _select(quest_id: StringName) -> void:
	_entry(quest_id).pressed.emit()
	await _frames(2)


func _detail() -> Control:
	return panel.find_child("QuestDetail", true, false) as Control


func _detail_text() -> String:
	var texts: PackedStringArray = []
	for label: Label in _detail().find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func _action(button_name: String) -> Button:
	return _detail().find_child(button_name, true, false) as Button


## A, B, J: before the prologue nothing can be taken - every quest is readable, none starts by choosing it.
func test_a_b_j_nothing_available_locked_quests_readable() -> void:
	await _open_at_station()
	var ids := ["unlock_arcanist", "unlock_shadowrunner", "unlock_warrior"]
	check_eq(panel.find_child("QuestList", true, false).get_child_count(), 3, "the three playable class quests")
	check(panel.find_child("Quest_unlock_guardian", true, false) == null and panel.find_child("Quest_unlock_soulbinder", true, false) == null, "prepared quests stay hidden")
	var log_before := character.quests.to_dict()
	for quest_id: String in ids:
		await _select(StringName(quest_id))
		check(_entry(StringName(quest_id)).button_pressed, "%s selectable" % quest_id)
	check(_status(&"unlock_arcanist").begins_with("Locked") and _status(&"unlock_arcanist").contains("Complete the prologue first"), "B: locked with the reason: %s" % _status(&"unlock_arcanist"))
	check(_status(&"unlock_warrior").begins_with("Class unlocked"), "own class: Class unlocked")
	await _select(&"unlock_arcanist")
	var start := _action("Start")
	check(start != null and start.disabled and _detail_text().contains("Complete the prologue first."), "A: Take quest locked with the reason")
	check(_detail_text().contains("Not met  ·  Prologue completed"), "requirement shown as not met")
	await _select(&"unlock_warrior")
	check(_action("Start") == null and _detail_text().contains("already unlocked"), "nothing to do for an unlocked class")
	check_eq(character.quests.to_dict(), log_before, "J: choosing changed no quest")


## C, K, D, E, F, G: take a quest through the button, partial progress, ready to turn in, turn in, completed.
func test_c_k_d_e_f_g_take_progress_turn_in() -> void:
	_prologue_done()
	await _open_at_station()
	await _select(&"unlock_arcanist")
	check(_status(&"unlock_arcanist").begins_with("Available"), "C: available")
	check_eq(character.quests.state(&"unlock_arcanist"), "", "J: choosing does not take it")
	check(not _action("Start").disabled and _action("Start").tooltip_text.contains("Takes the quest"), "C: Take quest with what it does (tooltip)")
	check(_detail_text().contains("Unlocks the Arcanist class for good") and _detail_text().contains("uses up the deliveries"), "reward and the delivery use shown")
	check(_detail_text().contains("All met: Prologue completed"), "met requirements in one compact line")
	check(not (character.database.quests[&"unlock_arcanist"] as ClassQuestDefinition).description.contains("8"), "the context text repeats no counts")
	_action("Start").pressed.emit()
	await _frames(2)
	check_eq(character.quests.state(&"unlock_arcanist"), "active", "K: taken through QuestService")
	check(_status(&"unlock_arcanist").begins_with("Active") and _status(&"unlock_arcanist").contains("0/8"), "D: active, 0/8")
	QuestService.record(character, TrialObjective.Kind.KILLS, &"grunt", 5.0)
	panel.show_page("Quests")
	await _frames(3)
	check(_status(&"unlock_arcanist").contains("5/8") and _status(&"unlock_arcanist").contains("0/2 items"), "E: partial progress in the list: %s" % _status(&"unlock_arcanist"))
	check(_detail_text().contains("Defeat hollow creatures | 5/8"), "E: objective progress in the details: %s" % _detail_text())
	var bar := _detail().find_children("*", "ProgressBar", true, false)[0] as ProgressBar
	check_eq([bar.value, bar.max_value], [5.0, 8.0], "E: progress bar")
	check(_action("TurnIn").disabled and _detail_text().contains("Objectives not complete yet."), "E: turn in locked with the reason")
	QuestService.record(character, TrialObjective.Kind.KILLS, &"grunt", 3.0)
	character.inventory.add_item(&"hollow_essence", 4)
	character.inventory.add_item(&"gold_coin", 25)
	panel.show_page("Quests")
	await _frames(3)
	check(_status(&"unlock_arcanist").begins_with("Ready to Turn In"), "F: ready: %s" % _status(&"unlock_arcanist"))
	check(_detail_text().contains("Hollow Essence | 4/3  done"), "F: deliveries against the bag (have/need)")
	check(not _action("TurnIn").disabled, "F: Turn in enabled")
	_action("TurnIn").pressed.emit()
	await _frames(2)
	check_eq(character.quests.state(&"unlock_arcanist"), "completed", "G: completed through QuestService")
	check(character.classes.is_unlocked(&"arcanist"), "G: class unlocked")
	check_eq([character.inventory.count(&"hollow_essence"), character.inventory.count(&"gold_coin")], [1, 5], "exactly the deliveries consumed")
	check(_status(&"unlock_arcanist").begins_with("Completed"), "G: completed in the list")
	check(_action("TurnIn") == null and _action("Start") == null and _detail_text().contains("Completed"), "G: no action any more")


## H, I, L: the class switch shows the same character-wide quests with their real states; away from the station
## everything is readable and nothing can be done; the progress survives save/load (v15).
func test_h_i_l_class_switch_away_and_save_load() -> void:
	_prologue_done()
	check_eq(QuestService.start(character, &"unlock_shadowrunner"), "", "a quest taken")
	QuestService.record(character, TrialObjective.Kind.KILLS, &"grunt", 2.0)
	character.classes.unlock(&"arcanist")   # e.g. through its quest earlier
	check_eq(character.switch_class(&"arcanist", true), "", "H: class switch")
	map.hud.toggle_talents()   # I: away from the station
	await _frames(3)
	panel.show_page("Quests")
	await _frames(3)
	check(_status(&"unlock_shadowrunner").begins_with("Active") and _status(&"unlock_shadowrunner").contains("2/8"), "H: the active quest with its progress")
	check(_status(&"unlock_arcanist").begins_with("Class unlocked") and _status(&"unlock_warrior").begins_with("Class unlocked"), "H: the unlocked classes")
	await _select(&"unlock_shadowrunner")
	check(_action("TurnIn").disabled, "I: Turn in locked away from the station")
	check(_detail_text().contains("Turn in class quests at a class station."), "I: the reason")
	var log := character.quests.to_dict()
	var path := "user://test_saves/quest_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), 15, "L: save v15")
	file.close()
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.ok() and loaded.character.quests.to_dict() == log, "L: quest progress identical after load")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


## M + keyboard: the same frame as the other pages (100 / 150 %), the window never scrolls, list and details side
## by side; focus + Enter on an entry only selects.
func test_m_geometry_and_keyboard() -> void:
	_prologue_done()
	await _open_at_station()
	for scale: float in [1.0, 1.5]:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		panel.show_page("Presets")
		await _frames(3)
		var frame := panel.get_global_rect()
		panel.show_page("Quests")
		await _frames(4)
		check(panel.get_global_rect().is_equal_approx(frame), "%d %%: same frame" % roundi(scale * 100))
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%d %%: the window never scrolls" % roundi(scale * 100))
		var list := (panel.find_child("QuestListScroll", true, false) as Control).get_global_rect()
		var detail := _detail().get_global_rect()
		check(frame.encloses(list) and frame.encloses(detail) and not list.intersects(detail), "%d %%: list and details inside, side by side" % roundi(scale * 100))
		check(_detail().find_child("QuestDetailScroll", true, false) is ScrollContainer, "details scroll inside")
	var log := character.quests.to_dict()
	_entry(&"unlock_shadowrunner").grab_focus()
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter)
	await _frames(3)
	check_eq(panel.selected_quest(), &"unlock_shadowrunner", "Enter selects")
	check_eq(character.quests.to_dict(), log, "Enter never takes the quest")
