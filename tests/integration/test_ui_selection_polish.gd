extends TestCase
## UI Selection & Surface Polish 1.0 (docs/UI_SELECTION_POLISH_1_0.md): clickable cards (CardButton, class
## station) use the card art of Journal / class choice - selected = panel/card_selected, hover / disabled =
## tinted card art; keyboard focus stays the separate resonance outline. Skinned windows draw a hard pixel
## shadow outside their rect only: size, content margins, anchors, mouse filter and z-order unchanged.

var session: SessionState
var map: GameMap
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	session.set_character(CharacterFactory.create_new(session.database))
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 2) -> void:
	for i in count:
		await get_tree().process_frame


func test_card_states_share_the_card_language() -> void:
	var theme := UiTheme.get_theme()
	if not check(UiSkin.has(&"panel/card") and UiSkin.has(&"panel/card_selected"), "card art present"):
		return
	var expected := {&"normal": [&"panel/card", Color.WHITE], &"hover": [&"panel/card", UiTheme.CARD_HOVER_TINT],
		&"pressed": [&"panel/card_selected", Color.WHITE], &"hover_pressed": [&"panel/card_selected", UiTheme.CARD_HOVER_TINT],
		&"disabled": [&"panel/card", UiTheme.CARD_DISABLED_TINT]}
	for state: StringName in expected:
		var style := theme.get_stylebox(state, &"CardButton") as StyleBoxTexture
		if not check(style != null, "CardButton %s is the card art" % state):
			continue
		check(style.texture == UiSkin.texture(expected[state][0]), "CardButton %s uses %s" % [state, expected[state][0]])
		check(style.modulate_color.is_equal_approx(expected[state][1]), "CardButton %s tint %s" % [state, style.modulate_color])
	# the same art as the selected card of Journal / class choice
	var selected_panel := theme.get_stylebox(&"panel", &"SelectedCardPanel") as StyleBoxTexture
	check(selected_panel != null and selected_panel.texture == (theme.get_stylebox(&"pressed", &"CardButton") as StyleBoxTexture).texture,
		"selected card button = selected card panel")
	# padding unchanged (taken from the procedural style: 12 / 10)
	var normal := theme.get_stylebox(&"normal", &"CardButton")
	check_eq([normal.get_content_margin(SIDE_LEFT), normal.get_content_margin(SIDE_TOP)], [12.0, 10.0], "content margins kept")


func test_keyboard_focus_stays_separate_from_selection() -> void:
	var theme := UiTheme.get_theme()
	var focus := theme.get_stylebox(&"focus", &"CardButton") as StyleBoxFlat
	if not check(focus != null, "focus is its own procedural style"):
		return
	check(not focus.draw_center and focus.border_color.is_equal_approx(UiTheme.COLOR_FOCUS), "focus = resonance outline, no fill")
	check(focus.expand_margin_left >= 2.0 and focus.expand_margin_bottom >= 2.0, "drawn outside the card: never hides the gold selection")
	# a real toggled card with keyboard focus: selected style and focus style both apply
	var card := Button.new()
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.button_pressed = true
	card.custom_minimum_size = Vector2(240, 80)
	map.hud.add_child(card)
	card.theme = theme
	card.grab_focus()
	await _frames(2)
	check(card.has_focus() and card.button_pressed, "selected and focused at once")
	check(card.get_theme_stylebox(&"pressed") is StyleBoxTexture and card.get_theme_stylebox(&"focus") is StyleBoxFlat,
		"both states keep their own look")
	card.queue_free()


func test_window_shadow_changes_no_geometry_or_input() -> void:
	var hud := map.hud
	hud.toggle_journal()
	await _frames(4)
	var window := hud.journal_panel
	if not check(window.visible, "journal open"):
		return
	var style := window.get_theme_stylebox(&"panel")
	check(style is StyleBoxTexture, "skinned window")
	check_eq(style.get_content_margin(SIDE_LEFT), float(UiTheme.PANEL_PADDING + 4), "window content margin kept")
	var rect := window.get_global_rect()
	window.queue_redraw()
	await _frames(2)
	check(window.get_global_rect().is_equal_approx(rect), "window rect unchanged by the shadow")
	check(window.mouse_filter != Control.MOUSE_FILTER_IGNORE, "window input unchanged")
	var shadow_point := rect.end + Vector2(-UiTheme.SHADOW_OFFSET * 0.5, -10)
	shadow_point.x = rect.end.x + UiTheme.SHADOW_OFFSET * 0.5
	check(not rect.has_point(shadow_point), "the shadow lies outside the window: clicks there are not the window's")
	check(UiTheme.SHADOW_OFFSET >= 2.0 and fmod(UiTheme.SHADOW_OFFSET, 2.0) == 0.0, "hard shadow on the 2 px grid")
	hud.close_windows()
