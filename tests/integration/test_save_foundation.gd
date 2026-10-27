extends TestCase
## Save Foundation 1.1: slot layout (5 manual, 3 rotating autosaves), queued and
## merged writes, periodic autosave on ACTIVE play time (paused/disabled),
## milestone saves that are never dropped (retry after a failure), damaged
## files, failed writes keep older saves, metadata, v4 -> v5 migration, full
## data roundtrip, save indicator, pause menu saving. Only user://test_saves/.

const DIR := "user://test_saves/save_foundation"
const PROFILE := DIR + "/slot_1.save.json"

var session: SessionState
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	_clean()
	session.set_character(CharacterFactory.create_new(session.database))


func after_each() -> void:
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	session.saves.periodic_enabled = true
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _load_arena() -> GameMap:
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			return map
	fail("arena not loaded")
	return null


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func test_slot_layout_keeps_tests_away_from_player_saves() -> void:
	var real := SessionState.DEFAULT_SAVE_PATH
	check_eq(SaveSlots.manual_path(real, 1), real, "manual slot 1 = the existing player slot (F6)")
	check_eq(SaveSlots.manual_path(real, 5), "user://saves/slot_5.save.json", "five manual slots")
	check_eq(SaveSlots.auto_path(real, 3), "user://saves/autosave_3.save.json", "three autosaves")
	check_eq(SaveSlots.all_paths(real).size(), 8, "5 manual + 3 auto")
	for path in SaveSlots.all_paths("user://test_saves/x/foo.save.json"):
		check(path.begins_with("user://test_saves/"), "test profile stays in test_saves: %s" % path)
	check(session.SCRIPTED_SAVE_PATH.begins_with("user://test_saves/"), "scripted runs default to test saves")


func test_autosaves_rotate_and_never_touch_manual_slots() -> void:
	var map := await _load_arena()
	if map == null:
		return
	session.saves.request_manual(2)
	await _frames(2)
	var manual := SaveSystem.read_info(SaveSlots.manual_path(PROFILE, 2))
	check(manual.valid and manual.meta.kind == "manual", "manual slot 2 written")
	var written: Array[String] = []
	for i in 4:
		session.saves.request_autosave("test %d" % i)
		await _frames(2)
		written.append(session.saves.last_result.path.get_file())
	check_eq(written, ["autosave_1.save.json", "autosave_2.save.json", "autosave_3.save.json", "autosave_1.save.json"] as Array[String],
		"rotation 1, 2, 3, then the oldest (1)")
	check_eq(SaveSystem.read_info(SaveSlots.manual_path(PROFILE, 2)).order, manual.order, "manual slot untouched by autosaves")
	check_eq(SaveSlots.latest(PROFILE).path, SaveSlots.auto_path(PROFILE, 1), "newest save = last autosave")


func test_requests_are_queued_and_merged() -> void:
	var map := await _load_arena()
	if map == null:
		return
	var finished: Array[int] = []
	session.saves.save_finished.connect(func(id: int, _ok: bool, _kind: SaveCoordinator.Kind, _m: String) -> void: finished.append(id))
	var ids := [session.saves.request_autosave("a"), session.saves.request_critical("quest"), session.saves.request_autosave("b"),
		session.saves.request_manual(1)]
	session.saves.flush()   # one write per call: the manual one first
	check_eq(finished, [ids[3]] as Array[int], "one write at a time (manual first)")
	session.saves.flush()
	check_eq(finished.size(), 4, "the three autosave requests were merged into one write")
	check_eq(session.saves.last_result.kind, SaveCoordinator.Kind.CRITICAL, "merged write counts as a milestone save")
	check(not session.saves.has_pending(), "queue empty")
	var autos := 0
	for slot in range(1, 4):
		autos += 1 if SaveSystem.read_info(SaveSlots.auto_path(PROFILE, slot)).valid else 0
	check_eq(autos, 1, "exactly one autosave file for the merged requests")


