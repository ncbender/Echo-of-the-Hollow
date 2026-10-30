extends TestCase
## UI Usability & Haven Crafting 1.0 (docs/UI_USABILITY_HAVEN_CRAFTING_1_0.md): numbers inside bars sit
## centred on their digits and never leave the bar (PlayerFrame health / resource, the one EXP bar); the
## professions window has a bounded recipe list with search ("Search recipes...", case-insensitive,
## "No recipes found."), the wheel over the list moves only the list.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
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


## The text's ink box inside `text`'s rect: [left, top, right, bottom] margins (design px).
func _margins(text: BarText) -> Array:
	var font := UiTheme.body_font()
	var size := text.used_font_size()
	var origin := BarText.centred_origin(font, text.text, size, text.size)
	var ink := BarText.digit_ink(font, size)
	var width := font.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var top := origin.y + ink.x
	return [origin.x, top, text.size.x - origin.x - width, text.size.y - top - ink.y]


func _check_centred(text: BarText, label: String) -> void:
	var m := _margins(text)
	check(m[0] >= 0.0 and m[2] >= 0.0 and m[1] >= 0.0 and m[3] >= 0.0, "%s: '%s' inside the bar %s" % [label, text.text, m])
	check(absf(m[0] - m[2]) <= 1.0 and absf(m[1] - m[3]) <= 1.0, "%s: '%s' centred (margins %s)" % [label, text.text, m])


func test_bar_numbers_are_centred_and_never_leave_the_bar() -> void:
	var hud := map.hud
	for scale: float in [0.75, 1.0, 1.25, 1.5]:
		var tag := "%d %%" % int(scale * 100)
		session.settings.set_ui_scale(scale)
		await _frames(4)
		# Combat HUD UX 2.0: health and resource are vessels with a number (test_combat_hud); the EXP bar stays a bar
		var xp := hud.xp_bar
		check(xp.get_global_rect().size.is_equal_approx(Vector2(426, 14)), "%s: EXP bar still 426 x 14" % tag)
		var sizes: Array = []
		for value: String in ["0%", "50%", "99%", "MAX"]:
			xp._label.text = value
			check(xp._label.get_global_rect().is_equal_approx(xp.get_global_rect()), "%s: EXP text box = the bar" % tag)
			_check_centred(xp._label, "%s EXP" % tag)
			sizes.append(xp._label.used_font_size())
		check(sizes.all(func(v: int) -> bool: return v == sizes[0] and v >= xp._label.min_font_size), "%s EXP: one readable size for 0%% .. MAX %s" % [tag, sizes])
	check(hud.xp_bar._label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "bar text never takes input")


