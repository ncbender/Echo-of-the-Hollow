extends TestCase
## UI Layout Lock 1.0 (docs/UI_LAYOUT_LOCK_1_0.md): the one icon menu bar (seven views, click
## = key, again = close, one window at a time, Esc), C = character overview and T = talents,
## mouse presses on the HUD never attack or charge (also held, also into a closing window),
## the HUD zones never overlap at 100 / 125 / 150 % UI scale, the quest tracker (three side
## quests, "+N more", rewards, collapse) and the bottom HUD stepping back for a dialogue.

const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
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
	get_tree().paused = false
	Input.action_release(&"attack_light")
	Input.action_release(&"attack_heavy")
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


## A mouse button event at a canvas position, through the real input path (Input + GUI).
func _mouse(button: MouseButton, pressed: bool, at_canvas: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	event.position = get_tree().root.get_final_transform() * at_canvas
	event.global_position = event.position
	var motion := InputEventMouseMotion.new()
	motion.position = event.position
	motion.global_position = event.position
	Input.parse_input_event(motion)
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _centre(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


# --- A. menu --------------------------------------------------------------------------------------

func test_seven_icons_and_seven_keys_open_the_same_views() -> void:
	var hud := map.hud
	check_eq(hud.find_children("*", "HudMenuBar", true, false).size(), 1, "exactly one menu bar")
	check_eq(hud.menu_bar.buttons.size(), 7, "seven icons")
	for id: StringName in VIEWS:
		var icon := hud.menu_bar.buttons[id] as Button
		check(icon.focus_mode == Control.FOCUS_NONE and icon.text == "", "%s: icon only, takes no keyboard focus" % id)
		icon.pressed.emit()
		await _frames()
		check_eq(hud.open_menu_view(), id, "click opens %s" % id)
		check((hud.menu_bar.buttons[id] as HudMenuBar.MenuIcon).active, "%s icon lit" % id)
		icon.pressed.emit()
		await _frames()
		check_eq(hud.open_menu_view(), &"", "a second click closes %s" % id)
		await _key(VIEWS[id])
		check_eq(hud.open_menu_view(), id, "key opens %s" % id)
		var tooltip := icon.tooltip_text
		check(tooltip.contains("[%s]" % OS.get_keycode_string(VIEWS[id])), "%s tooltip names its key: %s" % [id, tooltip])
		await _key(VIEWS[id])
		check_eq(hud.open_menu_view(), &"", "the key again closes %s" % id)


func test_c_is_the_character_overview_and_t_the_talents() -> void:
	var hud := map.hud
	await _key(KEY_C)
	check(hud.inventory_panel.visible and hud.inventory_panel.left_page == "Overview", "C: the character overview")
	await _key(KEY_I)
	check(hud.inventory_panel.visible and hud.inventory_panel.left_page == "Equipment", "I switches to the equipment page")
	await _key(KEY_T)
	check(hud.class_panel.visible and hud.class_panel.page == "Talents" and not hud.inventory_panel.visible, "T: talents, one window only")
	await _key(KEY_J)
	check(hud.journal_panel.visible and not hud.class_panel.visible, "J replaces it")
	await _key(KEY_ESCAPE)
	check(not hud.is_window_open(), "Esc closes the window")
	await _key(KEY_ESCAPE)
	check(hud.pause_menu.visible, "Esc again: the pause menu as before")
	hud.pause_menu.hide()
	get_tree().paused = false


# --- B. mouse and combat --------------------------------------------------------------------------

func test_hud_clicks_and_holds_never_attack_but_the_playfield_does() -> void:
	var player := map.player
	player.feed_input(InputFrame.new())   # the test reads the device input itself
	var input := player.input
	var icon := map.hud.menu_bar.buttons[&"journal"] as Control
	# click on an icon: the GUI takes it
	await _mouse(MOUSE_BUTTON_LEFT, true, _centre(icon))
	var frame := input.poll(player)
	check(not frame.light_pressed and not frame.light_held, "LMB on an icon: no quick attack")
	await _mouse(MOUSE_BUTTON_LEFT, false, _centre(icon))
	check(map.hud.journal_panel.visible, "the click reached the icon (journal open)")
	map.hud.close_windows()
	await _frames()
	# held over the UI
	await _mouse(MOUSE_BUTTON_LEFT, true, _centre(icon))
	for i in 3:
		await get_tree().process_frame
		frame = input.poll(player)
		check(not frame.light_held, "LMB held over the UI: no hold")
	await _mouse(MOUSE_BUTTON_LEFT, false, _centre(icon))
	map.hud.close_windows()
	await _mouse(MOUSE_BUTTON_RIGHT, true, _centre(map.hud.skill_bar.get_child(0) as Control))
	for i in 3:
		await get_tree().process_frame
		frame = input.poll(player)
		check(not frame.heavy_pressed and not frame.heavy_held, "RMB held over a skill slot: no charge")
	await _mouse(MOUSE_BUTTON_RIGHT, false, _centre(map.hud.skill_bar.get_child(0) as Control))
	input.poll(player)
	# the playfield still works
	var free := get_tree().root.get_visible_rect().size * Vector2(0.5, 0.45)
	await _mouse(MOUSE_BUTTON_LEFT, true, free)
	frame = input.poll(player)
	check(frame.light_pressed and frame.light_held, "LMB on the playfield attacks and holds")
	# held into a window and out again: no attack afterwards
	player.use_external_input = false
	map.hud.toggle_journal()
	for i in 3:
		await get_tree().physics_frame
	map.hud.close_windows()
	player.feed_input(InputFrame.new())
	await get_tree().process_frame
	frame = input.poll(player)
	check(not frame.light_held, "a button held into a window does not attack once it closes")
	await _mouse(MOUSE_BUTTON_LEFT, false, free)


# --- C. layout ------------------------------------------------------------------------------------

func test_zones_never_overlap_at_three_ui_scales() -> void:
	for quest_id: StringName in [&"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]:
		character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	map.spawn_enemy(map.player.global_position + Vector2(120, 0), load("res://data/enemies/grove_warden_config.tres"))
	map.hud.show_hint("A tutorial hint")
	map.hud.loot_feed.push(&"iron_ore", 2)
	map.hud.loot_feed.push(&"timber", 3)
	map.hud.loot_feed.push(&"stone", 1)
	var hud := map.hud
	for entry: Array in [[1.0, Vector2(1920, 1080), 200.0], [1.25, Vector2(1536, 864), 200.0], [1.5, Vector2(1280, 720), 168.0]]:
		check(session.settings.set_ui_scale(entry[0]), "UI %d %%" % int(entry[0] * 100))
		await _frames(6)
		var canvas := get_tree().root.get_visible_rect().size
		check(canvas.is_equal_approx(entry[1]), "%d %%: canvas %s" % [int(entry[0] * 100), canvas])
		check(is_equal_approx(hud.minimap_frame.size.x, entry[2]), "%d %%: minimap area %.0f" % [int(entry[0] * 100), hud.minimap_frame.size.x])
		var parts := {"status": hud.health_vessel, "resource": hud.resource_vessel, "boss": hud.target_frame, "minimap": hud.minimap_frame, "tracker": hud.objectives,
			"feed": hud.loot_feed, "menu": hud.menu_bar, "combat": hud._combat_row, "hint": hud.hint_panel}
		for name: String in parts:
			var control := parts[name] as Control
			if not check(control.is_visible_in_tree(), "%d %%: %s shown" % [int(entry[0] * 100), name]):
				continue
			check(Rect2(Vector2.ZERO, canvas).grow(0.5).encloses(control.get_global_rect()), "%d %%: %s inside the screen %s" % [int(entry[0] * 100), name, control.get_global_rect()])
		for pair: Array in [["status", "boss"], ["boss", "minimap"], ["minimap", "tracker"], ["tracker", "feed"], ["menu", "combat"],
				["combat", "feed"], ["hint", "status"], ["hint", "tracker"], ["status", "menu"], ["resource", "feed"], ["status", "combat"], ["resource", "combat"]]:
			var a := (parts[pair[0]] as Control).get_global_rect()
			var b := (parts[pair[1]] as Control).get_global_rect()
			check(not a.intersects(b), "%d %%: %s %s and %s %s apart" % [int(entry[0] * 100), pair[0], a, pair[1], b])
		check(hud.target_frame.size.x >= 400.0, "%d %%: boss bar still wide (%.0f)" % [int(entry[0] * 100), hud.target_frame.size.x])
		var feed_top := canvas.y - hud.feed_bottom - hud.loot_feed.max_rows * GameHud.FEED_ROW
		check(hud.objectives.get_global_rect().end.y <= feed_top + 0.5, "%d %%: tracker ends above the feed area" % int(entry[0] * 100))
		var reward := hud.objectives._rewards
		check(reward.is_visible_in_tree() and reward.text.contains("Return to Edrin Vale")
			and hud.objectives.get_global_rect().grow(0.5).encloses(reward.get_global_rect()), "%d %%: the open reward stays in sight (never scrolled away)" % int(entry[0] * 100))
		var prompt := hud._prompt_box
		var column := hud._combat_unit as Control   # Combat HUD UX 2.0: vessels + combat bar + EXP bar
		check(prompt.get_parent() == column.get_parent() and prompt.get_index() < column.get_index()
			and hud.toasts.get_index() < prompt.get_index(), "%d %%: toasts, then prompt, stacked above the combat bar" % int(entry[0] * 100))
	session.settings.set_ui_scale(1.0)


# --- D. tracker -----------------------------------------------------------------------------------

func test_tracker_three_side_quests_more_rewards_and_collapse() -> void:
	var hud := map.hud
	for quest_id: StringName in [&"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]:
		character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	await _frames(3)
	var tracker := hud.objectives
	var text := tracker.full_text()
	check(text.contains("The First Signs") and text.contains("Find the way east of the Whisper Forest") and not text.contains("The Roots Remember"),
		"main quest: short title and the concrete goal, no chapter (Combat HUD UX 2.0)")
	check(not text.contains("Edrin warned") and not text.contains("[J]") and not text.contains("[M]"), "no narrative summary, no key hints")
	for name: String in ["The Lost Hunter", "What the Roots Keep", "Embers of Shelter"]:
		check(text.contains(name), "%s listed" % name)
	check(text.contains("Return to Edrin Vale for your reward"), "the open reward stays")
	check(not text.contains("more in the Journal"), "no '+N more' with three side quests")
	var hunter := tracker.find_child("Side0", true, false) as Control
	check(hunter.tooltip_text.contains("Hunter's Trail"), "the tooltip holds the full step text")
	# a fourth (synthetic) side quest: "+1 more"
	var extra: StoryQuestDefinition = session.database.story_quests[&"the_lost_hunter"].duplicate()
	extra.id = &"test_extra_side"
	session.database.story_quests[extra.id] = extra
	character.quests.entries[extra.id] = {"state": "active", "step": 0, "progress": {}}
	await _frames(2)
	check(tracker.full_text().contains("+1 more in the Journal"), "a fourth side quest: +1 more in the Journal")
	session.database.story_quests.erase(extra.id)
	character.quests.entries.erase(extra.id)
	await _frames(2)
	var tall := tracker.size.y
	var before := character.to_dict()
	before.erase("play_time")
	(tracker.find_child("Collapse", true, false) as Button).pressed.emit()
	await _frames(3)
	check(ObjectivePanel.collapsed and tracker.size.y < tall, "collapsed: smaller (%.0f < %.0f)" % [tracker.size.y, tall])
	var mark := tracker.find_child("RewardMark", true, false) as Label
	check(tracker.full_text() == "" and mark.is_visible_in_tree() and mark.tooltip_text.contains("Return to Edrin Vale for your reward"),
		"collapsed: the header only, a reward mark names the open reward")
	check(tracker.size.y <= 40.0, "collapsed: one slim header row (%.0f px)" % tracker.size.y)
	var after := character.to_dict()
	after.erase("play_time")
	check_eq(JSON.stringify(after), JSON.stringify(before), "collapsing changes no character data")
	(tracker.find_child("Collapse", true, false) as Button).pressed.emit()
	await _frames(3)
	check(not ObjectivePanel.collapsed and tracker.full_text().contains("The Lost Hunter"), "expanded again")
	await _key(KEY_J)
	check(hud.journal_panel.visible, "the Journal holds the details (J)")


# --- E. dialogue ----------------------------------------------------------------------------------

func test_bottom_hud_steps_back_for_a_dialogue() -> void:
	var hud := map.hud
	hud.open_lines([{"name": "Note", "text": "A line.", "color": UiTheme.PARCHMENT, "note": true}] as Array[Dictionary])
	await _frames(3)
	check(hud.dialogue_panel.visible, "dialogue open")
	check(not hud.menu_bar.visible and not hud._combat_row.is_visible_in_tree(), "menu bar and combat bar step back")
	check(hud.objectives.is_visible_in_tree(), "the tracker stays")
	check(not hud.health_vessel.is_visible_in_tree(), "Combat HUD UX 2.0: the combat unit with its vessels steps back for the dialogue box")
	hud.close_windows()
	await _frames(3)
	check(hud.menu_bar.visible and hud._combat_row.is_visible_in_tree() and hud.health_vessel.is_visible_in_tree(), "back after the dialogue")
