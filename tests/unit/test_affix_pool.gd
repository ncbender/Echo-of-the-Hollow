extends TestCase
## Crafting phase B: affix pool (eligibility, tiers, material weights, focus,
## exclusions, free slots), normalized probabilities and seeded rolls.

var db: GameDatabase
var blade_def: ItemDefinition


func before_each() -> void:
	db = GameDatabase.get_default()
	blade_def = db.get_item(&"forged_blade")


func _blade(item_level: int = 1) -> ItemInstance:
	var item := ItemInstance.create(&"forged_blade")
	item.item_level = item_level
	return item


func _material(id: StringName) -> MaterialDefinition:
	return db.materials[id]


func _ids(entries: Array[Dictionary]) -> Dictionary:
	return AffixPool.by_affix(entries)


func test_data_is_complete() -> void:
	check_eq(db.materials.size(), 3, "three main materials")
	check_eq(db.affixes.size(), 15, "12 global + striking, tempered blade, armored (%d)" % db.affixes.size())
	for affix: AffixDefinition in db.affixes.values():
		check(not affix.tags.is_empty() and affix.group != &"" and not affix.tiers.is_empty(), "%s complete" % affix.id)


func test_eligibility_by_item_type() -> void:
	var pool := _ids(AffixPool.compute(_blade(), blade_def, null, db))
	check(not pool.has(&"guarded"), "armor-only affix not on a weapon")
	check(pool.has(&"sharpened") and pool.has(&"vital"), "weapon and generic affixes offered")
	check_eq(pool.size(), 11, "11 affixes fit a one-handed weapon")
	check(AffixPool.compute(ItemInstance.create(&"iron_sword"), db.get_item(&"iron_sword"), null, db).is_empty(), "non-craftable item: empty pool")


func test_tiers_follow_item_level() -> void:
	var tiers_at := func(level: int) -> Array:
		var found := []
		for entry in AffixPool.compute(_blade(level), blade_def, null, db):
			if (entry.affix as AffixDefinition).id == &"sharpened":
				found.append((entry.tier as AffixTier).tier)
		found.sort()
		return found
	check_eq(tiers_at.call(1), [5], "ilvl 1: T5 only")
	check_eq(tiers_at.call(12), [4, 5], "ilvl 12: T5 and T4")
	check_eq(tiers_at.call(24), [4, 5], "ilvl 24: still T5 and T4 (early Hollowwood table)")
	check_eq(tiers_at.call(25), [], "ilvl 25: tier weights not configured, nothing offered")


func test_probabilities_are_exact_and_normalized() -> void:
	var neutral := AffixPool.compute(_blade(), blade_def, null, db)
	var total := 0.0
	for entry in neutral:
		total += entry.probability
	check_near(total, 1.0, 0.000001, "normalized")
	# Loot Foundation 1.0 base weights: 8 standard affixes x 100, executioner 90,
	# bloodthirsty 80, thundering 30 -> total 1000
	check_near(_ids(neutral)[&"thundering"], 30.0 / 1000.0, 0.000001, "no material: thundering weight 30")
	check_near(_ids(neutral)[&"executioner"], 90.0 / 1000.0, 0.000001, "executioner weight 90")
	check_near(_ids(neutral)[&"bloodthirsty"], 80.0 / 1000.0, 0.000001, "bloodthirsty weight 80")
	check_near(_ids(neutral)[&"vital"], 100.0 / 1000.0, 0.000001, "standard weight 100")
	# Storm Ore: shock x3 (90), speed x2 (200), crit x1.5 (keen, cruel 150 each), rest x1 -> 1260
	var storm := _ids(AffixPool.compute(_blade(), blade_def, _material(&"storm_ore"), db))
	check_near(storm[&"thundering"], 90.0 / 1260.0, 0.000001, "storm ore triples shock")
	check_near(storm[&"swift"], 200.0 / 1260.0, 0.000001, "storm ore doubles speed")
	check_near(storm[&"cruel"], 150.0 / 1260.0, 0.000001, "largest matching tag multiplier (crit)")
	check_near(storm[&"sharpened"], 100.0 / 1260.0, 0.000001, "unrelated affix unchanged")
	var split := AffixPool.compute(_blade(12), blade_def, null, db)
	for entry in split:
		if (entry.affix as AffixDefinition).id == &"sharpened":
			var share := 0.75 if (entry.tier as AffixTier).tier == 5 else 0.25
			check_near(entry.probability, 0.1 * share, 0.000001, "tier share inside the affix (T5 75 / T4 25)")


func test_focus_catalyst_raises_tag_weight() -> void:
	var pool := _ids(AffixPool.compute(_blade(), blade_def, null, db, &"crit", 4.0))
	# keen and cruel x4: total = 400 + 400 + 800 (others) = 1600
	check_near(pool[&"keen"], 400.0 / 1600.0, 0.000001, "focused tag x4")
	check_near(pool[&"vital"], 100.0 / 1600.0, 0.000001, "others relatively rarer")
	check(AffixPool.tags_of(AffixPool.compute(_blade(), blade_def, null, db)).has(&"crit"), "focus tags listed")


func test_groups_and_exclusion_groups() -> void:
	var item := _blade()
	item.affixes.append({"affix": "crushing", "tier": 3, "stat": "poise_damage", "flat": 8.0, "percent": 0.0})
	var pool := _ids(AffixPool.compute(item, blade_def, null, db))
	check(not pool.has(&"crushing"), "same group never twice")
	check(not pool.has(&"impactful"), "exclusion group control_core blocks impactful")
	item.affixes.append({"affix": "thundering", "tier": 3, "stat": "shock_damage", "flat": 12.0, "percent": 0.0})
	check(not _ids(AffixPool.compute(item, blade_def, null, db)).has(&"bloodthirsty"), "element_core: shock excludes blood")


func test_free_slots_and_replacement_pool() -> void:
	var item := _blade()
	for affix_id: String in ["sharpened", "keen", "vital", "furious"]:
		item.affixes.append({"affix": affix_id, "tier": 3, "stat": "x", "flat": 1.0, "percent": 0.0})
	check(AffixPool.compute(item, blade_def, null, db).is_empty(), "all 4 affix slots used: empty pool")
	var replace := _ids(AffixPool.compute(item, blade_def, null, db, &"", 1.0, 1))
	check(replace.has(&"keen"), "replacing keen: keen may roll again")
	check(not replace.has(&"sharpened"), "other present affixes still excluded")


func test_seeded_rolls_are_deterministic_and_follow_the_pool() -> void:
	var entries := AffixPool.compute(_blade(12), blade_def, _material(&"storm_ore"), db)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	check_eq((AffixPool.pick(entries, a).affix as AffixDefinition).id, (AffixPool.pick(entries, b).affix as AffixDefinition).id, "same seed, same result")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {}
	var draws := 6000
	for i in draws:
		var entry := AffixPool.pick(entries, rng)
		var affix_id: StringName = (entry.affix as AffixDefinition).id
		counts[affix_id] = counts.get(affix_id, 0) + 1
		var rolled := (entry.affix as AffixDefinition).roll(entry.tier, rng)
		var value: float = rolled.flat
		if value < (entry.tier as AffixTier).min_value or value > (entry.tier as AffixTier).max_value:
			fail("rolled value %s outside tier range" % value)
			return
	var expected := AffixPool.by_affix(entries)
	for affix_id: StringName in expected:
		check_near(counts.get(affix_id, 0) / float(draws), expected[affix_id], 0.025, "%s frequency matches shown probability" % affix_id)
	check(AffixPool.pick([] as Array[Dictionary], rng).is_empty(), "empty pool: nothing drawn")
