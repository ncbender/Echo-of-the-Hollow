extends TestCase
## Skills & Talents UX 2.0 Phase 4 (docs/SKILLS_TALENTS_UX_2_0.md): the Presets page - five compact slots
## (number, name, Saved / Empty, Save / Overwrite) with name / Rename / Delete of the chosen one on the left,
## the chosen preset's build on the right (talent points per tree, Q/E/R/F with mods, equipment references and
## their state) with the Activate footer. Every action goes through the unchanged PresetService; nothing is
## duplicated, created or lost.

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character
var station: ClassStation


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.classes.set_active(&"warrior")
	var definition := session.database.get_class_def(&"warrior")
	var xp := 0
	for level in range(1, 20):
		xp += definition.xp_to_next(level)
	character.classes.add_xp(&"warrior", xp)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	panel = map.hud.class_panel
	station = map.get_node("ClassStation") as ClassStation


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous_character)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _open_at_station() -> void:
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	map.hud.open_class_panel(station)
	panel.show_page("Presets")
	await _frames(4)


func _row(index: int) -> Control:
	return panel.find_child("Preset%d" % index, true, false) as Control


func _detail() -> Control:
	return panel.find_child("PresetDetail", true, false) as Control


func _detail_text() -> String:
	var texts: PackedStringArray = []
	for label: Label in _detail().find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func _press(root: Node, button_name: String) -> void:
	(root.find_child(button_name, true, false) as Button).pressed.emit()
	await _frames(2)


## Every item the character owns (bag + stash), by instance id - for "nothing duplicated, nothing lost".
func _items() -> Array:
	var ids: Array = []
	for item in character.inventory.items():
		ids.append(item.instance_id)
	for item in character.stash.items():
		ids.append(item.instance_id)
	ids.sort()
	return ids


func _learn(node_id: StringName, times: int = 1) -> void:
	for i in times:
		check_eq(TalentService.learn(character, &"warrior", node_id), "", "learn %s" % node_id)


func test_five_empty_slots_compact_and_save_one() -> void:
	await _open_at_station()
	for index in 5:
		var row := _row(index)
		check(row != null and (row.find_child("PresetName", true, false) as Label).text == "Empty", "slot %d empty" % (index + 1))
		check_eq((row.find_child("Save", true, false) as Button).text, "Save", "slot %d: Save" % (index + 1))
		check(row.size.y <= ClassStationPanel.PRESET_ENTRY_HEIGHT + 1.0, "slot %d compact" % (index + 1))
	check(_detail_text().contains("Preset 1 is empty") and _detail().find_child("Activate", true, false) == null, "compact empty state, no Activate")
	check((panel.find_child("Rename", true, false) as Button).disabled and (panel.find_child("Delete", true, false) as Button).disabled, "Rename / Delete only for a saved preset")
	var items := _items()
	(panel.find_child("PresetNameEdit", true, false) as LineEdit).text = "Opener"
	await _press(_row(0), "Save")
	var preset := PresetService.get_preset(character, &"warrior", 0)
	check_eq(preset.get("name"), "Opener", "saved with the field's name")
	check_eq((_row(0).find_child("PresetState", true, false) as Label).text, "Saved  ·  0 pts", "entry: Saved")
	check_eq((_row(0).find_child("Save", true, false) as Button).text, "Overwrite", "entry: Overwrite")
	check(_row(0).find_child("PresetEntry", true, false).button_pressed, "the saved slot is chosen (gold)")
	check_eq(_items(), items, "saving creates or moves no item")


