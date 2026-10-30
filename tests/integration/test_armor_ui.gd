extends TestCase
## Skills & Talents UX 2.0 Phase 7 (docs/SKILLS_TALENTS_UX_2_0.md): the Armor page - burden of what is worn now on
## top, the four mastery tracks as a 2x2 grid (level, XP, worn share, active bonuses, next milestone) and the chosen
## track's details; read-only over ArmorMasteryService. Plus the small Classes correction: the start class only while
## it is the active class.

const S := EquipSlot.Slot

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = CharacterFactory.create_new(session.database)
	for class_id: StringName in [&"warrior", &"arcanist"]:
		character.classes.unlock(class_id)
	character.classes.set_active(&"warrior")
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 120:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	panel = map.hud.class_panel


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous_character)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


## Wears exactly `item_ids` in the armour slots (everything else there taken off).
func _wear(item_ids: Array) -> void:
	for slot: int in ArmorMasteryRules.SLOTS:
		if character.equipment.get_item(slot) != null:
			character.equipment.unequip(slot)
	for item_id: StringName in item_ids:
		var piece: ItemInstance = null
		for item in character.inventory.items():
			if item.definition_id == item_id:
				piece = item
		if piece == null:
			piece = character.inventory.add_item(item_id, 1, ItemInstance.ORIGIN_STARTING)[0]
		check_eq(character.equipment.equip(piece.instance_id), "", "wear %s" % item_id)
	character.invalidate_stats()


func _open() -> void:
	map.hud.toggle_talents()
	await _frames(3)
	panel.show_page("Armor")
	await _frames(4)


func _card(key: String) -> Control:
	return panel.find_child("Track_%s" % key, true, false) as Control


func _text(node: Node) -> String:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


