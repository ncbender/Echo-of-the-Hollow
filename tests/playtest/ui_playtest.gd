extends SceneTree
## Visual display/UI test (NOT headless): every target resolution, every UI scale,
## all RPG windows, tooltips, combat HUD, window <-> fullscreen. Saves screenshots
## to tests/output/ui/ and checks programmatically that no visible control leaves
## the screen, windows keep their margin and no control is squeezed below its
## minimum size (= cut-off text). Settings stay in memory (scripted run). Run:
##   godot --path . -s res://tests/playtest/ui_playtest.gd [-- --quick]

const OUTPUT := "res://tests/output/ui"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const VISIBLE_WORLD_WIDTH := 512.0

var session: SessionState
var map: GameMap
var f := InputFrame.new()
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/ui_playtest.save.json"
	session.set_character(CharacterFactory.create_new(session.database))
	GameMap.give_debug_items(session.character)
	for i in DisplayServer.get_screen_count():
		_log("screen %d at %s: %s px, dpi %d%s" % [i, DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i), DisplayServer.screen_get_dpi(i), " (primary)" if i == DisplayServer.get_primary_screen() else ""])
	for resolution in RESOLUTIONS:
		await _resolution_pass(resolution)
	if not "--quick" in OS.get_cmdline_user_args():
		for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
			await _scale_pass(resolution)
		await _fullscreen_pass()
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("ui_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


# --- passes -------------------------------------------------------------------

func _resolution_pass(resolution: Vector2i) -> void:
	session.settings.set_ui_scale(1.0)
	await _set_window_size(resolution)
	var tag := "%dp" % resolution.y
	await _load_map(&"home_base", "res://scenes/maps/home_base.tscn")
	await _shot(tag, "01_home_hud")
	_check_layout(tag + " home HUD")
	_check_world_view(tag)
	await _open_inventory(tag)
	await _open_class_panel(tag)
	await _open_build_panel(tag)
	await _open_story_windows(tag)
	await _open_options(tag, true)
	await _load_map(&"test_arena", "res://scenes/arena/test_arena.tscn")
	await _combat(tag)


func _scale_pass(resolution: Vector2i) -> void:
	await _set_window_size(resolution)
	await _load_map(&"home_base", "res://scenes/maps/home_base.tscn")
	for scale in UserSettings.UI_SCALES:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		var tag := "%dp_scale%d" % [resolution.y, roundi(scale * 100.0)]
		_check_world_view(tag)
		map.hud.toggle_inventory()
		await _frames(4)
		_check_layout(tag + " inventory")
		if is_equal_approx(scale, UserSettings.MAX_UI_SCALE) or is_equal_approx(scale, UserSettings.UI_SCALES[0]):
			await _shot(tag, "inventory")
		map.hud.toggle_options()
		await _frames(4)
		_check_layout(tag + " options")
		if is_equal_approx(scale, UserSettings.MAX_UI_SCALE):
			await _shot(tag, "options")
		map.hud.close_windows()
		await _frames(2)
		_check_layout(tag + " HUD")
		if is_equal_approx(scale, UserSettings.MAX_UI_SCALE):
			await _shot(tag, "hud")
		if is_equal_approx(scale, 1.0) or is_equal_approx(scale, 1.5):
			await _open_build_panel(tag)
			await _open_story_windows(tag)
			await _title_check(tag)
			await _load_map(&"home_base", "res://scenes/maps/home_base.tscn")
	session.settings.reset_to_defaults()
	await _frames(4)
	_check(is_equal_approx(root.content_scale_factor, 1.0), "reset to defaults -> UI scale 100 %")


func _fullscreen_pass() -> void:
	await _set_window_size(Vector2i(1920, 1080))
	root.borderless = false
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen()) + Vector2i(100, 100)
	await _frames(6)
	await _load_map(&"home_base", "res://scenes/maps/home_base.tscn")
	_log("before F11: window on screen %d" % root.current_screen)
	var key := InputEventAction.new()
	key.action = &"toggle_fullscreen"
	key.pressed = true
	Input.parse_input_event(key)   # real F11 path through SessionState
	await _frames(40)
	_log("fullscreen: mode=%d size=%s screen=%s" % [root.mode, root.size, DisplayServer.screen_get_size(root.current_screen)])
	_check(root.mode == Window.MODE_FULLSCREEN, "F11 -> fullscreen")
	_check(root.size == DisplayServer.screen_get_size(root.current_screen), "fullscreen covers the screen (%s)" % root.size)
	_check_layout("fullscreen HUD")
	_check_world_view("fullscreen")
	map.hud.toggle_inventory()
	await _frames(4)
	_check_layout("fullscreen inventory")
	await _shot("fullscreen", "inventory")
	map.hud.close_windows()
	session.settings.set_window_mode(UserSettings.WindowMode.WINDOWED)
	await _frames(40)
	_log("windowed again: mode=%d size=%s" % [root.mode, root.size])
	_check(root.mode == Window.MODE_WINDOWED, "back to windowed")
	_check_layout("windowed after fullscreen")
	_check_world_view("windowed after fullscreen")
	await _shot("windowed_again", "hud")


