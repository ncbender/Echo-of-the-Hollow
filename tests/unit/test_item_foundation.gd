extends TestCase
## Item Foundation 1.0 (docs/ITEM_FOUNDATION_1_0.md): structural item and affix
## rules - five regular affix slots at most, two essences, affix categories,
## five-tier model, local/global scope, quality 0.5 % per point.

var db: GameDatabase


func before_each() -> void:
	db = GameDatabase.get_default()


func _profile(slots: int) -> CraftingProfile:
	var profile := CraftingProfile.new()
	profile.affix_slots = slots
	return profile


func test_real_data_validates() -> void:
	check(db.load_errors.is_empty(), "real data loads cleanly: %s" % [db.load_errors])
	var errors := db.validate()
	check(errors.is_empty(), "real data validates: %s" % [errors])


func test_at_most_five_regular_affix_slots() -> void:
	check_eq(CraftingProfile.MAX_AFFIX_SLOTS, 5, "five regular affix slots")
	check_eq(CraftingProfile.MAX_ESSENCE_SLOTS, 2, "essences stay at two")
	check(_profile(5).validate(&"t").is_empty(), "five slots are valid")
	check(not _profile(6).validate(&"t").is_empty(), "six slots are rejected")
	check_eq(_profile(6).affix_limit(), 5, "unvalidated data never yields more than five")
	var essences := _profile(0)
	essences.essence_slots = 3
	check(not essences.validate(&"t").is_empty(), "three essence slots are rejected")
	for item: ItemDefinition in db.items.values():
		if item.crafting != null:
			check(item.crafting.affix_slots <= 5, "%s: at most five affix slots" % item.id)


func test_full_five_slot_item_has_no_free_slot() -> void:
	var definition := db.get_item(&"forged_blade").duplicate() as ItemDefinition
	definition.crafting = definition.crafting.duplicate() as CraftingProfile
	definition.crafting.affix_slots = 5
	var item := ItemInstance.create(&"forged_blade")
	item.item_level = 30
	check(not AffixPool.compute(item, definition, null, db).is_empty(), "free slots: pool offered")
	for index in 5:
		item.affixes.append({"affix": "x%d" % index, "tier": 3, "stat": "armor", "flat": 1.0, "percent": 0.0})
	check(AffixPool.compute(item, definition, null, db).is_empty(), "five affixes: no further slot")


func test_affix_categories() -> void:
	var expected := {
		&"bloodthirsty": AffixDefinition.Category.DEFENSIVE, &"cruel": AffixDefinition.Category.OFFENSIVE,
		&"crushing": AffixDefinition.Category.OFFENSIVE, &"executioner": AffixDefinition.Category.OFFENSIVE,
		&"furious": AffixDefinition.Category.RESOURCE, &"guarded": AffixDefinition.Category.DEFENSIVE,
		&"impactful": AffixDefinition.Category.UTILITY, &"keen": AffixDefinition.Category.OFFENSIVE,
		&"sharpened": AffixDefinition.Category.OFFENSIVE, &"swift": AffixDefinition.Category.OFFENSIVE,
		&"thundering": AffixDefinition.Category.OFFENSIVE, &"vital": AffixDefinition.Category.DEFENSIVE,
	}
	check_eq(AffixDefinition.Category.size(), 4, "four affix categories")
	for affix_id: StringName in expected:
		var affix: AffixDefinition = db.affixes.get(affix_id)
		check(affix != null and affix.category == expected[affix_id], "%s category" % affix_id)


## Synthetic five-tier affix (values are test values, not designed balance).
func _five_tier_affix() -> AffixDefinition:
	var affix := AffixDefinition.new()
	affix.id = &"test_five"
	affix.stat = Stats.ARMOR
	affix.group = &"test_five"
	affix.tags = [&"defense"] as Array[StringName]
	affix.tier_model = AffixTiers.MODEL_FIVE
	for tier_number: int in [5, 4, 3, 2, 1]:
		var tier := AffixTier.new()
		tier.tier = tier_number
		tier.min_item_level = AffixTiers.min_item_level(tier_number)
		tier.min_value = 6 - tier_number
		tier.max_value = 6 - tier_number
		affix.tiers.append(tier)
	return affix


func test_five_tier_thresholds() -> void:
	check_eq(AffixTiers.COUNT, 5, "five tiers")
	var expected := {5: 1, 4: 10, 3: 25, 2: 45, 1: 70}
	for tier: int in expected:
		check_eq(AffixTiers.min_item_level(tier), expected[tier], "T%d threshold" % tier)
	var highest := {1: 5, 9: 5, 10: 4, 24: 4, 25: 3, 44: 3, 45: 2, 69: 2, 70: 1, 99: 1, 0: 0}
	for level: int in highest:
		check_eq(AffixTiers.highest_tier(level), highest[level], "highest tier at ilvl %d" % level)