## One wheel notch at `at` (viewport px) through the real GUI path: press + release, as a mouse sends it.
func _wheel(at: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = button
		wheel.pressed = pressed
		wheel.position = at
		wheel.global_position = at
		get_tree().root.push_input(wheel)
	await _frames(2)


func _professions() -> ProfessionsPanel:
	map.hud.open_menu(&"professions")
	var panel := map.hud.professions_panel
	panel.show_page("Crafting")
	panel.select_profession(&"blacksmithing")
	return panel


func _rows(panel: ProfessionsPanel) -> Array:
	return panel.find_child("Recipes", true, false).get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Recipe_"))


func test_recipe_search_filters_while_typing() -> void:
	var panel := _professions()
	await _frames()
	var search := panel.find_child("RecipeSearch", true, false) as LineEdit
	if not check(search != null, "search field"):
		return
	check_eq(search.placeholder_text, "Search recipes...", "placeholder")
	var all := _rows(panel).size()
	check(all >= 2, "blacksmithing has several recipes (%d)" % all)
	search.grab_focus()
	search.text = "SMELT"
	search.text_changed.emit(search.text)
	await _frames()
	var rows := _rows(panel)
	check_eq(rows.size(), 1, "one hit, case-insensitive")
	check(rows.size() == 1 and String(rows[0].name) == "Recipe_bs_smelt_iron", "the smelt recipe")
	check(search.has_focus(), "typing keeps the focus in the search field")
	search.text = "iron ingot"   # a material / output name
	search.text_changed.emit(search.text)
	await _frames()
	check(_rows(panel).size() >= 2, "material names match too")
	search.text = "zzz no such thing"
	search.text_changed.emit(search.text)
	await _frames()
	check(_rows(panel).is_empty() and panel.find_child("NoRecipes", true, false) != null, "no hit: 'No recipes found.'")
	check_eq((panel.find_child("NoRecipes", true, false) as Label).text, "No recipes found.", "message")
	search.text = ""
	search.text_changed.emit("")
	await _frames()
	check_eq(_rows(panel).size(), all, "cleared: every recipe again")
	search.text = "smelt"
	search.text_changed.emit(search.text)
	panel.select_profession(&"leatherworking")
	await _frames()
	check_eq((panel.find_child("RecipeSearch", true, false) as LineEdit).text, "", "a new profession starts without the old search")
	check(_rows(panel).all(func(n: Node) -> bool:
		return (session.database.profession_recipes[StringName(String(n.name).trim_prefix("Recipe_"))] as ProfessionRecipeDefinition).profession_id == &"leatherworking"),
		"only the shown profession's recipes")


func test_recipe_list_is_bounded_and_the_wheel_moves_only_it() -> void:
	var panel := _professions()
	await _frames()
	var scroll := panel.find_child("RecipeScroll", true, false) as ScrollContainer
	if not check(scroll != null, "recipe list scroll"):
		return
	check(scroll.size.y + 0.5 >= float(ProfessionsPanel.RECIPE_LIST_HEIGHT), "list at least its minimum height (%s)" % scroll.size.y)
	var list_height := scroll.size.y
	# many recipes: pad the list beyond its height, the window stays the same
	var window_rect := panel.get_global_rect()
	var list := panel.find_child("Recipes", true, false) as VBoxContainer
	for i in 12:
		var filler := Button.new()
		filler.custom_minimum_size = Vector2(0, ProfessionsPanel.RECIPE_ROW_HEIGHT)
		filler.text = "A very long recipe name that does not fit into the narrow list column at all %d" % i
		filler.clip_text = true
		filler.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		list.add_child(filler)
	await _frames()
	panel.fit()
	await _frames()
	check(panel.get_global_rect().is_equal_approx(window_rect), "many recipes do not grow the window")
	check_eq(scroll.size.y, list_height, "list height unchanged")
	check(list.size.x <= scroll.size.x + 0.5, "long names stay inside the list (trimmed)")
	var body := panel._scroll
	var body_before := body.scroll_vertical
	# wheel over the list (through the real GUI input path)
	var at := get_tree().root.get_final_transform() * scroll.get_global_rect().get_center()
	for i in 2:
		await _wheel(at, MOUSE_BUTTON_WHEEL_DOWN)
	check(scroll.scroll_vertical > 0, "the wheel over the list scrolls the list (%d)" % scroll.scroll_vertical)
	check_eq(body.scroll_vertical, body_before, "the window body did not move")
	# wheel outside the list: the list stays
	var list_before := scroll.scroll_vertical
	var outside := get_tree().root.get_final_transform() * (panel.find_child("RecipeCard", true, false) as Control).get_global_rect().get_center()
	await _wheel(outside, MOUSE_BUTTON_WHEEL_UP)
	check_eq(scroll.scroll_vertical, list_before, "a wheel outside the list leaves it alone")
	map.hud.close_windows()


## HUD Resource Text Readability 1.0: the resource value is dark over a bright fill (light text there falls
## below 3:1) and light elsewhere; both halves the same size and place, split at the fill edge; at 75 % still
## a readable size. Every class resource colour (also the not yet playable Guardian / Soulbinder).
func test_resource_text_contrast_on_every_fill() -> void:
	var expected := {}
	for path: String in ["warrior", "arcanist", "shadowrunner", "guardian", "soulbinder"]:
		var definition := load("res://data/classes/%s.tres" % path) as ClassDefinition
		if definition != null and definition.resource != null:
			expected[definition.resource.display_name] = definition.resource.color
	check_eq(expected.size(), 5, "five class resources")
	var split := SplitBarText.new()
	split.set_anchors_preset(Control.PRESET_TOP_LEFT)
	split.size = Vector2(340, 12)
	add_child(split)
	for resource_name: String in expected:
		var fill: Color = expected[resource_name]
		split.set_fill(170.0, fill)
		var light := SplitBarText.contrast(UiTheme.PARCHMENT, fill)
		var dark := SplitBarText.contrast(SplitBarText.DARK, fill)
		if split._dark_on_fill:
			check(dark >= 4.5, "%s: dark text on the fill reads %.1f:1" % [resource_name, dark])
		else:
			check(light >= SplitBarText.MIN_CONTRAST, "%s: light text on the fill reads %.1f:1" % [resource_name, light])
		check(SplitBarText.contrast(UiTheme.PARCHMENT, Color("111216")) >= 7.0, "%s: light text on the empty groove" % resource_name)
	check(not _dark_for(split, expected["Rage"]) and _dark_for(split, expected["Focus"]) and _dark_for(split, expected["Mana"]), "Rage light, Focus / Mana dark")
	split.text = "Focus 50 / 100"
	split.set_fill(170.0, expected["Focus"])
	check(is_equal_approx(split._dark_clip.size.x, 170.0) and is_equal_approx(split._light_clip.position.x, 170.0), "split exactly at the fill edge")
	check(split._dark.size == split._light.size and is_equal_approx(split._light.position.x, -170.0), "both halves one text in one place")
	split.set_fill(0.0, expected["Focus"])
	check(not split._dark_clip.visible, "an empty bar: light text only")
	split.queue_free()   # Combat HUD UX 2.0: the HUD shows the resource in a vessel (test_combat_hud); SplitBarText stays a component


func _dark_for(split: SplitBarText, fill: Color) -> bool:
	split.set_fill(100.0, fill)
	return split._dark_on_fill
