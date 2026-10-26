extends GameplayTestCase
## Class Foundation C: Warrior vertical slice with the real data - rage and
## Combat Pressure, skill costs, passive/active/transformative talents, bleeding
## synergies, the Worldbreaker heavy finisher, weapon switching, respec, save/load.

const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const SAVE := "user://test_saves/warrior.save.json"
const S := EquipSlot.Slot

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var dispatched: Array[HitData] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	bridge.rng.seed = 7
	bridge.stat_modifier.rng.seed = 7
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void: dispatched.append(hit))


func _level(level: int) -> void:
	var definition := db.get_class_def(&"warrior")
	var needed := -character.classes.get_xp(&"warrior")
	for l in range(character.classes.get_level(&"warrior"), level):
		needed += definition.xp_to_next(l)
	character.classes.add_xp(&"warrior", needed)


## Sets a complete, validated talent allocation.
func _talents(talents: Dictionary) -> void:
	var errors := TalentService.validate_allocation(db, &"warrior", character.classes.get_level(&"warrior"), talents)
	check(errors.is_empty(), "test allocation valid: %s" % [errors])
	var build := character.builds.get_build(&"warrior")
	build.talents = talents.duplicate()
	SkillBook.auto_fill(character, &"warrior")
	character.builds.notify(&"warrior")


## 5 points in each lower tier of `tree` (first node of each tier, up to `below`).
func _fill(tree_id: StringName, below: int) -> Dictionary:
	var result := {}
	var tree: TalentTreeDefinition = db.talent_trees[tree_id]
	var needed := db.rules.talent_rules().tier_requirement(below)
	var spent := 0
	for tier in range(1, below):
		for node in tree.nodes:
			if node.tier == tier and spent < needed and node.prerequisites.is_empty():
				var ranks := mini(node.max_rank, needed - spent)
				result[node.id] = ranks
				spent += ranks
	return result


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _press(slot: int) -> InputFrame:
	var f := frame()
	f.ability_slot = slot
	return f


func _slot(skill_id: StringName, index: int) -> void:
	check_eq(SkillBook.assign_slot(character, &"warrior", index, skill_id, true), "", "slot %s" % skill_id)


func test_warrior_data() -> void:
	check(db.load_errors.is_empty(), "data loads: %s" % [db.load_errors])
	var definition := db.get_class_def(&"warrior")
	check_eq(definition.talent_tree_ids.size(), 3, "three trees")
	var skills := db.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == &"warrior")
	check(skills.size() >= 6, "at least six warrior skills (%d)" % skills.size())
	var kinds := {}
	for tree_id in definition.talent_tree_ids:
		var tree: TalentTreeDefinition = db.talent_trees[tree_id]
		check(tree.validate(db.rules.talent_rules()).is_empty(), "%s valid" % tree_id)
		for node in tree.nodes:
			kinds[node.kind] = true
			check(not node.stat_modifiers.is_empty() or not node.effects.is_empty() or node.unlocks_skill != &"" \
				or not node.skill_mods.is_empty() or not node.unlocks_mods.is_empty(), "%s has a real effect" % node.id)
	check_eq(kinds.size(), 3, "passive, active and transformative talents")
	check_eq(definition.max_level, 60, "level cap 60")


func test_rage_builds_with_pressure_and_pays_for_skills() -> void:
	_bind()
	_dummy(Vector2(22, 0))
	await wait_physics(2)
	var rage := bridge.class_runtime.pool
	check_eq(rage.definition.id, &"rage", "warrior uses rage")
	await tick(_press(0))
	check(bridge.class_runtime.cooldown_left(&"furious_strike") == 0.0, "no rage: Furious Strike refused")
	var f := frame()
	for i in 3:
		await tick(light(f))
		await tick(f, 14)
	# 8 + 8 * 1.1 + (8 + 6 finisher) * 1.2 = 33.6
	check_near(rage.value, 8.0 + 8.8 + 14.0 * 1.2, 0.5, "rage from hits, finisher bonus and Combat Pressure")
	check_eq(bridge.class_runtime.pressure, 3, "three pressure stacks")
	await tick(f, 20)
	var before := rage.value
	await tick(_press(0))
	await tick(f, 10)
	check(bridge.class_runtime.cooldown_left(&"furious_strike") > 0.0, "Furious Strike cast")
	# 25 spent; the strike breaks the dummy's poise: +10 rage x 1.3 (3 pressure stacks)
	check_near(rage.value, before - 25.0 + 13.0, 0.5, "25 rage spent, poise break refunds 13")
	var strike := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"furious_strike")
	check_eq(strike.size(), 1, "Furious Strike hit the dummy")


func test_berserker_talents_change_combat() -> void:
	_level(20)
	_bind()
	_talents({&"war_b_seething": 5, &"war_b_relentless": 3, &"war_b_temper": 1, &"war_b_whirlwind": 1})
	check_near(player.combat.attack_speed, 1.10, 0.0001, "Seething Blood: +10% attack speed in combat")
	check(SkillBook.is_skill_available(character, &"warrior", &"whirlwind"), "active talent unlocks Whirlwind")
	_dummy(Vector2(22, 0))
	await wait_physics(2)
	var f := frame()
	await tick(light(f))
	await tick(f, 20)
	var calm: float = dispatched[0].damage
	bridge.class_runtime.pool.gain(100.0)
	await tick(f, 20)
	await tick(light(f))
	await tick(f, 20)
	check_near(dispatched[1].damage, calm * 1.12, 0.01, "Relentless: +12% at high rage")
	_slot(&"whirlwind", 1)
	dispatched.clear()
	await tick(_press(1))
	await tick(f, 90)
	var spins := dispatched.filter(func(h: HitData) -> bool: return h.skill_id == &"whirlwind")
	check_eq(spins.size(), 4, "Whirlwind hits a target four times")


