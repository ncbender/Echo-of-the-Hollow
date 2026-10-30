extends TestCase
## UI Window Foundation 1.0 (docs/UI_WINDOW_FOUNDATION_1_0.md): the journal sorts quests by
## their data (main chain / side / class / completed), the seven menu views open, close and
## stay exclusive with consistent titles and close keys, the HUD steps back behind a window,
## the optional UI art falls back to the procedural look, and every view fits the canvas at
## 100 / 125 / 150 % UI.

const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
const SIDE: Array[StringName] = [&"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]
const VIEWS := {&"inventory": KEY_I, &"character": KEY_C, &"talents": KEY_T, &"professions": KEY_P,
	&"journal": KEY_J, &"map": KEY_M, &"settings": KEY_O}

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = session.database.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	StoryService.start(character, &"the_first_signs")
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
	UiSkin.clear_cache()
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 2) -> void:
	for i in count:
		await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


func _texts(root: Node) -> String:
	var lines := PackedStringArray()
	for label in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			lines.append((label as Label).text)
	return "\n".join(lines)


func _page(id: String) -> String:
	map.hud.journal_panel.show_page(id)
	await _frames(2)
	return _texts(map.hud.journal_panel)


# --- 1. journal categories -------------------------------------------------------------------------

func test_quests_are_sorted_by_their_data() -> void:
	var db := session.database
	for quest_id: StringName in PROLOGUE_QUESTS + [&"the_first_signs", &"beyond_the_roots"]:
		check(StoryService.is_main_story(db, quest_id), "%s belongs to the main story" % quest_id)
	for quest_id in SIDE:
		check(not StoryService.is_main_story(db, quest_id), "%s is a side quest" % quest_id)
		check((db.story_quests[quest_id] as StoryQuestDefinition).chapter == "Side Quest", "%s: the data agrees (chapter)" % quest_id)
	check_eq(StoryService.main_story_ids(db).size() + SIDE.size(), db.story_quests.size(), "every story quest has exactly one kind")


func test_journal_pages_main_side_class_completed() -> void:
	StoryService.start(character, &"the_lost_hunter")
	StoryService.start(character, &"embers_of_shelter")
	var roots: StoryQuestDefinition = session.database.story_quests[&"what_the_roots_keep"]
	character.quests.entries[roots.id] = {"state": "completed", "step": roots.steps.size(), "progress": {}}
	character.quests.entries[&"unlock_arcanist"] = {"state": "active", "step": 0, "progress": {}}   # as a started class quest
	map.hud.toggle_journal()
	await _frames(3)
	var journal := map.hud.journal_panel
	check(journal.visible and journal.page == "Main Story", "J opens the Main Story")
	var main := _texts(journal)
	check(main.contains("The First Signs") and not main.contains("A Road Forgotten"), "main quest; earlier chapters folded (Menu UX Polish 1.1)")
	var earlier := journal.find_child("EarlierChapters", true, false) as Button
	check(earlier != null and earlier.text.contains("Earlier chapters"), "the fold names the earlier chapters")
	earlier.pressed.emit()
	await _frames(2)
	check(_texts(journal).contains("A Road Forgotten"), "unfolded: the history stays reachable")
	for quest_id in SIDE:
		check(not main.contains((session.database.story_quests[quest_id] as StoryQuestDefinition).display_name), "no side quest under Main Story: %s" % quest_id)
	var side := await _page("Side Quests")
	check(side.contains("The Lost Hunter") and side.contains("Embers of Shelter"), "active side quests")
	journal.select_quest(&"the_lost_hunter")   # Main Window Layout Lock 1.0: list | details
	await _frames(3)
	check(_texts(journal).contains((session.database.story_quests[&"the_lost_hunter"] as StoryQuestDefinition).steps[0].description), "with their current step")
	check(not side.contains("What the Roots Keep") and side.contains("1 completed"), "a finished one points to Completed")
	check(not side.contains("The First Signs"), "no main quest under Side Quests")
	var classes := await _page("Class Quests")
	var class_quest: ClassQuestDefinition = session.database.quests[&"unlock_arcanist"]
	check(classes.contains(class_quest.display_name) and classes.contains("ACTIVE"), "the class quest has its own page")
	check(not classes.contains("The Lost Hunter"), "no story quest under Class Quests")
	character.quests.entries[&"unlock_arcanist"]["state"] = "completed"
	var done := await _page("Completed")
	check(done.contains("MAIN STORY") and done.contains("SIDE QUESTS") and done.contains("CLASS QUESTS"), "Completed grouped by kind: %s" % done.left(120))
	check(done.contains("A Road Forgotten") and done.contains("What the Roots Keep") and done.contains(class_quest.display_name), "all finished quests")
	check(not done.contains("The Lost Hunter") and not done.contains("The First Signs"), "nothing still running")
	check(journal.find_child("Entry_the_first_binding", true, false) != null, "completed story quests listed for choosing")
	var empty := await _page("Class Quests")
	check(empty.contains("No class quests in progress"), "empty state explained")
	map.hud.objectives.refresh()
	var tracker := map.hud.objectives.full_text()
	check(tracker.contains("The Lost Hunter") and tracker.contains("The First Signs"), "the tracker uses the same split")