# --- steps ----------------------------------------------------------------------

func _open_inventory(tag: String) -> void:
	map.hud.toggle_inventory()
	await _frames(4)
	_check(map.hud.inventory_panel.visible, tag + " inventory opens")
	_check_layout(tag + " inventory")
	await _shot(tag, "02_inventory")
	# hover the first bag slot and the right-most equipped slot -> custom item tooltips
	var slots: Array[Control] = []
	for button: Button in map.hud.inventory_panel.find_children("*", "ItemCell", true, false):
		if not button.disabled and (button as ItemCell).instance_id != "":
			if slots.is_empty() or button.get_global_rect().end.x > slots[slots.size() - 1].get_global_rect().end.x + 1.0:
				slots.append(button)
	for index in [0, slots.size() - 1]:
		var slot := slots[index]
		# Real cursor warp: hover needs the OS mouse inside the window.
		# The window can cover the whole screen (4K): a real mouse movement may
		# interfere, so retry until the slot is really hovered.
		var at := root.get_final_transform() * slot.get_global_rect().get_center()
		for attempt in 4:
			Input.warp_mouse(at)
			await _frames(2)
			var motion := InputEventMouseMotion.new()
			motion.position = at
			motion.global_position = at
			motion.relative = Vector2(1, 0)
			Input.parse_input_event(motion)
			await create_timer(0.3).timeout   # the item tooltip shows without delay
			if root.gui_get_hovered_control() == slot:
				break
		var hovered := root.gui_get_hovered_control()
		_log("%s hover target %s -> hovered %s (window px %s, mouse canvas %s, slot %s, os mouse %s)" % [tag, slot.name, hovered.name if hovered != null else "-", at, root.get_mouse_position(), slot.get_global_rect(), DisplayServer.mouse_get_position()])
		var tooltip: Control = map.hud.inventory_panel.tooltip if map.hud.inventory_panel.tooltip.visible else null
		_check(tooltip != null, tag + " item tooltip shown")
		if tooltip != null:
			_log("%s tooltip at %s size %s, canvas %s" % [tag, tooltip.position, tooltip.size, root.get_visible_rect().size])
			_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1.0).encloses(Rect2(tooltip.position, tooltip.size)), tag + " tooltip inside the screen")
		await _shot(tag, "03_tooltip_%d" % index)
		Input.warp_mouse(Vector2(4, 4))
	await _right_click_roundtrip(tag)
	map.hud.close_windows()
	await _frames(2)


## Real right clicks (OS cursor + mouse button events): equip an item from the
## bag, then unequip it again with a right click on the same bag cell.
func _right_click_roundtrip(tag: String) -> void:
	var panel := map.hud.inventory_panel
	var character := session.character
	var target: ItemInstance = null
	for cell: ItemCell in panel.find_children("Item_*", "ItemCell", true, false):
		var item := cell.item()
		if item != null and character.database.get_item(item.definition_id).is_equippable() and not character.equipment.is_equipped(item.instance_id) \
				and character.equipment.quick_slot(item) >= 0 and cell.is_visible_in_tree():
			target = item
			break
	if target == null:
		_check(false, tag + " an equippable bag item for the right click")
		return
	for expected: bool in [true, false]:
		var cell := panel.find_child("Item_%s" % target.instance_id, true, false) as ItemCell
		var scroll := cell.get_parent()
		while scroll != null and not scroll is ScrollContainer:
			scroll = scroll.get_parent()
		if scroll != null:
			(scroll as ScrollContainer).ensure_control_visible(cell)
			await _frames(3)
		var at := root.get_final_transform() * cell.get_global_rect().get_center()
		Input.warp_mouse(at)
		await _frames(2)
		for pressed: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = pressed
			click.position = at
			click.global_position = at
			Input.parse_input_event(click)
			await _frames(2)
		_check(character.equipment.is_equipped(target.instance_id) == expected, "%s real right click %s" % [tag, "equips" if expected else "unequips"])
	Input.warp_mouse(Vector2(4, 4))


