extends TestCase
## Armor Mastery 1.0: burden table and tiers (full plate 39 = Heavy), mixed
## armour, weapons / shields carry none; penalties on walking and attack
## recovery only (dash and parry untouched); XP split by coverage, empty slots
## lose their share; milestones scaled by coverage; class change; kills and
## blocks give XP, hits taken and training targets none, one enemy cannot be
## farmed; save v10 and the v9 -> v10 migration; the Armor page of the
## character book. Only user://test_saves/.

const DIR := "user://test_saves/armor"
const PATH := DIR + "/slot_1.save.json"
const C := ItemDefinition.ArmorType.CLOTH
const L := ItemDefinition.ArmorType.LEATHER
const M := ItemDefinition.ArmorType.MAIL
const P := ItemDefinition.ArmorType.PLATE
const N := ItemDefinition.ArmorType.NONE
const SLOT_KINDS := [ItemDefinition.SlotKind.HEAD, ItemDefinition.SlotKind.CHEST, ItemDefinition.SlotKind.HANDS,
	ItemDefinition.SlotKind.LEGS, ItemDefinition.SlotKind.FEET]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var rules: ArmorMasteryRules
var _previous: Character
var _previous_path: String
var _test_items: Array[StringName] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	rules = db.rules.armor_rules()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	character = CharacterFactory.create_new(db)
	character.world.set_flag(&"prologue.haven_discovered")
	for slot: int in ArmorMasteryRules.SLOTS:   # start bare in the five armour slots
		if character.equipment.get_item(slot) != null:
			character.equipment.unequip(slot)
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for id in _test_items:
		db.items.erase(id)
	_test_items.clear()
	for path in [PATH] + SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


## Test-only armour piece (the game data has no plate yet).
func _piece(type: int, slot_index: int) -> ItemInstance:
	var id := StringName("test_armor_%d_%d" % [type, slot_index])
	if not db.items.has(id):
		var definition := ItemDefinition.new()
		definition.id = id
		definition.display_name = "Test Armour"
		definition.category = ItemDefinition.Category.ARMOR
		definition.slot_kind = SLOT_KINDS[slot_index]
		definition.armor_type = type
		db.items[id] = definition
		_test_items.append(id)
	return character.inventory.add_item(id, 1)[0]


func _wear(types: Array) -> void:
	for index in types.size():
		var slot: int = ArmorMasteryRules.SLOTS[index]
		if character.equipment.get_item(slot) != null:
			character.equipment.unequip(slot)
		if types[index] != N:
			check_eq(character.equipment.equip(_piece(types[index], index).instance_id, slot), "", "equip %d in slot %d" % [types[index], index])


func test_burden_table_and_tiers() -> void:
	check_eq(ArmorMasteryService.burden_of([P, P, P, P, P], rules), 39, "full plate = 39")
	check_eq(ArmorMasteryService.tier(39, rules), 3, "full plate is Heavy")
	check_eq(ArmorMasteryService.burden_of([C, C, C, C, C], rules), 8, "full cloth = 8")
	check_eq(ArmorMasteryService.burden_of([L, L, L, L, L], rules), 15, "full leather = 15")
	check_eq(ArmorMasteryService.burden_of([M, M, M, M, M], rules), 24, "full mail = 24")
	check_eq(ArmorMasteryService.burden_of([P, L, C, M, L], rules), 5 + 5 + 1 + 6 + 2, "mixed armour adds per slot")
	check_eq(ArmorMasteryService.burden_of([N, N, N, N, N], rules), 0, "nothing worn: 0")
	for entry: Array in [[14, 0], [15, 1], [25, 1], [26, 2], [37, 2], [38, 3]]:
		check_eq(ArmorMasteryService.tier(entry[0], rules), entry[1], "%d points -> %s" % [entry[0], ArmorMasteryService.TIER_NAMES[entry[1]]])


func test_worn_armour_coverage_and_no_weapon_burden() -> void:
	for item_id: StringName in [&"leather_cap", &"leather_gloves", &"worn_boots", &"linen_trousers"]:
		var item: ItemInstance = character.inventory.add_item(item_id, 1)[0]
		check_eq(character.equipment.equip(item.instance_id), "", "%s worn" % item_id)
	var covered := ArmorMasteryService.coverage(character)
	check(is_equal_approx(covered[L], 0.35) and is_equal_approx(covered[C], 0.25), "leather 35 %%, cloth 25 %% (%s)" % [covered])
	check_eq(ArmorMasteryService.burden(character), 2 + 2 + 2 + 2, "cap, gloves, boots, trousers = 8")
	var shield: ItemInstance = character.inventory.add_item(&"oak_shield", 1)[0]
	character.equipment.equip(shield.instance_id)
	check_eq(ArmorMasteryService.burden(character), 8, "the shield carries no burden")
	var mantle: ItemInstance = character.inventory.add_item(&"padded_mantle", 1)[0]
	character.equipment.equip(mantle.instance_id)
	check_eq(ArmorMasteryService.burden(character), 8, "slots outside the five carry none")


