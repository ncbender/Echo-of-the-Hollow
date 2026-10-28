extends TestCase
## Grove Warden Rare Reward R1 (docs/GROVE_WARDEN_RARE_R1.md): the reward source table
## (twelve models, Rare, item level 20, T5 75 / T4 25), the eligibility of every model,
## Keen on head/chest/shield and the open Thundering finding. Data and roller only: no boss,
## no claim, no inventory grant. Fixed seeds; reachability is proven by exhaustive search,
## not by hoping a roll shows four affixes.

const R := ItemDefinition.Rarity
const REWARD := "res://data/loot/grove_warden_rare_reward.tres"
const GRUNT_LOOT := "res://data/loot/hollow_grunt_equipment.tres"
const WOLF_LOOT := "res://data/loot/hollowwood_wolves_equipment.tres"
const WEAPONS := [&"iron_sword", &"steel_greatsword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear",
	&"oak_staff", &"oak_wand", &"hunting_bow"]
const ARMOUR := [&"leather_cap", &"wanderer_coat", &"oak_shield"]
const ARMOUR_AFFIXES := [&"furious", &"guarded", &"keen", &"vital"]
## D_weapon at item level 20 = base x (1 + 0.012 x 19) (Weapon Base Damage 1.2), unchanged by R1.
const BASE_AT_20 := {
	&"iron_sword": 14.736, &"steel_greatsword": 27.016, &"iron_axe": 17.192, &"iron_dagger": 11.052,
	&"iron_mace": 18.42, &"ash_spear": 15.964, &"oak_staff": 15.964, &"oak_wand": 12.28, &"hunting_bow": 15.964,
}

var db: GameDatabase
var table: EquipmentLootTable


func before_each() -> void:
	db = GameDatabase.get_default()
	table = load(REWARD) as EquipmentLootTable


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _models() -> Array:
	return WEAPONS + ARMOUR


## Smallest number of affixes at which some legal roll order runs dry (capped at `limit`):
## every eligible identity with a configured tier is tried at every depth, so a result of
## `limit` proves that no RNG outcome can end below `limit` affixes.
func _dead_end(definition: ItemDefinition, present: Array[Dictionary], limit: int) -> int:
	if present.size() >= limit:
		return limit
	var smallest := limit
	var any := false
	for affix in AffixRoller.eligible(definition, table.source_level, present, db, definition.generation_affixes, true):
		var tiers := AffixRoller.tier_options(affix, table.source_level, table.tier_weights)
		if tiers.is_empty():
			continue
		any = true
		var next := present.duplicate()
		next.append(affix.roll(tiers[0].tier, _rng(1)))
		smallest = mini(smallest, _dead_end(definition, next, limit))
	return smallest if any else present.size()


func _cap_with(affix_ids: Array, flat_overrides: Dictionary = {}) -> ItemInstance:
	var item := ItemCreation.create(db.get_item(&"leather_cap"), 1, db, 20)
	for affix_id: StringName in affix_ids:
		var affix: AffixDefinition = db.affixes[affix_id]
		var entry := affix.roll(affix.get_tier(5), _rng(3))
		if flat_overrides.has(affix_id):
			entry.flat = flat_overrides[affix_id]
		item.affixes.append(entry)
	return item


## Empties the target slot first (the starter gear already holds a cap), so a measured
## difference is exactly this item's contribution.
func _wear(character: Character, item: ItemInstance, measure: Callable = Callable()) -> String:
	if character.inventory.add_instance(item) != "":
		return "no room"
	var slot := character.equipment.quick_slot(item)
	if slot < 0:
		return "no fitting slot"
	if character.equipment.get_item(slot) != null:
		character.equipment.unequip(slot)
	if measure.is_valid():
		measure.call()
	return character.equipment.equip(item.instance_id, slot)


func _stat_delta(character: Character, item: ItemInstance, stat: StringName) -> float:
	var before := {}
	var error := _wear(character, item, func() -> void: before.merge(character.get_stats()))
	if error != "":
		fail("%s not equipped: %s" % [item.definition_id, error])
	return character.get_stats().get(stat, 0.0) - before.get(stat, 0.0)