func test_periodic_timer_counts_active_play_only() -> void:
	var map := await _load_arena()
	if map == null:
		return
	var saves := session.saves
	saves.active_time = SaveCoordinator.AUTOSAVE_INTERVAL - 0.2
	get_tree().paused = true
	await _frames(30)
	check(saves.active_time < SaveCoordinator.AUTOSAVE_INTERVAL, "paused: the timer does not run")
	check(not SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 1)).valid, "no autosave while paused")
	get_tree().paused = false
	await _frames(30)
	check(SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 1)).valid, "autosave after 5 minutes of active play")
	check(saves.active_time < 1.0, "timer restarted after the autosave")
	saves.periodic_enabled = false
	saves.active_time = SaveCoordinator.AUTOSAVE_INTERVAL + 10.0
	await _frames(10)
	check(not SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 2)).valid, "periodic autosave off: no periodic write")
	session.request_critical_save("class choice")
	await _frames(3)
	check(SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 2)).valid, "milestone saves still happen with periodic autosave off")
	check(session.character.play_time > 0.0, "play time counted")


func test_failed_write_keeps_older_saves_and_critical_is_retried() -> void:
	var map := await _load_arena()
	if map == null:
		return
	session.saves.request_autosave("first")
	await _frames(2)
	var first := SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 1))
	SaveSystem.fail_next_write = true
	var results: Array = []
	session.saves.save_finished.connect(func(_id: int, ok: bool, _k: SaveCoordinator.Kind, _m: String) -> void: results.append(ok))
	session.request_critical_save("restoration")
	await _frames(2)
	check_eq(results, [false], "the write failed")
	check_eq(SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 1)).order, first.order, "older autosave intact")
	check(not SaveSystem.read_info(SaveSlots.auto_path(PROFILE, 2)).valid, "the failed slot holds no half-written save")
	check(session.saves._retry_left > 0.0, "the milestone is retried, not dropped")
	session.saves._retry_left = 0.01
	await _frames(4)
	check_eq(results, [false, true], "retry succeeded")


func test_damaged_files_are_detected_and_backups_used() -> void:
	var character := session.character
	var path := SaveSlots.manual_path(PROFILE, 3)
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	check_eq(SaveSystem.save_to(character, path), OK, "saved again (backup of the first)")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	var info := SaveSystem.read_info(path)
	check(info.valid and info.error == "restored from backup", "damaged main file, valid backup reported")
	check(SaveSystem.load_from(path, session.database).ok(), "loads from the backup")
	DirAccess.remove_absolute(path + SaveSystem.BACKUP_SUFFIX)
	info = SaveSystem.read_info(path)
	check(not info.valid and info.exists and info.error == "damaged", "damaged without backup: shown as damaged")
	check(not SaveSystem.load_from(path, session.database).ok(), "never loads a damaged file")
	check(SaveSlots.latest(PROFILE).is_empty() or SaveSlots.latest(PROFILE).path != path, "Continue skips damaged saves")


func test_metadata_and_full_roundtrip() -> void:
	var character := session.character
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	character.classes.add_xp(&"warrior", 3000)
	TalentService.learn(character, &"warrior", &"war_b_seething")
	PresetService.save_preset(character, &"warrior", 0, "Test")
	character.inventory.add_item(&"forged_blade")
	character.world.waystones.append(&"whispering_stone")
	character.world.restoration[&"old_smithy"] = &"restored"
	character.play_time = 3725.0
	var path := SaveSlots.manual_path(PROFILE, 4)
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var info := SaveSystem.read_info(path)
	check_eq(info.meta.get("class"), "Warrior", "class in the slot info")
	check_eq(int(info.meta.get("play_time")), 3725, "play time in the slot info")
	check(PauseMenu.describe(info).contains("1:02:05 played"), "readable slot text: %s" % PauseMenu.describe(info))
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.ok() and loaded.warnings.is_empty(), "loads cleanly: %s" % [loaded.warnings])
	check_eq(_normalized(loaded.character.to_dict()), _normalized(character.to_dict()), "every saved field identical")
	check(loaded.character.inventory.integrity_errors().is_empty(), "no duplicated item instances")


