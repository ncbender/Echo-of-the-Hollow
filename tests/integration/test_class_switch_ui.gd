extends TestCase
## Skills & Talents UX 2.0 Phase 6 (docs/SKILLS_TALENTS_UX_2_0.md): the Classes page - compact cards (emblem, name,
## Active / Unlocked / Locked, level, tagline; prepared classes hidden) and the chosen class's details with the
## switch footer. A card only selects; "Switch to <class>" is enabled exactly when Character.class_switch_error
## (= the checks of switch_class) allows it and shows the reason otherwise. The switch itself is the unchanged,
## atomic Character.switch_class: loadouts kept, no item created, lost or duplicated.

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = CharacterFactory.create_new(session.database)
	for class_id: StringName in [&"warrior", &"arcanist"]:
		character.classes.unlock(class_id)
	character.classes.set_active(&"warrior")
	character.classes.add_xp(&"warrior", 2500)
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


func _open_at_station() -> void:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	map.hud.open_class_panel(station)
	panel.show_page("Classes")
	await _frames(4)


func _card(class_id: StringName) -> Button:
	return panel.find_child("Class_%s" % class_id, true, false) as Button


func _badge(class_id: StringName) -> String:
	return (_card(class_id).find_child("Status", true, false) as Label).text


func _details_text() -> String:
	var texts: PackedStringArray = []
	for label: Label in panel.find_child("ClassDetails", true, false).find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func _switch(class_id: StringName) -> Button:
	return panel.find_child("Activate_%s" % class_id, true, false) as Button


func _state() -> Dictionary:
	return {"active": character.classes.active_class_id, "equipment": character.equipment.to_dict(), "bag": character.inventory.to_array(),
		"stash": character.stash.to_array(), "builds": character.builds.get_build(&"warrior").to_dict()}


## The list: the three regular classes (the start class Basic Adventurer only while it is active - Phase 7), the
## three states, level and tagline; a click only selects - active and chosen are different cards and both say so.
func test_list_states_and_selection_without_switch() -> void:
	await _open_at_station()
	var names: PackedStringArray = []
	for card: Node in panel.find_child("ClassCards", true, false).get_children():
		names.append(String(card.name).trim_prefix("Class_"))
	check_eq(names, PackedStringArray(["warrior", "arcanist", "shadowrunner"]), "active, unlocked, locked - the three regular classes")
	check(_card(&"guardian") == null and _card(&"soulbinder") == null, "prepared classes stay hidden")
	check_eq([_badge(&"warrior"), _badge(&"arcanist"), _badge(&"shadowrunner")], ["ACTIVE", "UNLOCKED", "LOCKED"], "states on the cards")
	check(((_card(&"warrior").find_child("ClassLine", true, false) as Label).text).begins_with("Lv %d" % character.classes.get_level(&"warrior")), "level on the card")
	# Menu UX Polish 1.1: no cut-off tagline on the cards (it is the card's tooltip); a locked card has no level line
	check(_card(&"shadowrunner").find_child("ClassLine", true, false) == null and _card(&"shadowrunner").tooltip_text.contains(session.database.get_class_def(&"shadowrunner").tagline), "locked: no level, the tagline in the tooltip")
	check(_card(&"warrior").button_pressed and (panel.find_child("ClassState", true, false) as Label).text == "Active", "the active class chosen by default")
	check(not _details_text().contains("you are playing"), "one status, no extra sentence")
	check(_switch(&"warrior") == null, "no switch for the active class")
	var before := _state()
	_card(&"arcanist").pressed.emit()
	await _frames(2)
	check(_card(&"arcanist").button_pressed and not _card(&"warrior").button_pressed, "the chosen card is the arcanist")
	check_eq(_badge(&"warrior"), "ACTIVE", "the warrior card still says ACTIVE")
	check((panel.find_child("ClassState", true, false) as Label).text == "Unlocked", "chosen vs active: the details say Unlocked, the list says which is ACTIVE")
	check_eq(_state(), before, "choosing a card switched nothing")
	_card(&"shadowrunner").pressed.emit()
	await _frames(2)
	check(_details_text().contains("Path of Shadows") and _switch(&"shadowrunner") == null, "locked: its unlock, no switch")
	check(_details_text().contains("Focus (max 100)"), "locked classes stay readable (resource)")
	check_eq(_state(), before, "still nothing switched")


