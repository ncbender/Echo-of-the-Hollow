extends TestCase
## Skills & Talents UX 2.0 Phase 1 (docs/SKILLS_TALENTS_UX_2_0.md): the Weapons tab shows only the family of the
## equipped main-hand weapon - its mastery, every combo with its icon, locked / unlocked, the chosen combo's details -
## follows weapon changes, has an empty state without a weapon, keeps the shared frame, and changes no data.

var session: SessionState
var map: GameMap
var character: Character
var panel: ClassStationPanel
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.inventory.capacity += 20
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame
	panel = map.hud.class_panel


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _wield(family_id: StringName) -> void:
	for definition: ItemDefinition in session.database.items.values():
		if definition.weapon_family_id == family_id and definition.is_equippable():
			var item: ItemInstance = character.inventory.add_item(definition.id, 1)[0]
			check_eq(character.equipment.equip(item.instance_id, EquipSlot.Slot.MAIN_HAND), "", "%s equipped" % family_id)
			return
	fail("no item of %s" % family_id)


func _open_weapons() -> void:
	if not panel.visible:
		map.hud.toggle_talents()
	panel.show_page("Weapons")
	await _frames()


func _cells() -> Array:
	var grid := panel.find_child("Combos", true, false)
	return grid.get_children() if grid != null else []


func test_every_combo_of_every_family_has_its_icon() -> void:
	var paths := 0
	for family: WeaponFamily in session.database.weapons.values():
		if not family.uses_flow():
			continue
		paths += family.combo_paths.size()
		for entry: Dictionary in ComboIcons.entries(family):
			var icon := ComboIcons.icon_id(family, entry.sequence)
			check(UiSkin.has(icon), "%s %s -> %s exists" % [family.id, entry.key, icon])
	check_eq(paths, 72, "72 combo paths in the data (unchanged)")
	# shared action, own effect: the dagger's side steps and triple hit, the wand's twin bolts, the lunges
	var db := session.database
	check_eq(ComboIcons.icon_id(db.weapons[&"one_handed_sword"], "LLL"), &"combos/sweep_lll", "a sword's LLL is the shared sweep")
	check_eq(ComboIcons.icon_id(db.weapons[&"axe"], "LLL"), &"combos/sweep_lll", "the axe shares it")
	check_eq(ComboIcons.icon_id(db.weapons[&"axe"], "HLL"), &"combos/sweep_hll_lunge", "a lunge is shown")
	check_eq(ComboIcons.icon_id(db.weapons[&"dagger"], "HLL"), &"combos/sweep_hll", "the dagger's HLL has no lunge")
	check_eq(ComboIcons.icon_id(db.weapons[&"dagger"], "HHH"), &"combos/sweep_hhh_x3", "triple hit")
	check_eq(ComboIcons.icon_id(db.weapons[&"spear"], "LLH"), &"combos/thrust_llh_lunge", "the spear thrusts and lunges")
	check_eq(ComboIcons.icon_id(db.weapons[&"wand"], "LHL"), &"combos/bolt_lhl_twin", "twin bolts")
	check_eq(ComboIcons.icon_id(db.weapons[&"bow"], ComboIcons.FLOWING_DRAW), &"combos/arrow_flowing_draw", "Flowing Draw")


func test_only_the_wielded_family_and_its_states() -> void:
	_wield(&"axe")
	character.mastery._levels[&"axe"] = 6
	character.mastery._levels[&"bow"] = 15   # saved mastery of a weapon not in hand: never shown here
	await _open_weapons()
	var frame := panel.get_global_rect()
	check_eq((panel.find_child("Family", true, false) as Label).text, "Axe", "only the wielded family")
	check(panel.find_child("Family_bow", true, false) == null and not (panel.find_child("Family", true, false) as Label).text.contains("Bow"), "no other family")
	check((panel.find_child("Level", true, false) as Label).text.begins_with("Mastery 6 /"), "its mastery level")
	var cells := _cells()
	check_eq(cells.size(), 10, "2 base attacks + 8 paths")
	var unlocked := cells.filter(func(c: Node) -> bool: return (c.find_child("Icon", true, false) as TextureRect).modulate == Color.WHITE)
	check_eq(unlocked.size(), 5, "base L / H and the paths of levels 2, 4, 6 unlocked at mastery 6")
	# choosing a locked combo shows it, changes nothing
	var locked := panel.find_child("Combo_HHH", true, false) as Button
	locked.pressed.emit()
	await _frames()
	check(locked.button_pressed, "chosen combo marked")
	check_eq((panel.find_child("ComboName", true, false) as Label).text, "Reaver's Crown", "its details")
	check((panel.find_child("ComboState", true, false) as Label).text.begins_with("Locked"), "shown as locked with its level")
	check_eq(character.mastery.get_level(&"axe"), 6, "choosing changes no mastery")
	check_eq(session.database.weapons[&"axe"].combo_paths.size(), 8, "no path changed")
	check(panel.get_global_rect().is_equal_approx(frame), "same frame")
	# the weapon changes: the tab follows the hand
	_wield(&"bow")
	panel.show_page("Weapons")
	await _frames()
	check_eq((panel.find_child("Family", true, false) as Label).text, "Bow", "now the bow")
	check_eq(_cells().size(), 10, "bow: L, P, 7 paths, Flowing Draw")
	check(panel.find_child("Combo_flowing_draw", true, false) != null, "Flowing Draw listed")
	check((panel.find_child("Level", true, false) as Label).text.begins_with("Mastery 15 /"), "the bow's own saved mastery")
	check(panel.get_global_rect().is_equal_approx(frame), "same frame after the change")
	# a mastery level reached: the next combo unlocks in the tab
	character.mastery._levels[&"bow"] = 17
	panel.show_page("Weapons")
	await _frames()
	var split := panel.find_child("Combo_LPL", true, false) as Button
	check((split.find_child("Icon", true, false) as TextureRect).modulate == Color.WHITE, "Split Volley unlocked at 17")
	# no weapon: the empty state
	check_eq(character.equipment.unequip(EquipSlot.Slot.MAIN_HAND), "", "unequipped")
	panel.show_page("Weapons")
	await _frames()
	check(panel.find_child("NoWeapon", true, false) != null and panel.find_child("Combos", true, false) == null, "empty state, no grid")
	check(panel.get_global_rect().is_equal_approx(frame), "same frame without a weapon")


func test_selection_is_kept_per_family_and_keyboard_moves() -> void:
	_wield(&"one_handed_sword")
	await _open_weapons()
	(panel.find_child("Combo_LHL", true, false) as Button).pressed.emit()
	await _frames()
	panel.show_page("Skills")
	await _frames()
	panel.show_page("Weapons")
	await _frames()
	check((panel.find_child("Combo_LHL", true, false) as Button).button_pressed, "the chosen combo stays chosen")
	var first := _cells()[0] as Button
	first.grab_focus()
	await _frames(1)
	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	get_viewport().push_input(right)
	await _frames(2)
	check((_cells()[1] as Control).has_focus(), "the right arrow moves the focus to the next combo")
	check((panel.find_child("Combo_LHL", true, false) as Button).button_pressed, "focus does not change the selection")
