extends SceneTree
## Scripted end-to-end playtest of the prologue in a REAL window (not headless):
## title screen -> New Game -> Old Road -> Mara's cart -> Haven ... The player is
## driven only through InputFrames (move, aim, attack) and the interact key as
## a real input event; no debug keys (F4/F6/F9/F10) and no direct story calls.
## Uses a separate test profile. Screenshots + log in tests/output. Run:
##   godot --path . --fixed-fps 60 -s res://tests/playtest/prologue_playtest.gd
## Optional user args (after --): --until=road|haven|stone|all

const OUTPUT := "res://tests/output"
const PROFILE := "user://test_saves/prologue_playtest/slot_1.save.json"

var session: SessionState
var map: GameMap
var f := InputFrame.new()
var log_lines: PackedStringArray = []
var failures: int = 0
var _started_ms: int = 0
var _deaths: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = PROFILE
	_clean_profile()
	_started_ms = Time.get_ticks_msec()
	change_scene_to_file(SessionState.TITLE_SCENE)
	await _ticks(20)
	await _shot("p00_title")
	var title := current_scene as TitleScreen
	_check(title != null, "title screen is the main menu")
	if title != null:
		_check((title.find_child("Continue", true, false) as Button).disabled, "no save yet: Continue disabled")
		_click_button(title, "New Game")
	await _await_map(&"old_road")
	var until := _arg("until", "all")
	await _road()
	if until != "road":
		await _haven()
	_log("play time (character clock): %.0f s, wall clock: %.0f s" % [session.character.play_time if session.character else 0.0,
		(Time.get_ticks_msec() - _started_ms) / 1000.0])
	_log("RESULT: %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("prologue_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


# --- sections -------------------------------------------------------------

func _road() -> void:
	var character := session.character
	_check(character.classes.active_class_id == &"basic_adventurer", "New Game: Basic Adventurer")
	await _ticks(30)
	await _shot("p01_road_start")
	_check(map.hud.has_hint("WASD"), "movement hint shown")
	await _walk_to(Vector2(0, 430))
	_check(StoryService.at_step(character, &"a_road_forgotten", 1), "signpost reached")
	await _walk_to(Vector2(30, 410))
	await _press(&"interact")
	_check(map.hud.dialogue_panel.visible and map.hud.dialogue_panel.current_text().contains("HAVEN"), "signpost read")
	await _press(&"interact")
	# around the fallen tree (it blocks the west part of the road)
	await _walk_to(Vector2(110, 330))
	await _walk_to(Vector2(110, 260))
	await _walk_to(Vector2(0, 200))
	await _shot("p02_ambush")
	await _fight(map.get_node("Encounters/RoadAmbush") as Encounter)
	_check(StoryService.at_step(character, &"a_road_forgotten", 2), "ambush defeated")
	await _walk_to(Vector2(0, -70))
	_check(character.world.spawn_id == &"rest", "rest area passed")
	# optional side path: the note
	await _walk_to(Vector2(-300, -60))
	await _fight(map.get_node("Encounters/SideWolves") as Encounter, true)
	await _walk_to(Vector2(-360, -96))   # optional: timber and stone for the Old Storehouse
	await _press(&"interact")
	await _walk_to(Vector2(-470, 22))
	await _press(&"interact")
	_log("  gathered: timber %d, stone %d" % [character.inventory.count(&"timber"), character.inventory.count(&"stone")])
	await _walk_to(Vector2(-540, -60))
	await _press(&"interact")
	_check(map.hud.dialogue_panel.current_text() == "Third shipment delayed. Mara went ahead before sunrise.", "note read")
	await _shot("p03_note")
	await _press(&"interact")
	await _walk_to(Vector2(-60, -60))
	await _walk_to(Vector2(-60, -240))
	_check(StoryService.at_step(character, &"the_broken_cart", 0), "cart reached")
	await _walk_to(Vector2(-60, -290))
	await _ticks(10)
	var mara := map.get_node("Mara") as CompanionNpc
	_check(mara.current_bark().contains("blade"), "Mara: If you've got a blade ...")
	await _shot("p04_cart_fight")
	await _fight(map.get_node("Encounters/CartAttack") as Encounter)
	_check(mara.strikes > 0, "Mara helped in the fight (%d strikes)" % mara.strikes)
	await _talk_to(mara)
	_check(StoryService.at_step(character, &"the_broken_cart", 2), "talked to Mara")
	_log("  crates: west visible %s, HP %.0f" % [(map.get_node("CrateWest") as StoryPickup).visible, map.player.health.health])
	await _walk_to(Vector2(-166, -372))
	await _press(&"interact")
	await _walk_to(Vector2(-60, -300))
	await _walk_to(Vector2(110, -262))
	await _press(&"interact")
	_check(character.inventory.count(&"supply_crate") == 2, "two supply crates recovered (%d, player at %s)" % [character.inventory.count(&"supply_crate"), map.player.global_position])
	await _shot("p05_second_wave")
	await _fight(map.get_node("Encounters/SecondWave") as Encounter)
	_check(StoryService.at_step(character, &"the_broken_cart", 4), "second wave survived")
	await _talk_to(mara)
	_check(StoryService.at_step(character, &"shelter_among_the_trees", 0), "Mara: there's a place north of here")
	_check(mara.is_following(), "Mara follows")
	await _walk_to(Vector2(-60, -480))
	await _shot("p06_escort")
	_check(mara.global_position.distance_to(map.player.global_position) < 80.0, "Mara keeps up (%.0f px)" % mara.global_position.distance_to(map.player.global_position))
	_log("Mara recoveries on the road: %d" % mara.recoveries)
	await _walk_into(map.get_node("ToHaven") as Node2D)
	await _await_map(&"home_base")
	_check(StoryService.at_step(character, &"shelter_among_the_trees", 1), "arrived in Haven")
	await _ticks(10)
	_check(SaveSlots.latest(PROFILE).get("meta", {}).get("kind") == "milestone", "arrival saved (milestone)")
	await _shot("p07_haven_arrival")


func _haven() -> void:
	var character := session.character
	var mara := map.get_node("Mara") as StoryNpc
	var edrin := map.get_node("Edrin") as StoryNpc
	_check(mara.visible and edrin.visible, "Mara and Edrin in Haven")
	await _talk_to(mara)
	_check(StoryService.at_step(character, &"shelter_among_the_trees", 2), "Mara: Welcome to Haven")
	# ruins that cannot be restored yet
	var hall := map.get_node("Ruins/CommonHall") as RuinSite
	await _walk_to(hall.global_position + Vector2(0, 30))
	await _press(&"interact")
	_check(map.hud.restoration_panel.visible and _label_texts(map.hud.restoration_panel).has("Restoration unavailable for now."),
		"Common Hall: Restoration unavailable for now.")
	await _shot("p08_ruin_unavailable")
	await _press(&"interact")
	# A Fire Rekindled
	var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
	await _walk_to(Vector2(-200, -100))
	await _walk_to(smithy.global_position + Vector2(0, 30))
	await _press(&"interact")
	await _shot("p09_smithy_ruin")
	_click_button(map.hud.restoration_panel, "Restore")
	await _ticks(2)
	_check(map.hud.dialogue_panel.current_text() == "This place isn't dead. Just buried under years of neglect.", "Mara: This place isn't dead ...")
	for i in 3:
		await _press(&"interact")
	_check(RestorationService.is_restored(character, &"old_smithy") and character.inventory.count(&"supply_crate") == 0, "Old Smithy restored with the cart supplies")
	_check(StoryService.at_step(character, &"shelter_among_the_trees", 3), "on to Edrin")
	await _shot("p10_smithy_restored")
	await _press(&"interact")
	_check(map.hud.crafting_panel.visible, "the restored smithy opens the forge")
	await _press(&"interact")
	# optional: the Old Storehouse
	var store := map.get_node("Ruins/OldStorehouse") as RuinSite
	await _walk_to(Vector2(-200, 100))
	await _walk_to(store.global_position + Vector2(0, 30))
	await _press(&"interact")
	var capacity := character.inventory.capacity
	if _click_button(map.hud.restoration_panel, "Restore"):
		_check(character.inventory.capacity == capacity + 10, "Old Storehouse: +10 inventory slots")
	map.hud.close_windows()
	await _walk_to(Vector2(0, 0))
	await _talk_to(mara)
	_check(map.hud.dialogue_panel.visible == false, "Mara: Haven wasn't always this quiet ...")
	await _walk_to(Vector2(0, -150))
	await _talk_to(edrin)
	_check(StoryService.at_step(character, &"the_whispering_stone", 0), "Edrin: the Whispering Stone")
	await _shot("p11_north_gate_open")
	await _walk_into(map.get_node("ToShrine") as Node2D)
	await _await_map(&"whispering_stone")
	_check(StoryService.at_step(character, &"the_whispering_stone", 1), "reached the Whispering Stone")


func _label_texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text.strip_edges())
	return texts


