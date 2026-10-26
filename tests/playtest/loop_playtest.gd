extends SceneTree
## Scripted end-to-end playtest of the world loop (NOT headless). The player is
## driven only through InputFrames (walking through doorways), the UI through
## real input events / buttons. Uses a separate test save. Run:
##   godot --path . --fixed-fps 60 -s res://tests/playtest/loop_playtest.gd

const OUTPUT := "res://tests/output"
const TEST_SAVE := "user://test_saves/loop_playtest.save.json"

var session: SessionState
var map: GameMap
var f := InputFrame.new()
var log_lines: PackedStringArray = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = TEST_SAVE
	session.set_character(CharacterFactory.create_new(session.database))
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	await _await_map(&"home_base")
	if "--build-only" in OS.get_cmdline_user_args():
		await _world_tour()
		await _build_check()
	elif "--tour" in OS.get_cmdline_user_args():
		await _world_tour()
	else:
		await _gameplay_loop()
	_log("RESULT: %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("loop_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _world_tour() -> void:
	await _shot("l01_home_start")
	_check(map.map_id == &"home_base", "game starts in the home base")
	await _walk_into_door("ToForest")
	await _await_map(&"whisper_forest")
	_check(_at_spawn(&"from_home"), "forest: entered at the west door")
	await _shot("l02_forest")
	await _walk_into_door("ToHomeBase")
	await _await_map(&"home_base")
	_check(_at_spawn(&"from_forest"), "home: arrived at the east door")
	await _walk_into_door("ToArena")
	await _await_map(&"test_arena")
	_check(_at_spawn(&"from_home"), "arena: entered at the west door")
	await _shot("l03_arena")
	await _walk_into_door("ToHomeBase")
	await _await_map(&"home_base")
	_check(_at_spawn(&"from_arena"), "home: arrived at the north door")


func _gameplay_loop() -> void:
	var character := session.character
	await _shot("g01_start_in_base")
	_check(map.map_id == &"home_base", "1. starts in the home base")
	await _walk_into_door("ToForest")
	await _await_map(&"whisper_forest")
	_check(map.map_id == &"whisper_forest", "2. entered the forest")
	# 3. fight the nearest grunt with light attacks
	var grunt := map.get_node("Enemies/GruntA") as Enemy
	var hp_before := grunt.health.health
	for i in 1500:
		if grunt.health.is_dead():
			break
		var to := grunt.global_position - map.player.global_position
		f.aim_direction = to.normalized()
		f.move = to.normalized() if to.length() > 24.0 else Vector2.ZERO
		if map.player.combat.state == CombatComponent.State.IDLE and to.length() < 34.0:
			f.light_pressed = true
		if i == 60:
			await _shot("g02_forest_fight")
		await physics_frame
	f.move = Vector2.ZERO
	_check(grunt.health.is_dead(), "3. grunt defeated by player attacks (hp %d -> 0)" % hp_before)
	await _ticks(10)
	for pickup: ItemPickup in map.find_children("*", "ItemPickup", true, false):
		await _walk_to(pickup.global_position)
	# 4. gather by walking to every node and pressing G
	var ore_before := character.inventory.count(&"iron_ore")
	for node: ResourceNode in map.find_children("*", "ResourceNode", true, false):
		await _walk_to(node.global_position + Vector2(0, 16))
		if node.player_inside:
			await _press(&"interact")
	await _shot("g03_forest_gathered")
	var timber := character.inventory.count(&"timber")
	var stone := character.inventory.count(&"stone")
	_check(timber >= 6 and stone >= 4 and character.inventory.count(&"iron_ore") >= 3,
		"5. resources in inventory (timber %d, stone %d, ore %d -> %d)" % [timber, stone, ore_before, character.inventory.count(&"iron_ore")])
	# 6. back home
	await _walk_to(Vector2(-280, 0))
	await _walk_into_door("ToHomeBase")
	await _await_map(&"home_base")
	_check(map.map_id == &"home_base", "6. returned to the base")
	# 7./8. choose a plot and build with the gathered materials
	var plot := map.get_node("Plots/PlotWest") as BuildPlot
	await _walk_to(plot.global_position + Vector2(0, 30))
	await _press(&"interact")
	_check(map.hud.build_panel.visible, "7. build menu opened at the plot")
	await _shot("g04_build_menu")
	_click_button(map.hud.build_panel, "Build")
	await _ticks(3)
	_check(plot.built_building() != null, "8. building constructed")
	await _press(&"interact")
	await _shot("g05_smithy_standing")
	# 9. save and reload
	var snapshot := character.to_dict()
	await _press(&"debug_save")
	_check(FileAccess.file_exists(TEST_SAVE), "9. F6 saved (test slot)")
	session.set_character(CharacterFactory.create_new(session.database))
	await _press(&"debug_load")
	await _await_map(&"home_base")
	# 10. everything is still there
	var loaded := session.character
	_check(comparable(loaded.to_dict()) == comparable(snapshot), "10. loaded state equals the saved state (except visit counters)")
	var plot_after := map.get_node("Plots/PlotWest") as BuildPlot
	_check(plot_after.built_building() != null, "10. smithy still standing after load")
	await _shot("g06_after_load")


func _build_check() -> void:
	var character := session.character
	var smithy: BuildingDefinition = session.database.buildings[&"smithy"]
	for cost in smithy.costs:
		character.inventory.add_item(cost.item_id, cost.quantity)
	character.inventory.add_item(&"iron_ore", 3)
	character.inventory.add_item(&"timber", 1)
	var plot := map.get_node("Plots/PlotWest") as BuildPlot
	await _walk_to(plot.global_position + Vector2(0, 28))
	await _press(&"interact")
	_check(map.hud.build_panel.visible, "build panel opened at the plot")
	await _shot("l04_build_menu")
	_click_button(map.hud.build_panel, "Build")
	await _ticks(3)
	_check(plot.built_building() != null and plot.built_building().id == &"smithy", "smithy built via UI")
	_click_button(map.hud.build_panel, "Craft")
	_check(character.inventory.count(&"iron_sword") == 2, "smithy recipe crafted a second Iron Sword")
	await _shot("l05_smithy_built")


# --- helpers ---------------------------------------------------------------

func _await_map(map_id: StringName, limit: int = 300) -> void:
	for i in limit:
		await process_frame
		var current := current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			f = InputFrame.new()
			map.player.feed_input(f)
			await _ticks(15)   # let the fade-in finish
			_log("arrived in %s" % map_id)
			return
	_check(false, "reached map %s" % map_id)


func _walk_into_door(door_name: String, limit: int = 400) -> void:
	var door := map.get_node(door_name) as Node2D
	for i in limit:
		if session.is_traveling():
			break
		var to := door.global_position - map.player.global_position
		f.move = to.normalized()
		f.aim_direction = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO


func _walk_to(target: Vector2, limit: int = 400) -> void:
	for i in limit:
		var to := target - map.player.global_position
		if to.length() < 6.0:
			break
		f.move = to.normalized()
		f.aim_direction = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO
	await _ticks(3)


func _at_spawn(spawn_id: StringName) -> bool:
	var point := map.find_spawn(spawn_id)
	return point != null and map.player.global_position.distance_to(point.global_position) < 2.0


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _ticks(2)


func _click_button(container: Node, text: String) -> bool:
	for button: Button in container.find_children("*", "Button", true, false):
		if button.text == text and not button.disabled and not button.is_queued_for_deletion():
			button.pressed.emit()
			_log("clicked '%s'" % text)
			return true
	_check(false, "button '%s' found" % text)
	return false


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s.png" % label)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
	_log("%s %s" % ["CHECK OK  " if condition else "CHECK FAIL", text])


func _log(text: String) -> void:
	var line := "[%5d] %s" % [Engine.get_physics_frames(), text]
	log_lines.append(line)
	print(line)


## Character data without the per-visit counters that entering a map updates.
static func comparable(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	for map: String in copy.world.map_states:
		(copy.world.map_states[map] as Dictionary).erase("visits")
	return copy
