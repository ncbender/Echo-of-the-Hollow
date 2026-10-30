extends TestCase
## UI Usability & Haven Crafting 1.0 (docs/UI_USABILITY_HAVEN_CRAFTING_1_0.md): inside one window the
## outer geometry (size, position, title) stays constant while its tabs / pages / categories change -
## content scrolls inside, little content leaves free room. Checked at 100 / 125 / 150 % UI scale with
## a well-filled character (items of every kind, quests, professions).

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
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
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


## Applies every step (a Callable) and checks the window rect and the title row after each one.
func _check_steps(window: UiWindow, label: String, steps: Array) -> void:
	await _frames()
	window.fit()
	await _frames()
	var rect := window.get_global_rect()
	var title := (window._title as Control).get_global_rect()
	for step: Array in steps:
		(step[1] as Callable).call()
		await _frames()
		window.fit()
		await _frames()
		var now := window.get_global_rect()
		check(now.is_equal_approx(rect), "%s: %s keeps the window (%s, was %s)" % [label, step[0], now, rect])
		check((window._title as Control).get_global_rect().is_equal_approx(title), "%s: %s keeps the title row" % [label, step[0]])
		check(get_tree().root.get_visible_rect().grow(0.5).encloses(now), "%s: %s inside the canvas" % [label, step[0]])


func test_tab_windows_keep_their_geometry_at_three_scales() -> void:
	var hud := map.hud
	for scale: float in [1.0, 1.25, 1.5]:
		var tag := "%d %%" % int(scale * 100)
		session.settings.set_ui_scale(scale)
		await _frames(4)
		# inventory: left pages x bag categories
		hud.open_menu(&"inventory")
		var inventory := hud.inventory_panel
		var steps: Array = []
		for page: String in ["Overview", "Details", "Equipment"]:
			steps.append([page, func() -> void: inventory._left_tabs.select(page, true)])
		for category: String in InventoryPanel.CATEGORIES:
			steps.append([category, func() -> void: inventory._bag_tabs.select(category, true)])
		await _check_steps(inventory, "%s inventory" % tag, steps)
		hud.close_windows()
		# journal pages
		hud.open_menu(&"journal")
		steps = []
		for page: String in JournalPanel.PAGES:
			steps.append([page, func() -> void: hud.journal_panel.show_page(page)])
		await _check_steps(hud.journal_panel, "%s journal" % tag, steps)
		hud.close_windows()
		# professions: pages and professions
		hud.open_menu(&"professions")
		var professions := hud.professions_panel
		steps = []
		for page: String in ProfessionsPanel.PAGES:
			steps.append([page, func() -> void: professions.show_page(page)])
		for profession: ProfessionDefinition in ProfessionService.professions(character.database, ProfessionDefinition.Kind.CRAFTING):
			steps.append([String(profession.id), func() -> void:
				professions.show_page("Crafting")
				professions.select_profession(profession.id)])
		await _check_steps(professions, "%s professions" % tag, steps)
		hud.close_windows()
		# class station pages
		hud.open_menu(&"talents")
		steps = []
		for page: String in ClassStationPanel.PAGES:
			steps.append([page, func() -> void: hud.class_panel.show_page(page)])
		await _check_steps(hud.class_panel, "%s class station" % tag, steps)
		hud.close_windows()
		# map, options
		hud.open_menu(&"map")
		steps = []
		for page: String in WorldMapPanel.PAGES:
			steps.append([page, func() -> void: hud.world_map_panel.show_page(page)])
		await _check_steps(hud.world_map_panel, "%s map" % tag, steps)
		hud.close_windows()
		hud.open_menu(&"settings")
		steps = []
		for page: String in OptionsPanel.PAGES:
			steps.append([page, func() -> void: hud.options_panel.show_page(page)])
		await _check_steps(hud.options_panel, "%s options" % tag, steps)
		hud.close_windows()
