extends TestCase
## HUD EXP Bar 1.0 (docs/HUD_EXP_BAR_1_0.md): exactly one EXP bar, 426 x 14 directly (6 px) under the
## combat bar and aligned with it; whole percent of the active class's level ("MAX" at the max level),
## updates on XP, resets on level-up, follows a class switch, survives save/load, steps back with the
## combat bar behind windows and in dialogues, never takes input, no overlap at 100 / 125 / 150 %.
## Files only under user://test_saves/hud_xp_bar/.

const PATH := "user://test_saves/hud_xp_bar/roundtrip.save.json"

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
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _frames(count: int = 2) -> void:
	for i in count:
		await get_tree().process_frame


func _bar() -> HudXpBar:
	return map.hud.xp_bar


## Text and share the HUD shows after a frame.
func _shown() -> Array:
	await _frames(2)
	return [_bar().text, snappedf(_bar().ratio, 0.001)]


func test_exactly_one_bar_under_the_combat_bar_aligned_at_three_scales() -> void:
	var hud := map.hud
	check_eq(hud.find_children("*", "HudXpBar", true, false).size(), 1, "exactly one EXP bar")
	check(not hud.health_vessel.is_ancestor_of(_bar()) and not hud._left_column.is_ancestor_of(_bar()), "not in a vessel / top left")
	check(_bar().get_parent() == hud._combat_row.get_parent() and _bar().get_index() == hud._combat_row.get_index() + 1, "directly after the combat bar")
	check(_bar().mouse_filter == Control.MOUSE_FILTER_IGNORE and hud._combat_column.mouse_filter == Control.MOUSE_FILTER_IGNORE, "never takes input")
	var probe := Interactable.new()   # a real interaction prompt above the bars
	probe.prompt = "Open Chest"
	map.add_child(probe)
	probe.player_inside = true
	for entry: Array in [[1.0, Vector2(1920, 1080)], [1.25, Vector2(1536, 864)], [1.5, Vector2(1280, 720)]]:
		var tag := "%d %%" % int(entry[0] * 100)
		check(session.settings.set_ui_scale(entry[0]), "UI %s" % tag)
		await _frames(6)
		var canvas := get_tree().root.get_visible_rect().size
		check(canvas.is_equal_approx(entry[1]), "%s: canvas %s" % [tag, canvas])
		var bar := _bar().get_global_rect()
		var combat := hud._combat_row.get_global_rect()
		check(bar.size.is_equal_approx(Vector2(426, 14)), "%s: 426 x 14 (%s)" % [tag, bar.size])
		check(is_equal_approx(combat.size.x, 426.0) and is_equal_approx(bar.position.x, combat.position.x)
			and is_equal_approx(bar.end.x, combat.end.x), "%s: aligned with the combat bar %s / %s" % [tag, bar, combat])
		check(is_equal_approx(bar.position.y - combat.end.y, 6.0), "%s: 6 px below the combat bar (%.1f)" % [tag, bar.position.y - combat.end.y])
		check(is_equal_approx(bar.end.y, canvas.y - UiTheme.SCREEN_MARGIN), "%s: on the bottom margin" % tag)
		check(is_equal_approx(bar.get_center().x, canvas.x * 0.5), "%s: centred" % tag)
		for name: String in ["menu_bar", "loot_feed", "skill_bar", "quick_use", "save_indicator", "toasts", "charge_meter"]:
			var other := hud.get(name) as Control
			if other.is_visible_in_tree() and other.size.x > 2.0 and other.size.y > 2.0:
				check(not bar.intersects(other.get_global_rect().grow(-0.5)), "%s: apart from %s %s" % [tag, name, other.get_global_rect()])
		var prompt := hud._prompt_box.get_global_rect()
		check(hud._prompt_box.is_visible_in_tree(), "%s: prompt shown" % tag)
		check(prompt.end.y <= combat.position.y + 0.5, "%s: the interaction prompt stays above the combat bar" % tag)


func test_percent_levels_up_and_max() -> void:
	var classes := character.classes
	check_eq(classes.xp_to_next(&"warrior"), 100, "warrior level 1 needs 100 XP (data unchanged)")
	check_eq(await _shown(), ["0%", 0.0], "0 %")
	classes.add_xp(&"warrior", 50)
	check_eq(await _shown(), ["50%", 0.5], "50 %")
	classes.add_xp(&"warrior", 49)
	check_eq(await _shown(), ["99%", 0.99], "99 %")
	classes.add_xp(&"warrior", 1)
	check_eq(classes.get_level(&"warrior"), 2, "level-up")
	check_eq(await _shown(), ["0%", 0.0], "reset after the level-up")
	classes.add_xp(&"warrior", classes.xp_to_next(&"warrior") - 1)
	check_eq((await _shown())[0], "99%", "never 100 % before the next level")
	# the max level of the starting class (level 10)
	check_eq(character.switch_class(&"basic_adventurer", true), "", "switched")
	classes.add_xp(&"basic_adventurer", 1000000)
	check_eq(classes.get_level(&"basic_adventurer"), session.database.get_class_def(&"basic_adventurer").max_level, "max level")
	check_eq(await _shown(), ["MAX", 1.0], "MAX instead of a percentage")
	check(not _bar().text.contains("XP") and not _bar()._label.text.is_valid_int(), "no absolute XP")


func test_class_switch_shows_the_active_class() -> void:
	var classes := character.classes
	classes.add_xp(&"basic_adventurer", 60)   # 60 / 120
	classes.add_xp(&"warrior", 25)            # 25 / 100
	check_eq(await _shown(), ["25%", 0.25], "warrior active")
	check_eq(character.switch_class(&"basic_adventurer", true), "", "switch")
	check_eq(await _shown(), ["50%", 0.5], "basic adventurer progress")
	check_eq(character.switch_class(&"warrior", true), "", "switch back")
	check_eq(await _shown(), ["25%", 0.25], "warrior progress again")


func test_save_and_load_keep_the_shown_progress() -> void:
	character.classes.add_xp(&"warrior", 137)   # level 2, 37 / 107
	var before: Array = await _shown()
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, session.database)
	if not check(loaded.ok(), "loaded %s" % [loaded.errors]):
		return
	var after := HudXpBar.progress(loaded.character.classes)
	check(is_equal_approx(after[0], 37.0 / 107.0) and after[1] == "34%", "same progress after loading %s" % [after])
	check_eq(before[0], "34%", "34 % before saving")


func test_steps_back_with_the_combat_bar() -> void:
	var hud := map.hud
	check(hud.combat_bar_shown() and is_equal_approx(_bar().modulate.a, 1.0), "shown")
	hud.toggle_journal()
	await _frames(3)
	check(not hud.combat_bar_shown() and is_equal_approx(_bar().modulate.a, 0.0), "steps back with the combat bar behind a window")
	check(_bar().is_visible_in_tree(), "layout kept (fades, not hidden)")
	hud.close_windows()
	await _frames(3)
	check(hud.combat_bar_shown() and is_equal_approx(_bar().modulate.a, 1.0), "back after closing")
	hud.open_lines([{"name": "Note", "text": "A line.", "color": UiTheme.PARCHMENT, "note": true}] as Array[Dictionary])
	await _frames(3)
	check(not _bar().is_visible_in_tree(), "hidden in a dialogue")
	hud.close_windows()
	await _frames(3)
	check(_bar().is_visible_in_tree() and is_equal_approx(_bar().modulate.a, 1.0), "back after the dialogue")