func _num(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


func test_no_armor_and_four_tracks() -> void:
	_wear([])
	await _open()
	check_eq((panel.find_child("Tier", true, false) as Label).text, "0  ·  Light", "no armour: 0, Light")
	check_eq((panel.find_child("BurdenEffects", true, false) as Label).text, "No penalty.", "no penalty")
	for key: String in ["cloth", "leather", "mail", "plate"]:
		var card := _card(key)
		check(card != null and (card.find_child("Worn", true, false) as Label).text == "not worn", "%s card, not worn" % key)
		check(_text(card).contains("Lv 1 / 20"), "%s level 1" % key)
	var grid := panel.find_child("Tracks", true, false) as GridContainer
	check_eq([grid.columns, grid.get_child_count()], [2, 4], "a 2x2 grid of the four types")
	# Menu UX Polish 1.1: the tier table is the burden help ("?"), opened by keyboard focus too
	var help := panel.find_child("BurdenHelp", true, false) as HelpButton
	var ranges := help.help_text if help != null else ""
	var rules := ArmorMasteryService.rules(character)
	check(ranges.contains("Balanced %d-%d" % [rules.tier_starts[0], rules.tier_starts[1] - 1]) and ranges.contains("Heavy %d+" % rules.tier_starts[2]), "tier ranges from the rules: %s" % ranges)
	check(ranges.contains("Light 0-%d  (now)" % (rules.tier_starts[0] - 1)) and ranges.contains("Dash and parry are never affected."), "current tier and the rule in the help")
	help.grab_focus()
	await _frames(2)
	check(help.is_open(), "the help opens on keyboard focus")
	help.release_focus()
	await _frames(1)
	check(not help.is_open(), "and closes when the focus leaves")
	for key: String in ["cloth", "leather", "mail", "plate"]:
		check(_card(key).find_child("Bonus", true, false) == null and _card(key).find_child("Next", true, false) == null, "%s card: no bonus / next lines (details only)" % key)


func test_mixed_armor_burden_worn_shares_levels_and_bonuses() -> void:
	_wear([&"leather_cap", &"leather_gloves", &"linen_trousers", &"worn_boots"])
	var rules := ArmorMasteryService.rules(character)
	character.armor_mastery.add_xp(ItemDefinition.ArmorType.LEATHER, 1400.0, rules)
	character.armor_mastery.add_xp(ItemDefinition.ArmorType.CLOTH, 260.0, rules)
	character.invalidate_stats()
	await _open()
	var points := ArmorMasteryService.burden(character)
	check_eq((panel.find_child("Tier", true, false) as Label).text, "%d  ·  %s" % [points, ArmorMasteryService.TIER_NAMES[ArmorMasteryService.tier(points, rules)]], "burden from the character")
	var covered := ArmorMasteryService.coverage(character)
	check_eq((_card("leather").find_child("Worn", true, false) as Label).text, "WORN %d%%" % roundi(float(covered[ItemDefinition.ArmorType.LEATHER]) * 100.0), "leather worn share")
	check_eq((_card("cloth").find_child("Worn", true, false) as Label).text, "WORN %d%%" % roundi(float(covered[ItemDefinition.ArmorType.CLOTH]) * 100.0), "cloth worn share")
	var level := character.armor_mastery.level(ItemDefinition.ArmorType.LEATHER)
	check(level > 5, "leather above its first milestone (%d)" % level)
	check_eq((_card("leather").find_child("Level", true, false) as Label).text, "Lv %d / %d" % [level, rules.max_level], "level on the card")
	var bar := _card("leather").find_child("XpBar", true, false) as ProgressBar
	check_eq([bar.value, bar.max_value], [character.armor_mastery.xp(ItemDefinition.ArmorType.LEATHER), float(rules.xp_to_next(level))], "XP bar")
	for entry: Dictionary in ArmorMasteryService.milestone_bonuses(character):
		if int(entry.type) == ItemDefinition.ArmorType.LEATHER and float(entry.value) > 0.0:
			check((panel.find_child("Bonus", true, false) as Label).text.contains("+%s%%" % _num(float(entry.value))), "active bonus %s in the details" % entry.stat)
	check((panel.find_child("Next", true, false) as Label).text.begins_with("Next: Lv 10"), "next milestone in the details")
	# choosing a track changes nothing
	var before := [character.armor_mastery.to_dict(), character.equipment.to_dict(), character.inventory.to_array()]
	(_card("mail") as Button).pressed.emit()
	await _frames(3)
	check_eq((panel.find_child("ArmorTitle", true, false) as Label).text, "Mail Mastery", "mail chosen")
	check((_card("mail") as Button).button_pressed and (_card("mail").find_child("Worn", true, false) as Label).text == "not worn", "chosen (gold) is not worn")
	check(_text(panel.find_child("ArmorDetail", true, false)).contains("Not worn now - its bonuses are inactive."), "the details say it is not worn")
	check_eq([character.armor_mastery.to_dict(), character.equipment.to_dict(), character.inventory.to_array()], before, "choosing changed no gear and no mastery")


func test_mail_balanced_mastered_detail() -> void:
	_wear([&"warden_helm", &"warden_mail", &"warden_greaves", &"leather_gloves", &"worn_boots"])
	var rules := ArmorMasteryService.rules(character)
	character.armor_mastery.add_xp(ItemDefinition.ArmorType.MAIL, 200000.0, rules)
	character.invalidate_stats()
	await _open()
	panel.select_armor_type(ItemDefinition.ArmorType.MAIL)
	await _frames(3)
	var tier := ArmorMasteryService.tier(ArmorMasteryService.burden(character), rules)
	check(tier >= 1, "a burden tier above Light (%s)" % ArmorMasteryService.TIER_NAMES[tier])
	check_eq((panel.find_child("BurdenEffects", true, false) as Label).text, "-%s%% movement  ·  +%s%% attack recovery time" % [_num(ArmorMasteryService.move_penalty(character)), _num(ArmorMasteryService.recovery_penalty(character))], "penalties from the service")
	check_eq(character.armor_mastery.level(ItemDefinition.ArmorType.MAIL), rules.max_level, "mail mastered")
	check((panel.find_child("ArmorProgress", true, false) as Label).text.ends_with("Mastered"), "Mastered in the details")
	check((panel.find_child("Next", true, false) as Label).text.begins_with("Mastered"), "Mastered in the details")
	var poise := 0.0
	for entry: Dictionary in ArmorMasteryService.milestone_bonuses(character):
		if int(entry.type) == ItemDefinition.ArmorType.MAIL and entry.stat == Stats.POISE:
			poise += float(entry.value)
	var bonus := (panel.find_child("Bonus", true, false) as Label).text
	check(bonus.count("Poise") == 1, "each stat once in the summary: %s" % bonus)
	if poise > 0.0:
		check(bonus.contains("+%s%%" % _num(poise)), "summed poise (+%s%%): %s" % [_num(poise), bonus])
	for at in [5, 10, 15, 20]:
		check((panel.find_child("Milestone%d" % at, true, false) as Label).text.contains("now +"), "milestone %d active now" % at)


func test_class_switch_save_load_and_geometry() -> void:
	_wear([&"leather_cap", &"worn_boots"])
	character.armor_mastery.add_xp(ItemDefinition.ArmorType.LEATHER, 300.0, ArmorMasteryService.rules(character))
	await _open()
	var mastery := character.armor_mastery.to_dict()
	check_eq(character.switch_class(&"arcanist", true), "", "class switch")
	panel.show_page("Armor")
	await _frames(3)
	check_eq(character.armor_mastery.to_dict(), mastery, "mastery is character-wide - unchanged by the switch")
	check_eq((panel.find_child("Tier", true, false) as Label).text.get_slice(" ", 0), str(ArmorMasteryService.burden(character)), "burden of the new class's gear")
	var path := "user://test_saves/armor_ui/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), 15, "save v15")
	file.close()
	var loaded := SaveSystem.load_from(path, session.database)
	check(loaded.ok() and loaded.character.armor_mastery.to_dict() == mastery, "mastery after load")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	for scale: float in [1.0, 1.5]:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		panel.show_page("Classes")
		await _frames(3)
		var frame := panel.get_global_rect()
		panel.show_page("Armor")
		await _frames(4)
		check(panel.get_global_rect().is_equal_approx(frame), "%d %%: same frame" % roundi(scale * 100))
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%d %%: the window never scrolls" % roundi(scale * 100))
		var grid := (panel.find_child("Tracks", true, false) as Control).get_global_rect()
		var detail := (panel.find_child("ArmorDetail", true, false) as Control).get_global_rect()
		var burden := (panel.find_child("Burden", true, false) as Control).get_global_rect()
		check(frame.encloses(grid) and frame.encloses(detail) and frame.encloses(burden), "%d %%: everything inside" % roundi(scale * 100))
		check(burden.end.y <= grid.position.y and not grid.intersects(detail), "%d %%: burden on top, cards and details side by side" % roundi(scale * 100))
	_card("plate").grab_focus()
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter)
	await _frames(3)
	check_eq(panel.selected_armor_type(), ItemDefinition.ArmorType.PLATE, "Enter selects")
	check(_card("plate").has_focus(), "focus stays on the card")


