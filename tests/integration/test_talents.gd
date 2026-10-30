extends GameplayTestCase
## Class Foundation B: generic talent engine on a synthetic test class (three
## trees, four tiers - Talent Structure Rework 1.0): points per level, tier gates per tree, ranks,
## prerequisites, capstones, data validation (cycles, reachability), respec
## costs and effect removal, stat bonuses applied exactly once, persistence.

const CLASS_ID := &"test_mage"

static var _db: GameDatabase

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = class_database()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(CLASS_ID)
	character.switch_class(CLASS_ID, true)


## Real data + a synthetic class "test_mage" with trees ta/tb/tc, skills
## t_bolt (level 1), t_nova (active talent), t_ward (level 3) and three mods.
static func class_database() -> GameDatabase:
	if _db != null:
		return _db
	_db = GameDatabase.new()
	_db.load_all()
	var mana := ClassResourceDefinition.new()
	mana.id = &"test_mana"
	mana.display_name = "Mana"
	mana.max_value = 100.0
	mana.start_value = 100.0
	mana.regen_per_second = 5.0
	var mage := ClassDefinition.new()
	mage.id = CLASS_ID
	mage.display_name = "Test Mage"
	mage.max_level = 60
	mage.xp_growth = 1.0
	mage.resource = mana
	mage.talent_tree_ids = [&"ta", &"tb", &"tc"]
	_db.register(mage)
	var bolt_hit := SkillHitSpec.new()
	bolt_hit.damage = 10.0
	bolt_hit.damage_type = &"arcane"
	var bolt_action := ProjectileAction.new()
	bolt_action.hit = bolt_hit
	_db.register(_skill(&"t_bolt", 1, 10.0, 1.0, [bolt_action]))
	var nova_action := AreaStrikeAction.new()
	nova_action.arc_degrees = 360.0
	nova_action.hit = bolt_hit
	_db.register(_skill(&"t_nova", 0, 20.0, 4.0, [nova_action]))
	var ward := BuffAction.new()
	ward.key = &"t_ward"
	ward.stat_modifiers = [StatModifier.make(Stats.ARMOR, 10.0)]
	_db.register(_skill(&"t_ward", 3, 0.0, 6.0, [ward]))
	var split := _mod(&"f_split", SkillModDefinition.Slot.FORM, 1)
	split.extra_projectiles = 2
	split.incompatible_with = [&"r_focus"]
	_db.register(split)
	var focus := _mod(&"r_focus", SkillModDefinition.Slot.RESONANCE, 0)
	focus.damage_multiplier = 1.5
	focus.unlock_source = &"talent.ta_1b"
	_db.register(focus)
	var siphon := _mod(&"r_siphon", SkillModDefinition.Slot.RESONANCE, 1)
	siphon.resource_on_hit = 5.0
	_db.register(siphon)
	for tree_id: StringName in [&"ta", &"tb", &"tc"]:
		_db.register(_tree(tree_id))
	return _db


static func _skill(id: StringName, level: int, cost: float, cooldown: float, actions: Array) -> SkillDefinition:
	var skill := SkillDefinition.new()
	skill.id = id
	skill.class_id = CLASS_ID
	skill.display_name = String(id).capitalize()
	skill.unlock_level = level
	skill.resource_cost = cost
	skill.cooldown = cooldown
	skill.cast_lock = 0.1
	skill.tags = [&"spell"]
	skill.actions.assign(actions)
	return skill


static func _mod(id: StringName, slot: SkillModDefinition.Slot, level: int) -> SkillModDefinition:
	var mod := SkillModDefinition.new()
	mod.id = id
	mod.display_name = String(id).capitalize()
	mod.slot = slot
	mod.skill_ids = [&"t_bolt"]
	mod.unlock_level = level
	return mod