## Allowed switch through the button: atomic, loadouts kept, no item created or lost; the page follows.
func test_allowed_switch_keeps_loadouts_and_items() -> void:
	await _open_at_station()
	panel.select_class(&"arcanist")
	await _frames(2)
	var button := _switch(&"arcanist")
	check(button != null and not button.disabled and button.text == "Switch to Arcanist", "switch possible")
	check(button.tooltip_text.contains("Switching makes Arcanist's level, talents, skills and gear active"), "what happens, before the click (tooltip)")
	var equipment := character.equipment.to_dict()
	var bag := character.inventory.to_array()
	button.pressed.emit()
	await _frames(3)
	check_eq(character.classes.active_class_id, &"arcanist", "switched through the button")
	check_eq(character.equipment.to_dict(), equipment, "both loadouts kept")
	check_eq(character.inventory.to_array(), bag, "the same items")
	check(StashService.ownership_errors(character).is_empty(), "ownership consistent")
	check_eq(_badge(&"arcanist"), "ACTIVE", "the arcanist card is active now")
	check(_switch(&"warrior") != null or _card(&"warrior") != null, "the warrior can be chosen again")


## Blocked: away from the station, and a full bag that would not take the old gear back - reason shown before,
## button locked, and even a forced press changes nothing.
func test_blocked_switch_reasons_and_nothing_changes() -> void:
	map.hud.toggle_talents()   # away from the station
	await _frames(3)
	panel.show_page("Classes")
	panel.select_class(&"arcanist")
	await _frames(2)
	check(_switch(&"arcanist").disabled and _details_text().contains("Classes can only be changed at a class station."), "away: locked with the reason")
	map.hud.close_windows()
	character.equipment.apply_loadout(&"arcanist", {})   # the arcanist wears nothing of its own
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"worn_boots", 1, ItemInstance.ORIGIN_STARTING)
	await _open_at_station()
	panel.select_class(&"arcanist")
	await _frames(2)
	var button := _switch(&"arcanist")
	check(button.disabled and _details_text().contains("Your bag is too full to change class"), "full bag: locked with the reason: %s" % _details_text())
	check(not _details_text().contains(".."), "one full stop")
	var before := _state()
	button.pressed.emit()   # a press of the locked button goes through the same rules
	await _frames(2)
	check_eq(_state(), before, "nothing changed - no partial switch")
	check_eq(character.classes.active_class_id, &"warrior", "still the warrior")


## The pre-check is switch_class's own verdict: every case agrees.
func test_class_switch_error_matches_switch_class() -> void:
	for entry: Array in [[&"arcanist", false], [&"warrior", true], [&"shadowrunner", true], [&"guardian", true]]:
		var error := character.class_switch_error(entry[0], entry[1])
		check(error != "", "%s refused (%s)" % [entry[0], error])
		check_eq(character.switch_class(entry[0], entry[1]), error, "%s: the same reason" % entry[0])
	check_eq(character.class_switch_error(&"arcanist", true), "", "arcanist allowed")
	check_eq(character.switch_class(&"arcanist", true), "", "and switched")


func test_save_load_geometry_and_keyboard() -> void:
	await _open_at_station()
	panel.select_class(&"arcanist")
	await _frames(2)
	_switch(&"arcanist").pressed.emit()
	await _frames(2)
	var path := "user://test_saves/class_switch_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), 15, "save v15")
	file.close()
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.ok() and loaded.character.classes.active_class_id == &"arcanist", "active class after load")
	check_eq(loaded.character.equipment.to_dict(), character.equipment.to_dict(), "loadouts after load")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	for scale: float in [1.0, 1.5]:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		panel.show_page("Quests")
		await _frames(3)
		var frame := panel.get_global_rect()
		panel.show_page("Classes")
		await _frames(4)
		check(panel.get_global_rect().is_equal_approx(frame), "%d %%: same frame" % roundi(scale * 100))
		panel.select_class(&"shadowrunner")
		await _frames(3)
		check(panel.get_global_rect().is_equal_approx(frame), "%d %%: choosing a card keeps the frame" % roundi(scale * 100))
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%d %%: the window never scrolls" % roundi(scale * 100))
		var list := (panel.find_child("ClassListScroll", true, false) as Control).get_global_rect()
		var details := (panel.find_child("ClassDetails", true, false) as Control).get_global_rect()
		check(frame.encloses(list) and frame.encloses(details) and not list.intersects(details), "%d %%: cards and details side by side inside" % roundi(scale * 100))
	var active := character.classes.active_class_id
	_card(&"warrior").grab_focus()
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter)
	await _frames(3)
	check_eq(panel.selected_class, &"warrior", "Enter selects")
	check_eq(character.classes.active_class_id, active, "Enter never switches")
	check(_card(&"warrior").has_focus(), "focus stays on the chosen card")
