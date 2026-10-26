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
	await _save_load_cycle(1, "after the road (Haven arrival)")
	if until != "road":
		await _haven()
		await _save_load_cycle(2, "at the Whispering Stone")
	if until != "road" and until != "haven":
		await _stone()
		await _save_load_cycle(3, "after the class choice")
		await _return()
		await _autosave_probe()
		await _continue_from_title()
	_log("play time (character clock): %.0f s, wall clock: %.0f s" % [session.character.play_time if session.character else 0.0,
		(Time.get_ticks_msec() - _started_ms) / 1000.0])
	_log("RESULT: %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("prologue_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	if failures > 0:   # keep failed runs: a later green run must not overwrite the evidence (flake hunt)
		var kept := FileAccess.open(OUTPUT.path_join("prologue_playtest_failed_%d.txt" % Time.get_unix_time_from_system()), FileAccess.WRITE)
		kept.store_string("\n".join(log_lines))
		kept.close()
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
	await _ticks(14)   # the new dialogue ignores presses for 0.18 s
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
	_check(map.hud.stash_panel.visible, "the ruined Old Storehouse already opens the Haven stash")
	await _shot("p10b_stash_ruined")
	var capacity := character.inventory.capacity
	_click_button(map.hud.stash_panel, "Restore the Storehouse")
	await _ticks(2)
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


func _stone() -> void:
	var character := session.character
	await _shot("p12_shrine_path")
	await _walk_to(Vector2(0, 160))
	await _fight(map.get_node("Encounters/ShrinePath") as Encounter)
	# optional side area: the Memory Fragment
	await _walk_to(Vector2(0, 0))
	await _walk_to(Vector2(300, 0))
	await _fight(map.get_node("Encounters/SideWolves") as Encounter, true)
	await _walk_to(Vector2(470, 0))
	await _press(&"interact")
	_check(map.hud.dialogue_panel.current_text() == "Three stood here when the stone was whole.", "Memory Fragment read")
	await _shot("p13_memory_fragment")
	await _press(&"interact")
	await _walk_to(Vector2(200, 0))
	await _walk_to(Vector2(0, -60))
	# the three echoes, in free order
	for entry: Array in [["TrialShadowrunner", [1, 2, 1, 3]], ["TrialWarrior", [0, 1, 0, 3]], ["TrialArcanist", [0, 0, 0, 1, 0, 0, 1]]]:
		var station := map.get_node(entry[0]) as TrialStation
		for attempt in 3:
			if character.prologue.has_completed_trial(station.trial_id):
				break
			await _walk_to(station.global_position + Vector2(0, 8))
			await _press(&"interact")
			_check(character.classes.in_trial(), "%s started (attempt %d)" % [station.trial().display_name, attempt + 1])
			if attempt == 0:
				await _ticks(20)
				await _shot("p14_%s" % String(station.trial_id))
			await _echo_fight(entry[1], 60.0)
			map.player.health.heal(map.player.health.max_health)
		_check(character.prologue.has_completed_trial(station.trial_id), "%s walked in real combat" % station.trial().display_name)
		_check(character.classes.active_class_id == &"basic_adventurer", "back to Basic Adventurer after %s" % station.trial_id)
	_check(StoryService.at_step(character, &"the_whispering_stone", 2), "three echoes walked")
	# the choice
	var stone := map.get_node("TheStone") as ClassChoiceStation
	await _walk_to(stone.global_position + Vector2(0, 26))
	await _press(&"interact")
	var panel := map.hud.class_choice_panel
	_check(panel.visible and _label_texts(panel).has(ClassChoicePanel.INTRO), "the stone: three paths linger ...")
	await _shot("p15_choice")
	_click_button(panel, "Choose Shadowrunner")
	await _ticks(3)
	_click_button(panel, "Confirm Shadowrunner")
	for i in 30:
		if panel.save_state != "saving":
			break
		await _ticks(1)
	_check(panel.save_state == "saved" and panel.status_text().contains("taken root"), "success shown after the save: %s" % panel.status_text())
	await _shot("p16_chosen")
	_check(character.classes.active_class_id == &"shadowrunner" and not character.classes.is_unlocked(&"warrior")
		and not character.classes.is_unlocked(&"arcanist"), "Shadowrunner chosen, the others locked")
	map.hud.close_windows()
	# the damaged waystone
	var waystone := map.get_node("Waystone") as Waystone
	await _walk_to(waystone.global_position + Vector2(0, 22))
	await _press(&"interact")
	_check(map.hud.dialogue_panel.current_text() == WaystoneService.ACTIVATION_LINE, "May the road remember those who return.")
	await _shot("p17_waystone")
	await _press(&"interact")
	_check(StoryService.at_step(character, &"the_first_binding", 0), "waystone awakened: return to Haven")


func _return() -> void:
	var character := session.character
	var waystone := map.get_node("Waystone") as Waystone
	await _walk_to(waystone.global_position + Vector2(0, 22))
	await _press(&"interact")
	_check(map.hud.waystone_panel.visible, "waystone travel window")
	await _shot("p18_fast_travel")
	var row := map.hud.waystone_panel.find_child("Waystone_haven", true, false)
	if row != null:
		_click_button(row, "Travel")
	await _await_map(&"home_base")
	_check(StoryService.at_step(character, &"the_first_binding", 1), "back in Haven by fast travel")
	await _talk_to(map.get_node("Mara") as StoryNpc)
	_check(StoryService.at_step(character, &"the_first_binding", 2), "Mara: You left here carrying a sword ...")
	await _talk_to(map.get_node("Edrin") as StoryNpc)
	_check(character.world.has_flag(&"prologue.completed"), "prologue complete")
	_check(StoryService.at_step(character, &"the_first_signs", 0), "main quest The Roots Remember: The First Signs")
	await _ticks(20)
	await _shot("p19_prologue_complete")


## Esc -> Save Game -> slot, then Esc -> Load Game -> the same slot: the story
## continues exactly where it was (real pause menu, real buttons).
func _save_load_cycle(slot: int, label: String) -> void:
	var before := session.character.quests.to_dict()
	var flags := session.character.world.flags.duplicate()
	var items := session.character.inventory.to_array()
	var map_id := map.map_id
	await _press(&"ui_cancel")
	var menu := map.hud.pause_menu
	_check(menu.visible and paused, "%s: Esc pauses" % label)
	_click_button(menu, "Save Game")
	await process_frame
	var row := menu.find_child("Slot%d" % slot, true, false)
	if row != null:
		_click_button(row, "Save here")
	for i in 10:
		await process_frame
	_check(SaveSystem.read_info(SaveSlots.manual_path(PROFILE, slot)).valid, "%s: saved to slot %d" % [label, slot])
	menu.show_page("load")
	await process_frame
	row = menu.find_child("Slot%d" % slot, true, false)
	if row != null:
		_click_button(row, "Load")
	await _await_map(map_id)
	var loaded := session.character
	var loaded_flags := loaded.world.flags.duplicate()
	for key: StringName in loaded_flags.keys() + flags.keys():
		if String(key).begins_with("count.enter:"):   # arriving on the map again is counted (story event)
			loaded_flags.erase(key)
			flags.erase(key)
	var same := [_norm(loaded.quests.to_dict()) == _norm(before), _norm(loaded_flags) == _norm(flags),
		_norm(loaded.inventory.to_array()) == _norm(items)]
	_check(not false in same, "%s: loaded state identical (quests, flags, items: %s)" % [label, same])
	_check(not paused, "%s: game runs again" % label)


func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)