## Six pairs "<tree>_<n>" (5 ranks, +1 skill damage per rank) and "<tree>_<n>b"
## (1 rank), n = 1..6, plus the capstone "<tree>_7" - laid out like the real
## trees (Talent Structure Rework 1.0): pair n sits in tier ceil(n / 2), four
## nodes per tier (12 ranks), the capstone alone in tier 4.
## ta_2b is ACTIVE (t_nova), ta_3b TRANSFORMATIVE (t_bolt +1 pierce), ta_1b unlocks r_focus,
## ta_4 requires ta_3b (a direct upgrade in the same tier).
static func _tree(tree_id: StringName) -> TalentTreeDefinition:
	var tree := TalentTreeDefinition.new()
	tree.id = tree_id
	tree.class_id = CLASS_ID
	tree.display_name = "Tree %s" % tree_id
	for pair in range(1, 8):
		var tier := ceili(pair / 2.0)
		var column := 0 if pair % 2 == 1 else 2
		var main := _node(tree_id, StringName("%s_%d" % [tree_id, pair]), tier, 1 if pair == 7 else 5)
		main.column = 0 if pair == 7 else column
		main.stat_modifiers = [StatModifier.make(Stats.SKILL_DAMAGE, 1.0)]
		tree.nodes.append(main)
		if pair == 7:
			continue
		var second := _node(tree_id, StringName("%s_%db" % [tree_id, pair]), tier, 1)
		second.column = column + 1
		tree.nodes.append(second)
	if tree_id == &"ta":
		var active := tree.get_node_def(&"ta_2b")
		active.kind = TalentNodeDefinition.Kind.ACTIVE
		active.unlocks_skill = &"t_nova"
		var transform := tree.get_node_def(&"ta_3b")
		transform.kind = TalentNodeDefinition.Kind.TRANSFORMATIVE
		var pierce := SkillModDefinition.new()
		pierce.id = &"t_bolt_pierce"
		pierce.skill_ids = [&"t_bolt"]
		pierce.extra_pierce = 1
		transform.skill_mods = [pierce]
		tree.get_node_def(&"ta_1b").unlocks_mods = [&"r_focus"]
		tree.get_node_def(&"ta_4").prerequisites = [&"ta_3b"]
	return tree


static func _node(tree_id: StringName, id: StringName, tier: int, ranks: int) -> TalentNodeDefinition:
	var node := TalentNodeDefinition.new()
	node.id = id
	node.class_id = CLASS_ID
	node.tree_id = tree_id
	node.display_name = String(id)
	node.tier = tier
	node.max_rank = ranks
	return node


