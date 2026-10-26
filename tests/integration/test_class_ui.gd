extends TestCase
## Class Foundation G2: the class station window drives the real services -
## learning talents with the tree buttons, station-only actions, skill slots,
## mods, presets and quests - and shows requirements/costs in tooltips.

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


func test_learning_talents_with_the_tree_buttons() -> void:
	map.hud.toggle_character()
	await get_tree().process_frame
	check(panel.visible and panel.page == "Talents", "C opens the talent page anywhere")
	var tab := panel.find_children("TabTalents", "Button", true, false)[0] as Button
	check_eq(tab.text, "Talents", "localization key resolved to English")
	check_eq(panel._title.text, "Character - Class, Talents & Skills", "translated window title")
	check_eq(panel._trees.size(), 3, "three trees shown")
	var view := panel.tree_view(&"war_berserker")
	var button := view.button_for(&"war_b_seething")
	check(button.tooltip_text.contains("+2% attack speed"), "tooltip shows the effect")
	button.emit_signal(&"pressed")
	await get_tree().process_frame
	check_eq(character.builds.get_build().rank(&"war_b_seething"), 1, "learned through the UI")
	view = panel.tree_view(&"war_berserker")
	var locked := view.button_for(&"war_b_relentless")
	check(locked.tooltip_text.contains("Requires 5 points"), "tier requirement explained: %s" % locked.tooltip_text)
	locked.emit_signal(&"pressed")
	await get_tree().process_frame
	check_eq(character.builds.get_build().rank(&"war_b_relentless"), 0, "locked node not learned")
	check(panel._status.text.contains("points"), "reason shown: %s" % panel._status.text)
	var respec := _button(panel, "Respec")
	check(respec != null and respec.disabled, "reset only at a class station")


func test_station_actions_skills_mods_presets() -> void:
	var station := await _at_station()
	map.hud.open_class_panel(station)
	await get_tree().process_frame
	check(panel.at_station(), "panel knows it is at the station")
	panel.show_page("Skills")
	await get_tree().process_frame
	var slot := panel.find_children("Slot3", "OptionButton", true, false)[0] as OptionButton
	check(not slot.disabled, "slots editable at the station")
	for index in slot.item_count:
		if slot.get_item_metadata(index) == &"warbreaker":
			slot.select(index)
			slot.item_selected.emit(index)
	await get_tree().process_frame
	check_eq(character.builds.get_build().slots[3], &"warbreaker", "slot changed through the UI")
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
	var row := panel.find_children("Preset0", "HBoxContainer", true, false)[0]
	(row.find_children("Name", "LineEdit", true, false)[0] as LineEdit).text = "Opener"
	_button(row, "Save").emit_signal(&"pressed")
	await get_tree().process_frame
	check_eq(PresetService.get_preset(character, &"warrior", 0).get("name"), "Opener", "preset saved through the UI")
	row = panel.find_children("Preset0", "HBoxContainer", true, false)[0]
	var activate := _button(row, "Activate")
	check(activate != null and not activate.disabled and activate.text.contains("free"), "activation free with identical talents")
	panel.show_page("Quests")
	await get_tree().process_frame
	var quest := panel.find_children("Quest_unlock_arcanist", "VBoxContainer", true, false)[0]
	var start := _button(quest, "Start")
	check(start != null and start.disabled and start.tooltip_text.contains("prologue"), "quests wait for the prologue choice")
