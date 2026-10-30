extends TestCase
## Talent Structure Rework 1.0 (docs/TALENT_STRUCTURE_REWORK_1_0.md) on the real
## data of the three playable classes: four tiers per tree (three tiers of four
## free choices + one capstone), gates 0 / 5 / 18 / 30 points in lower tiers of
## the same tree, prerequisites only for direct skill upgrades, and every build
## that was valid under the old seven-tier rules stays valid (no migration).

const CLASSES: Array[StringName] = [&"warrior", &"arcanist", &"shadowrunner"]
const SAVE := "user://test_saves/talent_structure/slot_1.save.json"
## The old rule (Class Foundation 0.2): seven tiers, 5 points per tier step.
const OLD_GATES: Array[int] = [0, 5, 10, 15, 20, 25, 30]

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _play(class_id: StringName, level: int) -> void:
	character.classes.unlock(class_id)
	character.switch_class(class_id, true)
	var definition := db.get_class_def(class_id)
	var needed := -character.classes.get_xp(class_id)
	for l in range(character.classes.get_level(class_id), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(class_id, needed)


## Old tier of a node, recovered from the deterministic rework mapping
## (old tier t -> new tier ceil(t / 2); old even tiers sit in columns 2 / 3).
static func _old_tier(node: TalentNodeDefinition) -> int:
	if node.is_capstone():
		return 7
	return node.tier * 2 - (1 if node.column < 2 else 0)


## validate_allocation under the OLD gates (prerequisites and ranks unchanged).
func _old_valid(class_id: StringName, talents: Dictionary) -> bool:
	var total := 0
	for node_id: StringName in talents:
		var node: TalentNodeDefinition = db.talent_nodes[node_id]
		var rank: int = talents[node_id]
		if rank <= 0:
			continue
		total += rank
		if rank > node.max_rank or node.class_id != class_id:
			return false
		for prerequisite in node.prerequisites:
			if talents.get(prerequisite, 0) <= 0:
				return false
		var below := 0
		for other: TalentNodeDefinition in db.talent_trees[node.tree_id].nodes:
			if _old_tier(other) < _old_tier(node):
				below += talents.get(other.id, 0)
		if below < OLD_GATES[_old_tier(node) - 1]:
			return false
	return total <= db.rules.talent_rules().points_at_level(60)


func test_rules_and_tree_shape() -> void:
	var rules := db.rules.talent_rules()
	check_eq(TalentRules.TIERS, 4, "four tiers")
	check_eq(Array(rules.tier_points), [0, 5, 18, 30], "gates 0 / 5 / 18 / 30")
	check_eq(rules.points_at_level(60), 56, "56 points at level 60 (unchanged)")
	check(2 * (rules.tier_requirement(4) + 1) > 56, "only one capstone per build")
	check(3 * (rules.tier_requirement(3) + 1) > 56, "tier 3 in at most two trees")
	check(3 * (rules.tier_requirement(2) + 1) <= 56, "tier 2 in all three trees")
	check(TalentService.validate_data(db).is_empty(), "talent data valid: %s" % [TalentService.validate_data(db)])
	for class_id in CLASSES:
		var trees := TalentService.trees_of(db, class_id)
		check_eq(trees.size(), 3, "%s: three specializations" % class_id)
		for tree in trees:
			check(tree.validate(rules).is_empty(), "%s valid: %s" % [tree.id, tree.validate(rules)])
			var per_tier := {}
			var columns := {}
			for node in tree.nodes:
				per_tier[node.tier] = per_tier.get(node.tier, 0) + 1
				var key := "%d:%d" % [node.tier, node.column]
				check(not columns.has(key), "%s: %s has its own place" % [tree.id, node.id])
				columns[key] = true
			check_eq(per_tier, {1: 4, 2: 4, 3: 4, 4: 1}, "%s: 4 / 4 / 4 + capstone" % tree.id)
			check_eq(tree.capstones().size(), 1, "%s: one capstone" % tree.id)


## Prerequisites are left only where a node directly upgrades the skill another
## node unlocks - never on capstones, never on passives.
func test_prerequisites_only_for_direct_upgrades() -> void:
	var count := 0
	for class_id in CLASSES:
		for tree in TalentService.trees_of(db, class_id):
			for node in tree.nodes:
				if node.prerequisites.is_empty():
					continue
				count += node.prerequisites.size()
				check(not node.is_capstone(), "%s: capstones need points only" % node.id)
				check_eq(node.kind, TalentNodeDefinition.Kind.TRANSFORMATIVE, "%s: only upgrades have a parent" % node.id)
				for prerequisite in node.prerequisites:
					var parent: TalentNodeDefinition = db.talent_nodes[prerequisite]
					check(parent.kind == TalentNodeDefinition.Kind.ACTIVE and parent.tree_id == node.tree_id, "%s upgrades the skill of %s" % [node.id, parent.id])
					check(node.skill_mods.any(func(mod: SkillModDefinition) -> bool: return mod.skill_ids.has(parent.unlocks_skill)),
						"%s changes %s" % [node.id, parent.unlocks_skill])
	check_eq(count, 6, "six upgrade links in 117 talents")


## Tier 1 is open from the first point; once 5 points are in a tree, every node of
## its tier 2 is a free choice - whichever tier 1 nodes the points went into.
func test_free_choice_inside_open_tiers() -> void:
	for class_id in CLASSES:
		character = CharacterFactory.create_new(db)
		_play(class_id, 5)
		check_eq(TalentService.points_available(character, class_id), 1, "%s level 5: one point" % class_id)
		for tree in TalentService.trees_of(db, class_id):
			for node in tree.nodes:
				var error := TalentService.can_learn(character, class_id, node.id)
				if node.tier == 1:
					check_eq(error, "", "%s: tier 1 open at the first point" % node.id)
				else:
					check(error != "", "%s: tier %d still closed" % [node.id, node.tier])
		_play(class_id, 60)
		for tree in TalentService.trees_of(db, class_id):
			var tier_1 := tree.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == 1)
			var backwards := tier_1.duplicate()
			backwards.reverse()
			for order: Array in [tier_1, backwards]:
				var talents := {}
				var spent := 0
				for node: TalentNodeDefinition in order:
					var ranks := mini(node.max_rank, 5 - spent)
					if ranks > 0:
						talents[node.id] = ranks
						spent += ranks
				for node in tree.nodes:
					if node.tier != 2 or not node.prerequisites.is_empty():
						continue
					var probe := talents.duplicate()
					probe[node.id] = 1
					check(TalentService.validate_allocation(db, class_id, 60, probe).is_empty(), "%s open via %s" % [node.id, talents.keys()])