# --- helpers ----------------------------------------------------------------

func _fight(encounter: Encounter, optional: bool = false, limit: int = 3600) -> void:
	for i in limit:
		if encounter.done or (not encounter.running and encounter.is_cleared()):
			break
		var target := _nearest_alive(encounter)
		if target == null:
			if not encounter.running:
				var to_start := encounter.global_position - map.player.global_position
				f.move = to_start.normalized() if to_start.length() > 20.0 else Vector2.ZERO
			await physics_frame
			continue
		var to := target.global_position - map.player.global_position
		f.aim_direction = to.normalized()
		f.move = to.normalized() if to.length() > 22.0 else Vector2.ZERO
		f.light_pressed = map.player.combat.state == CombatComponent.State.IDLE and to.length() < 32.0
		await physics_frame
		f.light_pressed = false
	f.move = Vector2.ZERO
	_check(encounter.done or optional, "encounter %s won (HP %.0f/%.0f, deaths so far %d)" % [encounter.encounter_id, map.player.health.health, map.player.health.max_health, _deaths])
	await _ticks(20)


func _nearest_alive(encounter: Encounter) -> Enemy:
	var best: Enemy = null
	for enemy in encounter.enemies:
		if is_instance_valid(enemy) and enemy.state != Enemy.State.DEAD:
			if best == null or enemy.global_position.distance_to(map.player.global_position) < best.global_position.distance_to(map.player.global_position):
				best = enemy
	return best


