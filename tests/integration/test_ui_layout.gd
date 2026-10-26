extends TestCase
## Headless layout regression: at every UI scale all RPG windows stay inside the
## visible canvas with the screen margin, scroll instead of overflowing and are
## never squeezed below their minimum size. (Screenshots: tests/playtest/ui_playtest.gd.)

var session: SessionState
var _previous_character: Character
var _previous_factor: float


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_factor = get_tree().root.content_scale_factor
	var character := CharacterFactory.create_new(session.database)
	GameMap.give_debug_items(character)
	GameMap.give_crafting_kit(character)
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	get_tree().root.content_scale_factor = _previous_factor
	session.set_character(_previous_character)


func _load_home() -> GameMap:
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			return map
	fail("home base not loaded")
	return null


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


func _check_window(window: UiWindow, label: String) -> void:
	window.fit()
	var view := get_tree().root.get_visible_rect()
	var rect := window.get_global_rect()
	check(view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(rect), "%s inside canvas %s with margin (%s)" % [label, view.size, rect])
	var minimum := window.get_combined_minimum_size()
	check(window.size.x + 0.5 >= minimum.x and window.size.y + 0.5 >= minimum.y, "%s not squeezed (%s >= %s)" % [label, window.size, minimum])


func test_windows_fit_at_every_ui_scale() -> void:
	var map := await _load_home()
	if map == null:
		return
	var station := map.get_node("ClassStation") as ClassStation
	var warrior := session.character
	warrior.classes.unlock(&"warrior")
	warrior.classes.set_active(&"warrior")
	warrior.classes.add_xp(&"warrior", 200000)   # level 60: all talent tiers and skills shown
	var ruin := map.get_node("Ruins/OldSmithy") as RuinSite
	for value in UserSettings.UI_SCALES:
		session.settings.set_ui_scale(value)
		await _settle()
		var tag := "%d %%" % roundi(value * 100.0)
		map.hud.toggle_inventory()
		await _settle()
		_check_window(map.hud.inventory_panel, tag + " inventory")
		map.hud.close_windows()
		map.hud.class_panel.open(session.character, station)
		for page_name: String in ClassStationPanel.PAGES:
			map.hud.class_panel.show_page(page_name)
			await _settle()
			_check_window(map.hud.class_panel, "%s class station / %s" % [tag, page_name])
		map.hud.close_windows()
		map.hud.class_choice_panel.open(session.character, null)
		await _settle()
		_check_window(map.hud.class_choice_panel, tag + " class choice")
		map.hud.close_windows()
		map.hud.restoration_panel.open(session.character, ruin)
		await _settle()
		_check_window(map.hud.restoration_panel, tag + " restoration")
		map.hud.close_windows()
		map.hud.open_lines([{"name": "Mara Veyne", "text": "There's a place north of here. Haven. Not much to look at, but it's got walls, a forge, and people who still give a damn.", "color": UiTheme.COLOR_ACCENT}] as Array[Dictionary])
		await _settle()
		_check_window(map.hud.dialogue_panel, tag + " dialogue")
		map.hud.close_windows()
		map.hud.toggle_options()
		await _settle()
		_check_window(map.hud.options_panel, tag + " options")
		map.hud.close_windows()
		map.hud.crafting_panel.open(session.character, null)
		map.hud.crafting_panel.select_item(_first_craftable())
		map.hud.crafting_panel.select_operation(CraftingOps.IMPRINT)
		map.hud.crafting_panel.choose_material(&"storm_ore")
		await _settle()
		_check_window(map.hud.crafting_panel, tag + " resonance forge")
		map.hud.close_windows()
	session.settings.reset_to_defaults()


func test_inventory_scrolls_instead_of_overflowing_at_150_percent() -> void:
	var map := await _load_home()
	if map == null:
		return
	session.settings.set_ui_scale(UserSettings.MAX_UI_SCALE)   # the smallest canvas a player can choose
	map.hud.toggle_inventory()
	await _settle()
	var inventory := map.hud.inventory_panel
	inventory.fit()
	var canvas := get_tree().root.get_visible_rect().size
	check(inventory.size.x <= canvas.x - 2 * UiTheme.SCREEN_MARGIN + 0.5 and inventory.size.y <= canvas.y - 2 * UiTheme.SCREEN_MARGIN + 0.5,
		"window clamped to the 150 %% canvas (%s): %s" % [canvas, inventory.size])
	var scroll := inventory.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "body scrolls vertically")
	session.settings.reset_to_defaults()


func _first_craftable() -> String:
	for item in session.character.inventory.items():
		if item.definition_id == &"forged_greatsword":
			return item.instance_id
	return ""
