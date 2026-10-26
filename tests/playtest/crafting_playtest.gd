extends SceneTree
## Visual crafting test (NOT headless): Resonance Forge at 1920x1080 and 3840x2160,
## each at UI scale 100 % and 150 %. Shows item list + tooltip, imprint probability
## table, reforge with focus, essences + resonance, sockets, quality and the
## evolution mutation choice; checks that no control leaves the screen or is
## squeezed and that the confirm button is reachable. One real mouse click on
## the confirm button verifies the wiring. Screenshots: tests/output/crafting/.
##   godot --path . -s res://tests/playtest/crafting_playtest.gd [-- --loop]
## --loop: full crafting loop in a window with real keys (F4, G, F6, F9): forge,
## equip, arena fight (discharge + resonance), save, load, compare.

const OUTPUT := "res://tests/output/crafting"
const PASSES: Array = [[Vector2i(1920, 1080), 1.0], [Vector2i(1920, 1080), 1.5], [Vector2i(3840, 2160), 1.0], [Vector2i(3840, 2160), 1.5]]

var session: SessionState
var map: GameMap
var panel: CraftingPanel
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/crafting_playtest.save.json"
	if "--loop" in OS.get_cmdline_user_args():
		await _loop()
	else:
		for pass_spec: Array in PASSES:
			await _pass(pass_spec[0], pass_spec[1])
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("crafting_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _pass(resolution: Vector2i, scale: float) -> void:
	var tag := "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	session.set_character(CharacterFactory.create_new(session.database))
	var character := session.character
	character.inventory.add_item(&"timber", 6)
	character.inventory.add_item(&"stone", 4)
	character.inventory.add_item(&"iron_ore", 3)
	GameMap.give_crafting_kit(character)
	session.settings.set_ui_scale(scale)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 300:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(20)
	var plot := map.get_node("Plots/PlotWest") as BuildPlot
	BaseBuilder.build(character, plot.definition(), session.database.buildings[&"smithy"])
	plot.refresh()
	map.player.global_position = plot.global_position + Vector2(0, 26)
	await _frames(6)
	plot.interact(map.hud)
	panel = map.hud.crafting_panel
	panel.rng.seed = 77
	_check(panel.visible, "%s forge opens at the smithy" % tag)
	var blade := _first(&"forged_blade")
	var greatsword := _first(&"forged_greatsword")
	var fang := _first(&"stormcaller_fang")
	# 1) item list + imprint probability table (greatsword, Storm Ore, focus shown)
	panel.select_item(greatsword.instance_id)
	panel.select_operation(CraftingOps.IMPRINT)
	panel.choose_material(&"storm_ore")
	await _view(tag, "01_imprint_probabilities")
	# 2) craft the blade: imprint, augment x2, reforge with focus
	panel.select_item(blade.instance_id)
	panel.select_operation(CraftingOps.IMPRINT)
	panel.choose_material(&"frost_glass")
	panel.confirm()
	for i in 2:
		panel.select_operation(CraftingOps.AUGMENT)
		panel.confirm()
	panel.select_operation(CraftingOps.REFORGE)
	panel.choose_affix(1)
	panel.choose_focus(&"control")
	await _view(tag, "02_reforge_focus")
	# 3) essences + resonance
	for essence_id: StringName in [&"storm_wolf", &"stone_golem"]:
		panel.select_operation(CraftingOps.ESSENCE_INSERT)
		panel.choose_essence(essence_id)
		panel.confirm()
	panel.select_operation(CraftingOps.ESSENCE_EXTRACT)
	panel.choose_slot(0)
	await _view(tag, "03_essences_resonance")
	# 4) sockets
	panel.select_operation(CraftingOps.SOCKET_OPEN)
	panel.confirm()
	panel.select_operation(CraftingOps.SOCKET_INSERT)
	panel.choose_socketable(&"garnet")
	await _view(tag, "04_sockets")
	panel.confirm()
	# 5) quality - confirmed with a REAL mouse click on the button (1080p 100 % only)
	panel.select_operation(CraftingOps.QUALITY)
	await _frames(4)
	if tag == "1080p_100":
		await _click_confirm(blade)
	await _view(tag, "05_quality")
	# 6) evolution with the mutation choice
	fang.evolution = {"stage": 2, "xp": 150, "path": ""}
	panel.select_item(fang.instance_id)
	panel.select_operation(CraftingOps.EVOLVE)
	panel.choose_mutation(&"storm_charge")
	await _view(tag, "06_evolution_mutation")
	# 7) item tooltip in the list
	await _hover_first_item(tag)
	# idle cost of an open forge (no rebuild loop)
	var start := Time.get_ticks_usec()
	await _frames(120)
	var ms := (Time.get_ticks_usec() - start) / 120000.0
	_check(ms < 34.0, "%s idle frame time with the forge open: %.1f ms" % [tag, ms])
	map.hud.close_windows()
	session.settings.reset_to_defaults()


## Screenshot at scroll top, checks, and - if the body scrolls - a second shot
## with the confirm button scrolled into view.
func _view(tag: String, label: String) -> void:
	await _frames(4)
	panel.fit()
	await _frames(2)
	_check_layout("%s %s" % [tag, label])
	await _shot(tag, label)
	var scroll := panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	var confirm := _confirm_button()
	scroll.ensure_control_visible(confirm)
	await _frames(3)
	var visible := scroll.get_global_rect().grow(1.0).encloses(confirm.get_global_rect())
	_check(visible, "%s %s: confirm button reachable (scroll %d)" % [tag, label, scroll.scroll_vertical])
	if scroll.scroll_vertical > 0:
		await _shot(tag, label + "_scrolled")
		scroll.scroll_vertical = 0


func _click_confirm(blade: ItemInstance) -> void:
	var button := _confirm_button()
	var scroll := panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	scroll.ensure_control_visible(button)
	await _frames(3)
	var quality := blade.quality
	var at := root.get_final_transform() * button.get_global_rect().get_center()
	Input.warp_mouse(at)
	await _frames(2)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _frames(2)
	_check(blade.quality == quality + 1, "real mouse click on Confirm raised quality (%d -> %d)" % [quality, blade.quality])
	scroll.scroll_vertical = 0


func _hover_first_item(tag: String) -> void:
	var scroll := panel.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	await _frames(3)
	scroll.scroll_vertical = 0   # ensure_control_visible scrolls deferred; reset afterwards
	await _frames(3)
	var slot := panel.find_children("*", "ItemSlotButton", true, false)[0] as Control
	var at := root.get_final_transform() * slot.get_global_rect().get_center()
	for attempt in 4:
		Input.warp_mouse(at)
		await _frames(2)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.global_position = at
		motion.relative = Vector2(1, 0)
		Input.parse_input_event(motion)
		await create_timer(1.0).timeout
		if root.gui_get_hovered_control() == slot:
			break
	_log("%s tooltip hover: hovered %s" % [tag, root.gui_get_hovered_control()])
	_check(_tooltip(root) != null, "%s item tooltip in the forge" % tag)
	await _shot(tag, "07_tooltip")
	Input.warp_mouse(Vector2(4, 4))


func _confirm_button() -> Button:
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.text.begins_with("Confirm") or button.text.begins_with("Choose"):
			return button
	return null


func _tooltip(node: Node) -> Window:
	for child in node.get_children(true):
		if child is PopupPanel and (child as Window).visible:
			return child
		var found := _tooltip(child)
		if found != null:
			return found
	return null


func _first(item_id: StringName) -> ItemInstance:
	for item in session.character.inventory.items():
		if item.definition_id == item_id:
			return item
	return null


func _check_layout(label: String) -> void:
	var view := root.get_visible_rect()
	var problems: PackedStringArray = []
	for node in map.hud.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or _inside_scroll(control):
			continue
		var rect := control.get_global_rect()
		if not view.grow(1.0).encloses(rect):
			problems.append("%s off screen %s" % [control.name, rect])
		if control is UiWindow and not view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(rect):
			problems.append("%s inside margin %s" % [control.name, rect])
		var minimum := control.get_combined_minimum_size()
		if control.size.x + 0.5 < minimum.x or control.size.y + 0.5 < minimum.y:
			problems.append("%s squeezed %s < %s" % [control.name, control.size, minimum])
	_check(problems.is_empty(), "%s: layout inside %s (%s)" % [label, view.size, "; ".join(problems.slice(0, 4))])


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
	log_lines.append(text)
	print(text)


# --- --loop: end-to-end crafting loop in a real window ----------------------------

var f := InputFrame.new()


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _await_map(map_id: StringName) -> void:
	for i in 400:
		await process_frame
		var current := current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			f = InputFrame.new()
			map.player.feed_input(f)
			await _frames(20)
			return
	_check(false, "reached %s" % map_id)


func _loop() -> void:
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = Vector2i(1920, 1080)
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	session.set_character(CharacterFactory.create_new(session.database))
	var character := session.character
	character.inventory.add_item(&"timber", 6)
	character.inventory.add_item(&"stone", 4)
	character.inventory.add_item(&"iron_ore", 3)
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	await _await_map(&"home_base")
	await _press(&"debug_crafting_kit")   # F4
	_check(character.inventory.count(&"imprint_shard") == 10, "F4 crafting kit received")
	var plot := map.get_node("Plots/PlotWest") as BuildPlot
	BaseBuilder.build(character, plot.definition(), session.database.buildings[&"smithy"])
	plot.refresh()
	map.player.global_position = plot.global_position + Vector2(0, 26)
	await _frames(8)
	await _press(&"interact")   # G at the smithy
	panel = map.hud.crafting_panel
	_check(panel.visible, "G at the smithy opens the Resonance Forge")
	panel.rng.seed = 4242
	var blade := _first(&"forged_blade")
	panel.select_item(blade.instance_id)
	panel.select_operation(CraftingOps.IMPRINT)
	panel.choose_material(&"frost_glass")
	await _frames(4)
	await _shot("loop", "01_imprint")
	_check(panel.confirm().ok, "imprint")
	panel.select_operation(CraftingOps.AUGMENT)
	_check(panel.confirm().ok, "augment")
	panel.select_operation(CraftingOps.REFORGE)
	panel.choose_affix(0)
	_check(panel.confirm().ok, "reforge (instant replacement)")
	for essence_id: StringName in [&"storm_wolf", &"stone_golem"]:
		panel.select_operation(CraftingOps.ESSENCE_INSERT)
		panel.choose_essence(essence_id)
		_check(panel.confirm().ok, "bind %s" % essence_id)
	panel.select_operation(CraftingOps.SOCKET_OPEN)
	_check(panel.confirm().ok, "open socket")
	panel.select_operation(CraftingOps.SOCKET_INSERT)
	panel.choose_socketable(&"impact_rune")
	_check(panel.confirm().ok, "insert rune")
	panel.select_operation(CraftingOps.QUALITY)
	await _frames(4)
	await _click_confirm(blade)
	await _shot("loop", "02_crafted")
	await _press(&"ui_cancel")
	_check(character.equipment.equip(blade.instance_id, EquipSlot.Slot.MAIN_HAND) == "", "crafted blade equipped")
	var expected := blade.to_dict()
	session.travel(&"test_arena", &"from_home")
	await _await_map(&"test_arena")
	var enemy: Enemy = map.call(&"spawn_enemy", map.player.global_position + Vector2(26, 0))
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	enemy.health.max_health = 100000.0
	enemy.health.max_poise = 100000.0
	enemy.health.reset()
	var tags: Array[StringName] = []
	map.player.combat.hit_landed.connect(func(hit: HitData) -> void: tags.append_array(hit.tags))
	await _frames(10)
	f.aim_direction = Vector2.RIGHT
	for step: String in ["L", "L"]:
		f.light_pressed = true
		for i in 14:
			await physics_frame
	f.heavy_pressed = true
	f.heavy_held = true
	for i in 50:
		await physics_frame
	f.heavy_held = false
	f.heavy_released = true
	for i in 8:
		await physics_frame
	await _shot("loop", "03_discharge")
	for i in 40:
		await physics_frame
	_log("finisher knocked the grunt to %.1f px" % map.player.global_position.distance_to(enemy.global_position))
	for i in 90:   # walk back into reach like a player would
		var to := enemy.global_position - map.player.global_position
		if to.length() <= 24.0:
			break
		f.move = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO
	f.light_pressed = true
	for i in 30:
		await physics_frame
	var effects := map.bridge.effects
	_check(effects.shared_state(&"storm_wolf_discharge").get("triggers", 0) >= 1, "Storm Wolf discharge fired in the arena")
	_check(&"stone_golem_crush" in tags, "Stone Golem boosted the fully charged finisher")
	_check(&"impact_rune" in tags, "Rune of Impact on heavy hits")
	_check(&"thunder_quake" in tags, "Thunderquake resonance on the follow-up hit")
	await _press(&"debug_save")   # F6
	session.set_character(CharacterFactory.create_new(session.database))
	await _press(&"debug_load")   # F9
	await _await_map(&"test_arena")
	var loaded := session.character.inventory.find(blade.instance_id)
	_check(loaded != null and loaded.to_dict() == expected, "same instance with identical properties after F6/F9")
	_check(map.bridge.effects.has_effect(&"thunder_quake"), "effects active again after loading")
	await _shot("loop", "04_after_load")
