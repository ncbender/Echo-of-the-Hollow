extends TestCase
## UI/UX redesign G: title screen, load window (manual and autosaves apart,
## damaged files marked), pause menu (overwrite and quit ask first), options
## pages and the read-only controls list. Only user://test_saves/.

const DIR := "user://test_saves/menus"
const PROFILE := DIR + "/slot_1.save.json"

var session: SessionState
var _previous: Character
var _previous_path: String


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	_clean()
	session.set_character(CharacterFactory.create_new(session.database))


func after_each() -> void:
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _title() -> TitleScreen:
	get_tree().change_scene_to_file(SessionState.TITLE_SCENE)
	for i in 10:
		await get_tree().process_frame
	return get_tree().current_scene as TitleScreen


func _texts(node: Node) -> String:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			texts.append(label.text)
	return " | ".join(texts)


func test_title_without_saves() -> void:
	var title := await _title()
	check((title.find_child("Continue", true, false) as Button).disabled, "Continue disabled without saves")
	check((title.find_child("LoadGame", true, false) as Button).disabled, "Load disabled without saves")
	check(_texts(title).contains("No saved journey yet."), "says so")


func test_title_with_saves_asks_before_a_new_game() -> void:
	SaveSystem.save_to(session.character, SaveSlots.manual_path(PROFILE, 2))
	SaveSystem.write_payload(session.character.to_dict(), SaveSlots.auto_path(PROFILE, 1), {"kind": "autosave"})
	var broken := FileAccess.open(SaveSlots.manual_path(PROFILE, 4), FileAccess.WRITE)
	broken.store_string("{ not a save")
	broken.close()
	var title := await _title()
	check(not (title.find_child("Continue", true, false) as Button).disabled, "Continue enabled")
	title.new_game()
	check(title.confirm_dialog.visible, "new game asks first when saves exist")
	title.confirm_dialog.cancel()
	check(get_tree().current_scene == title, "cancel stays on the title")
	title.open_load()
	await get_tree().process_frame
	var text := _texts(title.load_window)
	check(text.contains("MANUAL SAVES") and text.contains("AUTOSAVES"), "manual and automatic saves apart")
	check(text.contains("MANUAL") and text.contains("AUTOSAVE"), "badges on the cards")
	check(text.contains("Damaged - this save cannot be loaded."), "damaged slot marked")
	var damaged_row := title.load_window.find_child("Slot4", true, false)
	check((damaged_row.find_child("Action", true, false) as Button).disabled, "damaged save cannot be loaded")


func test_pause_menu_overwrite_and_quit_ask_first() -> void:
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	var map: GameMap
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	SaveSystem.save_to(session.character, SaveSlots.manual_path(PROFILE, 1))
	var before: int = SaveSystem.read_info(SaveSlots.manual_path(PROFILE, 1)).order
	map.hud.open_pause_menu()
	var menu := map.hud.pause_menu
	menu.show_page("save")
	await get_tree().process_frame
	var row := menu.find_child("Slot1", true, false)
	var action := row.find_child("Action", true, false) as Button
	check_eq(action.text, "Overwrite", "existing slot says Overwrite")
	action.pressed.emit()
	check(map.hud.confirm_dialog.visible, "overwrite asks first")
	map.hud.confirm_dialog.cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq(SaveSystem.read_info(SaveSlots.manual_path(PROFILE, 1)).order, before, "cancel keeps the old save")
	menu.show_page("main")
	(menu.find_child("QuittoTitle", true, false) as Button).pressed.emit()
	check(map.hud.confirm_dialog.visible, "quitting asks first")
	map.hud.confirm_dialog.cancel()
	check(get_tree().paused and menu.visible, "still paused in the menu")
	menu.hide()


func test_options_pages_and_controls() -> void:
	var panel := OptionsPanel.new()
	get_tree().root.add_child(panel)
	panel.open(session.settings)
	for id in OptionsPanel.PAGES:
		panel.show_page(id)
		check(panel.find_child("Page%s" % id, true, false).visible, "%s page" % id)
	check_eq(OptionsPanel.binding_text(&"attack_light"), "LMB", "mouse binding in words")
	check_eq(OptionsPanel.binding_text(&"dash"), "Space", "key binding in words")
	check(panel.find_child("ReduceMotion", true, false) != null and panel.find_child("PeriodicAutosave", true, false) != null, "options present")
	panel.queue_free()
