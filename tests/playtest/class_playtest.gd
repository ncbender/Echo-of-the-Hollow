extends SceneTree
## Visual class test (NOT headless).
##   godot --path . -s res://tests/playtest/class_playtest.gd              # UI: 1080p/4K x 100/150 %
##   godot --path . --fixed-fps 60 -s res://tests/playtest/class_playtest.gd -- --prologue
## UI mode: class station pages (classes, talent trees with prerequisite lines,
## skills + mods, presets, quests) and the class choice, each in four display
## configurations; layout checks (on screen, not squeezed, margin), a real mouse
## hover tooltip on a talent and one real mouse click that learns a rank.
## --prologue: the whole prologue in a window - all three class trials fought
## by a scripted player against real grunts, the permanent choice at the altar,
## F6 save, F9 load and a check that exactly the chosen class is unlocked.
## --polish (Class Combat Polish 0.3): Shadowrunner in the arena - Focus regenerates
## while idle and fighting, Shadowstep is refused without a target (nothing spent)
## and closes in on a real grunt, Space dash unchanged; Warrior Blade Rush charge.
## Screenshots and log: tests/output/classes/.

const OUTPUT := "res://tests/output/classes"
const PASSES: Array = [[Vector2i(1280, 720), 1.0], [Vector2i(1280, 720), 1.5], [Vector2i(1280, 720), 1.25], [Vector2i(1920, 1080), 1.0], [Vector2i(1920, 1080), 1.5],
	[Vector2i(1920, 1080), 1.25], [Vector2i(2560, 1440), 1.0],
	[Vector2i(3840, 2160), 1.0], [Vector2i(3840, 2160), 1.5], [Vector2i(3840, 2160), 1.25]]

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/class_playtest.save.json"
	if "--prologue" in OS.get_cmdline_user_args():
		await _prologue()
	elif "--polish" in OS.get_cmdline_user_args():
		await _polish()
	else:
		for pass_spec: Array in PASSES:
			await _ui_pass(pass_spec[0], pass_spec[1])
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("class_playtest_log%s.txt" % ("_" + OS.get_cmdline_user_args()[0].trim_prefix("--") if not OS.get_cmdline_user_args().is_empty() else "")), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


# --- UI passes ------------------------------------------------------------------------

func _ui_pass(resolution: Vector2i, scale: float) -> void:
	var tag := "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	var character := CharacterFactory.create_new(session.database)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.chosen_class = &"warrior"
	character.classes.unlock(&"warrior")
	character.classes.set_active(&"warrior")
	character.classes.add_xp(&"warrior", 30000)   # ~level 40
	for node_id: StringName in [&"war_b_seething", &"war_b_seething", &"war_b_seething", &"war_b_seething", &"war_b_seething",
			&"war_b_temper", &"war_b_whirlwind", &"war_b_relentless", &"war_b_relentless", &"war_bb_serrated", &"war_bb_serrated"]:
		TalentService.learn(character, &"warrior", node_id)
	PresetService.save_preset(character, &"warrior", 0, "Berserker")
	PresetService.save_preset(character, &"warrior", 1, "Opener")
	QuestService.start(character, &"unlock_arcanist")
	session.set_character(character)
	session.settings.set_ui_scale(scale)
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = resolution
	root.position = DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	await _load_map("res://scenes/maps/home_base.tscn", &"home_base")
	var station := map.get_node("ClassStation") as ClassStation
	map.player.global_position = station.global_position
	await _frames(8)
	station.interact(map.hud)
	var panel := map.hud.class_panel
	_check(panel.visible and panel.at_station(), "%s class station opens with G" % tag)
	for page_name: String in ClassStationPanel.PAGES:
		panel.show_page(page_name)
		await _frames(4)
		panel.fit()
		await _frames(2)
		_check_layout("%s %s" % [tag, page_name])
		await _shot(tag, "%s" % page_name.to_lower())
		if page_name == "Talents":
			await _talent_mouse(tag, panel)
		if page_name == "Presets":
			var activate := panel.find_children("Activate", "Button", true, false)
			_check(not activate.is_empty() and activate[0].text.contains("free"), "%s preset costs shown" % tag)
	await _tab_stability(tag, panel)   # after the page checks: its clicks and keys move the OS cursor
	map.hud.close_windows()
	map.hud.class_choice_panel.open(character, null)
	await _frames(4)
	map.hud.class_choice_panel.fit()
	await _frames(2)
	_check_layout("%s class choice" % tag)
	await _shot(tag, "class_choice")
	map.hud.close_windows()
	# HUD with skill bar and resource while fighting stance
	await _shot(tag, "hud_skillbar")
	session.settings.reset_to_defaults()