## The periodic 5-minute autosave: the timer is advanced to just before the
## interval (only the timer - no debug key); the write must follow.
func _autosave_probe() -> void:
	var saves := session.saves
	var latest_before: int = SaveSlots.latest(PROFILE).get("order", 0)
	saves.active_time = SaveCoordinator.AUTOSAVE_INTERVAL - 1.0
	await _ticks(120)
	var latest := SaveSlots.latest(PROFILE)
	_check(int(latest.get("order", 0)) > latest_before and latest.get("meta", {}).get("kind") == "autosave",
		"periodic autosave after 5 minutes of active play")
	_check(map.hud.save_indicator.text() == "Progress saved" or map.hud.save_indicator.text() == "", "save indicator calm")


## Quit to Title, then Continue loads the newest save.
func _continue_from_title() -> void:
	await _press(&"ui_cancel")
	_click_button(map.hud.pause_menu, "Quit to Title")
	await process_frame
	_check(map.hud.confirm_dialog.visible, "quitting asks first")
	await _shot("p19b_quit_confirm")
	_click_button(map.hud.confirm_dialog, "Quit to Title")
	await _ticks(20)
	var title := current_scene as TitleScreen
	_check(title != null and not (title.find_child("Continue", true, false) as Button).disabled, "title: Continue available")
	await _shot("p20_title_continue")
	if title != null:
		_click_button(title, "Continue")
	await _await_map(&"home_base")
	_check(session.character.world.has_flag(&"prologue.completed"), "Continue: prologue complete, main quest active")


## Scripted fighter for an echo: walks to the nearest enemy (the warrior goes for
## the Hardened Husk), light attacks and presses the skill slots of `rotation`.
func _echo_fight(rotation: Array, seconds: float) -> void:
	var character := session.character
	var ticks := 0
	var step := 0
	while character.classes.in_trial() and ticks < seconds * 60.0:
		var target := _nearest_enemy(character.classes.active_class_id == &"warrior")
		f.move = Vector2.ZERO
		f.light_pressed = false
		f.ability_slot = -1
		if target != null:
			var to := target.global_position - map.player.global_position
			f.aim_direction = to.normalized()
			var next_slot: int = rotation[step % rotation.size()]
			var wanted := 60.0 if character.classes.active_class_id == &"arcanist" and next_slot != 1 else 22.0
			if to.length() > wanted:
				f.move = to.normalized()
			if ticks % 15 == 0 and to.length() < 34.0:
				f.light_pressed = true
			if ticks % 50 == 25:
				f.ability_slot = rotation[step % rotation.size()]
				step += 1
		ticks += 1
		await physics_frame
	f.move = Vector2.ZERO
	f.light_pressed = false
	f.ability_slot = -1
	_log("  echo fight ended after %.1f s (in trial: %s, deaths %d)" % [ticks / 60.0, character.classes.in_trial(), _deaths])
	if character.classes.in_trial():
		await _press(&"interact")   # step out; the next attempt starts fresh
	await _ticks(30)


func _nearest_enemy(prefer_robust: bool = false) -> Enemy:
	var best: Enemy = null
	for node in map.find_children("*", "Enemy", true, false):
		var enemy := node as Enemy
		if enemy.state == Enemy.State.DEAD:
			continue
		if prefer_robust and enemy.config.id == &"hardened_husk":
			return enemy
		if best == null or enemy.global_position.distance_to(map.player.global_position) < best.global_position.distance_to(map.player.global_position):
			best = enemy
	return best


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
	await _ticks(14 if action == &"interact" else 2)   # dialogues ignore presses for 0.18 s after a line


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