# --- 1-5: the source table ------------------------------------------------------------------------

func test_reward_table_holds_the_approved_parameters() -> void:
	check(table.validate(db).is_empty(), "reward table valid: %s" % [table.validate(db)])
	check_eq(table.id, &"grove_warden_rare_reward", "own source id")
	var models: Array[StringName] = []
	models.assign(_models())
	check_eq(table.item_ids, models, "exactly the twelve models")
	var unique := {}
	for item_id in table.item_ids:
		unique[item_id] = true
	check_eq(unique.size(), 12, "twelve distinct models, each listed once (equal weight)")
	check_near(table.chance, 1.0, 0.0, "guaranteed roll")
	check_eq(table.rarity_weights, {2: 100.0}, "Rare only")
	check_eq([table.source_level, table.level_spread], [20, 0], "item level exactly 20")
	check_eq(table.tier_weights.weights_for(20), {4: 25.0, 5: 75.0}, "T5 75 / T4 25 at item level 20")
	check(table.tier_weights.validate().is_empty(), "tier table valid")
	for level: int in [19, 21]:
		check(not table.tier_weights.covers(level), "no other item level configured (%d)" % level)


func test_rolls_are_rare_level_20_and_spread_evenly() -> void:
	var rng := _rng(2020)
	var by_model := {}
	var draws := 2400
	for i in draws:
		var item := EquipmentLoot.roll(table, db, rng)
		if item == null or item.rarity != R.RARE or item.item_level != 20 or item.origin != ItemInstance.ORIGIN_FOUND:
			fail("roll %d: Rare item level 20 expected, got %s" % [i, item.to_dict() if item != null else null])
			return
		by_model[item.definition_id] = by_model.get(item.definition_id, 0) + 1
	check_eq(by_model.size(), 12, "all twelve models reachable (%s)" % by_model)
	for model: StringName in _models():
		# sigma = sqrt(1/12 x 11/12 / 2400) = 0.0056 -> 3.5 sigma
		check_near(by_model.get(model, 0) / float(draws), 1.0 / 12.0, 0.02, "%s about 1/12" % model)


func test_every_eligible_affix_draws_only_t5_and_t4_at_75_25() -> void:
	for model: StringName in _models():
		var definition := db.get_item(model)
		var present: Array[Dictionary] = []
		for affix in AffixRoller.eligible(definition, 20, present, db, definition.generation_affixes, true):
			var options := AffixRoller.tier_options(affix, 20, table.tier_weights)
			var weights := {}
			for option in options:
				weights[option.tier.tier] = option.weight
			if weights != {4: 25.0, 5: 75.0}:
				fail("%s / %s: tiers %s instead of T5 75 / T4 25" % [model, affix.id, weights])
				return
	var rng := _rng(77)
	var tiers := {}
	var total := 0
	for i in 1200:
		for entry in EquipmentLoot.roll(table, db, rng).affixes:
			tiers[int(entry.tier)] = tiers.get(int(entry.tier), 0) + 1
			total += 1
	check_eq(tiers.keys().size(), 2, "only T5 and T4 rolled (%s)" % tiers)
	check_near(tiers.get(4, 0) / float(total), 0.25, 0.03, "T4 share 25 %")


# --- 6-10: eligibility per model --------------------------------------------------------------------

func test_every_model_reaches_three_and_four_without_shortfall() -> void:
	for model: StringName in _models():
		var definition := db.get_item(model)
		var empty: Array[Dictionary] = []
		check_eq(_dead_end(definition, empty, 4), 4, "%s: every legal roll order reaches four affixes" % model)
	var rng := _rng(4242)
	for model: StringName in _models():
		var definition := db.get_item(model)
		var counts := {}
		for i in 60:
			var result := ItemCreation.generate(definition, R.RARE, db, rng, table.tier_weights, 20, ItemInstance.ORIGIN_FOUND)
			if not result.ok() or result.shortfall != 0:
				fail("%s: refused or shortfall (%s %s)" % [model, result.error, result.note])
				return
			counts[result.item.affixes.size()] = counts.get(result.item.affixes.size(), 0) + 1
		check_eq(counts.keys().size(), 2, "%s: Rare rolls 3 and 4 affixes (%s)" % [model, counts])