func test_active_skills_upgrades_and_capstones() -> void:
	_play(&"warrior", 60)
	check_eq(TalentService.learn(character, &"warrior", &"war_b_whirlwind"), "", "Whirlwind: a tier 1 choice")
	check(SkillBook.is_skill_available(character, &"warrior", &"whirlwind"), "active skill unlocked")
	character.builds.get_build(&"warrior").talents = {&"war_b_seething": 5}
	character.builds.notify(&"warrior")
	var error := TalentService.can_learn(character, &"warrior", &"war_b_cyclone")
	check(error.contains("Whirlwind"), "tier 2 open, the upgrade still needs Whirlwind: %s" % error)
	check_eq(TalentService.can_learn(character, &"warrior", &"war_b_bloodlust"), "", "the rest of tier 2 is free")
	# capstone: 30 points in the tree's lower tiers, any mix
	var berserker: TalentTreeDefinition = db.talent_trees[&"war_berserker"]
	var talents := {}
	var spent := 0
	for node in berserker.nodes:
		if node.is_capstone() or not node.prerequisites.is_empty() or spent >= 29:
			continue
		var ranks := mini(node.max_rank, 29 - spent)
		talents[node.id] = ranks
		spent += ranks
	talents[&"war_b_unbound"] = 1
	check(Array(TalentService.validate_allocation(db, &"warrior", 60, talents)).any(func(e: String) -> bool: return e.contains("30 points")), "29 points: capstone locked")
	talents[&"war_b_bloodrush"] = 1
	check_eq(TalentService.validate_allocation(db, &"warrior", 60, talents), PackedStringArray(), "30 points: capstone open")
	# a transformation capstone of another tree
	var warbreaker := {&"war_wb_hands": 5, &"war_wb_skin": 3, &"war_wb_finish": 3, &"war_wb_earthshaker": 1,
		&"war_wb_breaker": 5, &"war_wb_will": 5, &"war_wb_overpower": 3, &"war_wb_bulwark": 5, &"war_wb_worldbreaker": 1}
	check_eq(TalentService.validate_allocation(db, &"warrior", 60, warbreaker), PackedStringArray(), "Worldbreaker over a mostly passive mix")
	check(db.talent_nodes[&"war_wb_worldbreaker"].kind == TalentNodeDefinition.Kind.TRANSFORMATIVE, "Worldbreaker stays a transformation")
	var both := warbreaker.duplicate()
	both.merge(talents)
	check(Array(TalentService.validate_allocation(db, &"warrior", 60, both)).any(func(e: String) -> bool: return e.contains("available")), "two capstones never fit")


