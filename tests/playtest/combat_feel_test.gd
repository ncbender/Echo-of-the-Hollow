extends SceneTree
## Combat feel test (docs/COMBAT_FEEL_TEST.md): the existing test arena with the
## real Player, CombatComponent, input, weapon mastery and burden, for manual
## play with One-Handed Sword, Dagger, Greatsword and Bow. Start (window):
##   Godot --path . -s res://tests/playtest/combat_feel_test.gd
## Isolation: a script main loop makes the session "scripted" (in-memory
## settings, test save path); additionally the save path is a test path, the
## periodic autosave is off and the character is a fresh test character - real
## save slots and settings.cfg are never read or written.
## `-- --selftest` checks start, weapon switching, the mastery toggle and real
## hits on the targets automatically, saves two screenshots and quits.

const ARENA := "res://scenes/arena/test_arena.tscn"
const TEST_SAVE := "user://test_saves/combat_feel/slot_1.save.json"
const OUTPUT := "res://tests/output/combat_feel"

var controller: Node
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := SessionState.find(self)
	session.save_path = TEST_SAVE
	session.saves.periodic_enabled = false
	session.set_character(CharacterFactory.create_new(session.database))
	controller = load("res://tests/playtest/combat_feel_controller.gd").new()
	controller.name = "CombatFeelTest"
	controller.set(&"session", session)
	root.add_child(controller)
	change_scene_to_file(ARENA)
	if "--selftest" in OS.get_cmdline_user_args():
		await _selftest(session)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
	print("%s %s" % ["CHECK OK  " if condition else "CHECK FAIL", label])


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _selftest(session: SessionState) -> void:
	for i in 60:
		await process_frame
		if controller.call(&"player") != null and current_scene is GameMap:
			break
	await _ticks(5)
	var player: Player = controller.call(&"player")
	_check(player != null, "arena started directly (no prologue, no travel)")
	if player == null:
		quit(1)
		return
	_check(session.save_path == TEST_SAVE and not session.saves.periodic_enabled, "test save path, periodic autosave off")
	var group: Array = []
	for dummy in current_scene.get_node("Dummies").get_children():
		if dummy.visible:
			group.append(dummy)
	_check(group.size() == 4, "one single target and a group of three")
	_check(player.combat.mastery_level == 1, "starts at mastery 1")
	var f := InputFrame.new()
	player.feed_input(f)
	for family_id: StringName in [&"one_handed_sword", &"dagger", &"two_handed_sword", &"bow"]:
		controller.call(&"equip", family_id)
		await _ticks(3)
		_check(player.combat.weapon.id == family_id, "%s equipped through the inventory" % family_id)
	controller.call(&"equip", &"one_handed_sword")
	controller.call(&"set_mastery", 20)
	await _ticks(2)
	_check(player.combat.mastery_level == 20, "Y: mastery 20 (all paths)")
	controller.call(&"set_mastery", 1)
	await _ticks(2)
	_check(player.combat.mastery_level == 1, "Y again: back to mastery 1")
	# a real quick attack into the group of three
	player.global_position = Vector2(84, 0)
	await _ticks(2)
	var before := 0
	for dummy in group.slice(1):
		before += int(dummy.get(&"hits_taken"))
	f.aim_direction = Vector2.RIGHT
	f.light_pressed = true
	await _ticks(2)
	await _shot("01_sword_quick_into_group")
	await _ticks(40)
	var after := 0
	for dummy in group.slice(1):
		after += int(dummy.get(&"hits_taken"))
	_check(after > before, "the quick attack hit the group (%d hits)" % (after - before))
	controller.call(&"equip", &"bow")
	await _ticks(3)
	player.global_position = Vector2(-20, 10)
	f.aim_direction = Vector2.LEFT
	var single: Node = group[0]
	var single_before := int(single.get(&"hits_taken"))
	f.light_pressed = true
	await _ticks(14)
	await _shot("02_bow_quick_shot")
	await _ticks(60)
	_check(int(single.get(&"hits_taken")) > single_before, "a Quick Shot hit the single target")
	print("RESULT: %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(0 if failures == 0 else 1)


func _shot(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join("%s.png" % label)))
	print("screenshot %s" % label)
