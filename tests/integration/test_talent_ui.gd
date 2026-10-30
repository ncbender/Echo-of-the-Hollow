extends TestCase
## Skills & Talents UX 2.0 Phase 2 (docs/SKILLS_TALENTS_UX_2_0.md): the Talents page - three specialization
## buttons (name · points), ONE tree with four tiers (4 / 4 / 4 + capstone), lines only for the six direct
## upgrades, a compact action row with the one Learn button (Menu UX Polish 1.0: effects / requirements in the
## tooltip, no permanent text block). A click only selects; Learn spends exactly one point through TalentService.
## All three classes, all nine trees, real window.

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = _make(&"warrior", 20)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	panel = map.hud.class_panel


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous_character)


func _make(class_id: StringName, level: int) -> Character:
	var result := CharacterFactory.create_new(session.database)
	result.classes.unlock(class_id)
	result.classes.set_active(class_id)
	var definition := session.database.get_class_def(class_id)
	var xp := 0
	for l in range(1, level):
		xp += definition.xp_to_next(l)
	result.classes.add_xp(class_id, xp)
	return result


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _at_station() -> ClassStation:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	return station


func _view() -> TalentTreeView:
	return panel._trees[0] if not panel._trees.is_empty() else null


func _learn_button() -> Button:
	return panel.find_child("LearnTalent", true, false) as Button


func _tab(tree_id: StringName) -> Button:
	return panel.find_child("TreeTab_%s" % tree_id, true, false) as Button


func _detail_text() -> String:
	var texts: PackedStringArray = []
	for label: Label in panel.find_child("TalentDetail", true, false).find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


## Menu UX Polish 1.0: effects, ranks and requirements live in the talent tooltip (no permanent text block).
func _tooltip_text(node_id: StringName) -> String:
	var texts: PackedStringArray = []
	for line in TalentTooltip.lines(character, &"warrior", session.database.talent_nodes[node_id]):
		texts.append(line.text)
	return " | ".join(texts)


## Selects `node_id` with its node button (as a click does) and presses Learn `times` times.
func _learn(node_id: StringName, times: int = 1) -> void:
	_view().button_for(node_id).pressed.emit()
	await _frames(1)
	for i in times:
		var learn := _learn_button()
		if not check(not learn.disabled, "Learn enabled for %s (%s)" % [node_id, learn.tooltip_text]):
			return
		learn.pressed.emit()
		await _frames(2)


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
	await _frames(3)


