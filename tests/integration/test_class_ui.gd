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
	check(view.info_text(&"war_b_seething").contains("+2% attack speed"), "tooltip shows the effect")
	button.emit_signal(&"pressed")
	await get_tree().process_frame
	check_eq(character.builds.get_build().rank(&"war_b_seething"), 1, "learned through the UI")
	view = panel.tree_view(&"war_berserker")
	var locked := view.button_for(&"war_b_relentless")
	check(view.info_text(&"war_b_relentless").contains("5 points in lower tiers"), "tier requirement explained: %s" % view.info_text(&"war_b_relentless"))
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


func test_compact_class_cards_and_details() -> void:
	map.hud.toggle_character()
	await get_tree().process_frame
	panel.show_page("Classes")
	await get_tree().process_frame
	var status := func(class_id: String) -> String:
		var card := panel.find_child("Class_%s" % class_id, true, false)
		return (card.find_child("Status", true, false) as Label).text if card != null else "missing"
	check_eq(status.call("warrior"), "ACTIVE", "active class card")
	check_eq(status.call("basic_adventurer"), "UNLOCKED", "unlocked class card")
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
	(panel.find_child("Class_basic_adventurer", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var activate := _button(panel, "Activate_basic_adventurer")
	check(activate != null and activate.disabled, "changing class needs the class station")
	var station := await _at_station()
	map.hud.open_class_panel(station)
	panel.show_page("Classes")
	panel.select_class(&"basic_adventurer")
	await get_tree().process_frame
	activate = _button(panel, "Activate_basic_adventurer")
	check(activate != null and not activate.disabled, "at the station the class can be activated")
	activate.pressed.emit()
	await get_tree().process_frame
	check_eq(character.classes.active_class_id, &"basic_adventurer", "class changed through the details button")


func _labels(root: Node) -> String:
	var texts: PackedStringArray = []
	for label: Label in root.find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func test_talent_trees_side_by_side_with_tiers() -> void:
	map.hud.toggle_character()
	for i in 4:
		await get_tree().process_frame
	var trees: Array[TalentTreeView] = panel._trees
	check_eq(trees.size(), 3, "three trees")
	check(trees[0].get_parent() == trees[1].get_parent() and trees[0].get_parent() is HBoxContainer, "trees share one row (never stacked)")
	check(trees[0].position.x < trees[1].position.x and trees[1].position.x < trees[2].position.x, "left to right")
	var view := panel.tree_view(&"war_berserker")
	var first := view.button_for(&"war_b_seething")
	var capstone := view.button_for(&"war_b_unbound")
	check(first.position.y < view.button_for(&"war_b_relentless").position.y and capstone.position.y > first.position.y, "tier 1 at the top, capstone at the bottom")
	check(view.links().any(func(link: Array) -> bool: return link[0] == &"war_b_whirlwind" and link[2]), "explicit prerequisite drawn as a line")
	var info := view.info_text(&"war_b_unbound")
	check(info.contains("30 points in lower tiers") and info.contains("Locked:") and info.contains("Capstone"), "lock reason and capstone rule in the tooltip: %s" % info)
	check(panel.find_child("TalentDetails", true, false) == null, "no permanent details bar")
	# hover: the tooltip appears at once, holds the node, stays on screen; leaving hides it
	capstone.mouse_entered.emit()
	await get_tree().process_frame
	var tooltip := panel.talent_tooltip
	check(tooltip.visible and tooltip.node_id == &"war_b_unbound", "hover shows the tooltip immediately")
	check(panel.get_viewport_rect().grow(1.0).encloses(tooltip.get_global_rect()), "tooltip on screen: %s" % tooltip.get_global_rect())
	check(tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "tooltip never blocks the nodes")
	var before := character.builds.get_build().rank(&"war_b_unbound")
	capstone.mouse_exited.emit()
	check(not tooltip.visible, "leaving the node hides it")
	check_eq(character.builds.get_build().rank(&"war_b_unbound"), before, "hovering never spends points")
	# keyboard focus shows the same information
	view.button_for(&"war_b_temper").grab_focus()
	await get_tree().process_frame
	check(tooltip.visible and tooltip.node_id == &"war_b_temper", "keyboard focus shows the tooltip too")


## Acceptance (Talent UI Polish 1.2): at 1920x1080 / 100 % every class shows its
## three complete trees - all tiers, all nodes - without any scrolling, tiers
## aligned across the trees, no overlapping nodes, nothing outside the window.
func test_all_talents_visible_without_scrolling_for_every_class() -> void:
	session.settings.set_ui_scale(1.0)
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		var other := CharacterFactory.create_new(session.database)
		other.classes.unlock(class_id)
		other.switch_class(class_id, true)
		panel.open(other, null, "Talents")
		for i in 4:
			await get_tree().process_frame
		var scroll := panel.find_child("TreeScroll", true, false) as ScrollContainer
		check(not scroll.get_v_scroll_bar().visible and not scroll.get_h_scroll_bar().visible, "%s: no scrolling in the tree area" % class_id)
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%s: no scrolling in the window" % class_id)
		check_eq(panel._trees.size(), 3, "%s: three trees" % class_id)
		var window := panel.get_global_rect()
		var view_rect := scroll.get_global_rect().grow(1.0)
		var rects: Array[Rect2] = []
		var rows: Dictionary = {}
		var count := 0
		for view in panel._trees:
			for node in view.tree.nodes:
				var button := view.button_for(node.id)
				var rect := button.get_global_rect()
				count += 1
				check(view_rect.encloses(rect) and window.encloses(rect), "%s: %s fully visible" % [class_id, node.id])
				for other_rect in rects:
					check(not other_rect.grow(-1.0).intersects(rect.grow(-1.0)), "%s: %s overlaps nothing" % [class_id, node.id])
				rects.append(rect)
				var center_y := rect.get_center().y
				if rows.has(node.tier):
					check(absf(rows[node.tier] - center_y) < 1.0, "%s: tier %d aligned across trees" % [class_id, node.tier])
				rows[node.tier] = center_y
		check_eq(count, 39, "%s: all 39 talents" % class_id)
		check_eq(rows.size(), 7, "%s: seven tiers" % class_id)
		check(not panel.talent_layout.compact, "%s: full layout with names at 100 %%" % class_id)
	panel.hide()


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
		check(tab_rect.end.x <= panel.get_global_rect().position.x + BookTabs.OVERLAP + 1.0, "%s: registers at the left outer edge" % id)
		check(panel.get_viewport_rect().grow(1.0).encloses(tab_rect) and panel.get_viewport_rect().grow(1.0).encloses(panel.get_global_rect()), "%s: window and registers on screen" % id)
	check_eq(character.builds.get_build().talents, talents_before, "talents unchanged by switching pages")
	check_eq(character.builds.get_build().slots, slots_before, "skill slots unchanged")
	check_eq(PresetService.get_preset(character, &"warrior", 0), preset_before, "preset unchanged")
	check((tabs.tab_button("Talents") as Button).focus_mode == Control.FOCUS_ALL, "registers reachable with the keyboard")


func _push_mouse(at: Vector2, button_index: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	if button_index != 0:
		for pressed: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = button_index as MouseButton
			click.pressed = pressed
			click.position = at
			click.global_position = at
			get_viewport().push_input(click, true)
	for i in 3:
		await get_tree().process_frame


func test_learning_by_mouse_keeps_layout_and_tooltip_and_survives_save_load() -> void:
	map.hud.toggle_character()   # away from the station: learning is allowed, respec is not
	for i in 4:
		await get_tree().process_frame
	var button := panel.tree_view(&"war_berserker").button_for(&"war_b_temper")
	var before_rect := button.get_global_rect()
	var at := before_rect.get_center()
	await _push_mouse(at)
	check(panel.talent_tooltip.visible and panel.talent_tooltip.node_id == &"war_b_temper", "real hover shows the tooltip")
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 0, "hover spends nothing")
	await _push_mouse(at, MOUSE_BUTTON_LEFT)
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 1, "a click learns one rank")
	var after := panel.tree_view(&"war_berserker").button_for(&"war_b_temper")
	check(after.get_global_rect().is_equal_approx(before_rect), "the node did not move (no layout jump): %s -> %s" % [before_rect, after.get_global_rect()])
	check(panel.talent_tooltip.visible and panel.talent_tooltip.node_id == &"war_b_temper", "tooltip back on the node under the mouse")
	check((panel.find_child("Status", true, false) as Label).text.begins_with("Learned"), "result shown in the bottom row")
	var respec := _button(panel, "Respec")
	check(respec != null and respec.disabled, "respec only at a class station")
	var path := "user://test_saves/class_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	SaveSystem.save_to(character, path)
	var restored := SaveSystem.load_from(path, session.database).character
	check(restored != null and restored.builds.get_build(&"warrior").rank(&"war_b_temper") == 1, "talent rank survives save/load")
	check_eq(restored.builds.get_build(&"warrior").talents, character.builds.get_build(&"warrior").talents, "whole build identical after load")
	DirAccess.remove_absolute(path)