func _visible_tooltip(node: Node) -> Window:
	for child in node.get_children(true):
		if child is PopupPanel and (child as Window).visible:
			return child
		var found := _visible_tooltip(child)
		if found != null:
			return found
	return null


func _open_class_panel(tag: String) -> void:
	var station := map.get_node("ClassStation") as ClassStation
	await _teleport(station.global_position + Vector2(0, 12))
	map.hud.open_class_panel(station)
	await _frames(4)
	_check(map.hud.class_panel.visible, tag + " class panel opens")
	_check_layout(tag + " class panel")
	await _shot(tag, "04_class_panel")
	map.hud.close_windows()


func _open_build_panel(tag: String) -> void:
	var plot := map.get_node("Ruins/OldSmithy") as RuinSite
	await _teleport(plot.global_position + Vector2(0, 26))
	map.hud.open_restoration(plot)
	await _frames(4)
	_check(map.hud.restoration_panel.visible, tag + " restoration window opens")
	_check_layout(tag + " restoration window")
	await _shot(tag, "05_restoration")
	map.hud.close_windows()


## Prologue & Haven windows: dialogue, tutorial hint, pause menu (save + load
## pages), waystone travel, class choice, restoration.
func _open_story_windows(tag: String) -> void:
	var lines: Array[Dictionary] = [{"name": "Mara Veyne", "text": "There's a place north of here. Haven. Not much to look at, but it's got walls, a forge, and people who still give a damn.", "color": UiTheme.COLOR_ACCENT}]
	map.hud.open_lines(lines)
	map.hud.show_hint("Hold RMB to charge a heavy attack. Release to strike.")
	await _frames(4)
	_check_layout(tag + " dialogue + hint")
	await _shot(tag, "07_dialogue_hint")
	map.hud.close_windows()
	map.hud.open_pause_menu()
	await _frames(4)
	_check_layout(tag + " pause menu")
	await _shot(tag, "08_pause")
	map.hud.pause_menu.show_page("save")
	await _frames(4)
	_check_layout(tag + " pause / save slots")
	map.hud.pause_menu.show_page("load")
	await _frames(4)
	_check_layout(tag + " pause / load slots")
	await _shot(tag, "09_load_slots")
	map.hud.pause_menu.hide()
	await _frames(2)
	var waystone := map.get_node("Waystone") as Waystone
	await _teleport(waystone.global_position + Vector2(0, 20))
	map.hud.open_waystones(waystone)
	await _frames(4)
	_check_layout(tag + " waystones")
	await _shot(tag, "10_waystones")
	map.hud.close_windows()
	map.hud.class_choice_panel.open(session.character, null)
	await _frames(4)
	_check_layout(tag + " class choice")
	await _shot(tag, "11_class_choice")
	map.hud.close_windows()
	await _frames(2)


## Title screen (main menu) at the current window size and UI scale.
func _title_check(tag: String) -> void:
	change_scene_to_file(SessionState.TITLE_SCENE)
	await _frames(8)
	var view := root.get_visible_rect()
	var problems: PackedStringArray = []
	for node in current_scene.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if not view.grow(1.0).encloses(control.get_global_rect()):
			problems.append("%s off screen" % control.name)
		var minimum := control.get_combined_minimum_size()
		if control.size.x + 0.5 < minimum.x or control.size.y + 0.5 < minimum.y:
			problems.append("%s squeezed" % control.name)
	_check(problems.is_empty(), "%s title screen layout (%s)" % [tag, "; ".join(problems.slice(0, 4))])
	await _shot(tag, "00_title")


