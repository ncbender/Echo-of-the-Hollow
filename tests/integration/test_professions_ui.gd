extends TestCase
## Professions Foundation 1.0 in the world: Haven's Artisan Quarter (ten fixed
## buildings, the four new workshops reachable on foot, the old paths and gates
## still work), the workshops open the professions window at their station,
## the Old Smithy's workbench (ruined: restoration window, restored: forge),
## crafting / learning through the window by real clicks, locked recipes with
## their reason, P away from a workstation (looking only), and the window at
## every UI scale. Only user://test_saves/.

const WORKSHOPS := {
	&"TannersLodge": [&"tanners_lodge", &"leatherworking"],
	&"WeaversHouse": [&"weavers_house", &"tailoring"],
	&"WoodwrightsWorkshop": [&"woodwrights_workshop", &"woodworking"],
	&"AlchemistsCottage": [&"alchemists_cottage", &"alchemy"],
}

var session: SessionState
var map: GameMap
var character: Character
var panel: ProfessionsPanel
var _previous: Character
var _previous_factor: float


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_factor = get_tree().root.content_scale_factor
	character = CharacterFactory.create_new(session.database)
	character.world.set_flag(&"prologue.haven_discovered")
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	map.player.feed_input(InputFrame.new())
	panel = map.hud.professions_panel


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	get_tree().root.content_scale_factor = _previous_factor
	session.settings.reset_to_defaults()
	session.set_character(_previous)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


## Walks the player to `target` with real movement input (collisions apply).
func _walk_to(target: Vector2, limit: int = 900) -> bool:
	var frame := InputFrame.new()
	for i in limit:
		var to := target - map.player.global_position
		if to.length() < 8.0:
			break
		frame.move = to.normalized()
		frame.aim_direction = to.normalized()
		map.player.feed_input(frame)
		await get_tree().physics_frame
	map.player.feed_input(InputFrame.new())
	await get_tree().physics_frame
	return map.player.global_position.distance_to(target) < 8.0


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	await _frames(2)


func _site(node_name: StringName) -> RuinSite:
	return map.get_node("Ruins/%s" % node_name) as RuinSite


func test_haven_has_ten_fixed_buildings_and_the_quarter_is_reachable() -> void:
	var sites := map.find_children("*", "RuinSite", true, false)
	check_eq(sites.size(), 10, "ten fixed buildings")
	var ids := sites.map(func(s: RuinSite) -> StringName: return s.ruin_id)
	for ruin_id: StringName in session.database.ruins:
		check(ruin_id in ids, "%s placed in Haven" % ruin_id)
	var places: Array[Vector2] = []
	for site: RuinSite in sites:
		for other in places:
			check(site.global_position.distance_to(other) > 100.0, "%s has its own place" % site.ruin_id)
		places.append(site.global_position)
	# every workshop of the Artisan Quarter on foot from the plaza, and back
	for node_name: StringName in WORKSHOPS:
		var site := _site(node_name)
		check(site.global_position.x < -408.0, "%s lies in the Artisan Quarter (west)" % node_name)
		map.player.global_position = map.find_spawn(&"default").global_position
		check(await _walk_to(Vector2(site.global_position.x, 0)), "path to %s" % node_name)
		check(await _walk_to(site.global_position + Vector2(0, 20 if site.global_position.y < 0 else -20)), "reached %s" % node_name)
		check(site.player_inside, "standing at %s" % node_name)
		check(site.prompt.begins_with("Work at"), "prompt: %s" % site.prompt)
	# the old places stay where they were
	check_eq(_site(&"OldSmithy").global_position, Vector2(-285, -150), "Old Smithy unchanged")
	check_eq(map.get_node("Waystone").global_position, Vector2(72, -8), "waystone unchanged")
	check_eq(map.get_node("ToShrine").global_position, Vector2(0, -254), "north gate unchanged")
	check(map.get_node("NorthGate") != null and map.get_node("Mara") != null and map.get_node("Edrin") != null, "gate and NPCs still there")
	# the arena door moved to the quarter's west wall and is reached on foot
	map.player.global_position = map.find_spawn(&"default").global_position
	check(await _walk_to(map.find_spawn(&"from_arena").global_position), "walked to the west door through the quarter")