## Several presets, a long name, talents per tree, skills with mods, equipment references; switching between
## presets shows each without changing anything.
func test_saved_presets_details_and_switching() -> void:
	_learn(&"war_b_seething", 5)
	_learn(&"war_b_whirlwind")
	check_eq(SkillBook.set_mod(character, &"warrior", &"furious_strike", SkillModDefinition.Slot.FORM, &"furious_wide_arc", true), "", "a mod")
	PresetService.save_preset(character, &"warrior", 0, "Spin")
	_learn(&"war_wb_hands", 2)
	var long_name := "Warbreaker Juggernaut - Heavy Hands and Thick Skin for very long boss fights in the Chapel"
	PresetService.save_preset(character, &"warrior", 3, long_name)
	await _open_at_station()
	check_eq(panel.selected_preset(), 0, "first saved preset chosen")
	check(_detail_text().contains("Berserker  6") and _detail_text().contains("Warbreaker  0"), "points per tree: %s" % _detail_text())
	check(_detail_text().contains("Furious Strike") and _detail_text().contains("Form: Wide Arc"), "skills and their mods")
	var slot_rows := _detail().find_children("PresetSlot*", "HBoxContainer", true, false)
	check_eq(slot_rows.size(), 4, "Q/E/R/F rows")
	check(slot_rows[0].find_child("SkillIcon", true, false) != null, "skill art reused")
	var equipment: Dictionary = PresetService.get_preset(character, &"warrior", 0).equipment
	check(not equipment.is_empty() and _detail().find_children("PresetItem_*", "Label", true, false).size() == equipment.size(), "one line per equipment reference")
	var before := [character.builds.get_build().to_dict(), _items(), character.equipment.to_dict()]
	_row(3).find_child("PresetEntry", true, false).pressed.emit()
	await _frames(3)
	check_eq(panel.selected_preset(), 3, "switched to preset 4")
	var title := _detail().find_child("PresetTitle", true, false) as Label
	check_eq(title.text, long_name, "whole long name in the details")
	check(title.get_global_rect().size.x <= _detail().get_global_rect().size.x, "long name wraps inside")
	check((_row(3).find_child("PresetName", true, false) as Label).text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "long name trimmed in the list")
	check(not panel._scroll.get_h_scroll_bar().visible and not panel._scroll.get_v_scroll_bar().visible, "the window never scrolls")
	check(_detail_text().contains("Warbreaker  2"), "its talents")
	check_eq([character.builds.get_build().to_dict(), _items(), character.equipment.to_dict()], before, "choosing changes nothing")


## Activation: the station, the respec cost (gold), missing items and a full bag - PresetService's checks,
## shown before the click; activating moves no item and duplicates none.
func test_activation_cost_missing_items_full_bag_and_station() -> void:
	_learn(&"war_b_seething", 3)
	PresetService.save_preset(character, &"warrior", 0, "Seething")
	check_eq(TalentService.respec(character, &"warrior", true), "", "first (free) reset")
	_learn(&"war_wb_hands", 3)
	PresetService.save_preset(character, &"warrior", 1, "Hands")
	# away from the station: everything readable, Activate locked with the reason
	map.hud.toggle_talents()
	await _frames(3)
	panel.show_page("Presets")
	await _frames(3)
	var activate := _detail().find_child("Activate", true, false) as Button
	check(activate.disabled and activate.tooltip_text != "", "away: Activate locked with a reason")
	check(not (_row(2).find_child("Save", true, false) as Button).disabled, "away: saving stays free (unchanged)")
	map.hud.close_windows()
	await _open_at_station()
	_row(0).find_child("PresetEntry", true, false).pressed.emit()
	await _frames(3)
	var cost := TalentService.respec_cost(character, &"warrior")
	check(cost > 0, "second reset costs gold")
	check(_detail_text().contains("counts as a talent reset") and _detail().find_child("Activate", true, false).text.contains("%d gold" % cost), "the effect said before, the cost at the action: %s" % _detail_text())
	activate = _detail().find_child("Activate", true, false) as Button
	check(activate.disabled and _detail_text().contains("Not enough gold"), "no gold: refused with the reason")
	check(activate.text.contains("%d gold" % cost), "cost on the button")
	character.inventory.add_item(&"gold_coin", cost + 5)
	panel.show_page("Presets")
	await _frames(3)
	var items := _items()
	var gold := character.inventory.count(&"gold_coin")
	await _press(_detail(), "Activate")
	check_eq(character.builds.get_build().rank(&"war_b_seething"), 3, "preset talents active")
	check_eq(character.inventory.count(&"gold_coin"), gold - cost, "exactly the reset cost paid")
	check_eq(_items(), items, "no item created, moved out or duplicated")
	check(StashService.ownership_errors(character).is_empty(), "ownership consistent")
	# a vanished item reference: shown, Activate refused, nothing recreated
	var kit := PresetService.get_preset(character, &"warrior", 1)
	var refs: Dictionary = kit.equipment
	var key: String = refs.keys()[0]
	refs[key] = "itm_vanished"
	_row(1).find_child("PresetEntry", true, false).pressed.emit()
	await _frames(3)
	check((_detail().find_child("PresetItem_%s" % key, true, false) as Label).text.contains("Missing"), "missing item named")
	check((_detail().find_child("Activate", true, false) as Button).disabled, "missing item: Activate refused")
	check_eq(_items(), items, "a missing reference creates nothing")
	# full bag: the unchanged loadout check refuses, no item moves
	PresetService.save_preset(character, &"warrior", 2, "Bare")
	(PresetService.get_preset(character, &"warrior", 2).equipment as Dictionary).clear()   # an empty loadout needs room for all gear
	while character.inventory.free_slots() > 0:
		character.inventory.add_item(&"leather_cap", 1, ItemInstance.ORIGIN_STARTING)
	items = _items()
	var worn := character.equipment.to_dict()
	_row(2).find_child("PresetEntry", true, false).pressed.emit()
	await _frames(3)
	check(_detail_text().contains("No equipment stored"), "empty loadout said")
	# Preset Activation Atomicity Fix 1.0: the bag in the target state is checked before the click
	check(_detail_text().contains(CharacterEquipment.BAG_FULL) and (_detail().find_child("Activate", true, false) as Button).disabled, "full bag: reason shown, Activate locked")
	var build_before := character.builds.get_build().to_dict()
	var gold_before := character.inventory.count(&"gold_coin")
	await _press(_detail(), "Activate")
	check(not (panel.find_child("Status", true, false) as Label).text.begins_with("Preset activated"), "full bag: refused (%s)" % (panel.find_child("Status", true, false) as Label).text)
	check_eq(character.equipment.to_dict(), worn, "full bag: gear stays worn")
	check_eq(_items(), items, "full bag: nothing lost, nothing duplicated")
	check_eq(character.builds.get_build().to_dict(), build_before, "full bag: talents, skills, mods unchanged")
	check_eq(character.inventory.count(&"gold_coin"), gold_before, "full bag: no gold taken")


