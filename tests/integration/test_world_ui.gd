extends TestCase
## UI/UX redesign F: journal (Main Story · Side Quests · Haven), region map,
## dialogue (note look, no double advance), restoration stages, waystone list.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	for event: StringName in [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
			&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
			&"talk:mara_road_end", &"enter:home_base"]:
		StoryService.notify(character, event)
	character.inventory.add_item(&"supply_crate", 2)
	session.set_character(character)
	session.travel(&"home_base", &"default", false)
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.map_id == &"home_base" and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _texts(node: Node) -> String:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func test_journal_pages() -> void:
	var key := InputEventAction.new()
	key.action = &"ui_journal"
	key.pressed = true
	check(InputMap.has_action(&"ui_journal") and InputMap.has_action(&"ui_map"), "J and M actions registered")
	map.hud.toggle_journal()
	var journal := map.hud.journal_panel
	check(journal.visible, "journal open")
	var story := _texts(journal)
	check(story.contains("Shelter Among the Trees") and story.contains("[now]"), "current story step: %s" % story.left(200))
	check(story.contains("A Road Forgotten") and story.contains("Completed"), "completed quests listed")
	check(not story.contains("The Whispering Stone"), "future quests are not spoiled")
	journal.show_page("Side Quests")
	check(_texts(journal).contains("class station"), "empty side quests explained")
	journal.show_page("Haven")
	var haven := _texts(journal)
	check(haven.contains("The Old Smithy") and haven.contains("[Ruined]") and haven.contains("Revitalized"), "ruins with stage track")
	check(haven.contains("Restoration unavailable for now."), "unavailable ruins say so")


func test_world_map() -> void:
	map.hud.toggle_map()
	check(map.hud.world_map_panel.visible, "map open")
	var known := WorldMapPanel.known_maps(character)
	check(&"home_base" in known, "Haven known")
	check(not &"prologue" in known, "developer area never drawn")
	check(not &"whispering_stone" in known, "unvisited places stay unknown")
	for map_def: MapDefinition in session.database.maps.values():
		for neighbor in map_def.neighbors:
			check(session.database.maps.has(neighbor), "%s neighbour %s exists" % [map_def.id, neighbor])
			check(map_def.id in (session.database.maps[neighbor] as MapDefinition).neighbors, "%s <-> %s both ways" % [map_def.id, neighbor])


func test_dialogue_guard_and_notes() -> void:
	var panel := map.hud.dialogue_panel
	var lines: Array[Dictionary] = [{"name": "Mara Veyne", "text": "One."}, {"name": "Mara Veyne", "text": "Two."}]
	map.hud.open_lines(lines)
	panel._on_continue_pressed()
	check_eq(panel.current_text(), "One.", "a press right after a line is ignored (no double advance)")
	panel._guard_left = 0.0
	panel._on_continue_pressed()
	check_eq(panel.current_text(), "Two.", "the next press continues")
	panel.advance()
	var note: Array[Dictionary] = [{"name": "Memory Fragment", "text": "Three stood here when the stone was whole.", "note": true}]
	map.hud.open_lines(note)
	check(_texts(panel).contains("Close  [G]") or (panel.find_child("Continue", true, false) as Button).text.contains("Close"), "notes close instead of continuing")


func test_restoration_window_stages_and_costs() -> void:
	var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
	map.player.global_position = smithy.global_position + Vector2(0, 26)
	for i in 4:
		await get_tree().physics_frame
	smithy.interact(map.hud)
	var panel := map.hud.restoration_panel
	var text := _texts(panel)
	check(text.contains("[Ruined]") and text.contains("AFTER RESTORING") and text.contains("Smithy"), "before / after: %s" % text.left(300))
	check(text.contains("have 2"), "costs with what you have")
	check(text.contains("Revitalized: not available in this version."), "revitalized never offered")
	check_eq(panel.restore(), "", "restore still works")


func test_waystone_list_states() -> void:
	var waystone := map.get_node("Waystone") as Waystone
	map.player.global_position = waystone.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	waystone.interact(map.hud)
	var text := _texts(map.hud.waystone_panel)
	check(text.contains("You are here") and text.contains("Undiscovered"), "waystone states in words")
	check(map.hud.waystone_panel.find_children("Travel", "Button", true, false).is_empty(), "no other awake waystone yet: no travel button")