func test_workshop_opens_its_profession_and_crafts_by_click() -> void:
	character.inventory.add_item(&"raw_hide", 4)
	var site := _site(&"TannersLodge")
	map.player.global_position = site.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	site.interact(map.hud)
	await _frames()
	check(panel.visible, "professions window opened")
	check(panel.station_id == &"tanners_lodge" and panel.profession_id == &"leatherworking", "at the Tanner's Lodge: Leatherworking")
	check(panel.side_tabs != null and panel.side_tabs.current == "Crafting", "book registers, Crafting page")
	check_eq(panel.recipe_id, &"lw_tan_hide", "first craftable recipe selected")
	var craft := panel.find_child("Craft", true, false) as Button
	check(craft != null and not craft.disabled, "Craft enabled at the workstation")
	await _click(craft)
	check(character.inventory.count(&"cured_leather") == 1 and character.inventory.count(&"raw_hide") == 2, "crafted by click")
	check(panel.last_ok and panel.last_message.contains("+16 XP") and panel.last_message.contains("first craft"), "feedback: %s" % panel.last_message)
	check_eq(character.professions.xp(&"leatherworking"), 16, "XP")
	var have := panel.find_child("Material_raw_hide", true, false)
	check(have != null and ((have as Node).get_node("Have") as Label).text.begins_with("2 / 2"), "materials refreshed")
	# fast clicks: the third has no materials left
	craft = panel.find_child("Craft", true, false) as Button
	await _click(craft)
	craft = panel.find_child("Craft", true, false) as Button
	check(craft.disabled and craft.tooltip_text.contains("Missing materials"), "disabled with the reason: %s" % craft.tooltip_text)
	await _click(craft)
	check_eq(character.inventory.count(&"cured_leather"), 2, "no craft without materials")
	# walking away closes the window
	map.player.global_position = Vector2.ZERO
	for i in 4:
		await get_tree().physics_frame
	await _frames()
	check(not panel.visible, "closes when walking off")


func test_locked_recipes_show_why_and_patterns_teach() -> void:
	var site := _site(&"TannersLodge")
	map.player.global_position = site.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	site.interact(map.hud)
	await _frames()
	var row := panel.find_child("Recipe_lw_leather_bracers", true, false) as Button
	check(row != null and row.tooltip_text.contains("Pattern: Leather Bracers"), "locked: names the pattern (%s)" % (row.tooltip_text if row else ""))
	await _click(row)
	check_eq(panel.recipe_id, &"lw_leather_bracers", "locked recipes can be looked at")
	check(panel.find_child("Learn", true, false) == null, "no Learn button without the pattern")
	character.inventory.add_item(&"pattern_leather_bracers", 1)
	await _frames()
	var learn := panel.find_child("Learn", true, false) as Button
	check(learn != null, "Learn button with the pattern in the bag")
	await _click(learn)
	check(character.professions.knows(&"lw_leather_bracers") and character.inventory.count(&"pattern_leather_bracers") == 0, "learned, pattern used")
	var craft := panel.find_child("Craft", true, false) as Button
	check(craft.disabled and craft.tooltip_text.contains("level 3"), "still needs level 3: %s" % craft.tooltip_text)
	# alchemy: shown, explained, never craftable
	panel.select_profession(&"alchemy")
	await _frames()
	var potion := panel.find_child("Recipe_al_stoneskin", true, false) as Button
	check(potion != null and potion.tooltip_text.contains("Not brewed in this version"), "data-only potion explained")
	check((panel.find_child("Craft", true, false) as Button).disabled, "potion not craftable")
	# gathering page: resources with level and XP
	panel.show_page("Gathering")
	await _frames()
	check(ProfessionService.professions(session.database, ProfessionDefinition.Kind.GATHERING).any(func(p: ProfessionDefinition) -> bool: return p.id == panel.profession_id), "a gathering profession shown")
	panel.select_profession(&"skinning")
	await _frames()
	check(panel.find_child("Node_stag_remains", true, false) != null, "skinning lists the stag remains")


