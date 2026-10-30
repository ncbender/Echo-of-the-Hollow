extends TestCase
## Skills & Talents UX 2.0 Phase 3 (docs/SKILLS_TALENTS_UX_2_0.md): the Skills page - four Q/E/R/F slots on top,
## the class's skills in a compact list (scrolls on its own), the chosen skill's details with an explicit equip
## row and its Form / Resonance modifications. Choosing never equips; slots and mods change only through
## SkillBook at a class station, with the unchanged rules (one slot per skill, move = swap, occupied = replace).

const CLASSES: Array[StringName] = [&"warrior", &"arcanist", &"shadowrunner"]

var session: SessionState
var _previous_character: Character
var map: GameMap
var panel: ClassStationPanel
var character: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	character = _make(&"warrior", 20)
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


func _make(class_id: StringName, level: int) -> Character:
	var result := CharacterFactory.create_new(session.database)
	result.classes.unlock(class_id)
	result.classes.set_active(class_id)
	var definition := session.database.get_class_def(class_id)
	var xp := 0
	for l in range(1, level):
		xp += definition.xp_to_next(l)
	result.classes.add_xp(class_id, xp)
	SkillBook.auto_fill(result, class_id)
	return result


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _open_at_station() -> void:
	var station := map.get_node("ClassStation") as ClassStation
	map.player.feed_input(InputFrame.new())
	map.player.global_position = station.global_position
	for i in 4:
		await get_tree().physics_frame
	map.hud.open_class_panel(station)
	panel.show_page("Skills")
	await _frames(4)


func _entry(skill_id: StringName) -> Button:
	return panel.find_child("Skill_%s" % skill_id, true, false) as Button


func _equip(index: int) -> Button:
	return panel.find_child("EquipSlot%d" % index, true, false) as Button


func _slots() -> Array:
	return character.builds.get_build().slots.duplicate()


func _detail_text() -> String:
	var texts: PackedStringArray = []
	for label: Label in panel.find_child("SkillDetail", true, false).find_children("*", "Label", true, false):
		texts.append(label.text)
	return " | ".join(texts)


## All 21 skills: each class lists exactly its own seven, with its own art; nothing of another class.
func test_every_class_lists_its_skills_with_their_icons() -> void:
	var total := 0
	for class_id in CLASSES:
		var other := _make(class_id, 1)
		panel.open(other, null, "Skills")
		await _frames(3)
		var own := session.database.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == class_id)
		var list := panel.find_child("SkillList", true, false)
		check_eq(list.get_child_count(), own.size(), "%s: one entry per class skill" % class_id)
		for skill: SkillDefinition in own:
			var entry := _entry(skill.id)
			if not check(entry != null, "%s listed" % skill.id):
				continue
			total += 1
			var art := entry.find_child("SkillIcon", true, false) as TextureRect
			check(art != null and art.texture == UiSkin.texture(StringName("skills/%s" % skill.id)), "%s: its own 40x40 art" % skill.id)
			check_eq((entry.find_child("SkillName", true, false) as Label).text, skill.display_name, "%s name" % skill.id)
			var unlocked := SkillBook.is_skill_available(other, class_id, skill.id)
			var state := (entry.find_child("SkillState", true, false) as Label).text
			check(state.begins_with("Locked") != unlocked, "%s: %s" % [skill.id, state])
		for skill: SkillDefinition in session.database.skills.values():
			if skill.class_id != class_id:
				check(_entry(skill.id) == null, "%s: no %s" % [class_id, skill.id])
	check_eq(total, 21, "21 skills with their icons")
	panel.hide()