func test_migration_v4_to_v5() -> void:
	var old := {"classes": {"active": "warrior", "progress": {"basic_adventurer": {"unlocked": true, "level": 2, "xp": 0},
			"warrior": {"unlocked": true, "level": 5, "xp": 0}}},
		"prologue": {"stage": "completed", "completed_trials": [], "chosen_class": "warrior"},
		"world": {"map": "home_base", "spawn": "default", "flags": {}, "buildings": {"plot_west": "smithy", "plot_east": "storage"}, "map_states": {}},
		"inventory": [{"id": "itm_1", "def": "iron_sword", "qty": 1, "ilvl": 1, "quality": 0}]}
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate(old.duplicate(true), 4, errors)
	check(errors.is_empty(), "migrates")
	check_eq(data.world.restoration, {"old_smithy": "restored", "old_storehouse": "restored"}, "plot buildings -> restored ruins")
	check_eq(data.world.waystones, ["haven", "whispering_stone"], "Haven active; finished prologue also has the stone")
	check_eq(data.quests.the_first_signs.state, "active", "finished prologue -> main quest active")
	for entry: Dictionary in data.inventory:
		check_eq(entry.get("origin"), "unknown_legacy", "v8 marks the origin unknown")
		check_eq(entry.get("base_damage"), 12.0, "v12 stores the iron sword base damage")
		check_eq(entry.get("rarity"), 0, "v14 stamps the definition rarity (Normal)")
		entry.erase("rarity")
		entry.erase("base_damage")
		entry.erase("origin")
	check_eq(data.inventory, old.inventory, "items otherwise untouched")
	var unfinished: Dictionary = SaveMigrations.migrate({"world": {}, "prologue": {"stage": "not_started"}}, 4, errors)
	check_eq(unfinished.quests.the_whispering_stone.state, "active", "unfinished prologue continues at the shrine")
	check_eq(unfinished.quests.a_road_forgotten.state, "completed", "the road part is done for an old character")
	var warnings: PackedStringArray = []
	var character := Character.from_dict(data, session.database, warnings)
	check(character.world.restoration.has(&"old_storehouse"), "restoration restored into the world state")
	check(SaveSystem.VERSION >= 5, "save version 5 or later (v6: Haven stash)")


func test_save_indicator_states() -> void:
	var map := await _load_arena()
	if map == null:
		return
	var indicator := map.hud.save_indicator
	session.saves.request_autosave("indicator")
	await _frames(2)
	check_eq(indicator.text(), "Progress saved", "success shown only after the write")
	SaveSystem.fail_next_write = true
	session.saves.request_autosave("fail")
	await _frames(2)
	check_eq(indicator.text(), "Save failed", "failure shown")
	session.settings.set_show_save_indicator(false)
	indicator.visible = false
	session.saves.request_autosave("hidden")
	await _frames(2)
	check_eq(indicator.text(), "", "indicator hidden when disabled")
	SaveSystem.fail_next_write = true
	session.saves.request_autosave("fail hidden")
	await _frames(2)
	check_eq(indicator.text(), "Save failed", "failures are always shown")
	session.settings.set_show_save_indicator(true)


func test_pause_menu_saves_and_lists_slots() -> void:
	var map := await _load_arena()
	if map == null:
		return
	map.hud.open_pause_menu()
	await _frames(1)
	check(get_tree().paused, "pause menu pauses the game")
	var menu := map.hud.pause_menu
	menu.show_page("save")
	await _frames(1)
	var row := menu.find_children("Slot3", "HBoxContainer", true, false)[0]
	(row.find_children("Action", "Button", true, false)[0] as Button).emit_signal(&"pressed")
	await _frames(3)
	check(SaveSystem.read_info(SaveSlots.manual_path(PROFILE, 3)).valid, "saved to slot 3 while paused")
	menu.show_page("load")
	await _frames(1)
	check(not menu.find_children("Autosave1", "HBoxContainer", true, false).is_empty(), "autosaves listed for loading")
	menu.hide()
	await _frames(1)
	check(not get_tree().paused, "closing resumes")


func test_settings_persist_autosave_options() -> void:
	var settings := UserSettings.new()
	settings.path = DIR + "/settings.cfg"
	settings.set_periodic_autosave(false)
	settings.set_show_save_indicator(false)
	settings.save()
	var loaded := UserSettings.load_from(settings.path)
	check(not loaded.periodic_autosave and not loaded.show_save_indicator, "autosave options persisted")
	check(UserSettings.new().periodic_autosave and UserSettings.new().show_save_indicator, "both on by default")
	DirAccess.remove_absolute(settings.path)


## JSON numbers have no int/float distinction: compare what a save file holds.
func _normalized(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)), "", true)