func test_five_tier_validation() -> void:
	check(_five_tier_affix().validate().is_empty(), "complete five-tier affix validates: %s" % [_five_tier_affix().validate()])
	var wrong_level := _five_tier_affix()
	wrong_level.tiers[2].min_item_level = 20
	check(not wrong_level.validate().is_empty(), "T3 must start at ilvl 25")
	var missing := _five_tier_affix()
	missing.tiers.remove_at(4)
	check(not missing.validate().is_empty(), "all five tiers required")
	var three := _five_tier_affix()
	three.tier_model = AffixTiers.MODEL_THREE
	check(not three.validate().is_empty(), "T4/T5 are outside the three-tier model")
	var unknown := _five_tier_affix()
	unknown.tier_model = 4
	check(not unknown.validate().is_empty(), "unknown tier model rejected")


## The real global affixes stay on the three-tier prototype model: their tiers are not
## silently renumbered or re-levelled (five-tier values are not designed yet). Only the
## local weapon damage affixes of Weapon Base Damage 1.0 are five-tier.
func test_existing_affixes_are_not_reinterpreted() -> void:
	for affix: AffixDefinition in db.affixes.values():
		if affix.scope == AffixDefinition.Scope.LOCAL:
			continue
		check_eq(affix.tier_model, AffixTiers.MODEL_THREE, "%s stays three-tier" % affix.id)
		check_eq(affix.tiers.size(), 3, "%s keeps its three tiers" % affix.id)
	var sharpened: AffixDefinition = db.affixes[&"sharpened"]
	check_eq(sharpened.get_tier(1).min_item_level, 20, "sharpened T1 still from ilvl 20")
	check_eq(sharpened.get_tier(1).max_value, 18.0, "sharpened T1 values unchanged")


func test_rolls_carry_their_tier_model() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var five := _five_tier_affix()
	var entry := five.roll(five.get_tier(2), rng)
	check_eq(entry.get("tier_model"), AffixTiers.MODEL_FIVE, "five-tier roll stamped")
	check_eq(five.tier_of(entry), five.get_tier(2), "tier found in its own model")
	var sharpened: AffixDefinition = db.affixes[&"sharpened"]
	var old := sharpened.roll(sharpened.get_tier(1), rng)
	check_eq(old.get("tier_model"), AffixTiers.MODEL_THREE, "three-tier roll stamped")
	check_eq(five.tier_of(old), null, "a three-tier T1 is never read as five-tier T1")
	check_eq(sharpened.tier_of({"affix": "sharpened", "tier": 1}), null, "unknown model: no tier")
	var saved := ItemInstance.from_dict(JSON.parse_string(JSON.stringify({"id": "a", "def": "forged_blade", "qty": 1, "affixes": [entry]})))
	check_eq(typeof(saved.affixes[0].tier_model), TYPE_INT, "tier model restored as int after JSON")


func test_pool_follows_five_tier_thresholds() -> void:
	var local_db := GameDatabase.new()
	local_db.load_all()
	local_db.affixes = {&"test_five": _five_tier_affix()}
	var definition := local_db.get_item(&"forged_blade").duplicate() as ItemDefinition
	definition.slot_kind = ItemDefinition.SlotKind.CHEST
	for level: int in [1, 10, 25, 45, 70]:
		var item := ItemInstance.create(&"forged_blade")
		item.item_level = level
		var tiers := []
		for entry in AffixPool.compute(item, definition, null, local_db):
			tiers.append((entry.tier as AffixTier).tier)
		tiers.sort()
		check_eq(tiers.size(), 6 - AffixTiers.highest_tier(level), "ilvl %d: tiers %s" % [level, tiers])
		check_eq(tiers[0], AffixTiers.highest_tier(level), "ilvl %d: best tier" % level)


func test_local_and_global_scope_rules() -> void:
	var K := ItemDefinition.SlotKind
	for kind: int in [K.ONE_HAND_WEAPON, K.TWO_HAND_WEAPON, K.HEAD, K.CHEST, K.HANDS, K.LEGS, K.FEET, K.SHIELD]:
		check(ItemDefinition.allows_local_affixes(kind), "slot kind %d allows local" % kind)
	for kind: int in [K.RING, K.NECK]:
		check(not ItemDefinition.allows_local_affixes(kind), "rings and amulets: global only (%d)" % kind)
	var local := _five_tier_affix()
	local.scope = AffixDefinition.Scope.LOCAL
	check(not local.validate().is_empty(), "local affix without slot list rejected")
	local.allowed_slot_kinds = [K.CHEST, K.RING] as Array[ItemDefinition.SlotKind]
	check(not local.validate().is_empty(), "local affix on a ring rejected")
	local.allowed_slot_kinds = [K.CHEST, K.ONE_HAND_WEAPON] as Array[ItemDefinition.SlotKind]
	check(local.validate().is_empty(), "local affix on armour and weapons valid: %s" % [local.validate()])
	check(not local.allows_slot(K.NECK), "local never on an amulet")
	var global := _five_tier_affix()
	check(global.allows_slot(K.RING) and global.allows_slot(K.CHEST), "global fits rings and armour")