func _talk_to(npc: StoryNpc) -> void:
	await _walk_to(npc.global_position + Vector2(0, 14))
	await _press(&"interact")
	for i in 12:
		if not map.hud.dialogue_panel.visible:
			break
		_log("  %s" % map.hud.dialogue_panel.current_text())
		if i == 0:
			await _shot("dialogue_%s" % npc.npc_id)
		await _press(&"interact")


func _await_map(map_id: StringName, limit: int = 400) -> void:
	for i in limit:
		await process_frame
		var current := current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			f = InputFrame.new()
			map.player.feed_input(f)
			map.player.health.died.connect(func() -> void:
				_deaths += 1
				_log("  player fell at %s" % map.player.global_position))
			map.player.health.health_changed.connect(func(current: float, maximum: float) -> void:
				if current <= 0.0:
					_log("  HP zero (max %.0f) dead=%s" % [maximum, map.player.health.is_dead()])
					print_stack())
			await _ticks(15)
			_log("arrived in %s" % map_id)
			return
	_check(false, "reached map %s" % map_id)


func _walk_to(target: Vector2, limit: int = 600) -> void:
	for i in limit:
		var to := target - map.player.global_position
		if to.length() < 6.0:
			break
		f.move = to.normalized()
		f.aim_direction = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO
	await _ticks(3)


func _walk_into(node: Node2D, limit: int = 600) -> void:
	for i in limit:
		if session.is_traveling():
			break
		var to := node.global_position - map.player.global_position
		f.move = to.normalized()
		f.aim_direction = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO


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
	print(text)
	log_lines.append(text)


func _arg(key: String, default: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return default


func _clean_profile() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