func test_hotkey_away_from_a_workstation_only_looks() -> void:
	character.inventory.add_item(&"iron_ore", 3)
	var key := InputEventAction.new()
	key.action = &"ui_professions"
	key.pressed = true
	get_viewport().push_input(key, true)
	await _frames()
	check(panel.visible and panel.station_id == &"", "P opens the window without a station")
	check(InputMap.has_action(&"ui_professions"), "P action registered")
	panel.select_profession(&"blacksmithing")
	panel.select_recipe(&"bs_smelt_iron")
	await _frames()
	var craft := panel.find_child("Craft", true, false) as Button
	check(craft.disabled and craft.tooltip_text.contains("The Old Smithy"), "crafting needs the workstation: %s" % craft.tooltip_text)
	panel.craft_selected()
	check_eq(character.inventory.count(&"iron_ore"), 3, "nothing consumed away from the workstation")
	var release := InputEventAction.new()
	release.action = &"ui_professions"
	release.pressed = true
	get_viewport().push_input(release, true)
	await _frames()
	check(not panel.visible, "P closes it again")


func test_old_smithy_workbench_ruined_and_restored() -> void:
	character.inventory.add_item(&"iron_ore", 3)
	var smithy := _site(&"OldSmithy")
	map.player.global_position = smithy.global_position + Vector2(0, 20)
	for i in 4:
		await get_tree().physics_frame
	smithy.interact(map.hud)
	await _frames()
	check(map.hud.restoration_panel.visible, "ruined smithy: restoration window as before (prologue)")
	var bench := map.hud.restoration_panel.find_child("Workbench", true, false) as Button
	check(bench != null, "workbench button in the ruin")
	await _click(bench)
	check(panel.visible and panel.station_id == &"old_smithy" and panel.profession_id == &"blacksmithing", "Blacksmithing at the ruined smithy")
	panel.select_recipe(&"bs_smelt_iron")
	check_eq(panel.craft_selected().error, "", "smelting works while ruined")
	map.hud.close_windows()
	character.world.set_restoration(&"old_smithy", &"restored")
	await _frames()
	smithy.interact(map.hud)
	await _frames()
	check(map.hud.crafting_panel.visible, "restored smithy: the Resonance Forge")
	map.hud.crafting_panel.select_section("Craft")
	await _frames()
	var forge_bench := map.hud.crafting_panel.find_child("Workbench", true, false) as Button
	check(forge_bench != null, "workbench button in the forge")
	await _click(forge_bench)
	check(panel.visible and panel.station_id == &"old_smithy", "forge -> Blacksmithing workbench")


func test_window_fits_every_ui_scale() -> void:
	GameMap.give_crafting_kit(character)
	for value in UserSettings.UI_SCALES:
		session.settings.set_ui_scale(value)
		await _frames(4)
		for page_name: String in ProfessionsPanel.PAGES:
			map.hud.open_professions(&"tanners_lodge")
			panel.show_page(page_name)
			await _frames(4)
			panel.fit()
			var view := get_tree().root.get_visible_rect()
			var rect := panel.get_global_rect()
			var tag := "%d %% %s" % [roundi(value * 100.0), page_name]
			check(view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(rect), "%s: window inside the canvas (%s in %s)" % [tag, rect, view.size])
			check(view.encloses(panel.side_tabs.get_global_rect()), "%s: book registers on screen" % tag)
			for card: Control in panel.find_children("Prof_*", "Button", true, false):
				check(card.size.x <= ProfessionsPanel.CARD_WIDTH + 1.0 and card.size.y <= 80.0, "%s: compact card %s (%s)" % [tag, card.name, card.size])
			if page_name == "Crafting":
				var craft := panel.find_child("Craft", true, false) as Button
				check(craft != null and panel.footer.is_ancestor_of(craft), "%s: Craft sits in the fixed footer" % tag)
				if craft != null:
					check(rect.encloses(craft.get_global_rect()) and view.encloses(craft.get_global_rect()),
						"%s: Craft visible without scrolling (%s in %s)" % [tag, craft.get_global_rect(), rect])
			map.hud.close_windows()