func _open_options(tag: String, via_key: bool) -> void:
	if via_key:
		var key := InputEventAction.new()
		key.action = &"ui_options"
		key.pressed = true
		Input.parse_input_event(key)   # real O key path through GameHud
		await _frames(2)
		var release := InputEventAction.new()
		release.action = &"ui_options"
		Input.parse_input_event(release)
	else:
		map.hud.toggle_options()
	await _frames(4)
	_check(map.hud.options_panel.visible, tag + " options open")
	_check_layout(tag + " options")
	await _shot(tag, "06_options")
	map.hud.close_windows()


func _combat(tag: String) -> void:
	var enemy: Enemy = map.call(&"spawn_enemy", map.player.global_position + Vector2(40, 0))
	for i in 150:
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			break
		var to := enemy.global_position - map.player.global_position
		f.aim_direction = to.normalized()
		f.move = to.normalized() if to.length() > 24.0 else Vector2.ZERO
		if map.player.combat.state == CombatComponent.State.IDLE and to.length() < 34.0:
			f.light_pressed = true
		map.player.health.heal(1000.0)
		if i == 70:
			await _shot(tag, "07_combat")
			_check_layout(tag + " combat HUD")
		await physics_frame
	f.move = Vector2.ZERO


# --- checks ---------------------------------------------------------------------

## Every visible control of the HUD and the debug overlay stays on screen, windows
## keep the screen margin, and nothing is smaller than its minimum size.
func _check_layout(label: String) -> void:
	var view := root.get_visible_rect()
	var problems: PackedStringArray = []
	var controls: Array[Node] = map.hud.find_children("*", "Control", true, false)
	var overlay := map.get_node_or_null("DebugOverlay")
	if overlay != null:
		controls.append_array(overlay.find_children("*", "Control", true, false))
	for node in controls:
		var control := node as Control
		if not control.is_visible_in_tree() or _inside_scroll(control):
			continue
		var rect := control.get_global_rect()
		if not view.grow(1.0).encloses(rect):
			problems.append("%s off screen %s" % [control.get_path(), rect])
		if control is UiWindow and not view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(rect):
			problems.append("%s inside margin %s" % [control.name, rect])
		var minimum := control.get_combined_minimum_size()
		if control.size.x + 0.5 < minimum.x or control.size.y + 0.5 < minimum.y:
			problems.append("%s squeezed %s < %s" % [control.get_path(), control.size, minimum])
	_check(problems.is_empty(), "%s: layout inside %s (%s)" % [label, view.size, "; ".join(problems.slice(0, 4))])


func _inside_scroll(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


## UI scale and resolution must never change how much of the world is visible.
func _check_world_view(label: String) -> void:
	var camera := map.player.get_node("Camera2D") as Camera2D
	var world_width := root.get_visible_rect().size.x / camera.zoom.x
	_check(absf(world_width - VISIBLE_WORLD_WIDTH) < 0.5, "%s: visible world width %.2f px" % [label, world_width])


# --- helpers --------------------------------------------------------------------

func _set_window_size(resolution: Vector2i) -> void:
	if root.mode != Window.MODE_WINDOWED:
		root.mode = Window.MODE_WINDOWED
	# Borderless: a 3840x2160 client area plus title bar would not fit the 4K screen,
	# and Windows would move the window to the other monitor.
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())   # 4K primary, not desktop (0,0)
	await _frames(6)
	_check(root.size == resolution, "window resized to %s (got %s)" % [resolution, root.size])


func _load_map(map_id: StringName, path: String) -> void:
	change_scene_to_file(path)
	for i in 300:
		await process_frame
		var current := current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			f = InputFrame.new()
			map.player.feed_input(f)
			await _frames(20)
			return
	_check(false, "map %s loaded" % map_id)


func _teleport(at: Vector2) -> void:
	map.player.global_position = at
	for i in 4:
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(tag: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s_%s.png" % [tag, label])
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s (%dx%d)" % [path.get_file(), image.get_width(), image.get_height()])


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	_log(("PASS " if ok else "FAIL ") + text)


func _log(text: String) -> void:
	log_lines.append(text)
	print(text)
