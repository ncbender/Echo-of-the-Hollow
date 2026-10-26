extends TestCase
## End-to-end gameplay loop (headless, real scene changes, real combat):
## start in base -> forest -> fight -> gather -> back -> build -> save -> load.

const TEST_SAVE := "user://test_saves/loop_test.save.json"

var session: SessionState
var _previous_character: Character
var _previous_path: String
var f := InputFrame.new()


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = TEST_SAVE
	session.set_character(CharacterFactory.create_new(session.database))


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			f = InputFrame.new()
			map.player.feed_input(f)
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _teleport(map: GameMap, at: Vector2) -> void:
	map.player.global_position = at
	for i in 3:
		await get_tree().physics_frame


func test_full_loop() -> void:
	var character := session.character
	# 1. start in the home base (main scene)
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/ui/title_screen.tscn", "main scene is the title screen")
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	var home := await _await_map(&"home_base")
	if home == null:
		return
	# 2. enter the forest by walking through the east door
	var door := home.get_node("ToForest") as Node2D
	for i in 600:
		if session.is_traveling():
			break
		f.move = (door.global_position - home.player.global_position).normalized()
		await get_tree().physics_frame
	var forest := await _await_map(&"whisper_forest", 600)
	if forest == null:
		return
	# 3. fight: kill one grunt with real light attacks
	var grunt := forest.get_node("Enemies/GruntA") as Enemy
	var mastery_before := character.mastery.get_xp(&"one_handed_sword") + character.mastery.get_level(&"one_handed_sword") * 1000
	await _teleport(forest, grunt.global_position + Vector2(-22, 0))
	for i in 900:
		if grunt.health.is_dead():
			break
		var to := grunt.global_position - forest.player.global_position
		f.aim_direction = to.normalized()
		f.move = to.normalized() if to.length() > 24.0 else Vector2.ZERO
		if forest.player.combat.state == CombatComponent.State.IDLE:
			f.light_pressed = true
		forest.player.health.heal(1000.0)   # keep the test independent of enemy damage
		await get_tree().physics_frame
	f.move = Vector2.ZERO
	check(grunt.health.is_dead(), "grunt defeated in combat")
	check(character.mastery.get_xp(&"one_handed_sword") + character.mastery.get_level(&"one_handed_sword") * 1000 > mastery_before, "mastery XP from the fight")
	# 4./5. gather resources into the real inventory
	var gathered := 0
	for node: ResourceNode in forest.find_children("*", "ResourceNode", true, false):
		await _teleport(forest, node.global_position + Vector2(0, 14))
		check(node.player_inside, "player stands at %s" % node.name)
		if node.gather() == "":
			gathered += 1
	check(gathered >= 8, "gathered from %d nodes" % gathered)
	for item_id: StringName in [&"timber", &"stone", &"iron_ore"]:
		check(character.inventory.count(item_id) > 0, "%s in inventory" % item_id)
	# 6. return home through the west door
	await _teleport(forest, Vector2(-290, 0))
	f.move = Vector2.LEFT
	home = await _await_map(&"home_base", 600)
	if home == null:
		return
	check(home.player.global_position.distance_to(home.find_spawn(&"from_forest").global_position) < 2.0, "arrived at the forest door")
	# 7./8. restore the Old Storehouse with the gathered materials (Haven has
	# fixed ruins; the prologue already rekindled the smithy in this story state)
	character.world.set_flag(&"haven.old_smithy.restored")
	var capacity_before := character.inventory.capacity
	var plot := home.get_node("Ruins/OldStorehouse") as RuinSite
	await _teleport(home, plot.global_position + Vector2(0, 26))
	plot.interact(home.hud)
	check(home.hud.stash_panel.visible, "the ruined storehouse opens the Haven stash")
	(home.hud.stash_panel.find_child("RestoreStorehouse", true, false) as Button).pressed.emit()
	check(home.hud.restoration_panel.visible, "restoration window from the stash")
	check_eq(home.hud.restoration_panel.restore(), "", "storehouse restored from gathered materials")
	check_eq(character.inventory.capacity, capacity_before + 10, "storehouse adds inventory slots")
	var timber_after_build := character.inventory.count(&"timber")
	# 9. save and load
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(session.database))
	check(session.load_game().ok(), "loaded")
	home = await _await_map(&"home_base")
	if home == null:
		return
	# 10. building and progress are still there
	var loaded := session.character
	check_eq(RestorationService.stage(loaded, &"old_storehouse"), &"restored", "restoration persisted")
	check((home.get_node("Ruins/OldStorehouse") as RuinSite).built_building() != null, "storehouse shown in Haven")
	check_eq(loaded.inventory.capacity, capacity_before + 10, "capacity bonus after loading")
	check_eq(loaded.inventory.count(&"timber"), timber_after_build, "inventory persisted")
	check_eq(loaded.mastery.to_dict(), character.mastery.to_dict(), "mastery persisted")
	check(not ResourceGathering.is_available(loaded.world, &"whisper_forest", &"deposit", Time.get_unix_time_from_system() + 1.0e9), "permanent deposit stays exhausted")
