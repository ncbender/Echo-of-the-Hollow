extends TestCase
## Main Window Layout Lock 1.0 (docs/MAIN_WINDOW_LAYOUT_LOCK_1_0.md): the seven main menus (I C T P J M O)
## share one outer rect - the same size and the same place for every menu and every page - at each UI
## scale; inside the canvas; nothing wider than the body (no sideways window scroll); the inner lists
## scroll on their own. A well-filled character (items, quests, professions).

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	GameMap.give_crafting_kit(character)
	GameMap.give_debug_items(character)
	for quest_id: StringName in [&"the_lost_hunter", &"what_the_roots_keep"]:
		StoryService.start(character, quest_id)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


## [menu id, window, [page label, Callable]...] for all seven menus.
func _menus() -> Array:
	var hud := map.hud
	var inventory := hud.inventory_panel
	var steps := {
		&"inventory": [["Equipment", func() -> void: inventory._left_tabs.select("Equipment", true)]],
		&"character": [["Overview", func() -> void: inventory._left_tabs.select("Overview", true)],
			["Details", func() -> void: inventory._left_tabs.select("Details", true)]],
		&"talents": ClassStationPanel.PAGES.map(func(p: String) -> Array: return [p, func() -> void: hud.class_panel.show_page(p)]),
		&"professions": ProfessionsPanel.PAGES.map(func(p: String) -> Array: return [p, func() -> void: hud.professions_panel.show_page(p)]),
		&"journal": JournalPanel.PAGES.map(func(p: String) -> Array: return [p, func() -> void: hud.journal_panel.show_page(p)]),
		&"map": WorldMapPanel.PAGES.map(func(p: String) -> Array: return [p, func() -> void: hud.world_map_panel.show_page(p)]),
		&"settings": OptionsPanel.PAGES.map(func(p: String) -> Array: return [p, func() -> void: hud.options_panel.show_page(p)]),
	}
	var windows := {&"inventory": inventory, &"character": inventory, &"talents": hud.class_panel, &"professions": hud.professions_panel,
		&"journal": hud.journal_panel, &"map": hud.world_map_panel, &"settings": hud.options_panel}
	var result: Array = []
	for id: StringName in steps:
		result.append([id, windows[id], steps[id]])
	return result


func test_seven_menus_share_one_frame_at_every_scale() -> void:
	var hud := map.hud
	for scale: float in [0.75, 1.0, 1.25, 1.5]:
		var tag := "%d %%" % int(scale * 100)
		session.settings.set_ui_scale(scale)
		await _frames(4)
		var canvas := Rect2(Vector2.ZERO, map.get_viewport().get_visible_rect().size)
		var frame := Rect2()
		for menu: Array in _menus():
			hud.close_windows()
			await _frames(2)
			hud.open_menu(menu[0])
			var window := menu[1] as UiWindow
			for step: Array in menu[2]:
				(step[1] as Callable).call()
				await _frames()
				window.fit()
				await _frames()
				var rect := window.get_global_rect()
				var label := "%s %s %s" % [tag, menu[0], step[0]]
				if frame.size == Vector2.ZERO:
					frame = rect
					var expected := UiTheme.MAIN_WINDOW_SIZE.min(window.max_window_size())
					check(rect.size.is_equal_approx(expected), "%s: the main size %s (%s)" % [label, expected, rect.size])
				check(rect.is_equal_approx(frame), "%s: the shared frame %s (%s)" % [label, frame, rect])
				check(canvas.grow(0.5).encloses(rect), "%s: inside the canvas" % label)
				if window.side_tabs != null:
					check(canvas.grow(0.5).encloses(window.side_tabs.get_global_rect()), "%s: registers on screen" % label)
				var body_width := window._scroll.size.x
				check(window.body.get_combined_minimum_size().x <= body_width + 0.5,
					"%s: nothing wider than the body (%.0f > %.0f)" % [label, window.body.get_combined_minimum_size().x, body_width])
		hud.close_windows()
		await _frames(2)
		if scale <= 1.25:
			check(frame.size.is_equal_approx(UiTheme.MAIN_WINDOW_SIZE), "%s: the full 1120 x 760 (%s)" % [tag, frame.size])


func test_inner_areas_scroll_on_their_own() -> void:
	var hud := map.hud
	hud.open_menu(&"character")
	hud.inventory_panel._left_tabs.select("Details", true)
	await _frames(4)
	var left := hud.inventory_panel.find_child("LeftScroll", true, false) as ScrollContainer
	# Playtest Corrections 1.0: Details lists only what is in effect - often no scrolling at all; the area is its own
	check(left != null and left.size.y > 0.0 and left.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "details stats in their own scroll area")
	check(hud.inventory_panel.find_child("BagScroll", true, false) is ScrollContainer, "the bag has its own area")
	check(not _texts(hud.inventory_panel).has("No item selected") and not _texts(hud.inventory_panel).has("Empty"), "no empty details panel, no 'Empty' slots")
	hud.close_windows()
	hud.open_menu(&"journal")
	hud.journal_panel.show_page("Side Quests")
	await _frames(4)
	var list := hud.journal_panel.find_child("QuestList", true, false) as ScrollContainer
	var detail := hud.journal_panel.find_child("QuestDetail", true, false) as ScrollContainer
	check(list != null and detail != null and list.get_global_rect().end.x <= detail.get_global_rect().position.x, "journal: list | details")
	var entries := list.find_children("Entry_*", "Button", true, false)
	check(entries.size() >= 2, "every side quest is listed (%d)" % entries.size())
	var names: Array = entries.map(func(n: Node) -> String: return String(n.name))
	for entry_name: String in names:   # every quest's full step text is one click away (a click rebuilds the list)
		(hud.journal_panel.find_child("QuestList", true, false).find_child(entry_name, true, false) as Button).pressed.emit()
		await _frames(2)
		var quest_id := StringName(entry_name.trim_prefix("Entry_"))
		var step: String = (session.database.story_quests[quest_id] as StoryQuestDefinition).steps[0].description
		detail = hud.journal_panel.find_child("QuestDetail", true, false) as ScrollContainer
		check("\n".join(_texts(detail)).contains(step), "details of %s show its step" % quest_id)
	hud.close_windows()
	hud.open_menu(&"settings")
	hud.options_panel.show_page("Controls")
	await _frames(4)
	var page := hud.options_panel.find_child("PageScroll", true, false) as ScrollContainer
	check(page != null and hud.options_panel._tabs.get_global_rect().end.y <= page.get_global_rect().position.y, "options: tabs above their own page area")


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			texts.append(label.text)
	return texts