## No migration: every allocation the old seven-tier rules allowed is valid
## under the new rules (random old builds, fixed seed), and so are the trials.
func test_old_builds_stay_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261029
	var checked := 0
	for class_id in CLASSES:
		var nodes: Array = []
		for tree in TalentService.trees_of(db, class_id):
			nodes.append_array(tree.nodes)
		for build_index in 150:
			var talents := {}
			var budget := rng.randi_range(1, 56)
			var stuck := 0
			while budget > 0 and stuck < 200:
				var node: TalentNodeDefinition = nodes[rng.randi() % nodes.size()]
				# deep builds: mostly one tree, like players chasing a capstone
				if build_index % 2 == 0 and node.tree_id != nodes[0].tree_id and rng.randf() < 0.85:
					stuck += 1
					continue
				var probe := talents.duplicate()
				probe[node.id] = probe.get(node.id, 0) + 1
				if _old_valid(class_id, probe):
					talents = probe
					budget -= 1
				else:
					stuck += 1
			var errors := TalentService.validate_allocation(db, class_id, 60, talents)
			checked += 1
			if not errors.is_empty():
				fail("%s old build %s invalid now: %s" % [class_id, talents, errors])
				return
	check_eq(checked, 450, "450 old builds checked")
	# the old rail to a capstone (everything below, tier by tier) is still fine
	for class_id in CLASSES:
		for tree in TalentService.trees_of(db, class_id):
			var full := {}
			for node in tree.nodes:
				full[node.id] = node.max_rank
			check(_old_valid(class_id, full), "%s: the full tree was an old build" % tree.id)
			check_eq(TalentService.validate_allocation(db, class_id, 60, full), PackedStringArray(), "%s: full tree" % tree.id)
	for trial: TrialDefinition in db.trials.values():
		var build := trial.make_build(db.rules.talent_rules().skill_slots)
		check(TalentService.validate_allocation(db, trial.class_id, trial.trial_level, build.talents).is_empty(), "trial %s talents valid" % trial.id)


## Save v15 unchanged: an allocation in the old layout loads without warnings;
## points, respec and class switching behave as before.
func test_save_load_respec_and_class_switch() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	_play(&"arcanist", 40)   # 36 points
	_play(&"shadowrunner", 30)   # 26 points
	# an old-style rail build (old tiers 1-5 of Runemaster) and a wide build
	var arcanist := {&"arc_rm_inscribed": 5, &"arc_rm_lore": 1, &"arc_rm_resonant": 3, &"arc_rm_rift": 1, &"arc_rm_detonation": 5,
		&"arc_rm_binding": 1, &"arc_rm_flow": 5, &"arc_rm_echo": 1, &"arc_rm_grandrift": 1, &"arc_ew_focus": 3, &"arc_as_studious": 1}
	check(_old_valid(&"arcanist", arcanist), "a build the old rules allowed")
	var shadow := {&"sr_as_eye": 3, &"sr_as_cold": 2, &"sr_bs_fan": 1, &"sr_bs_hands": 5, &"sr_bs_knives": 1, &"sr_nh_smoke": 1, &"sr_nh_feet": 3, &"sr_nh_ambush": 1}
	check(not _old_valid(&"shadowrunner", shadow), "a wide build the old rules refused (Fan of Knives with 6 points below)")
	for entry: Array in [[&"arcanist", arcanist], [&"shadowrunner", shadow]]:
		check_eq(TalentService.validate_allocation(db, entry[0], character.classes.get_level(entry[0]), entry[1]), PackedStringArray(), "%s build valid" % entry[0])
		character.builds.get_build(entry[0]).talents = (entry[1] as Dictionary).duplicate()
		SkillBook.auto_fill(character, entry[0])
		character.builds.notify(entry[0])
	check(SkillBook.is_skill_available(character, &"shadowrunner", &"blade_fan"), "Blade Fan from the build")
	var free := {&"arcanist": TalentService.points_available(character, &"arcanist"), &"shadowrunner": TalentService.points_available(character, &"shadowrunner")}
	check_eq(free, {&"arcanist": 9, &"shadowrunner": 9}, "free points: 36 - 27, 26 - 17")
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var file := FileAccess.open(SAVE, FileAccess.READ)
	check_eq(int((JSON.parse_string(file.get_as_text()) as Dictionary).get("version", 0)), SaveSystem.VERSION, "current save version")
	file.close()
	check_eq(SaveSystem.VERSION, 15, "save version unchanged (v15)")
	var loaded := SaveSystem.load_from(SAVE, db)
	if not check(loaded.ok() and loaded.warnings.is_empty(), "loads cleanly: %s %s" % [loaded.errors, loaded.warnings]):
		return
	var restored := loaded.character
	for class_id: StringName in [&"arcanist", &"shadowrunner"]:
		check_eq(restored.builds.get_build(class_id).talents, character.builds.get_build(class_id).talents, "%s talents identical after load" % class_id)
		check_eq(TalentService.points_available(restored, class_id), free[class_id], "%s free points after load" % class_id)
	check_eq(restored.classes.active_class_id, &"shadowrunner", "active class kept")
	check_eq(restored.switch_class(&"arcanist", true), "", "class switch at a safe place")
	check_eq(restored.builds.get_build(&"arcanist").talents, arcanist, "the other class keeps its talents")
	check_eq(TalentService.points_available(restored, &"arcanist"), 9, "and its points")
	check_eq(TalentService.respec(restored, &"arcanist", true), "", "respec (first one free)")
	check(restored.builds.get_build(&"arcanist").talents.is_empty(), "talents cleared")
	check_eq(TalentService.points_available(restored, &"arcanist"), 36, "all 36 points back")
	check(not SkillBook.is_skill_available(restored, &"arcanist", &"arcane_rift"), "talent skill gone after respec")
	check_eq(restored.builds.get_build(&"shadowrunner").talents, shadow, "respec touches one class only")
	check_eq(TalentService.learn(restored, &"arcanist", &"arc_as_lance"), "", "after respec: tier 1 active again at once")