func test_armour_pool_is_exactly_the_four_global_affixes() -> void:
	for model: StringName in ARMOUR:
		var definition := db.get_item(model)
		var present: Array[Dictionary] = []
		var ids: Array = []
		for affix in AffixRoller.eligible(definition, 20, present, db, definition.generation_affixes, true):
			ids.append(String(affix.id))
			check_eq(affix.scope, AffixDefinition.Scope.GLOBAL, "%s: %s is GLOBAL" % [model, affix.id])
		ids.sort()
		check_eq(ids, ["furious", "guarded", "keen", "vital"], "%s: furious, guarded, keen, vital" % model)


func test_rolls_have_no_duplicates_exclusions_or_essences() -> void:
	var rng := _rng(99)
	for i in 1500:
		var item := EquipmentLoot.roll(table, db, rng)
		var definition := db.get_item(item.definition_id)
		var seen := {}
		for entry in item.affixes:
			var affix: AffixDefinition = db.affixes.get(StringName(str(entry.affix)))
			if affix == null or not affix.rollable or not affix.id in definition.generation_affixes or not affix.allows_slot(definition.slot_kind):
				fail("%s: affix %s not allowed" % [item.definition_id, entry.affix])
				return
			if seen.has("g:%s" % affix.group) or (affix.exclusion_group != &"" and seen.has("x:%s" % affix.exclusion_group)):
				fail("%s: duplicate or excluded combination %s" % [item.definition_id, item.affixes])
				return
			seen["g:%s" % affix.group] = true
			if affix.exclusion_group != &"":
				seen["x:%s" % affix.exclusion_group] = true
		if not item.essences.is_empty() or not item.sockets.is_empty():
			fail("%s: essences or sockets invented" % item.definition_id)
			return
	for model: StringName in _models():
		var definition := db.get_item(model)
		var slots := definition.crafting.essence_slots if definition.crafting != null else 0
		check_eq(slots, 0, "%s has no monster essence slot" % model)


# --- 11-15: Keen and the other global affixes on head, chest and shield ---------------------------

func test_keen_works_on_cap_coat_and_shield_independent_of_the_weapon() -> void:
	var keen: AffixDefinition = db.affixes[&"keen"]
	for kind: int in [ItemDefinition.SlotKind.HEAD, ItemDefinition.SlotKind.CHEST, ItemDefinition.SlotKind.SHIELD]:
		check(keen.allows_slot(kind), "keen allowed on slot kind %d" % kind)
	check_eq(keen.scope, AffixDefinition.Scope.GLOBAL, "keen stays GLOBAL")
	for model: StringName in ARMOUR:
		var character := CharacterFactory.create_new(db)
		character.classes.unlock(&"warrior")   # the shield needs a shield class
		check_eq(character.switch_class(&"warrior", true), "", "warrior active")
		var item := ItemCreation.create(db.get_item(model), 1, db, 20)
		var entry := keen.roll(keen.get_tier(4), _rng(5))
		item.affixes.append(entry)
		check_near(_stat_delta(character, item, Stats.CRIT_CHANCE), entry.flat, 0.0001, "%s: keen +%s crit chance" % [model, entry.flat])
		var unarmed: float = character.get_stats().get(Stats.CRIT_CHANCE, 0.0)
		var weapon: ItemInstance = character.inventory.add_item(&"iron_dagger", 1)[0]
		check_eq(character.equipment.equip(weapon.instance_id), "", "%s: dagger equipped" % model)
		check_near(character.get_stats().get(Stats.CRIT_CHANCE, 0.0), unarmed, 0.0001, "%s: same crit with a weapon of another family" % model)