## Real mouse on the talent page (Skills & Talents UX 2.0 Phase 2: one tree at a time): hover nodes in all
## three trees (left, right edge, top row, capstone) - the tooltip shows the node and stays on screen; a real
## click only selects, a real click on Learn learns a rank; real clicks on the book tabs switch pages (also
## while the tree area is scrolled) and back.
func _talent_mouse(tag: String, panel: ClassStationPanel) -> void:
	var targets: Array = [[&"war_berserker", &"war_b_temper"], [&"war_bloodblade", &"war_bb_veins"], [&"war_warbreaker", &"war_wb_hands"],
		[&"war_warbreaker", &"war_wb_worldbreaker"], [&"war_bloodblade", &"war_bb_price"]]
	for target: Array in targets:
		panel.show_tree(target[0])
		await _frames(3)
		var view: TalentTreeView = panel._trees[0]
		var button := view.button_for(target[1])
		var at := await _bring_into_view(panel, button)
		await _hover(at)
		var tooltip := panel.talent_tooltip
		_check(tooltip.visible and tooltip.node_id == StringName(button.name), "%s tooltip for %s on hover" % [tag, button.name])
		_check(panel.get_viewport_rect().grow(1.0).encloses(tooltip.get_global_rect()), "%s tooltip of %s on screen" % [tag, button.name])
		_check(not tooltip.get_global_rect().intersects(button.get_global_rect().grow(-2.0)), "%s tooltip of %s does not cover the node" % [tag, button.name])
		await _shot(tag, "talent_tooltip_%s" % button.name)
	var character := session.character
	panel.show_tree(&"war_berserker")
	await _frames(3)
	var temper := panel.tree_view(&"war_berserker").button_for(&"war_b_temper")
	var temper_at := await _bring_into_view(panel, temper)
	await _hover(temper_at)
	var rank := character.builds.get_build().rank(&"war_b_temper")
	await _click(temper_at, MOUSE_BUTTON_LEFT)
	_check(character.builds.get_build().rank(&"war_b_temper") == rank and panel.selected_talent() == &"war_b_temper", "%s real mouse click only selected" % tag)
	var learn := panel.find_child("LearnTalent", true, false) as Button
	await _click(root.get_final_transform() * learn.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(2)
	_check(character.builds.get_build().rank(&"war_b_temper") == mini(rank + 1, 3), "%s real click on Learn learned a talent rank" % tag)
	# book tabs: Skills and back, with the tree area scrolled down if it can scroll
	var scroll := panel.find_child("TreeScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 10000
		await _frames(2)
	for id: String in ["Skills", "Talents"]:
		var tab := panel.find_child("BookTabs", true, false).find_child("Tab%s" % id, false, false) as Button
		await _click(root.get_final_transform() * tab.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		await _frames(3)
		_check(panel.page == id, "%s real click on the %s register" % [tag, id])
	_check(character.builds.get_build().rank(&"war_b_temper") == mini(rank + 1, 3), "%s switching pages changed no talent" % tag)
	Input.warp_mouse(Vector2(4, 4))
	await _frames(2)


## Book Tabs Stability Fix 1.3: two rounds over all five registers - first by
## real mouse clicks, then by real keys (Down + Enter from register to register) -
## and after every switch the registers and the window frame must be exactly
## where they were; everything inside the viewport.
func _tab_stability(tag: String, panel: ClassStationPanel) -> void:
	var tabs := panel.find_child("BookTabs", true, false) as BookTabs
	panel.show_page("Classes")
	await _frames(4)
	var reference := _tab_rects(panel, tabs)
	var moved: PackedStringArray = []
	for id: String in ClassStationPanel.PAGES:   # round 1: mouse
		await _click(root.get_final_transform() * tabs.tab_button(id).get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		await _frames(3)
		_check(panel.page == id, "%s mouse opens %s" % [tag, id])
		if _tab_rects(panel, tabs) != reference:
			moved.append("mouse %s" % id)
	Input.warp_mouse(Vector2(4, 4))
	tabs.tab_button("Classes").grab_focus()   # round 2: keyboard from the first register
	await _key(KEY_ENTER)
	for index in ClassStationPanel.PAGES.size():
		if index > 0:
			await _key(KEY_DOWN)
			await _key(KEY_ENTER)
		var id: String = ClassStationPanel.PAGES[index]
		_check(panel.page == id, "%s keyboard opens %s" % [tag, id])
		if _tab_rects(panel, tabs) != reference:
			moved.append("keys %s" % id)
	_check(moved.is_empty(), "%s registers and frame never move (%s)" % [tag, ", ".join(moved)])
	var view := panel.get_viewport_rect().grow(1.0)
	_check(view.encloses(panel.get_global_rect()) and view.encloses(tabs.get_global_rect()), "%s frame and registers inside the viewport" % tag)
	await _shot(tag, "book_tabs_%s" % panel.page.to_lower())


## Window frame plus each register's vertical place and page-side edge.
func _tab_rects(panel: ClassStationPanel, tabs: BookTabs) -> Array:
	var result: Array = [panel.get_global_rect(), tabs.get_global_rect()]
	for id: String in ClassStationPanel.PAGES:
		var rect := tabs.tab_button(id).get_global_rect()
		result.append(Vector2(rect.end.x, rect.position.y))
	return result


func _bring_into_view(panel: ClassStationPanel, button: Control) -> Vector2:
	var parent := button.get_parent()
	while parent != null and parent != panel.get_parent():
		if parent is ScrollContainer:
			(parent as ScrollContainer).ensure_control_visible(button)
			await _frames(2)
		parent = parent.get_parent()
	await _frames(2)
	return root.get_final_transform() * button.get_global_rect().get_center()


func _hover(at: Vector2) -> void:
	for spot: Vector2 in [at + Vector2(0, 40), at]:   # come from outside, as a player would
		Input.warp_mouse(spot)
		var motion := InputEventMouseMotion.new()
		motion.position = spot
		motion.global_position = spot
		motion.relative = Vector2(1, 0)
		Input.parse_input_event(motion)
		await _frames(3)


func _click(at: Vector2, button_index: MouseButton) -> void:
	await _hover(at)   # a real click always follows a mouse movement onto the target
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button_index
		click.pressed = pressed
		click.position = at
		click.global_position = at
		Input.parse_input_event(click)
		await _frames(2)


# --- Prologue ----------------------------------------------------------------------

func _prologue() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	session.set_character(CharacterFactory.create_new(session.database))
	var character := session.character
	await _load_map("res://scenes/arena/test_arena.tscn", &"test_arena")   # the Prologue Grounds gate is a developer gate in the arena
	_check(character.classes.active_class_id == &"basic_adventurer", "starts as Basic Adventurer")
	var gate := map.get_node("GatePrologue") as MapGate
	map.player.global_position = gate.global_position
	await _frames(6)
	await _key(KEY_G)
	await _wait_map(&"prologue")
	await _shot("prologue", "01_start")
	for entry: Array in [[&"TrialWarrior", [0, 3, 0, 1]], [&"TrialArcanist", [0, 0, 0, 1, 0, 0, 1]], [&"TrialShadowrunner", [1, 3, 1, 3]]]:
		var station := map.get_node(String(entry[0])) as TrialStation
		map.player.global_position = station.global_position
		await _frames(6)
		await _key(KEY_G)
		await _frames(4)
		_check(character.classes.in_trial(), "%s: trial started with G" % entry[0])
		var class_id := character.classes.active_class_id
		await _shot("prologue", "02_%s_start" % class_id)
		await _fight(entry[1], 45.0)
		_check(character.prologue.has_completed_trial(station.trial_id), "%s completed in real combat" % station.trial_id)
		_check(not character.classes.is_unlocked(class_id), "%s still locked after its trial" % class_id)
		await _shot("prologue", "03_%s_done" % class_id)
		map.player.health.reset()
	var altar := map.get_node("AltarOfChoice") as ClassChoiceStation
	map.player.global_position = altar.global_position
	await _frames(6)
	await _key(KEY_G)
	await _frames(4)
	var panel := map.hud.class_choice_panel
	_check(panel.visible, "altar opens the class choice")
	await _shot("prologue", "04_choice")
	for click in 2:   # choose, then confirm
		var button := panel.find_children("Choose_shadowrunner", "Button", true, false)[0] as Button
		button.emit_signal(&"pressed")
		await _frames(3)
	await _shot("prologue", "05_chosen")
	_check(character.classes.active_class_id == &"shadowrunner", "shadowrunner chosen and active")
	_check(not character.classes.is_unlocked(&"warrior") and not character.classes.is_unlocked(&"arcanist"), "the other two stay locked")
	map.hud.close_windows()
	await _key(KEY_F6)
	await _frames(10)
	session.set_character(CharacterFactory.create_new(session.database))
	await _key(KEY_F9)
	await _wait_map(&"prologue")
	var loaded := session.character
	_check(loaded.classes.active_class_id == &"shadowrunner", "after F9: shadowrunner")
	_check(not loaded.classes.is_unlocked(&"warrior") and not loaded.classes.is_unlocked(&"arcanist"), "after F9: others locked")
	_check(loaded.prologue.is_completed(), "after F9: prologue complete")
	await _shot("prologue", "06_after_load")


## Scripted fighter: walks to the nearest enemy, aims at it, light attacks and
## presses the skill slots of `rotation` in turn, until the trial ends.
func _fight(rotation: Array, seconds: float) -> void:
	var player := map.player
	var frame := InputFrame.new()
	player.feed_input(frame)
	var ticks := 0
	var step := 0
	while map.bridge.character.classes.in_trial() and ticks < seconds * 60.0:
		var target := _nearest_enemy()
		frame.clear_edges()
		frame.move = Vector2.ZERO
		if target != null:
			var to := target.global_position - player.global_position
			frame.aim_direction = to.normalized()
			# casters keep distance unless the next skill is the close-range Mana Pulse (slot E)
			var next_slot: int = rotation[step % rotation.size()]
			var wanted := 60.0 if map.bridge.character.classes.active_class_id == &"arcanist" and next_slot != 1 else 22.0
			if to.length() > wanted:
				frame.move = to.normalized()
			if ticks % 15 == 0 and to.length() < 34.0:
				frame.light_pressed = true
			if ticks % 50 == 25:
				frame.ability_slot = rotation[step % rotation.size()]
				step += 1
		ticks += 1
		await physics_frame
	frame.clear_edges()
	frame.move = Vector2.ZERO
	player.use_external_input = false
	_log("fight ended after %.1f s" % (ticks / 60.0))


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	for node in map.get_node("Enemies").get_children():
		var enemy := node as Enemy
		if enemy != null and enemy.state != Enemy.State.DEAD and (best == null \
				or enemy.global_position.distance_to(map.player.global_position) < best.global_position.distance_to(map.player.global_position)):
			best = enemy
	return best


# --- helpers -------------------------------------------------------------------------

func _load_map(path: String, map_id: StringName) -> void:
	change_scene_to_file(path)
	await _wait_map(map_id)


func _wait_map(map_id: StringName) -> void:
	for i in 400:
		await process_frame
		map = current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(10)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _tooltip(node: Node) -> Window:
	for child in node.get_children(true):
		if child is PopupPanel and (child as Window).visible:
			return child
		var found := _tooltip(child)
		if found != null:
			return found
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
	print(text)
	log_lines.append(text)


# --- Class Combat Polish 0.3 -------------------------------------------------------------

func _polish() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	var character := CharacterFactory.create_new(session.database)
	for class_id: StringName in [&"shadowrunner", &"warrior"]:
		character.classes.unlock(class_id)
		character.classes.add_xp(class_id, 1500)   # level 8+: all base skills
	character.classes.set_active(&"shadowrunner")
	session.set_character(character)
	await _load_map("res://scenes/arena/test_arena.tscn", &"test_arena")
	var player := map.player
	var frame := InputFrame.new()
	player.feed_input(frame)
	map.bridge.message.connect(func(text: String) -> void: _log("message: " + text))
	var runtime := map.bridge.class_runtime
	var pool := runtime.pool
	pool.spend(pool.value)
	for i in 60:
		await physics_frame
	_check(absf(pool.value - 6.0) < 0.5, "focus regenerates while idle (%.1f after 1 s)" % pool.value)
	# no target: Shadowstep refused, nothing spent
	player.global_position = Vector2(-200, 150)
	frame.aim_direction = Vector2.DOWN
	await _frames(4)
	pool.gain(50.0)   # enough focus: the only reason to refuse is the missing target
	var reasons: Array[String] = []
	map.bridge.message.connect(func(text: String) -> void: reasons.append(text))
	var focus := pool.value
	var start := player.global_position
	frame.ability_slot = character.builds.get_build().slot_of(&"shadowstep")
	await physics_frame
	for i in 10:
		await physics_frame
	_check(runtime.cooldown_left(&"shadowstep") == 0.0 and pool.value >= focus and player.global_position.distance_to(start) < 0.5 \
		and reasons.any(func(r: String) -> bool: return r.contains("No enemy")), "Shadowstep without a target: refused (%s), no cost, no movement" % [reasons])
	await _shot("polish", "01_shadowstep_no_target")
	# real grunt in front: close in, arrival hit
	player.global_position = Vector2(0, 150)   # away from the arena dummies
	var grunt := map.spawn_enemy(Vector2(110, 150))
	grunt.config = grunt.config.duplicate()
	grunt.config.move_speed = 0.0
	grunt.config.attack_range = 0.0
	frame.aim_direction = Vector2.RIGHT
	await _frames(6)
	pool.gain(100.0)
	var charges := player.dash.charges
	frame.ability_slot = character.builds.get_build().slot_of(&"shadowstep")
	await physics_frame
	for i in 4:
		await physics_frame
	await _shot("polish", "02_shadowstep_moving")
	for i in 20:
		await physics_frame
	var gap := player.global_position.distance_to(grunt.global_position)
	_check(gap < 26.0, "Shadowstep closed in on the grunt (gap %.1f)" % gap)
	_check(StatusComponent.of(grunt).has(&"weak_point"), "arrival exposed a Weak Point")
	_check(player.dash.charges == charges, "no dash charge used")
	await _shot("polish", "03_shadowstep_arrived")
	# fight: regeneration continues, hits add nothing
	pool.spend(pool.value)
	var regen_start := pool.value
	# the player consumes edge flags itself (physics_frame fires before node processing)
	for i in 60:
		frame.light_pressed = i % 15 == 0
		await physics_frame
	_check(absf(pool.value - regen_start - 6.0) < 0.6, "in combat: +6 focus per second, nothing from hits (%.1f)" % (pool.value - regen_start))
	# Space dash: no WASD -> towards the aim
	frame.aim_direction = Vector2.LEFT
	frame.dash_pressed = true
	await physics_frame
	_check(player.dash.is_dashing() and player.dash.direction == Vector2.LEFT, "Space dash without WASD goes towards the aim")
	for i in 40:
		await physics_frame
	# Warrior Blade Rush
	grunt.queue_free()
	character.classes.set_active(&"warrior")
	await _frames(4)
	runtime = map.bridge.class_runtime
	runtime.pool.gain(100.0)
	player.global_position = Vector2(-60, -150)
	var dummy_target := map.spawn_enemy(Vector2(40, -150))
	dummy_target.config = dummy_target.config.duplicate()
	dummy_target.config.move_speed = 0.0
	dummy_target.config.attack_range = 0.0
	frame.aim_direction = Vector2.RIGHT
	await _frames(6)
	frame.ability_slot = character.builds.get_build().slot_of(&"blade_rush")
	await physics_frame
	for i in 4:
		await physics_frame
	await _shot("polish", "04_blade_rush")
	for i in 25:
		await physics_frame
	_check(player.global_position.distance_to(dummy_target.global_position) < 26.0, "Blade Rush charged to the grunt")
	_check(runtime.cooldown_left(&"blade_rush") > 0.0, "Blade Rush cast")
	await _shot("polish", "05_blade_rush_arrived")
	player.use_external_input = false