# --- 2./3. windows, keys, HUD -----------------------------------------------------------------------

func test_seven_views_titles_close_keys_and_hud_step_back() -> void:
	var hud := map.hud
	for view: StringName in VIEWS:
		await _key(VIEWS[view])
		await _frames(2)
		check_eq(hud.open_menu_view(), view, "%s opens its view" % view)
		var open := 0
		var window: UiWindow = null
		for candidate: UiWindow in hud._windows:
			if candidate.visible:
				open += 1
				window = candidate
		check_eq(open, 1, "%s: exactly one window" % view)
		if window != null:   # Playtest Corrections 1.0: main menus show no Close button (Esc, key, icon close them)
			check(window._title.text != "" and not window.close_button().is_visible_in_tree(), "%s: title, no Close button" % view)
		check(not hud.objectives.is_visible_in_tree() and not hud.minimap_frame.is_visible_in_tree(), "%s: tracker and minimap step back" % view)
		check(not hud.combat_bar_shown(), "%s: combat bar steps back" % view)
		check(hud.health_vessel.is_visible_in_tree() and hud.menu_bar.is_visible_in_tree(), "%s: health and menu bar stay" % view)
		check(hud.menu_bar.buttons[view].active, "%s: its icon is lit" % view)
		await _key(KEY_ESCAPE)
		await _frames(2)
		check(not hud.is_window_open(), "%s: Esc closes" % view)
		check(hud.objectives.is_visible_in_tree() and hud.combat_bar_shown(), "%s: HUD back after closing" % view)
	await _key(KEY_T)
	check_eq(hud.class_panel._title.text, "Skills & Talents", "T: the talent window's own title")
	await _key(KEY_T)
	check(not hud.class_panel.visible, "T again closes")
	await _key(KEY_J)
	await _key(KEY_M)
	check(hud.world_map_panel.visible and not hud.journal_panel.visible, "M replaces the journal (exclusive)")
	await _key(KEY_M)


func test_tabs_switch_and_the_focus_frame_follows() -> void:
	var hud := map.hud
	await _key(KEY_J)
	await _frames(3)
	var first := hud.journal_panel.size
	hud.journal_panel.show_page("Class Quests")
	await _frames(3)
	check(hud.journal_panel.size.y >= first.y - 0.5, "switching tabs never shrinks the open window (%.0f -> %.0f)" % [first.y, hud.journal_panel.size.y])
	var focus := get_viewport().gui_get_focus_owner()
	check(focus == null or focus.name != "TabMainStory", "the focus frame left the old tab")
	for id: String in JournalPanel.PAGES:
		var tab := hud.journal_panel.find_child("Tab%s" % id.validate_node_name(), true, false) as Button
		if not check(tab != null, "tab %s exists" % id):
			continue
		tab.pressed.emit()
		await _frames(2)
		check_eq(hud.journal_panel.page, id, "tab %s shows its page" % id)
	await _key(KEY_J)
	await _key(KEY_O)
	await _frames(3)
	var focused := get_viewport().gui_get_focus_owner() as BaseButton
	check(focused != null and (not focused.toggle_mode or focused.button_pressed or focused.button_group == null),
		"Options: the focus frame sits on the selected choice (%s)" % (focused.text if focused is Button else "-"))
	await _key(KEY_O)


