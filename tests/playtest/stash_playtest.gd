extends SceneTree
## Haven stash in a real window (NOT headless):
##   godot --path . -s res://tests/playtest/stash_playtest.gd
## For 720p, 1080p and 4K at 100 / 150 / 200 % UI scale: open the stash at the
## ruined Old Storehouse, check the layout, then with the real mouse (OS cursor
## + input events): hover tooltip, right click store and take, drag & drop to
## the stash and back, "Deposit All Materials", "Sort", category tabs. After
## every step: no item duplicated or lost. Screenshots and log: tests/output/stash/.

const OUTPUT := "res://tests/output/stash"
const PASSES: Array = [[Vector2i(1280, 720), 1.0], [Vector2i(1280, 720), 1.5], [Vector2i(1280, 720), 2.0],
	[Vector2i(1920, 1080), 1.0], [Vector2i(1920, 1080), 1.5], [Vector2i(1920, 1080), 2.0],
	[Vector2i(3840, 2160), 1.0], [Vector2i(3840, 2160), 1.5], [Vector2i(3840, 2160), 2.0]]

var session: SessionState
var map: GameMap
var character: Character
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0
var _last_motion := Vector2.INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/stash_playtest/slot_1.save.json"
	for pass_spec: Array in PASSES:
		await _pass(pass_spec[0], pass_spec[1])
	session.settings.reset_to_defaults()
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("stash_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _pass(resolution: Vector2i, scale: float) -> void:
	var tag := "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	character = CharacterFactory.create_new(session.database)
	GameMap.give_crafting_kit(character)
	GameMap.give_debug_items(character)
	character.world.set_restoration(&"old_smithy", &"restored")
	character.world.set_flag(&"haven.old_smithy.restored")
	session.set_character(character)
	session.settings.set_ui_scale(scale)
	session.settings.set_reduce_motion(true)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(10)
	var store := map.get_node("Ruins/OldStorehouse") as RuinSite
	map.player.global_position = store.global_position + Vector2(0, 20)
	for i in 8:
		await physics_frame
	store.interact(map.hud)
	await _frames(6)
	var panel := map.hud.stash_panel
	_check(panel.visible, "%s stash opens at the ruined storehouse" % tag)
	_check_layout(tag)
	var total := _total()
	# hover tooltip
	var sword := _bag_item(&"militia_sword")
	await _hover(_cell(panel, "Bag", sword))
	_check(panel.tooltip.visible and panel.tooltip.item == sword, "%s tooltip on hover" % tag)
	_check(panel.get_viewport_rect().grow(1.0).encloses(panel.tooltip.get_global_rect()), "%s tooltip on screen" % tag)
	await _shot(tag, "01_tooltip")
	# right click store, take
	await _click(_cell(panel, "Bag", sword), MOUSE_BUTTON_RIGHT)
	_check(character.stash.has(sword.instance_id), "%s real right click stores" % tag)
	await _click(_cell(panel, "Stash", sword), MOUSE_BUTTON_RIGHT)
	_check(character.inventory.has(sword.instance_id) and not character.stash.has(sword.instance_id), "%s real right click takes" % tag)
	# drag & drop to the stash and back
	var oath := _bag_item(&"crushing_oath")
	await _drag(_cell(panel, "Bag", oath), panel.find_child("StashZone", true, false) as Control)
	_check(character.stash.has(oath.instance_id), "%s real drag into the stash" % tag)
	_check(panel.category == StashService.COLLECTION, "%s the unique shows in the Collection Vault" % tag)
	await _drag(_cell(panel, "Stash", oath), panel.find_child("BagZone", true, false) as Control)
	_check(character.inventory.has(oath.instance_id) and not character.stash.has(oath.instance_id), "%s real drag back into the bag" % tag)
	# deposit all, sort, tabs
	await _click(panel.find_child("DepositAll", true, false) as Control, MOUSE_BUTTON_LEFT)
	_check(character.inventory.count(&"iron_ore") == 0 and character.stash.count(&"iron_ore") > 0, "%s Deposit All Materials" % tag)
	await _click(panel.find_child("Sort", true, false) as Control, MOUSE_BUTTON_LEFT)
	_check((panel.find_child("Status", true, false) as Label).text == "Stash sorted.", "%s Sort" % tag)
	_check_layout(tag + " materials")
	await _shot(tag, "02_materials")
	await _click(panel._tabs.tab_button(String(StashService.EQUIPMENT)), MOUSE_BUTTON_LEFT)
	_check(panel.category == StashService.EQUIPMENT, "%s Equipment Chest tab" % tag)
	_check(_total() == total, "%s no item created or lost (%d -> %d)" % [tag, total, _total()])
	_check(StashService.ownership_errors(character).is_empty(), "%s ownership consistent" % tag)
	await _shot(tag, "03_chest")
	Input.warp_mouse(Vector2(4, 4))
	map.hud.close_windows()


## Units of every item (bag + stash, gold excluded) - must never change by transfers.
func _total() -> int:
	var sum := 0
	for container: Inventory in [character.inventory, character.stash]:
		for item in container.items():
			if item.definition_id != &"gold_coin":
				sum += item.quantity
	return sum


func _bag_item(item_id: StringName) -> ItemInstance:
	for item in character.inventory.items():
		if item.definition_id == item_id and not character.equipment.is_referenced(item.instance_id):
			return item
	return null


func _cell(panel: StashPanel, prefix: String, item: ItemInstance) -> Control:
	var cell := panel.find_child("%s_%s" % [prefix, item.instance_id], true, false) as Control
	if cell != null:
		var parent := cell.get_parent()
		while parent != null and parent != panel:
			if parent is ScrollContainer:
				(parent as ScrollContainer).ensure_control_visible(cell)
			parent = parent.get_parent()
	return cell


func _at(control: Control) -> Vector2:
	return root.get_final_transform() * control.get_global_rect().get_center()


## Motion with the real delta since the last one (Godot sums `relative` for the
## drag threshold - a fixed small value never starts a drag on scaled canvases).
func _motion(at: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = mask
	motion.relative = at - _last_motion if _last_motion != Vector2.INF else Vector2(1, 0)
	_last_motion = at
	Input.parse_input_event(motion)


func _button(at: Vector2, index: MouseButton, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = index
	click.pressed = pressed
	click.button_mask = (MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	click.position = at
	click.global_position = at
	Input.parse_input_event(click)


func _hover(control: Control) -> void:
	await _frames(2)
	var at := _at(control)
	Input.warp_mouse(at)
	_motion(at + Vector2(0, 30))
	await _frames(2)
	_motion(at)
	await _frames(4)


func _click(control: Control, index: MouseButton) -> void:
	await _hover(control)
	var at := _at(control)
	_button(at, index, true)
	await _frames(2)
	_button(at, index, false)
	await _frames(4)


## A real drag: the OS cursor goes to the cell (hover), the button is pressed,
## cursor and motion events move step by step to the target, release there.
func _drag(from: Control, to: Control) -> void:
	await _hover(from)
	var start := _at(from)
	var end := _at(to)
	_button(start, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	for step in range(1, 11):
		var at := start.lerp(end, step / 10.0)
		Input.warp_mouse(at)
		_motion(at, MOUSE_BUTTON_MASK_LEFT)
		await _frames(2)
	_button(end, MOUSE_BUTTON_LEFT, false)
	await _frames(4)


func _check_layout(label: String) -> void:
	var view := root.get_visible_rect()
	var problems: PackedStringArray = []
	for node in map.hud.stash_panel.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or _inside_scroll(control) or control is ItemTooltip or control.get_parent() is ItemTooltip:
			continue
		if not view.grow(1.0).encloses(control.get_global_rect()):
			problems.append("%s off screen %s" % [control.name, control.get_global_rect()])
	if not view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(map.hud.stash_panel.get_global_rect()):
		problems.append("window outside the margin")
	_check(problems.is_empty(), "%s layout (%s)" % [label, "; ".join(problems.slice(0, 3))])


func _inside_scroll(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(tag: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	_log(("PASS " if ok else "FAIL ") + text)


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)