func test_rename_delete_class_switch_and_save_load() -> void:
	PresetService.save_preset(character, &"warrior", 0, "First")
	PresetService.save_preset(character, &"warrior", 2, "Third")
	await _open_at_station()
	(panel.find_child("PresetNameEdit", true, false) as LineEdit).text = "Renamed"
	await _press(panel, "Rename")
	check_eq(PresetService.get_preset(character, &"warrior", 0).get("name"), "Renamed", "renamed")
	check_eq(PresetService.get_preset(character, &"warrior", 2).get("name"), "Third", "others untouched")
	# Delete asks first (UiConfirmDialog, unchanged): cancel keeps, confirm empties only this slot
	var items := _items()
	_row(2).find_child("PresetEntry", true, false).pressed.emit()
	await _frames(2)
	await _press(panel, "Delete")
	check(map.hud.confirm_dialog.visible, "delete asks first")
	map.hud.confirm_dialog.cancel()
	await _frames(2)
	check_eq(PresetService.get_preset(character, &"warrior", 2).get("name"), "Third", "cancel keeps the preset")
	await _press(panel, "Delete")
	map.hud.confirm_dialog.confirm()
	await _frames(2)
	check(PresetService.get_preset(character, &"warrior", 2).is_empty(), "confirmed: preset 3 deleted")
	check_eq((_row(2).find_child("PresetName", true, false) as Label).text, "Empty", "entry shows Empty")
	check_eq(PresetService.get_preset(character, &"warrior", 0).get("name"), "Renamed", "preset 1 untouched")
	check_eq(_items(), items, "deleting a preset touches no item")
	var path := "user://test_saves/preset_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), 15, "save v15")
	file.close()
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.ok(), "loaded")
	check_eq(loaded.character.builds.get_build(&"warrior").presets, character.builds.get_build(&"warrior").presets, "presets identical after load")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	character.classes.unlock(&"arcanist")
	check_eq(character.switch_class(&"arcanist", true), "", "class switch")
	panel.show_page("Presets")
	await _frames(3)
	check_eq((_row(0).find_child("PresetName", true, false) as Label).text, "Empty", "arcanist: own (empty) presets")
	check_eq(character.switch_class(&"warrior", true), "", "back")
	panel.show_page("Presets")
	await _frames(3)
	check_eq((_row(0).find_child("PresetName", true, false) as Label).text, "Renamed", "warrior presets kept")


## Window lock: same frame as the other pages, the window never scrolls (100 / 150 %), the list stays compact,
## the details fit beside it.
func test_geometry() -> void:
	for index in 5:
		PresetService.save_preset(character, &"warrior", index, "Preset with a rather long name number %d" % (index + 1))
	await _open_at_station()
	for scale: float in [1.0, 1.5]:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		panel.show_page("Skills")
		await _frames(3)
		var frame := panel.get_global_rect()
		panel.show_page("Presets")
		await _frames(4)
		check(panel.get_global_rect().is_equal_approx(frame), "%d %%: same frame" % roundi(scale * 100))
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%d %%: the window never scrolls" % roundi(scale * 100))
		var list := (panel.find_child("PresetList", true, false) as Control).get_global_rect()
		var detail := _detail().get_global_rect()
		check(panel.get_global_rect().encloses(list) and panel.get_global_rect().encloses(detail) and not list.intersects(detail), "%d %%: list and details side by side inside" % roundi(scale * 100))
		check(_detail().find_child("PresetDetailScroll", true, false) is ScrollContainer, "details scroll inside")
		var activate := _detail().find_child("Activate", true, false) as Control
		check(detail.encloses(activate.get_global_rect()), "%d %%: Activate visible in the details" % roundi(scale * 100))