# --- 7. asset fallbacks --------------------------------------------------------------------------------

func test_ui_art_is_optional_and_replaces_the_look() -> void:
	# Core UI Asset Prototype 1.0: real art exists for some ids now - a missing id still falls back
	const MISSING := &"window/never_produced"
	check(UiSkin.texture(MISSING) == null, "missing art: nothing found, no error")
	var flat := StyleBoxFlat.new()
	flat.set_content_margin_all(14)
	check(UiSkin.stylebox(MISSING, flat) == flat, "missing art: the procedural style stays")
	var produced := UiSkin.has(&"window/panel")
	var window_style := UiTheme.get_theme().get_stylebox(&"panel", &"WindowPanel")
	check((window_style is StyleBoxTexture) == produced, "the theme uses the art exactly when the file exists")
	UiSkin.clear_cache()
	# an asset as it would come from assets/ui/ (injected: tests never write into res://)
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.3, 0.25))
	UiSkin._cache[&"window/panel"] = ImageTexture.create_from_image(image)
	var skinned := UiSkin.stylebox(&"window/panel", flat) as StyleBoxTexture
	check(skinned != null and skinned.texture_margin_left == 12.0, "art present: nine-patch with its border")
	check(skinned != null and skinned.get_content_margin(SIDE_TOP) == 14.0, "the layout padding is kept")
	UiSkin._cache[&"menu/journal"] = ImageTexture.create_from_image(image)
	UiSkin._cache[&"hud/slot_frame"] = ImageTexture.create_from_image(image)
	UiSkin._cache[&"map/waystone"] = ImageTexture.create_from_image(image)
	map.hud.menu_bar.buttons[&"journal"].queue_redraw()
	map.hud.skill_bar.refresh()
	await _key(KEY_M)
	await _frames(3)
	check(map.hud.world_map_panel.visible, "components draw with art present (no error)")
	await _key(KEY_M)
	UiSkin.clear_cache()
	check(UiSkin._cache.is_empty(), "cache cleared (injected art gone)")
	check(UiSkin.texture(MISSING) == null, "missing id still missing after clearing")


# --- 9. resolutions / UI scale ---------------------------------------------------------------------------

func test_every_view_fits_at_each_ui_scale() -> void:
	var hud := map.hud
	StoryService.start(character, &"the_lost_hunter")
	for ui_scale: float in [1.0, 1.25, 1.5]:
		session.settings.set_ui_scale(ui_scale)
		await _frames(3)
		var canvas := hud.get_viewport().get_visible_rect()
		for view: StringName in VIEWS:
			hud.open_menu(view)
			await _frames(3)
			for window: UiWindow in hud._windows:
				if not window.visible:
					continue
				window.fit()
				var rect := window.get_global_rect()
				check(canvas.grow(0.5).encloses(rect), "%d %% %s: window inside the canvas (%s)" % [int(ui_scale * 100), view, rect])
				for tabs in window.find_children("*", "UiTabs", true, false):
					var tab_rect := (tabs as Control).get_global_rect()
					check(rect.grow(0.5).encloses(tab_rect), "%d %% %s: tabs inside the window" % [int(ui_scale * 100), view])
				var menu := hud.menu_bar.get_global_rect()
				check(canvas.encloses(menu), "%d %% %s: menu bar on screen" % [int(ui_scale * 100), view])
			hud.close_windows()
			await _frames(1)