func _set_level(level: int) -> void:
	var definition := db.get_class_def(CLASS_ID)
	var needed := 0
	for l in range(character.classes.get_level(CLASS_ID), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(CLASS_ID, needed - character.classes.get_xp(CLASS_ID))


func _learn(node_id: StringName, times: int = 1) -> String:
	var error := ""
	for i in times:
		error = TalentService.learn(character, CLASS_ID, node_id)
		if error != "":
			return error
	return error


func test_test_data_is_valid() -> void:
	check(db.load_errors.is_empty(), "real data loads cleanly: %s" % [db.load_errors])
	var errors := db.validate()
	check(errors.is_empty(), "synthetic class validates: %s" % [errors])
	for tree_id: StringName in [&"ta", &"tb", &"tc"]:
		check_eq(db.talent_trees[tree_id].nodes.size(), 13, "13 nodes in %s" % tree_id)


func test_points_per_level() -> void:
	var rules := db.rules.talent_rules()
	check_eq(rules.first_point_level, 5, "first talent point at class level 5 (design)")
	check_eq(rules.points_at_level(1), 0, "no points before level 5")
	check_eq(rules.points_at_level(4), 0, "level 4: none")
	check_eq(rules.points_at_level(5), 1, "level 5: first point")
	check_eq(rules.points_at_level(6), 2, "level 6: two points")
	check_eq(rules.points_at_level(10), 6, "level 10: six points")
	check_eq(rules.points_at_level(60), 56, "level 60: 56 points")
	check_eq(TalentService.points_total(character, CLASS_ID), 0, "level 1 character")
	check(_learn(&"ta_1") != "", "cannot learn without points")
	_set_level(4)
	check_eq(TalentService.points_available(character, CLASS_ID), 0, "level 4: still none")
	check(_learn(&"ta_1") != "", "level 4: cannot learn")
	_set_level(12)
	check_eq(TalentService.points_available(character, CLASS_ID), 8, "level 12: eight points (jump over level 5)")


func test_tier_gates_count_only_lower_tiers_of_the_same_tree() -> void:
	check_eq(Array(db.rules.talent_rules().tier_points), [0, 5, 18, 30], "gates 0 / 5 / 18 / 30 (Talent Structure Rework 1.0)")
	_set_level(30)   # 26 points
	check_eq(_learn(&"ta_1", 4), "", "4 points in tier 1")
	check(_learn(&"ta_3") != "", "tier 2 locked with 4 points")
	check_eq(_learn(&"tb_1", 5), "", "5 points in another tree")
	check(_learn(&"ta_3") != "", "points of other trees never count")
	check_eq(_learn(&"ta_2b"), "", "5th point in tree ta: the active of tier 1, no path needed")
	check_eq(_learn(&"ta_3"), "", "tier 2 unlocked by 5 points in lower tiers")
	check(_learn(&"ta_5") != "", "tier 3 needs 18 points below")
	check(_learn(&"ta_2b") != "", "max rank respected")
	check_eq(_learn(&"ta_3", 4), "", "ta_3 maxed")
	check(_learn(&"ta_5").contains("18 points"), "10 points below tier 3 are not enough")
	check(_learn(&"ta_4").contains("ta_3b"), "tier open, but the direct upgrade still needs its parent")


## Talent Structure Rework 1.0: inside an open tier every node is a free choice -
## no node of the tier needs another one first (except direct upgrades).
func test_free_choice_inside_an_open_tier() -> void:
	_set_level(60)
	var tree: TalentTreeDefinition = db.talent_trees[&"tb"]
	for node in tree.nodes:
		if node.tier == 1:
			check_eq(TalentService.can_learn(character, CLASS_ID, node.id), "", "tier 1 open from the first point: %s" % node.id)
	check_eq(_learn(&"tb_2", 5), "", "5 points in one node of tier 1")
	for node in tree.nodes:
		if node.tier == 2:
			check_eq(TalentService.can_learn(character, CLASS_ID, node.id), "", "any tier 2 node right away: %s" % node.id)
	# different routes to tier 3: the tier only counts points, not which nodes
	var routes: Array[Dictionary] = [
		{&"tb_1": 5, &"tb_2": 5, &"tb_3": 5, &"tb_4": 3},
		{&"tb_1b": 1, &"tb_2": 5, &"tb_2b": 1, &"tb_3": 4, &"tb_3b": 1, &"tb_4": 5, &"tb_4b": 1},
		{&"tb_1": 5, &"tb_3": 5, &"tb_4": 5},
	]
	for talents in routes:
		var below := TalentService.points_in_tree(talents, tree, 3)
		talents[&"tb_6b"] = 1
		check_eq(TalentService.validate_allocation(db, CLASS_ID, 60, talents).is_empty(), below >= 18,
			"route %s: %d points below tier 3 decide alone" % [talents.keys(), below])


func test_prerequisites_and_level_requirements() -> void:
	_set_level(60)
	_learn(&"ta_1", 5)
	_learn(&"ta_1b")
	_learn(&"ta_2", 5)
	_learn(&"ta_2b")
	_learn(&"ta_3", 3)
	check_eq(TalentService.points_in_tree(character.builds.get_build().talents, db.talent_trees[&"ta"], 3), 15, "15 points below tier 3")
	var error := _learn(&"ta_4")
	check(error.contains("ta_3b"), "prerequisite named in the reason: %s" % error)
	check_eq(_learn(&"ta_3b"), "", "prerequisite learned")
	check_eq(_learn(&"ta_4"), "", "now allowed")
	db.talent_nodes[&"tb_1b"].required_class_level = 61
	check(_learn(&"tb_1b").contains("level"), "class level requirement")
	db.talent_nodes[&"tb_1b"].required_class_level = 0
	check(TalentService.learn(character, CLASS_ID, &"warrior_unknown") != "", "unknown node refused")


func test_only_one_capstone_with_56_points() -> void:
	var talents := {}
	for tree_id: StringName in [&"ta", &"tb"]:
		for tier in range(1, 7):
			talents[StringName("%s_%d" % [tree_id, tier])] = 5
		talents[StringName("%s_3b" % tree_id)] = 1
		talents[StringName("%s_7" % tree_id)] = 1
	talents[&"ta_4"] = 5
	var errors := TalentService.validate_allocation(db, CLASS_ID, 60, talents)
	check(errors.size() > 0 and errors[errors.size() - 1].contains("available"), "two capstones exceed 56 points: %s" % [errors])
	var single := {}
	for tier in range(1, 7):
		single[StringName("ta_%d" % tier)] = 5
	single[&"ta_3b"] = 1
	single[&"ta_7"] = 1
	check_eq(TalentService.validate_allocation(db, CLASS_ID, 60, single), PackedStringArray(), "one capstone: 31 points in its tree")
	single[&"ta_6"] = 3   # 29 points below the capstone tier
	check(not TalentService.validate_allocation(db, CLASS_ID, 60, single).is_empty(), "capstone needs 30 points below")
	check(db.talent_nodes[&"ta_7"].is_capstone() and db.talent_nodes[&"ta_7"].tier == TalentRules.TIERS, "ta_7 is the capstone of the last tier")


## Talent Structure Rework 1.0: tier 3 (18 points below) fits into at most two
## trees of a 56-point build; tier 2 into all three.
func test_tier_3_in_at_most_two_trees() -> void:
	var three := {}
	var two := {}
	for tree_id: StringName in [&"ta", &"tb", &"tc"]:
		var part := {StringName("%s_1" % tree_id): 5, StringName("%s_2" % tree_id): 5, StringName("%s_3" % tree_id): 5,
			StringName("%s_3b" % tree_id): 1, StringName("%s_2b" % tree_id): 1, StringName("%s_1b" % tree_id): 1, StringName("%s_5b" % tree_id): 1}
		three.merge(part)
		if tree_id != &"tc":
			two.merge(part)
	var errors := TalentService.validate_allocation(db, CLASS_ID, 60, three)
	check_eq(errors.size(), 1, "three trees at tier 3: only the point total fails: %s" % [errors])
	check(errors.size() == 1 and errors[0].contains("57 talent points"), "3 x 19 = 57 > 56")
	check_eq(TalentService.validate_allocation(db, CLASS_ID, 60, two), PackedStringArray(), "two trees at tier 3 fit (38 points)")
	var wide := {&"ta_1": 5, &"ta_3": 1, &"tb_1": 5, &"tb_3": 1, &"tc_1": 5, &"tc_3": 1}
	check_eq(TalentService.validate_allocation(db, CLASS_ID, 60, wide), PackedStringArray(), "tier 2 in all three trees")


func test_data_validation_finds_cycles_and_unreachable_tiers() -> void:
	var rules := db.rules.talent_rules()
	var broken := _tree(&"tx")
	broken.get_node_def(&"tx_1").prerequisites = [&"tx_1b"]
	broken.get_node_def(&"tx_1b").prerequisites = [&"tx_1"]
	var check_db := GameDatabase.new()
	check_db.rules = db.rules
	check_db.register(db.get_class_def(CLASS_ID))
	check_db.register(broken)
	var errors := TalentService.validate_data(check_db)
	check(Array(errors).any(func(e: String) -> bool: return e.contains("circular")), "cycle detected: %s" % [errors])
	var sparse := TalentTreeDefinition.new()
	sparse.id = &"ts"
	sparse.class_id = CLASS_ID
	sparse.nodes = [_node(&"ts", &"ts_1", 1, 3), _node(&"ts", &"ts_2", 2, 1), _node(&"ts", &"ts_7", 4, 1)]
	var tree_errors := sparse.validate(rules)
	check(Array(tree_errors).any(func(e: String) -> bool: return e.contains("unreachable")), "unreachable tier: %s" % [tree_errors])
	for tree_id: StringName in [&"ta", &"tb", &"tc"]:
		check(db.talent_trees[tree_id].validate(rules).is_empty(), "%s reachable" % tree_id)


func test_stats_from_talents_apply_once_and_follow_the_class() -> void:
	_set_level(20)
	_learn(&"ta_1", 3)
	check_eq(character.get_stat(Stats.SKILL_DAMAGE), 3.0, "+1 per rank")
	character.invalidate_stats()
	character.builds.notify(CLASS_ID)
	check_eq(character.get_stat(Stats.SKILL_DAMAGE), 3.0, "re-resolving never stacks")
	character.switch_class(&"basic_adventurer", true)
	check_eq(character.get_stat(Stats.SKILL_DAMAGE), 0.0, "other class: talent bonus gone")
	character.switch_class(CLASS_ID, true)
	check_eq(character.get_stat(Stats.SKILL_DAMAGE), 3.0, "back: bonus again")


func test_respec_costs_station_and_effect_removal() -> void:
	_set_level(30)
	character.inventory.add_item(&"gold_coin", 200)
	_learn(&"ta_1", 4)
	_learn(&"ta_1b")
	_learn(&"ta_2b")
	check(SkillBook.is_skill_available(character, CLASS_ID, &"t_nova"), "active talent unlocks t_nova")
	var build := character.builds.get_build()
	check(build.slot_of(&"t_nova") >= 0, "new skill auto-slotted")
	check_eq(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", SkillModDefinition.Slot.RESONANCE, &"r_focus", true), "", "talent-unlocked mod slotted")
	var level := character.classes.get_level(CLASS_ID)
	check(TalentService.respec(character, CLASS_ID, false) != "", "respec only at a class station")
	check_eq(TalentService.respec_cost(character, CLASS_ID), 0, "first respec is free")
	check_eq(TalentService.respec(character, CLASS_ID, true), "", "first respec")
	check(build.talents.is_empty(), "talents cleared")
	check_eq(build.slot_of(&"t_nova"), -1, "talent skill removed from its slot")
	check_eq(build.mod_of(&"t_bolt", SkillModDefinition.Slot.RESONANCE), &"", "talent mod removed")
	check(build.slot_of(&"t_bolt") >= 0, "level skill stays slotted")
	check_eq(character.get_stat(Stats.SKILL_DAMAGE), 0.0, "talent stats removed")
	check_eq(character.classes.get_level(CLASS_ID), level, "class level kept")
	check_eq(character.inventory.count(&"gold_coin"), 200, "nothing paid")
	_learn(&"ta_1")
	var cost := TalentService.respec_cost(character, CLASS_ID)
	check_eq(cost, db.rules.talent_rules().respec_cost(level), "second respec costs gold by level")
	check_eq(TalentService.respec(character, CLASS_ID, true), "", "second respec")
	check_eq(character.inventory.count(&"gold_coin"), 200 - cost, "gold paid")
	character.inventory.remove_quantity(&"gold_coin", character.inventory.count(&"gold_coin"))
	_learn(&"ta_1")
	check(TalentService.respec(character, CLASS_ID, true).contains("Gold"), "not enough gold")
	check_eq(build.rank(&"ta_1"), 1, "refused respec changes nothing")


func test_build_persists_and_sanitizes() -> void:
	_set_level(25)
	_learn(&"ta_1", 5)
	_learn(&"ta_2b")
	SkillBook.set_mod(character, CLASS_ID, &"t_bolt", SkillModDefinition.Slot.FORM, &"f_split", true)
	var data := character.to_dict()
	var warnings: PackedStringArray = []
	var restored := Character.from_dict(JSON.parse_string(JSON.stringify(data)), db, warnings)
	check_eq(restored.builds.get_build(CLASS_ID).to_dict(), character.builds.get_build(CLASS_ID).to_dict(), "identical build after roundtrip")
	check_eq(restored.get_stat(Stats.SKILL_DAMAGE), 5.0, "talent stats after load")
	check(warnings.is_empty(), "no warnings: %s" % [warnings])
	var tampered: Dictionary = JSON.parse_string(JSON.stringify(data))
	tampered.class_builds[String(CLASS_ID)].talents["ta_7"] = 1
	tampered.class_builds[String(CLASS_ID)].talents["ghost"] = 2
	warnings.clear()
	var repaired := Character.from_dict(tampered, db, warnings)
	check(repaired.builds.get_build(CLASS_ID).rank(&"ghost") == 0, "unknown talent removed")
	check(TalentService.validate_allocation(db, CLASS_ID, 25, repaired.builds.get_build(CLASS_ID).talents).is_empty(),
		"loaded allocation always valid")
	check(not warnings.is_empty(), "repairs reported")


## Talent Progression Fix 1.0: points are derived from the class level (never stored), so an
## existing v15 save gets exactly the new count on load - spent points kept, none twice, none lost.
func test_first_point_at_level_5_survives_saves_and_level_jumps() -> void:
	var path := "user://test_saves/talent_fix/slot_1.save.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_set_level(7)   # 3 points under the new rule (0 under the old one)
	check_eq(TalentService.points_total(character, CLASS_ID), 3, "level 7: three points")
	check_eq(_learn(&"ta_1", 2), "", "two points spent")
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var file := FileAccess.open(path, FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	check_eq(int(payload.get("version", 0)), 15, "a v15 save")
	check(not JSON.stringify(payload).contains("talent_points"), "no stored point counter in the save")
	for pass_index in 2:   # loading twice never adds a point
		var loaded := SaveSystem.load_from(path, db)
		if not check(loaded.ok() and loaded.warnings.is_empty(), "loads cleanly %s %s" % [loaded.errors, loaded.warnings]):
			return
		var restored := loaded.character
		check_eq(restored.classes.get_level(CLASS_ID), 7, "level kept")
		check_eq(restored.builds.get_build(CLASS_ID).rank(&"ta_1"), 2, "spent points kept")
		check_eq([TalentService.points_total(restored, CLASS_ID), TalentService.points_available(restored, CLASS_ID)], [3, 1], "3 points, 1 free (load %d)" % pass_index)
		check_eq(SaveSystem.save_to(restored, path), OK, "saved again")
	# a jump from level 3 straight past level 5 grants every point at once
	var jumper := CharacterFactory.create_new(db)
	jumper.classes.unlock(CLASS_ID)
	jumper.switch_class(CLASS_ID, true)
	var definition := db.get_class_def(CLASS_ID)
	var to_three := definition.xp_to_next(1) + definition.xp_to_next(2)
	jumper.classes.add_xp(CLASS_ID, to_three)
	check_eq([jumper.classes.get_level(CLASS_ID), TalentService.points_total(jumper, CLASS_ID)], [3, 0], "level 3: none")
	var to_nine := 0
	for l in range(3, 9):
		to_nine += definition.xp_to_next(l)
	jumper.classes.add_xp(CLASS_ID, to_nine)
	check_eq([jumper.classes.get_level(CLASS_ID), TalentService.points_total(jumper, CLASS_ID)], [9, 5], "jump 3 -> 9: five points")
	# several classes count their own level
	for class_id: StringName in [&"warrior", &"arcanist"]:
		jumper.classes.unlock(class_id)
	var warrior := db.get_class_def(&"warrior")
	var xp := 0
	for l in range(1, 5):
		xp += warrior.xp_to_next(l)
	jumper.classes.add_xp(&"warrior", xp - 1)
	check_eq([jumper.classes.get_level(&"warrior"), TalentService.points_total(jumper, &"warrior")], [4, 0], "warrior level 4: none")
	jumper.classes.add_xp(&"warrior", 1)
	check_eq([jumper.classes.get_level(&"warrior"), TalentService.points_total(jumper, &"warrior")], [5, 1], "warrior level 5: one")
	check_eq(TalentService.points_total(jumper, &"arcanist"), 0, "arcanist level 1: none")
	check_eq(TalentService.points_total(jumper, CLASS_ID), 5, "the test class keeps its own count")
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