func test_tree_buttons_one_tree_and_click_only_selects() -> void:
	map.hud.toggle_talents()
	await _frames(4)
	check(panel.visible and panel.page == "Talents", "talent page open")
	var trees := TalentService.trees_of(session.database, &"warrior")
	for tree in trees:
		var tab := _tab(tree.id)
		check(tab != null and tab.text == "%s  ·  0" % tree.display_name, "button %s: name and points from the data (%s)" % [tree.id, tab.text if tab else "-"])
		check(tab.focus_mode == Control.FOCUS_ALL and tab.theme_type_variation == &"CardButton", "%s: keyboard focus, gold card when active" % tree.id)
	check_eq(panel.find_children("Tree_*", "TalentTreeView", true, false).size(), 1, "exactly one tree shown")
	check(_tab(&"war_berserker").button_pressed and not _tab(&"war_warbreaker").button_pressed, "first tree active (no points anywhere)")
	var points := TalentService.points_available(character, &"warrior")
	check_eq(points, 16, "level 20: 16 points")
	# a click only selects
	var view := _view()
	view.button_for(&"war_b_seething").pressed.emit()
	await _frames(2)
	check_eq(character.builds.get_build().rank(&"war_b_seething"), 0, "click spends nothing")
	check_eq(panel.selected_talent(), &"war_b_seething", "click selects")
	check(view.button_for(&"war_b_seething").button_pressed, "selected node marked (gold card)")
	check(_detail_text().contains("Seething Blood") and not _detail_text().contains("+2% attack speed"), "action row after one click: name, no effect text block: %s" % _detail_text())
	check(_tooltip_text(&"war_b_seething").contains("+2% attack speed") and _tooltip_text(&"war_b_seething").contains("Requirements"), "effect and requirements in the tooltip")
	check(panel.find_child("DetailScroll", true, false) == null, "no permanent detail text block")
	check(_detail_text().contains("Cost: 1 point per rank") and (panel.find_child("TalentPoints", true, false) as Label).text == "16 Talent Points free", "cost in the action row, free points in the page header")
	check_eq(_learn_button().text, "Learn", "learn button")
	_learn_button().pressed.emit()
	await _frames(2)
	check_eq(character.builds.get_build().rank(&"war_b_seething"), 1, "Learn: exactly one rank")
	check_eq(TalentService.points_available(character, &"warrior"), 15, "exactly one point spent")
	check_eq(panel.selected_talent(), &"war_b_seething", "still selected after learning")
	check_eq(_learn_button().text, "Upgrade to rank 2", "upgrade text")
	await _frames(2)
	check(not panel._scroll.get_h_scroll_bar().visible and not panel._scroll.get_v_scroll_bar().visible, "the window never scrolls (with free points and Upgrade)")
	var detail_rect := (panel.find_child("TalentDetail", true, false) as Control).get_global_rect()
	check(detail_rect.grow(1.0).encloses(_learn_button().get_global_rect()) and panel.get_global_rect().encloses(detail_rect), "Upgrade button inside the action row and the window")
	check(_tab(&"war_berserker").text.ends_with("·  1"), "tree button counts the point: %s" % _tab(&"war_berserker").text)
	check((panel.find_child("Status", true, false) as Label).text.begins_with("Learned"), "result in the bottom row")
	# locked tier: selectable, conditions readable, Learn disabled with the reason
	_view().button_for(&"war_b_bloodlust").pressed.emit()
	await _frames(2)
	check(_detail_text().contains("Needs 5 points in lower tiers of Berserker (1 / 5)") and _tooltip_text(&"war_b_bloodlust").contains("5 points in lower tiers of Berserker (1 / 5)"), "concrete block reason in the action row: %s" % _detail_text())
	check(_learn_button().disabled and _learn_button().tooltip_text.contains("5 points"), "locked: Learn disabled with the reason")
	check_eq(_view().button_for(&"war_b_bloodlust").get_node("Rank").text, "0/5", "Locked said once (padlock), not again in words")
	check_eq((_view().button_for(&"war_b_bloodlust") as TalentTreeView.TalentButton).state, "Locked", "the node is locked")
	check_eq(panel._tier_scale.progress_text(2), "1/5", "tier 2 progress on the scale")
	await _learn(&"war_b_seething", 4)
	check_eq(_view().button_for(&"war_b_seething").get_node("Rank").text, "5/5 Maxed", "maxed node")
	check(_learn_button().disabled and _learn_button().text == "Maxed", "maxed: no Learn")
	check_eq(panel._tier_scale.progress_text(2), "Open", "tier 2 open with 5 points in tier 1")
	_view().button_for(&"war_b_bloodlust").pressed.emit()
	await _frames(2)
	check(not _learn_button().disabled, "tier 2 talent learnable now")
	check_eq(_view().button_for(&"war_b_bloodlust").get_node("Rank").text, "0/5 Available", "available state")
	# keyboard: focus shows the tooltip, Enter selects - never learns
	_view().button_for(&"war_b_temper").grab_focus()
	await _frames(2)
	check(panel.talent_tooltip.visible and panel.talent_tooltip.node_id == &"war_b_temper", "focus shows the tooltip")
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter)
	await _frames(2)
	check_eq(panel.selected_talent(), &"war_b_temper", "Enter selects")
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 0, "Enter never learns")


func test_tree_switch_keeps_investments_window_and_selection() -> void:
	map.hud.toggle_talents()
	await _frames(4)
	await _learn(&"war_b_temper", 2)
	var window := panel.get_global_rect()
	var tabs := (panel.find_child("BookTabs", true, false) as Control).get_global_rect()
	_tab(&"war_warbreaker").pressed.emit()
	await _frames(4)
	check_eq(_view().tree.id, &"war_warbreaker", "Warbreaker shown")
	check(_tab(&"war_warbreaker").button_pressed and not _tab(&"war_berserker").button_pressed, "active tree button switched")
	check(panel.get_global_rect().is_equal_approx(window), "window did not move or resize: %s -> %s" % [window, panel.get_global_rect()])
	check((panel.find_child("BookTabs", true, false) as Control).get_global_rect().is_equal_approx(tabs), "book tabs unchanged")
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 2, "investments kept")
	check(_tab(&"war_berserker").text.ends_with("·  2"), "other tree keeps its count")
	await _learn(&"war_wb_hands")
	_tab(&"war_berserker").pressed.emit()
	await _frames(4)
	check_eq(panel.selected_talent(), &"war_b_temper", "selection remembered per tree")
	check_eq(_view().button_for(&"war_b_temper").get_node("Rank").text, "2/3 Learned", "partly learned state")
	check_eq(character.builds.get_build().rank(&"war_wb_hands"), 1, "Warbreaker point kept")
	panel.show_page("Skills")
	panel.show_page("Talents")
	await _frames(3)
	check_eq(_view().tree.id, &"war_berserker", "page switch keeps the chosen tree")