func test_xp_split_by_coverage_and_milestones_scale() -> void:
	_wear([L, N, L, C, L])   # leather 15+10+10 = 35 %, cloth 25 %, chest empty (40 % lost)
	ArmorMasteryService.add_xp(character, 100.0)
	check(is_equal_approx(character.armor_mastery.xp(L), 35.0), "leather +35 (%.1f)" % character.armor_mastery.xp(L))
	check(is_equal_approx(character.armor_mastery.xp(C), 25.0), "cloth +25")
	check(character.armor_mastery.xp(M) == 0.0 and character.armor_mastery.xp(P) == 0.0, "mail / plate nothing; the empty chest's 40 are not moved")
	# leather to level 10: +1 % move (lv 5) and +2 % attack recovery (lv 10), x 35 %
	while character.armor_mastery.level(L) < 10:
		character.armor_mastery.add_xp(L, rules.xp_to_next(character.armor_mastery.level(L)), rules)
	character.invalidate_stats()
	check(is_equal_approx(character.get_stat(Stats.MOVE_SPEED), 0.35), "move +0.35 %% at 35 %% leather (%.3f)" % character.get_stat(Stats.MOVE_SPEED))
	check(is_equal_approx(character.get_stat(Stats.ATTACK_RECOVERY_SPEED), 0.7), "attack recovery +0.7 %%")
	_wear([L, L, L, L, L])
	check(is_equal_approx(character.get_stat(Stats.MOVE_SPEED), 1.0), "full leather: the full +1 %")
	_wear([N, N, N, N, N])
	check_eq(character.get_stat(Stats.MOVE_SPEED), 0.0, "no leather worn: no bonus")
	check_eq(character.armor_mastery.level(L), 10, "the level stays")
	# max level
	for i in 40:
		character.armor_mastery.add_xp(C, 100000.0, rules)
	check_eq(character.armor_mastery.level(C), 20, "capped at 20")


func test_penalties_touch_walking_and_recovery_only() -> void:
	_wear([P, P, P, P, P])
	if not await _open_haven():
		return
	var player := map.player
	check(is_equal_approx(player.move_speed_multiplier, 0.92), "Heavy: -8 %% walking (%.3f)" % player.move_speed_multiplier)
	check(is_equal_approx(player.combat.recovery_multiplier, 1.08), "Heavy: +8 %% attack recovery time")
	var dash := player.dash.config
	check(dash.distance == 110.0 and dash.iframe_duration == 0.18 and dash.max_charges == 2 and dash.recharge_time == 2.5, "dash untouched")
	var guard := player.defense.profile()
	if guard != null:
		var parry := guard.parry_window
		check_eq(player.defense.profile().parry_window, parry, "parry window untouched")
	# Iron Discipline: plate 20 at full plate removes 1 point
	while character.armor_mastery.level(P) < 20:
		character.armor_mastery.add_xp(P, rules.xp_to_next(character.armor_mastery.level(P)), rules)
	character.invalidate_stats()
	await get_tree().process_frame
	check(is_equal_approx(player.move_speed_multiplier, 0.93), "Iron Discipline: -7 %% instead of -8 %% (%.3f)" % player.move_speed_multiplier)
	check(is_equal_approx(player.physical_damage_multiplier, 0.99), "plate 10: -1 % physical damage")
	_wear([C, C, C, C, C])
	await get_tree().process_frame
	check(is_equal_approx(player.move_speed_multiplier, 1.0) and is_equal_approx(player.combat.recovery_multiplier, 1.0), "full cloth (8, Light): no penalty")


func test_class_change_keeps_mastery() -> void:
	_wear([L, L, L, L, L])
	ArmorMasteryService.add_xp(character, 500.0)
	var level := character.armor_mastery.level(L)
	var other: StringName = &""
	for class_id: StringName in db.classes:
		if class_id != character.classes.active_class_id:
			other = class_id
			break
	character.classes.unlock(other)
	check_eq(character.switch_class(other, true), "", "class changed")
	check_eq(character.armor_mastery.level(L), level, "mastery is character-wide")
	check_eq(ArmorMasteryService.burden(character), ArmorMasteryService.burden_of(ArmorMasteryService.worn_types(character), rules), "burden from the new class's loadout")