func test_keen_on_armour_reaches_the_hit_through_the_stat_modifier() -> void:
	# Synthetic flat 100 on a worn cap: every hit must crit through CharacterStatModifier.
	var character := CharacterFactory.create_new(db)
	check_eq(_wear(character, _cap_with([&"keen"], {&"keen": 100.0})), "", "cap equipped")
	var modifier := CharacterStatModifier.new()
	modifier.stats = character.get_stats()
	modifier.rng = _rng(6)
	for i in 20:
		var hit := HitData.new()
		hit.damage = 10.0
		modifier.modify_hit(hit)
		if not &"crit" in hit.tags or not is_equal_approx(hit.damage, 10.0 * (Stats.CRIT_MULTIPLIER + character.get_stats().get(Stats.CRIT_DAMAGE, 0.0) / 100.0)):
			fail("hit %d did not crit from the cap's keen" % i)
			return


func test_other_global_affixes_keep_their_effect() -> void:
	var character := CharacterFactory.create_new(db)
	var item := _cap_with(ARMOUR_AFFIXES)
	var expected := {}
	for entry in item.affixes:
		expected[StringName(str(entry.stat))] = float(entry.flat)
	var before := {}
	check_eq(_wear(character, item, func() -> void: before.merge(character.get_stats())), "", "cap equipped")
	var after := character.get_stats()
	for stat: StringName in [Stats.RESOURCE_GAIN, Stats.MAX_HEALTH, Stats.CRIT_CHANCE]:
		check_near(after.get(stat, 0.0) - before.get(stat, 0.0), expected[stat], 0.0001, "%s from its affix" % stat)
	check_near(after[Stats.ARMOR] - before.get(Stats.ARMOR, 0.0), expected[Stats.ARMOR] + 3.0, 0.0001, "armor: guarded + cap base 3")


func test_armored_stays_disabled() -> void:
	var armored: AffixDefinition = db.affixes[&"armored"]
	check(not armored.rollable, "armored not rollable")
	check_eq(armored.scope, AffixDefinition.Scope.LOCAL, "armored stays LOCAL")
	check(not armored.allows_slot(ItemDefinition.SlotKind.SHIELD), "never on the shield")
	for model: StringName in _models():
		check(not &"armored" in db.get_item(model).generation_affixes, "%s pool without armored" % model)


# --- 16-19: no side effects beyond the intended Keen opening ------------------------------------

func test_weapon_base_damage_formula_unchanged() -> void:
	var rng := _rng(16)
	for model: StringName in WEAPONS:
		var definition := db.get_item(model)
		check_near(WeaponDamage.base_for_level(definition, 20, db), BASE_AT_20[model], 0.0001, "%s base at item level 20" % model)
		var item := ItemCreation.generate(definition, R.RARE, db, rng, table.tier_weights, 20).item
		check_near(item.base_weapon_damage, BASE_AT_20[model], 0.0001, "%s: stored instance base" % model)


func test_grunt_and_wolf_tables_unchanged() -> void:
	var grunt := load(GRUNT_LOOT) as EquipmentLootTable
	check_eq([grunt.chance, grunt.rarity_weights, grunt.source_level, grunt.level_spread], [0.07, {0: 75.0, 1: 25.0}, 5, 2], "grunt table")
	check_eq(grunt.item_ids, [&"iron_sword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear", &"leather_cap", &"wanderer_coat"] as Array[StringName], "grunt models")
	var wolves := load(WOLF_LOOT) as EquipmentLootTable
	check_eq([wolves.chance, wolves.rarity_weights, wolves.source_level, wolves.level_spread], [0.15, {0: 60.0, 1: 40.0}, 10, 2], "wolf table")
	check_eq(wolves.item_ids, [&"steel_greatsword", &"oak_staff", &"oak_wand", &"hunting_bow", &"oak_shield"] as Array[StringName], "wolf models")
	check_eq(grunt.tier_weights.resource_path, "res://data/loot/hollowwood_early_tiers.tres", "regular tier table untouched")