## Level 1 (A, B): one skill, Q filled, three slim empty slots; a locked skill can be chosen and read (F).
func test_level_one_slots_and_locked_skill() -> void:
	character = _make(&"warrior", 1)
	await _open_at_station()
	panel.open(character, map.get_node("ClassStation") as ClassStation, "Skills")   # this character, at the station
	await _frames(3)
	check_eq(_slots(), [&"furious_strike", &"", &"", &""], "level 1: only Furious Strike")
	var q := panel.find_child("SkillSlot0", true, false) as Control
	check(q is Button and q.find_child("SkillIcon", true, false) != null, "Q: card with icon")
	check(((q.find_child("SlotCost", true, false) as Label).text).contains("Rage"), "Q: cost and cooldown")
	for index in [1, 2, 3]:
		var empty := panel.find_child("SkillSlot%d" % index, true, false) as Control
		check(not (empty is Button) and (empty.find_child("SlotSkill", true, false) as Label).text == "Empty", "slot %d: slim empty state" % index)
		check(empty.size.y <= ClassStationPanel.SKILL_SLOT_HEIGHT + 1.0, "slot %d: no big card" % index)
	_entry(&"blade_rush").pressed.emit()
	await _frames(2)
	check(_entry(&"blade_rush").button_pressed, "locked skill selectable")
	check(_detail_text().contains("Locked") and _detail_text().contains("Class level 5"), "unlock condition readable: %s" % _detail_text())
	for index in 4:
		check(_equip(index).disabled and _equip(index).tooltip_text.contains("unlock it first"), "locked: equip %d disabled with reason" % index)
	check_eq(_slots(), [&"furious_strike", &"", &"", &""], "choosing changed nothing")


## C, D, E: equip into an empty slot, replace an occupied one, swap a slotted one, remove - SkillBook rules,
## said on the buttons; choosing alone never equips.
func test_equip_replace_swap_remove() -> void:
	character.builds.get_build().slots[3] = &""
	await _open_at_station()
	check_eq(_slots(), [&"furious_strike", &"battle_cry", &"blade_rush", &""], "F empty")
	_entry(&"warbreaker").pressed.emit()
	await _frames(2)
	check_eq(_slots()[3], &"", "selection does not equip")
	check_eq(_equip(3).text, "F · Equip", "empty slot: Equip")
	check_eq(_equip(0).text, "Q · Replace", "occupied slot: Replace")
	check(_equip(0).tooltip_text.contains("Replaces Furious Strike"), "replacement named before the click")
	_equip(3).pressed.emit()
	await _frames(2)
	check_eq(_slots(), [&"furious_strike", &"battle_cry", &"blade_rush", &"warbreaker"], "equipped on F")
	check(_detail_text().contains("Equipped on F"), "details show the slot")
	check(_entry(&"warbreaker").find_child("SlotKey", true, false) != null, "list entry shows F")
	check(_equip(3).disabled and _equip(3).text == "F · Equipped", "own slot: Equipped")
	check_eq(_equip(0).text, "Q · Swap", "slotted skill: Swap")
	check(_equip(0).tooltip_text.contains("Furious Strike goes to F"), "swap named before the click: %s" % _equip(0).tooltip_text)
	_equip(0).pressed.emit()
	await _frames(2)
	check_eq(_slots(), [&"warbreaker", &"battle_cry", &"blade_rush", &"furious_strike"], "swap Q <-> F (never twice)")
	(panel.find_child("UnequipSkill", true, false) as Button).pressed.emit()
	await _frames(2)
	check_eq(_slots(), [&"", &"battle_cry", &"blade_rush", &"furious_strike"], "removed from Q")
	_entry(&"warbreaker").pressed.emit()
	await _frames(2)
	_equip(1).pressed.emit()
	await _frames(2)
	check_eq(_slots(), [&"", &"warbreaker", &"blade_rush", &"furious_strike"], "replace E: Battle Cry back to the list")
	check(panel.find_child("SkillSlot0", true, false) is Panel, "Q shown empty")