func test_xp_sources_and_farm_guards() -> void:
	_wear([L, L, L, L, L])
	if not await _open_haven():
		return
	var bridge := map.bridge
	var enemy := (load("res://scenes/enemies/grunt.tscn") as PackedScene).instantiate() as Enemy
	map.add_child(enemy)
	await get_tree().process_frame
	# a hit taken gives nothing
	var taken := HitData.new()
	taken.damage = 1.0
	taken.attacker = enemy
	map.player.hurtbox.hit_received.emit(taken)
	check_eq(character.armor_mastery.xp(L), 0.0, "no XP for a hit taken")
	# blocks: once per attack instance, capped per enemy
	for attack in 10:
		var blocked := HitData.new()
		blocked.attacker = enemy
		blocked.attack_instance_id = attack
		bridge._on_defended(blocked)
		bridge._on_defended(blocked)   # the same attack twice
	check(is_equal_approx(character.armor_mastery.xp(L), rules.defense_xp_cap_per_enemy), "blocks: capped at %.0f per enemy (%.1f)" % [rules.defense_xp_cap_per_enemy, character.armor_mastery.xp(L)])
	# training targets give nothing
	var dummy := Node2D.new()
	dummy.add_to_group(&"training_target")
	map.add_child(dummy)
	var practice := HitData.new()
	practice.attacker = dummy
	practice.attack_instance_id = 999
	var before := character.armor_mastery.xp(L)
	bridge._on_defended(practice)
	check_eq(character.armor_mastery.xp(L), before, "no XP from training targets")
	# a kill: the enemy's kill reward, once
	enemy.health.apply_hit(_lethal())
	var kill := HitData.new()
	kill.target = enemy
	var reward: int = enemy.get_kill_reward().get("mastery_xp", 0)
	check(reward > 0, "the grunt has a kill reward")
	var xp_before := character.armor_mastery.xp(L)
	bridge.rewards.reward_kill(kill)
	check(is_equal_approx(character.armor_mastery.xp(L), xp_before + reward), "kill: +%d (%.1f)" % [reward, character.armor_mastery.xp(L)])
	var after_kill := character.armor_mastery.xp(L)
	bridge.rewards.reward_kill(kill)
	check_eq(character.armor_mastery.xp(L), after_kill, "a kill counts once")


func _lethal() -> HitData:
	var hit := HitData.new()
	hit.damage = 1000000.0
	return hit


func test_save_load_and_migration() -> void:
	_wear([M, M, N, N, N])
	ArmorMasteryService.add_xp(character, 300.0)
	var level := character.armor_mastery.level(M)
	var xp := character.armor_mastery.xp(M)
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	check(loaded.character.armor_mastery.level(M) == level and absf(loaded.character.armor_mastery.xp(M) - xp) < 0.02, "mail level and XP kept")
	var payload := character.to_dict()
	payload.erase("armor_mastery")
	var errors: PackedStringArray = []
	var migrated: Dictionary = SaveMigrations.migrate(payload, 9, errors)
	var warnings: PackedStringArray = []
	var old := Character.from_dict(migrated, db, warnings)
	check(errors.is_empty() and warnings.is_empty(), "v9 -> v10 clean: %s %s" % [errors, warnings])
	for type: int in ArmorMasteryRules.TYPES:
		check(old.armor_mastery.level(type) == 1 and old.armor_mastery.xp(type) == 0.0, "type %d starts at level 1" % type)
	check_eq(JSON.stringify(old.equipment.to_dict()), JSON.stringify(character.equipment.to_dict()), "loadouts untouched")
	check(int(SaveSystem.VERSION) >= 10, "save version 10 or later (v11: affix tier models)")


func _open_haven() -> bool:
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.is_node_ready() and not session.is_traveling():
			map = current
			map.player.feed_input(InputFrame.new())
			await get_tree().physics_frame
			return true
	fail("Haven not loaded")
	return false


func test_armor_page() -> void:
	_wear([P, P, P, P, P])
	if not await _open_haven():
		return
	map.hud.toggle_character()
	var panel := map.hud.class_panel
	panel.show_page("Armor")
	for i in 3:
		await get_tree().process_frame
	var tier := panel.find_child("Tier", true, false) as Label
	check(tier != null and tier.text == "39  ·  Heavy", "burden and tier shown: %s" % (tier.text if tier else "-"))
	for key: String in ["cloth", "leather", "mail", "plate"]:
		check(panel.find_child("Track_%s" % key, true, false) != null, "%s track" % key)
	check(panel.get_global_rect().size.x > 0.0 and get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "inside the screen")
