extends TestCase
## Class Foundation G2: the class station window drives the real services -
## station-only actions, skill slots, mods, presets and quests (the Talents page:
## test_talent_ui) - and shows requirements/costs in tooltips.

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
	var definition := session.database.get_class_def(&"warrior")
	var xp := 0
	for level in range(1, 20):
		xp += definition.xp_to_next(level)
	character.classes.add_xp(&"warrior", xp)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	panel = map.hud.class_panel


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous_character)


func _at_station() -> ClassStation:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	return station


func _button(root: Node, button_name: String) -> Button:
	var found := root.find_children(button_name, "Button", true, false)
	return found[0] as Button if not found.is_empty() else null


func test_station_actions_skills_mods_presets() -> void:
	var station := await _at_station()
	map.hud.open_class_panel(station)
	await get_tree().process_frame
	check(panel.at_station(), "panel knows it is at the station")
	panel.show_page("Skills")
	await get_tree().process_frame
	# Skills & Talents UX 2.0 Phase 3: choose the skill in the list, equip it with the slot button
	character.builds.get_build().slots[3] = &""
	panel.show_page("Skills")
	await get_tree().process_frame
	(panel.find_child("Skill_warbreaker", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var slot := panel.find_child("EquipSlot3", true, false) as Button
	check(slot != null and not slot.disabled, "slots editable at the station")
	slot.pressed.emit()
	await get_tree().process_frame
	check_eq(character.builds.get_build().slots[3], &"warbreaker", "slot changed through the UI")
	(panel.find_child("Skill_furious_strike", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var form := panel.find_children("furious_strike_form", "OptionButton", true, false)[0] as OptionButton
	var locked_shown := false
	for index in form.item_count:
		locked_shown = locked_shown or (form.is_item_disabled(index) and form.get_item_text(index).contains("locked"))
		if form.get_item_metadata(index) == &"furious_wide_arc":
			form.select(index)
			form.item_selected.emit(index)
	await get_tree().process_frame
	check_eq(character.builds.get_build().mod_of(&"furious_strike", SkillModDefinition.Slot.FORM), &"furious_wide_arc", "mod chosen through the UI")
	check(locked_shown, "locked mods are listed with their unlock source")
	panel.show_page("Presets")
	await get_tree().process_frame
	# Skills & Talents UX 2.0 Phase 4: the name field belongs to the chosen slot, Activate to the detail panel
	var row := panel.find_children("Preset0", "HBoxContainer", true, false)[0]
	(panel.find_child("PresetNameEdit", true, false) as LineEdit).text = "Opener"
	_button(row, "Save").emit_signal(&"pressed")
	await get_tree().process_frame
	check_eq(PresetService.get_preset(character, &"warrior", 0).get("name"), "Opener", "preset saved through the UI")
	var activate := _button(panel.find_child("PresetDetail", true, false), "Activate")
	check(activate != null and not activate.disabled and activate.text.contains("free"), "activation free with identical talents")
	panel.show_page("Quests")
	await get_tree().process_frame
	# Skills & Talents UX 2.0 Phase 5: choose the quest in the list, its action sits in the detail panel
	(panel.find_child("Quest_unlock_arcanist", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var start := _button(panel.find_child("QuestDetail", true, false), "Start")
	check(start != null and start.disabled and start.tooltip_text.contains("prologue"), "quests wait for the prologue choice")


func test_compact_class_cards_and_details() -> void:
	map.hud.toggle_talents()
	await get_tree().process_frame
	panel.show_page("Classes")
	await get_tree().process_frame
	var status := func(class_id: String) -> String:
		var card := panel.find_child("Class_%s" % class_id, true, false)
		return (card.find_child("Status", true, false) as Label).text if card != null else "missing"
	check_eq(status.call("warrior"), "ACTIVE", "active class card")
	check_eq(status.call("basic_adventurer"), "missing", "the start class is no regular class offer once another class is active (Phase 7)")
	check_eq(status.call("arcanist"), "LOCKED", "locked class card")
	check_eq(status.call("guardian"), "missing", "prepared class (not playable) is not listed")
	check_eq(status.call("soulbinder"), "missing", "prepared class (not playable) is not listed")
	var details := panel.find_child("ClassDetails", true, false)
	check(details != null and _labels(details).contains("Rage (max"), "details show the class resource from data")
	check(_labels(details).contains("Berserker"), "details list the talent trees")
	(panel.find_child("Class_arcanist", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	details = panel.find_child("ClassDetails", true, false)
	check(_labels(details).contains("Complete the prologue first."), "requirement from the class quest data: %s" % _labels(details))
	check(panel.requirements(session.database.get_class_def(&"guardian")).has("Not playable in this version."), "a prepared class would name why it is locked")
	character.classes.unlock(&"arcanist")   # e.g. through its class quest
	panel.rebuild()
	(panel.find_child("Class_arcanist", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var activate := _button(panel, "Activate_arcanist")
	check(activate != null and activate.disabled, "changing class needs the class station")
	var station := await _at_station()
	map.hud.open_class_panel(station)
	panel.show_page("Classes")
	panel.select_class(&"arcanist")
	await get_tree().process_frame
	activate = _button(panel, "Activate_arcanist")
	check(activate != null and not activate.disabled, "at the station the class can be activated")
	activate.pressed.emit()
	await get_tree().process_frame
	check_eq(character.classes.active_class_id, &"arcanist", "class changed through the details button")


func _labels(root: Node) -> String:
	var texts: PackedStringArray = []
	for label: Label in root.find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func test_book_tabs_switch_pages_without_changing_anything() -> void:
	var station := await _at_station()
	map.hud.open_class_panel(station)
	await get_tree().process_frame
	check(panel.find_children("*", "UiTabs", true, false).is_empty(), "no horizontal tab row any more")
	var tabs := panel.find_child("BookTabs", true, false) as BookTabs
	check(tabs != null and tabs.top_level, "book tabs outside the window body")
	var talents_before := character.builds.get_build().talents.duplicate()
	var slots_before := character.builds.get_build().slots.duplicate()
	PresetService.save_preset(character, &"warrior", 0, "Keep")
	var preset_before := PresetService.get_preset(character, &"warrior", 0).duplicate(true)
	for id: String in ClassStationPanel.PAGES:
		(tabs.tab_button(id) as Button).pressed.emit()
		for i in 2:
			await get_tree().process_frame
		check_eq(panel.page, id, "%s tab opens its page" % id)
		var pressed := tabs.get_children().filter(func(b: Node) -> bool: return (b as Button).button_pressed)
		check(pressed.size() == 1 and pressed[0] == tabs.tab_button(id), "only %s is active" % id)
		var tab_rect := tabs.get_global_rect()
		# Menu UX Polish 1.1: the registers reach under the frame up to the page (the inactive ones behind it)
		check(tab_rect.end.x <= panel.get_global_rect().position.x + panel.tab_bridge() + 1.0 and tab_rect.position.x < panel.get_global_rect().position.x, "%s: registers at the left outer edge" % id)
		check(panel.get_viewport_rect().grow(1.0).encloses(tab_rect) and panel.get_viewport_rect().grow(1.0).encloses(panel.get_global_rect()), "%s: window and registers on screen" % id)
	check_eq(character.builds.get_build().talents, talents_before, "talents unchanged by switching pages")
	check_eq(character.builds.get_build().slots, slots_before, "skill slots unchanged")
	check_eq(PresetService.get_preset(character, &"warrior", 0), preset_before, "preset unchanged")
	check((tabs.tab_button("Talents") as Button).focus_mode == Control.FOCUS_ALL, "registers reachable with the keyboard")


func _tab_snapshot(tabs: BookTabs) -> Dictionary:
	var shot := {"window": panel.get_global_rect(), "column": tabs.get_global_rect()}
	for id: String in ClassStationPanel.PAGES:
		var button := tabs.tab_button(id)
		# vertical place and the page-side (right) edge; the active one may only stick out to the left
		shot[id] = Vector2(button.get_global_rect().end.x, button.get_global_rect().position.y)
	return shot


func test_book_tabs_never_move_when_switching_pages() -> void:
	var station := await _at_station()
	for scale: float in [1.0, 1.25, 1.5]:
		session.settings.set_ui_scale(scale)
		map.hud.open_class_panel(station)
		panel.show_page("Classes")
		for i in 4:
			await get_tree().process_frame
		var tabs := panel.find_child("BookTabs", true, false) as BookTabs
		var first := _tab_snapshot(tabs)
		var view := panel.get_viewport_rect().grow(1.0)
		for round_index in 2:
			for id: String in ClassStationPanel.PAGES:
				if round_index == 0:
					(tabs.tab_button(id) as Button).pressed.emit()   # mouse click path
				else:
					tabs.tab_button(id).grab_focus()   # keyboard: focus + Enter
					var enter := InputEventKey.new()
					enter.keycode = KEY_ENTER
					enter.physical_keycode = KEY_ENTER
					enter.pressed = true
					get_viewport().push_input(enter)
					enter = enter.duplicate()
					enter.pressed = false
					get_viewport().push_input(enter)
				for i in 3:
					await get_tree().process_frame
				check_eq(panel.page, id, "%d %%: %s opened" % [roundi(scale * 100), id])
				var now := _tab_snapshot(tabs)
				for key: Variant in first:
					check(now[key] == first[key], "%d %% %s: %s unchanged (%s -> %s)" % [roundi(scale * 100), id, key, first[key], now[key]])
				check(view.encloses(panel.get_global_rect()) and view.encloses(tabs.get_global_rect()), "%d %% %s: frame and registers inside the viewport" % [roundi(scale * 100), id])
		map.hud.close_windows()
	session.settings.set_ui_scale(1.0)
	# the talent page still shows everything at 1920x1080 / 100 %
	map.hud.open_class_panel(station)
	panel.show_page("Talents")
	for i in 4:
		await get_tree().process_frame
	var scroll := panel.find_child("TreeScroll", true, false) as ScrollContainer
	check(not scroll.get_v_scroll_bar().visible and not scroll.get_h_scroll_bar().visible, "talents still complete without scrolling at 100 %")