## Every tree of every class at 1920x1080 / 100 %: 4 / 4 / 4 + capstone, tiers aligned, nothing outside the
## window, no overlap, no scrolling, whole names (no word cut, at most two lines), lines only for real
## prerequisites, straight between neighbouring tiers and never through a card.
func test_every_tree_readable_at_100_percent() -> void:
	session.settings.set_ui_scale(1.0)
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		var other := _make(class_id, 40)
		for tree in TalentService.trees_of(session.database, class_id):
			panel.open(other, null, "Talents")
			panel.show_tree(tree.id)
			await _frames(4)
			var view := _view()
			check_eq(view.tree, tree, "%s shown" % tree.id)
			var scroll := panel.find_child("TreeScroll", true, false) as ScrollContainer
			check(not scroll.get_v_scroll_bar().visible and not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible,
				"%s: no scrolling" % tree.id)
			var window := panel.get_global_rect()
			var detail := (panel.find_child("TalentDetail", true, false) as Control).get_global_rect()
			check(window.encloses(detail), "%s: action row inside the window" % tree.id)
			var rows := {}
			var per_tier := {}
			var cards: Array[Rect2] = []
			for node in tree.nodes:
				var button := view.button_for(node.id) as TalentTreeView.TalentButton
				var rect := button.get_global_rect()
				check(window.encloses(rect) and not rect.intersects(detail), "%s: %s inside, above the action row" % [tree.id, node.id])
				for other_rect in cards:
					check(not other_rect.grow(-1.0).intersects(rect.grow(-1.0)), "%s: %s overlaps nothing" % [tree.id, node.id])
				cards.append(rect)
				per_tier[node.tier] = per_tier.get(node.tier, 0) + 1
				if rows.has(node.tier):
					check(absf(rows[node.tier] - rect.position.y) < 0.5, "%s: tier %d one row" % [tree.id, node.tier])
				rows[node.tier] = rect.position.y
				var label := button.name_label
				check(label.text == node.display_name and label.get_line_count() <= TalentLayout.NAME_LINES, "%s: whole name in two lines" % node.id)
				var font := label.get_theme_font(&"font")
				var font_size := label.get_theme_font_size(&"font_size")
				for word in node.display_name.split(" "):
					check(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x, "%s: '%s' never cut" % [node.id, word])
				check(font.get_string_size(button.rank_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= button.rank_label.size.x, "%s: rank line fits" % node.id)
				if node.is_capstone():
					check(absf(view.card_rect(node.id).get_center().x - view.size.x * 0.5) < 1.0, "%s: capstone in the middle" % node.id)
			check_eq(per_tier, {1: 4, 2: 4, 3: 4, 4: 1}, "%s: four tiers" % tree.id)
			var expected := 0
			for node in tree.nodes:
				expected += node.prerequisites.size()
			check_eq(view.links().size(), expected, "%s: one line per prerequisite, nothing else" % tree.id)
			for link: Array in view.links():
				var path := view.link_path(link[0], link[1])
				if view.button_for(link[1]).node.tier - view.button_for(link[0]).node.tier == 1:
					check(path.size() == 2 and is_equal_approx(path[0].x, path[1].x), "%s: %s straight under %s" % [tree.id, link[1], link[0]])
				for index in path.size() - 1:
					for step in 21:
						var point := path[index].lerp(path[index + 1], step / 20.0)
						for node in tree.nodes:
							if view.card_rect(node.id).grow(-2.0).has_point(point):
								fail("%s: line %s -> %s runs through %s" % [tree.id, link[0], link[1], node.id])
		await _frames(1)
	panel.hide()


func test_skill_unlock_upgrade_capstone_reset_and_class_switch() -> void:
	character.classes.add_xp(&"warrior", 400000)   # level 60: 56 points
	var station := await _at_station()
	map.hud.open_class_panel(station)
	panel.show_page("Talents")
	await _frames(4)
	var view := _view()
	for node in view.tree.nodes:
		var art := view.button_for(node.id).find_child("SkillIcon", true, false)
		check((art != null) == (node.kind == TalentNodeDefinition.Kind.ACTIVE), "%s: skill art only for a skill unlock" % node.id)
	await _learn(&"war_b_seething", 5)
	_view().button_for(&"war_b_cyclone").pressed.emit()
	await _frames(2)
	check(_learn_button().disabled and _learn_button().tooltip_text.contains("Whirlwind"), "direct upgrade waits for Whirlwind")
	check(_detail_text().contains("Requires Whirlwind"), "parent named as the block reason")
	await _learn(&"war_b_whirlwind")
	check(SkillBook.is_skill_available(character, &"warrior", &"whirlwind"), "skill unlocked through Learn")
	check_eq(_view().button_for(&"war_b_whirlwind").get_node("Rank").text, "1/1 Maxed", "skill node maxed")
	await _learn(&"war_b_cyclone")
	check_eq(character.builds.get_build().rank(&"war_b_cyclone"), 1, "upgrade learned after its parent")
	# capstone: locked below 30 points in the tree, learnable at 30
	_view().button_for(&"war_b_unbound").pressed.emit()
	await _frames(2)
	check(_learn_button().disabled and _detail_text().contains("Capstone"), "capstone locked: %s" % _detail_text())
	for entry: Array in [[&"war_b_temper", 3], [&"war_b_relentless", 3], [&"war_b_bloodlust", 5], [&"war_b_pace", 5], [&"war_b_momentum", 3], [&"war_b_bloodrush", 5]]:
		await _learn(entry[0], entry[1])
	check_eq(TalentService.points_in_tree(character.builds.get_build().talents, _view().tree), 31, "31 points in Berserker (30 needed)")
	check_eq(panel._tier_scale.progress_text(4), "Open", "capstone tier open")
	await _learn(&"war_b_unbound")
	check(SkillBook.is_skill_available(character, &"warrior", &"unbound_fury"), "capstone skill unlocked")
	check_eq(TalentService.points_available(character, &"warrior"), 56 - 32, "32 points spent, one per Learn")
	# reset at the station: everything back, the page shows it
	var respec := panel.find_child("Respec", true, false) as Button
	check(respec != null and not respec.disabled, "reset available at the station")
	respec.pressed.emit()
	await _frames(3)
	check(character.builds.get_build().talents.is_empty(), "talents reset")
	check(_tab(&"war_berserker").text.ends_with("·  0"), "tree button back to 0")
	check((panel.find_child("TalentPoints", true, false) as Label).text == "56 Talent Points free", "all points free again")
	# class switch: the page follows the active class
	character.classes.unlock(&"arcanist")
	check_eq(character.switch_class(&"arcanist", true), "", "switched to the arcanist")
	panel.show_page("Talents")
	await _frames(3)
	for tree in TalentService.trees_of(session.database, &"arcanist"):
		check(_tab(tree.id) != null, "arcanist tree button %s" % tree.display_name)
	check(_tab(&"war_berserker") == null, "no warrior trees any more")


## Real mouse: a click on a node selects (no point), a click on Learn learns one rank; the node does not move.
func test_mouse_click_selects_and_learn_button_learns() -> void:
	map.hud.toggle_talents()   # away from the station: learning is allowed, reset is not
	await _frames(4)
	var button := _view().button_for(&"war_b_temper")
	var before := button.get_global_rect()
	await _push_mouse(before.get_center())
	check(panel.talent_tooltip.visible and panel.talent_tooltip.node_id == &"war_b_temper", "hover shows the tooltip")
	await _push_mouse(before.get_center(), MOUSE_BUTTON_LEFT)
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 0, "a click only selects")
	check_eq(panel.selected_talent(), &"war_b_temper", "selected by the click")
	await _push_mouse(_learn_button().get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	check_eq(character.builds.get_build().rank(&"war_b_temper"), 1, "Learn by mouse: one rank")
	check(_view().button_for(&"war_b_temper").get_global_rect().is_equal_approx(before), "node did not move")
	check(not panel.talent_tooltip.visible, "no tooltip over the Learn button")
	var respec := panel.find_child("Respec", true, false) as Button
	check(respec != null and respec.disabled, "reset only at a class station")
	var path := "user://test_saves/talent_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	SaveSystem.save_to(character, path)
	var restored := SaveSystem.load_from(path, session.database).character
	check(restored != null and restored.builds.get_build(&"warrior").rank(&"war_b_temper") == 1, "rank survives save/load")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


## 150 %: the same frame, the tree and the details fit or scroll on their own - never the window.
func test_150_percent_keeps_the_frame_and_scrolls_inside() -> void:
	session.settings.set_ui_scale(1.0)
	map.hud.toggle_talents()
	await _frames(4)
	var size_100 := panel.size
	session.settings.set_ui_scale(1.5)
	await _frames(6)
	check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "150 %: the window never scrolls")
	check(panel.get_viewport_rect().grow(1.0).encloses(panel.get_global_rect()), "150 %: window on screen")
	check(panel.size.x == size_100.x, "150 %%: same frame width (%s / %s)" % [panel.size, size_100])
	var view := _view()
	var scroll := panel.find_child("TreeScroll", true, false) as ScrollContainer
	var area := scroll.get_global_rect().grow(1.0)
	for node in view.tree.nodes:
		var rect := view.button_for(node.id).get_global_rect()
		check(area.encloses(rect) or scroll.get_v_scroll_bar().visible, "150 %%: %s visible or reachable by the tree's own scroll" % node.id)
	check(panel.get_global_rect().encloses(panel.find_child("LearnTalent", true, false).get_global_rect()), "Learn inside the window (no Close button since Playtest Corrections 1.0)")
