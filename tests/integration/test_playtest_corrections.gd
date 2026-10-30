extends TestCase
## Playtest Corrections 1.0 (docs/PLAYTEST_CORRECTIONS_1_0.md): Inventory Details shows only what is in effect (no
## switch; base values always; zero bonuses and empty groups hidden; it follows the stat sources); the seven main
## menus have no Close button and still close by Esc, their key and their icon, while confirmations and small windows
## keep theirs; talent tooltips stay inside the class station window for every column, row and a long text.

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
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	var definition := session.database.get_class_def(&"warrior")
	var xp := 0
	for level in range(1, 40):
		xp += definition.xp_to_next(level)
	character.classes.add_xp(&"warrior", xp)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(3)


func after_each() -> void:
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


func _detail_rows() -> Dictionary:
	var result := {}
	for row: Node in map.hud.inventory_panel.find_children("Stat_*", "", true, false):
		result[StringName(String(row.name).trim_prefix("Stat_"))] = row
	return result


## No switch; every shown stat is a base value or not 0; zero bonuses (the four of the playtest finding too) are
## hidden; a positive and a negative bonus show; groups without a value are gone; a new stat source shows at once.
func test_details_only_what_is_in_effect() -> void:
	var panel := map.hud.inventory_panel
	map.hud.toggle_inventory()
	panel.left_page = "Details"
	panel.rebuild()
	await _frames()
	check(panel.find_child("OnlyActive", true, false) == null, "no 'Only active bonuses' switch any more")
	var stats := character.get_stats()
	var rows := _detail_rows()
	for stat: StringName in Stats.ALL:
		var value: float = stats.get(stat, 0.0)
		check_eq(rows.has(stat), InventoryPanel.shows_stat(stat, value), "%s (%.2f) shown only when in effect" % [stat, value])
	check(rows.has(Stats.MAX_HEALTH) and rows.has(Stats.ARMOR), "base values stay")
	for stat: StringName in [Stats.PHYSICAL_DAMAGE, Stats.ATTACK_SPEED, Stats.CRIT_CHANCE, Stats.POISE_DAMAGE]:
		if is_zero_approx(snappedf(float(stats.get(stat, 0.0)), 0.1)):
			check(not rows.has(stat), "the playtest finding: %s at 0 is hidden" % stat)
	# a positive and a negative bonus from a real stat source (a runtime buff), shown at once
	character.set_runtime_modifiers(&"buff:test_details", [StatModifier.make(Stats.CRIT_CHANCE, 5.0), StatModifier.make(Stats.MOVE_SPEED, -10.0)] as Array[StatModifier])
	await _frames()
	rows = _detail_rows()
	check(rows.has(Stats.CRIT_CHANCE) and rows.has(Stats.MOVE_SPEED), "positive and negative bonuses shown (%s)" % [rows.keys()])
	# groups: a heading only with a value under it
	var headings: PackedStringArray = []
	for section: Node in panel.find_children("Section_*", "", true, false):
		headings.append(String(section.name).trim_prefix("Section_"))
	for group: Array in InventoryPanel.DETAIL_GROUPS:
		var any := (group[1] as Array).any(func(stat: StringName) -> bool: return rows.has(stat))
		check_eq(headings.has(String(group[0]).validate_node_name()), any, "group %s heading only with values" % group[0])
	character.clear_runtime_modifiers(&"buff:test_details")
	await _frames()
	check(not _detail_rows().has(Stats.MOVE_SPEED), "the buff gone: the row gone again")


## No Close button in the seven main menus (the room is the content's); Esc, the key and the menu icon close them;
## a confirmation keeps its actions and a small window its Close.
func test_main_menus_close_without_a_button() -> void:
	var hud := map.hud
	for view: StringName in VIEWS:
		await _key(VIEWS[view])
		await _frames()
		var window: UiWindow = null
		for candidate: UiWindow in hud._windows:
			if candidate.visible:
				window = candidate
		if not check(window != null, "%s open" % view):
			continue
		check(not window.close_button().is_visible_in_tree(), "%s: no Close button" % view)
		check(window.get_global_rect().size.is_equal_approx(UiTheme.MAIN_WINDOW_SIZE), "%s: the shared frame (%s)" % [view, window.size])
		var gap := window.get_global_rect().end.y - (window._scroll.get_global_rect().end.y if not window.footer.visible else window.footer.get_global_rect().end.y)
		check(gap <= 40.0, "%s: no empty close row under the content (%.0f px)" % [view, gap])
		await _key(VIEWS[view] if view != &"character" else KEY_C)
		await _frames()
		check(not hud.is_window_open(), "%s: its key closes it" % view)
		await _key(VIEWS[view])
		await _frames()
		await _key(KEY_ESCAPE)
		await _frames()
		check(not hud.is_window_open(), "%s: Esc closes it" % view)
	# the menu icon toggles too
	hud.menu_bar.buttons[&"journal"].pressed.emit()
	await _frames()
	check(hud.journal_panel.visible, "the icon opens the journal")
	hud.menu_bar.buttons[&"journal"].pressed.emit()
	await _frames()
	check(not hud.journal_panel.visible, "the icon closes it")
	# a confirmation keeps its own buttons; a small window keeps Close
	hud.confirm_dialog.ask("Delete?", "Sure?", "Delete", func() -> void: pass, true)
	await _frames()
	var buttons := hud.confirm_dialog.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).is_visible_in_tree())
	check(buttons.size() >= 2, "confirmation: confirm and cancel stay")
	hud.close_windows()
	hud.confirm_dialog.hide()
	check(hud.waystone_panel.close_button().visible, "a small window keeps its Close button")


## Every talent of every tree, hovered: the tooltip lies inside the class station window (with its inner margin),
## right of the talent or - without room - left of it; the long capstone tooltip too.
func test_talent_tooltips_inside_the_window() -> void:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	var panel := map.hud.class_panel
	panel.open(character, station, "Talents")
	await _frames(4)
	var window := panel.get_global_rect().grow(-TalentTooltip.INNER_MARGIN + 0.5)
	for tree in TalentService.trees_of(character.database, &"warrior"):
		panel.show_tree(tree.id)
		await _frames(3)
		var view: TalentTreeView = panel._trees[0]
		for node in tree.nodes:
			panel._on_talent_hovered(node.id, view)
			await _frames(2)
			var tip := panel.talent_tooltip.get_global_rect()
			var anchor := view.button_for(node.id).get_global_rect()
			check(window.encloses(tip), "%s: tooltip %s inside the window %s" % [node.id, tip, window])
			check(not tip.intersects(anchor.grow(-2.0)), "%s: the tooltip leaves the talent free" % node.id)
			if anchor.end.x + TalentTooltip.GAP + tip.size.x > window.end.x:
				check(tip.end.x <= anchor.position.x, "%s: no room on the right - opened on the left" % node.id)
	check(panel.talent_tooltip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the tooltip never takes the mouse")