func test_transformation_furious_cleave_hits_behind() -> void:
	_level(40)
	_bind()
	var talents := _fill(&"war_berserker", 5)
	talents[&"war_b_cleave"] = 1
	_talents(talents)
	bridge.class_runtime.pool.gain(100.0)
	var behind := _dummy(Vector2(-24, 0))
	await wait_physics(2)
	await tick(_press(0))
	await tick(frame(), 10)
	check(dispatched.any(func(h: HitData) -> bool: return h.skill_id == &"furious_strike" and h.target == behind),
		"Furious Cleave hits a target behind the warrior")


func test_bloodblade_bleeding_and_blood_oath() -> void:
	_level(60)
	_bind()
	var talents := _fill(&"war_bloodblade", 7)
	talents[&"war_bb_hemorrhage"] = 3
	talents[&"war_bb_oath"] = 1
	_talents(talents)
	var dummy := _dummy(Vector2(22, 0))
	await wait_physics(2)
	var status := StatusComponent.of(dummy)
	var f := frame()
	for i in 3:
		await tick(light(f))
		await tick(f, 14)
	check(status.stacks(&"bleeding") >= 3, "Hemorrhage: the finisher applied 3 bleeding stacks (%d)" % status.stacks(&"bleeding"))
	player.health.health = 50.0
	await tick(f, 40)
	check(player.health.health > 50.0, "Blood Oath: bleeding heals the warrior")
	for i in 3:
		await tick(light(f))
		await tick(f, 14)
	check(dispatched.any(func(h: HitData) -> bool: return &"rupture_bleeding" in h.tags and h.source == HitData.Source.TRIGGERED),
		"Blood Oath: finisher ruptures 3+ bleeding stacks")


func test_worldbreaker_heavy_finisher() -> void:
	_level(60)
	_bind()
	var talents := _fill(&"war_warbreaker", 7)
	talents[&"war_wb_worldbreaker"] = 1
	_talents(talents)
	var target := _dummy(Vector2(26, 0))
	var bystander := _dummy(Vector2(78, 0))   # beyond the crush reach, inside the quake radius
	await wait_physics(2)
	var f := frame()
	await tick(light(f))
	await tick(f, 14)
	await tick(light(f))
	await tick(f, 14)
	await tick(heavy_down(f))
	await tick(f, seconds_to_ticks(0.8))
	await tick(heavy_up(f))
	await tick(f, 40)
	var crush := dispatched.filter(func(h: HitData) -> bool: return h.target == target and h.attack != null and h.attack.id == &"sword_llh_crush")
	check_eq(crush.size(), 1, "full-charge L-L-H finisher landed")
	if not crush.is_empty():
		check(&"worldbreaker" in crush[0].tags, "Worldbreaker boosts the finisher's poise")
	check(dispatched.any(func(h: HitData) -> bool: return h.target == bystander and &"war_worldbreaker" in h.tags),
		"Worldbreaker quake hits the bystander")


func test_weapon_switch_keeps_skills_working() -> void:
	_bind()
	var great := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"steel_greatsword")[0] as ItemInstance
	check_eq(character.equipment.equip(great.instance_id, S.MAIN_HAND), "", "greatsword equipped")
	await wait_physics(3)
	check_eq(player.combat.weapon.id, &"two_handed_sword", "combat weapon follows")
	_dummy(Vector2(24, 0))
	bridge.class_runtime.pool.gain(50.0)
	await wait_physics(2)
	await tick(_press(0))
	await tick(frame(), 10)
	check(dispatched.any(func(h: HitData) -> bool: return h.skill_id == &"furious_strike"), "skill works with the greatsword")


func test_respec_and_save_load_roundtrip() -> void:
	_level(30)
	_talents(_fill(&"war_warbreaker", 5))
	_slot(&"warbreaker", 2)
	SkillBook.set_mod(character, &"warrior", &"furious_strike", SkillModDefinition.Slot.FORM, &"furious_wide_arc", true)
	var health := character.get_stat(Stats.MAX_HEALTH)
	var session_path := SAVE
	check_eq(SaveSystem.save_to(character, session_path), OK, "saved")
	var loaded := SaveSystem.load_from(session_path, db)
	check(loaded.ok(), "loaded")
	var restored := loaded.character
	check_eq(restored.builds.get_build(&"warrior").to_dict(), character.builds.get_build(&"warrior").to_dict(), "build identical")
	check_eq(restored.get_stat(Stats.MAX_HEALTH), health, "talent stats identical")
	check_eq(TalentService.respec(restored, &"warrior", true), "", "free first respec")
	check(restored.get_stat(Stats.ARMOR) < character.get_stat(Stats.ARMOR), "Thick Skin armor removed by the respec")
	check_eq(restored.classes.get_level(&"warrior"), 30, "level kept")
	check_eq(restored.mastery.to_dict(), character.mastery.to_dict(), "mastery kept")