func test_regular_armour_drops_can_now_roll_keen() -> void:
	var early := load("res://data/loot/hollowwood_early_tiers.tres") as AffixTierWeights
	var present: Array[Dictionary] = []
	for model: StringName in ARMOUR:
		var definition := db.get_item(model)
		for level: int in [3, 12]:
			var ids: Array = []
			for affix in AffixRoller.eligible(definition, level, present, db, definition.generation_affixes, true):
				ids.append(affix.id)
			check(&"keen" in ids, "%s item level %d: keen eligible for regular drops" % [model, level])
	var rng := _rng(18)
	var seen := 0
	var grunt := (load(GRUNT_LOOT) as EquipmentLootTable).duplicate() as EquipmentLootTable
	grunt.chance = 1.0
	for i in 600:
		var item := EquipmentLoot.roll(grunt, db, rng)
		if item.definition_id in ARMOUR:
			for entry in item.affixes:
				seen += 1 if entry.affix == "keen" else 0
	check(seen > 0, "regular grunt armour drops roll keen (%d)" % seen)
	check_near(db.affixes[&"keen"].weight, 100.0, 0.0, "keen weight unchanged")


func test_old_instances_stay_unchanged() -> void:
	var saved := {"id": "old_cap", "def": "leather_cap", "qty": 1, "rarity": 1, "ilvl": 5,
		"affixes": [{"affix": "guarded", "tier": 5, "tier_model": 5, "stat": "armor", "flat": 3.0, "percent": 0.0},
			{"affix": "vital", "tier": 5, "tier_model": 5, "stat": "max_health", "flat": 6.0, "percent": 0.0}]}
	var item := ItemInstance.from_dict(saved)
	check_eq(item.affixes.size(), 2, "no affix added on load")
	check_eq(item.to_dict().affixes, ItemInstance.from_dict(item.to_dict()).to_dict().affixes, "round trip unchanged")
	var stats := ItemStats.modifiers(item, db.get_item(&"leather_cap"), db)
	var crit := 0.0
	for modifier in stats:
		crit += modifier.flat if modifier.stat == Stats.CRIT_CHANCE else 0.0
	check_near(crit, 0.0, 0.0, "an old cap without keen gives no crit")


# --- 20: the open Thundering finding ----------------------------------------------------------------

func test_thundering_rolls_on_all_nine_weapons_without_a_shock_source() -> void:
	# Open gameplay eligibility blocker (docs/GROVE_WARDEN_RARE_R1.md §6): shock_damage is only read
	# by EssenceDischargeEffect (storm wolf essence), essences only sit on weapons with essence slots,
	# and there is exactly one weapon slot - so Thundering on these nine models never acts.
	var present: Array[Dictionary] = []
	for model: StringName in WEAPONS:
		var definition := db.get_item(model)
		var ids: Array = []
		for affix in AffixRoller.eligible(definition, 20, present, db, definition.generation_affixes, true):
			ids.append(affix.id)
		check(&"thundering" in ids, "%s: thundering eligible in the reward pool" % model)
		var item := ItemCreation.create(definition, 1, db, 20)
		item.affixes.append(db.affixes[&"thundering"].roll(db.affixes[&"thundering"].get_tier(5), _rng(20)))
		for effect in ItemStats.effects(item, definition, db):
			if effect.effect is EssenceDischargeEffect:
				fail("%s carries a shock source" % model)
	for model: StringName in ARMOUR:
		check(not &"thundering" in db.get_item(model).generation_affixes, "%s: no thundering" % model)
	var thundering: AffixDefinition = db.affixes[&"thundering"]
	var slots: Array = []
	slots.assign(thundering.allowed_slot_kinds)
	check_eq(slots, [10, 11], "thundering only on weapon slots")
	var rng := _rng(2021)
	var with_thundering := 0
	var weapons := 0
	for i in 2400:
		var item := EquipmentLoot.roll(table, db, rng)
		if item.definition_id in WEAPONS:
			weapons += 1
			for entry in item.affixes:
				with_thundering += 1 if entry.affix == "thundering" else 0
	check(with_thundering > 0, "the reward pool does roll thundering on weapons (%d of %d)" % [with_thundering, weapons])