## Classes correction: the three regular classes; the start class only while it is still active (before the
## prologue choice) - data, playable flag and unlocks untouched.
func test_classes_list_and_start_class_special_case() -> void:
	await _open()
	panel.show_page("Classes")
	await _frames(3)
	var names := panel.find_child("ClassCards", true, false).get_children().map(func(n: Node) -> String: return String(n.name).trim_prefix("Class_"))
	check_eq(names, ["warrior", "arcanist", "shadowrunner"], "the three regular classes")
	var start := session.database.get_class_def(&"basic_adventurer")
	check(start.playable and character.classes.is_unlocked(&"basic_adventurer"), "start class still playable and unlocked in the data")
	var fresh := CharacterFactory.create_new(session.database)
	panel.open(fresh, null, "Classes")
	await _frames(3)
	names = panel.find_child("ClassCards", true, false).get_children().map(func(n: Node) -> String: return String(n.name).trim_prefix("Class_"))
	check_eq(names[0], "basic_adventurer", "before the choice: the active start class first")
	check_eq(names.size(), 4, "plus the three regular classes")
	check_eq((panel.find_child("Class_basic_adventurer", true, false).find_child("Status", true, false) as Label).text, "ACTIVE", "shown as the active class")
	check_eq(fresh.classes.active_class_id, &"basic_adventurer", "nothing about the prologue state changed")
	panel.hide()