## I, J: mods only for the chosen skill - current, alternatives, locked with their unlock; the dropdown sets
## exactly the chosen mod.
func test_modifications_of_the_chosen_skill() -> void:
	await _open_at_station()
	_entry(&"furious_strike").pressed.emit()
	await _frames(2)
	var form := panel.find_child("furious_strike_form", true, false) as OptionButton
	check(form != null and not form.disabled, "Form dropdown of Furious Strike")
	check(panel.find_children("*_form", "OptionButton", true, false).size() == 1, "mods of the chosen skill only")
	var locked := 0
	var wide := -1
	for index in form.item_count:
		if form.is_item_disabled(index):
			locked += 1
			check(form.get_item_text(index).contains("locked"), "locked mod says so: %s" % form.get_item_text(index))
		if form.get_item_metadata(index) == &"furious_wide_arc":
			wide = index
	check(locked >= 1, "a locked form mod listed")
	# Menu UX Polish 1.1: only the chosen mod's effect shows; every mod (state, unlock, effect) after "All modifications"
	check(panel.find_child("Mod_furious_lunge", true, false) == null, "no permanent list of every mod")
	check(form.get_popup().get_item_tooltip(1) != "", "the open dropdown explains each mod")
	(panel.find_child("ToggleAllMods", true, false) as Button).pressed.emit()
	await _frames(2)
	form = panel.find_child("furious_strike_form", true, false) as OptionButton   # the details were rebuilt
	check(panel.find_child("Mod_furious_lunge", true, false) != null and (panel.find_child("Mod_furious_lunge", true, false) as Label).text.contains("Locked"), "locked mod with its unlock")
	var talents_before := character.builds.get_build().talents.duplicate()
	var slots_before := _slots()
	form.select(wide)
	form.item_selected.emit(wide)
	await _frames(2)
	check_eq(character.builds.get_build().mod_of(&"furious_strike", SkillModDefinition.Slot.FORM), &"furious_wide_arc", "mod set")
	check((panel.find_child("Mod_furious_wide_arc", true, false) as Label).text.contains("Active"), "current mod marked Active")
	check_eq(character.builds.get_build().mod_of(&"furious_strike", SkillModDefinition.Slot.RESONANCE), &"", "the other slot untouched")
	check_eq(character.builds.get_build().talents, talents_before, "talents untouched")
	check_eq(_slots(), slots_before, "slots untouched")
	# a talent that unlocks a mod (Concussive Rush: Piercing Lunge)
	character.classes.add_xp(&"warrior", 400000)
	for node_id: StringName in [&"war_wb_hands", &"war_wb_hands", &"war_wb_hands", &"war_wb_hands", &"war_wb_hands", &"war_wb_rush"]:
		check_eq(TalentService.learn(character, &"warrior", node_id), "", "learn %s" % node_id)
	panel.show_page("Skills")
	await _frames(3)
	check((panel.find_child("Mod_furious_lunge", true, false) as Label).text.contains("Available"), "talent mod unlocked")


## G, H, L, K: a talent unlocks a skill (list + details follow), the reset locks it again and empties its
## slot, a preset puts its slots back, a class switch shows the other class.
func test_talent_unlock_reset_preset_and_class_switch() -> void:
	character.classes.add_xp(&"warrior", 400000)
	await _open_at_station()
	check((_entry(&"whirlwind").find_child("SkillState", true, false) as Label).text.begins_with("Locked"), "Whirlwind locked")
	check_eq(TalentService.learn(character, &"warrior", &"war_b_whirlwind"), "", "talent learned")
	panel.show_page("Skills")
	await _frames(3)
	check(not (_entry(&"whirlwind").find_child("SkillState", true, false) as Label).text.begins_with("Locked"), "Whirlwind unlocked in the list")
	_entry(&"whirlwind").pressed.emit()
	await _frames(2)
	_equip(2).pressed.emit()
	await _frames(2)
	check_eq(_slots()[2], &"whirlwind", "Whirlwind on R")
	PresetService.save_preset(character, &"warrior", 0, "Spin")
	_entry(&"blade_rush").pressed.emit()
	await _frames(2)
	_equip(2).pressed.emit()
	await _frames(2)
	check_eq(_slots()[2], &"blade_rush", "R changed")
	check_eq(PresetService.activate(character, &"warrior", 0, true), "", "preset activated")
	panel.show_page("Skills")
	await _frames(3)
	check_eq((panel.find_child("SkillSlot2", true, false).find_child("SlotSkill", true, false) as Label).text, "Whirlwind", "slot bar shows the preset's R")
	panel.show_page("Talents")   # the reset sits in the Talents header
	await _frames(2)
	var respec := panel.find_child("Respec", true, false) as Button
	respec.pressed.emit()
	await _frames(2)
	panel.show_page("Skills")
	await _frames(3)
	check(not _slots().has(&"whirlwind"), "reset: Whirlwind left its slot")
	check((_entry(&"whirlwind").find_child("SkillState", true, false) as Label).text.begins_with("Locked"), "reset: Whirlwind locked again")
	character.classes.unlock(&"arcanist")
	check_eq(character.switch_class(&"arcanist", true), "", "class switch")
	panel.show_page("Skills")
	await _frames(3)
	check(_entry(&"arcane_bolt") != null and _entry(&"whirlwind") == null, "the arcanist's skills")
	check_eq(panel.selected_skill(), &"arcane_bolt", "first slotted skill chosen")