## Every pre-existing affix is GLOBAL, so stats, damage and defence work exactly as
## before; a LOCAL affix is only offered on a weapon on the base damage model (none of
## the craftable weapons is on it yet), never for a local target without a calculation.
func test_existing_affixes_stay_global_and_local_is_not_rolled() -> void:
	for affix: AffixDefinition in db.affixes.values():
		if affix.id in [&"tempered_blade", &"striking"]:
			check_eq(affix.scope, AffixDefinition.Scope.LOCAL, "%s is local" % affix.id)
		else:
			check_eq(affix.scope, AffixDefinition.Scope.GLOBAL, "%s is global" % affix.id)
	var local_db := GameDatabase.new()
	local_db.load_all()
	var local := _five_tier_affix()
	local.scope = AffixDefinition.Scope.LOCAL
	local.allowed_slot_kinds = [ItemDefinition.SlotKind.ONE_HAND_WEAPON] as Array[ItemDefinition.SlotKind]
	local_db.affixes[local.id] = local
	var item := ItemInstance.create(&"forged_blade")
	item.item_level = 70
	var pool := AffixPool.by_affix(AffixPool.compute(item, local_db.get_item(&"forged_blade"), null, local_db))
	check(not pool.has(&"test_five"), "local affix not rollable yet")
	check_eq(pool.size(), 11, "the eleven global weapon affixes are offered as before")


func test_quality_is_half_a_percent_per_point() -> void:
	check_near(ItemStats.quality_factor(0), 1.0, 0.0001, "quality 0: no bonus")
	check_near(ItemStats.quality_factor(1), 1.005, 0.0001, "+0.5 % per point")
	check_near(ItemStats.quality_factor(20), 1.1, 0.0001, "quality 20: +10 %")
	check_near(ItemStats.quality_factor(35), 1.1, 0.0001, "never above +10 %")
	check_eq(ItemStats.quality_percent_text(1), "0.5", "display 0.5")
	check_eq(ItemStats.quality_percent_text(20), "10", "display 10")
	var too_high := _profile(0)
	too_high.max_quality = 20
	check(too_high.validate(&"t").is_empty(), "max quality 20 valid")


## Quality only scales base stats that exist (eligible = profile.quality_stats or
## all); affixes are untouched and items without base stats get nothing invented.
func test_quality_scales_existing_base_stats_only() -> void:
	var definition := db.get_item(&"forged_blade")
	var blade := ItemInstance.create(&"forged_blade")
	blade.quality = 20
	blade.affixes.append({"affix": "sharpened", "tier": 3, "tier_model": 3, "stat": "physical_damage", "flat": 5.0, "percent": 0.0})
	var totals := {}
	for modifier in ItemStats.modifiers(blade, definition, db):
		totals[modifier.stat] = totals.get(modifier.stat, 0.0) + modifier.flat
	check_near(totals[Stats.PHYSICAL_DAMAGE], 6.0 * 1.1 + 5.0, 0.0001, "base 6 +10 %, affix 5 unchanged")
	check_near(totals[Stats.POISE_DAMAGE], 4.0 * 1.1, 0.0001, "base 4 +10 %")
	var oath := ItemInstance.create(&"crushing_oath")
	oath.quality = 10
	var oath_mods := ItemStats.modifiers(oath, db.get_item(&"crushing_oath"), db)
	check_eq(oath_mods.size(), 1, "unique: only its one base stat, nothing added")
	check_near(oath_mods[0].flat, 4.0 * 1.05, 0.0001, "unique base 4 +5 %")
	var cap := ItemInstance.create(&"leather_cap")
	cap.quality = 20   # no crafting profile: quality cannot reach it
	var cap_def := db.get_item(&"leather_cap")
	var cap_mods := ItemStats.modifiers(cap, cap_def, db)
	check_eq(cap_mods.size(), cap_def.base_stats.size(), "no stats invented")
	for index in cap_mods.size():
		check_eq(cap_mods[index], cap_def.base_stats[index], "item without profile: base stat untouched")