## M, N + keyboard: away from the station everything is readable but nothing can change; Enter on an entry
## only selects; closing and reopening keeps the choice and shows the real state.
func test_away_from_station_keyboard_and_reopen() -> void:
	map.hud.toggle_talents()
	await _frames(3)
	panel.show_page("Skills")
	await _frames(3)
	_entry(&"battle_cry").grab_focus()
	for pressed: bool in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		get_viewport().push_input(enter)
	await _frames(2)
	check_eq(panel.selected_skill(), &"battle_cry", "Enter selects")
	check(_entry(&"battle_cry").has_focus() or panel.find_child("SkillDetail", true, false) != null, "details reachable by keyboard")
	var slots_before := _slots()
	for index in 4:
		check(_equip(index).disabled, "away: equip %d disabled" % index)
	check(_equip(0).tooltip_text != "", "away: the reason in the tooltip")
	for choice: OptionButton in panel.find_child("SkillDetail", true, false).find_children("*", "OptionButton", true, false):
		check(choice.disabled, "away: %s disabled" % choice.name)
	check((panel.find_child("UnequipSkill", true, false) as Button).disabled, "away: remove disabled")
	check_eq(_slots(), slots_before, "nothing changed")
	map.hud.close_windows()
	await _frames(2)
	character.builds.get_build().slots[1] = &""   # the state changes while closed
	character.builds.notify(&"warrior")
	map.hud.toggle_talents()
	await _frames(2)
	panel.show_page("Skills")
	await _frames(3)
	check_eq(panel.selected_skill(), &"battle_cry", "choice kept after reopening")
	check(_detail_text().contains("Not equipped"), "details show the real state")
	check(panel.find_child("SkillSlot1", true, false) is Panel, "E shown empty")


## Window lock: the Skills page has the frame of every main page; the window never scrolls (100 / 150 %), the
## list and the details scroll on their own, slots stay on top.
func test_window_geometry_and_inner_scrolling() -> void:
	await _open_at_station()
	for scale: float in [1.0, 1.5]:
		session.settings.set_ui_scale(scale)
		await _frames(4)
		panel.show_page("Talents")
		await _frames(3)
		var talents_rect := panel.get_global_rect()
		panel.show_page("Skills")
		await _frames(4)
		check(panel.get_global_rect().is_equal_approx(talents_rect), "%d %%: same frame as Talents" % roundi(scale * 100))
		check(not panel._scroll.get_v_scroll_bar().visible and not panel._scroll.get_h_scroll_bar().visible, "%d %%: the window never scrolls" % roundi(scale * 100))
		var slots := (panel.find_child("SkillSlots", true, false) as Control).get_global_rect()
		var list := (panel.find_child("SkillListScroll", true, false) as Control).get_global_rect()
		var detail := (panel.find_child("SkillDetail", true, false) as Control).get_global_rect()
		check(slots.end.y <= list.position.y and slots.end.y <= detail.position.y, "%d %%: slots above list and details" % roundi(scale * 100))
		check(panel.get_global_rect().encloses(list) and panel.get_global_rect().encloses(detail), "%d %%: list and details inside" % roundi(scale * 100))
		check(not list.intersects(detail), "%d %%: list and details side by side" % roundi(scale * 100))
		check(panel.find_child("SkillDetailScroll", true, false) is ScrollContainer, "details scroll inside")
		for label: Label in panel.find_child("SkillSlots", true, false).find_children("*", "Label", true, false):
			check(label.get_global_rect().size.x > 0.0 and slots.grow(1.0).encloses(label.get_global_rect()), "%d %%: slot text inside its card: %s" % [roundi(scale * 100), label.text])
