extends TestCase
## Loot Foundation 1.0 (docs/LOOT_FOUNDATION_1_0.md): instance rarity, the five-tier
## values of the twelve global affixes, the shared affix roller (eligibility, weights,
## tiers, values), ItemCreation.generate and save v14. Isolated: no drops, no sources.
## Files only under user://test_saves/.

const DIR := "user://test_saves"
const R := ItemDefinition.Rarity

var db: GameDatabase
var early: AffixTierWeights
var path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	early = load("res://data/loot/hollowwood_early_tiers.tres") as AffixTierWeights
	path = DIR.path_join("loot_%s.save.json" % IdGenerator.new_id("t"))


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _generate(item_id: StringName, rarity: R, level: int, rng: RandomNumberGenerator) -> ItemCreation.Generated:
	return ItemCreation.generate(db.get_item(item_id), rarity, db, rng, early, level)


func _affix(entry: Dictionary) -> AffixDefinition:
	return db.affixes.get(StringName(str(entry.get("affix", ""))))


# --- Phase C: five tiers ---------------------------------------------------------------

## Approved values (min, max) per tier T5, T4, T3, T2, T1.
const APPROVED := {
	&"cruel": [[2, 4], [4, 6], [6, 9], [9, 12], [12, 15]],
	&"keen": [[0.5, 1], [1, 1.5], [1.5, 2], [2, 2.5], [2.5, 3]],
	&"sharpened": [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6]],
	&"crushing": [[4, 6], [7, 10], [11, 14], [15, 19], [20, 25]],
	&"executioner": [[5, 7], [8, 11], [12, 16], [17, 22], [23, 30]],
	&"thundering": [[8, 12], [13, 18], [19, 25], [26, 33], [34, 42]],
	&"vital": [[4, 7], [8, 12], [13, 19], [20, 28], [29, 40]],
	&"bloodthirsty": [[1, 1], [1, 1], [2, 2], [2, 2], [3, 3]],
	&"guarded": [[2, 3], [4, 5], [6, 8], [9, 12], [13, 17]],
	&"impactful": [[5, 8], [9, 13], [14, 19], [20, 26], [27, 35]],
	&"swift": [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6]],
	&"furious": [[4, 6], [7, 10], [11, 15], [16, 21], [22, 28]],
	&"tempered_blade": [[3, 5], [6, 8], [9, 12], [13, 16], [17, 20]],
	&"striking": [[3, 6], [5, 9], [8, 12], [11, 16], [15, 22]],
	&"armored": [[3, 5], [6, 9], [10, 13], [14, 18], [19, 24]],
}
## Unchanged semantics: stat, scope and exclusion group of every affix.
const SEMANTICS := {
	&"cruel": [&"crit_damage", 0, &""], &"keen": [&"crit_chance", 0, &""],
	&"sharpened": [&"physical_damage", 0, &""], &"crushing": [&"poise_damage", 0, &"control_core"],
	&"executioner": [&"finisher_power", 0, &""], &"thundering": [&"shock_damage", 0, &"element_core"],
	&"vital": [&"max_health", 0, &""], &"bloodthirsty": [&"life_on_hit", 0, &"element_core"],
	&"guarded": [&"armor", 0, &""], &"impactful": [&"knockback_power", 0, &"control_core"],
	&"swift": [&"attack_speed", 0, &""], &"furious": [&"resource_gain", 0, &""],
	&"tempered_blade": [&"weapon_damage", 1, &""], &"striking": [&"weapon_damage", 1, &""],
	&"armored": [&"armor", 1, &""],
}
const WEIGHTS := {&"executioner": 90.0, &"bloodthirsty": 80.0, &"thundering": 30.0}


func test_affixes_carry_the_approved_five_tier_values() -> void:
	check_eq(db.affixes.size(), APPROVED.size(), "15 affix definitions")
	for affix_id: StringName in APPROVED:
		var affix: AffixDefinition = db.affixes.get(affix_id)
		if not check(affix != null, "%s exists" % affix_id):
			continue
		check_eq(affix.tier_model, AffixTiers.MODEL_FIVE, "%s five-tier" % affix_id)
		for index in 5:
			var tier := affix.get_tier(5 - index)
			var expected: Array = APPROVED[affix_id][index]
			check(tier != null and is_equal_approx(tier.min_value, expected[0]) and is_equal_approx(tier.max_value, expected[1]),
					"%s T%d = %s" % [affix_id, 5 - index, expected])
			check_eq(tier.min_item_level, AffixTiers.min_item_level(5 - index), "%s T%d threshold" % [affix_id, 5 - index])
		var semantics: Array = SEMANTICS[affix_id]
		check_eq(affix.stat, semantics[0], "%s stat unchanged" % affix_id)
		check_eq(int(affix.scope), semantics[1], "%s scope" % affix_id)
		check_eq(affix.exclusion_group, semantics[2], "%s exclusion group" % affix_id)
		check_eq(affix.weight, WEIGHTS.get(affix_id, 100.0), "%s base weight" % affix_id)
	check_eq(db.affixes[&"executioner"].required_attack_tags, [&"heavy", &"finisher"] as Array[StringName], "executioner needs a heavy finisher")
	check(not db.affixes[&"armored"].rollable, "armored is defined but not rollable")
	check_near(db.affixes[&"keen"].value_step, 0.1, 0.0001, "keen rolls tenths of a point")


func test_tier_weight_table_is_the_approved_early_hollowwood_one() -> void:
	check(early.validate().is_empty(), "table valid: %s" % [early.validate()])
	check_eq(early.weights_for(1), {5: 100.0}, "ilvl 1: T5 100 %")
	check_eq(early.weights_for(9), {5: 100.0}, "ilvl 9: T5 100 %")
	check_eq(early.weights_for(10), {5: 75.0, 4: 25.0}, "ilvl 10: T5 75 / T4 25")
	check_eq(early.weights_for(24), {5: 75.0, 4: 25.0}, "ilvl 24: T5 75 / T4 25")
	check(not early.covers(25) and not early.covers(100), "ilvl >= 25 not configured")
	var invalid := AffixTierWeights.new()
	invalid.bands.append({"min_level": 10, "max_level": 30, "weights": {3: 1.0}})
	check(not invalid.validate().is_empty(), "T3 below its threshold rejected")
	invalid.bands = [{"min_level": 1, "max_level": 10, "weights": {5: 1.0}}, {"min_level": 10, "max_level": 20, "weights": {5: 1.0}}] as Array[Dictionary]
	check(not invalid.validate().is_empty(), "overlapping bands rejected")


func test_rolled_values_stay_inside_their_tier() -> void:
	var rng := _rng(3)
	for affix: AffixDefinition in db.affixes.values():
		for tier in affix.tiers:
			for i in 40:
				var entry := affix.roll(tier, rng, 12.0)
				var value: float = entry.get("share", entry.flat + entry.percent)
				if value < tier.min_value - 0.0001 or value > tier.max_value + 0.0001:
					fail("%s T%d rolled %s" % [affix.id, tier.tier, value])
					return
				if not is_equal_approx(value / affix.value_step, roundf(value / affix.value_step)):
					fail("%s rolled %s off its step" % [affix.id, value])
					return


# --- Phase B: instance rarity -----------------------------------------------------------

func test_new_instances_own_their_rarity() -> void:
	var coat := ItemCreation.create(db.get_item(&"wanderer_coat"), 1, db)
	check_eq(coat.rarity, R.MAGIC, "create: definition rarity copied onto the instance")
	var other := _generate(&"wanderer_coat", R.NORMAL, 5, _rng(1)).item
	check_eq(other.rarity, R.NORMAL, "a second instance of the same definition is Normal")
	check_eq(other.effective_rarity(db.get_item(&"wanderer_coat")), R.NORMAL, "effective rarity is the instance's")
	var ore := ItemCreation.create(db.get_item(&"iron_ore"), 5, db)
	check_eq(ore.rarity, ItemInstance.RARITY_FROM_DEFINITION, "stacks follow their definition")
	check(not ore.to_dict().has("rarity"), "stacks save no rarity")
	var oath := ItemCreation.create(db.get_item(&"crushing_oath"), 1, db)
	check_eq(oath.rarity, R.UNIQUE, "unique identity kept")


# --- Phase D/E: generation --------------------------------------------------------------

func test_generation_refusals_are_clean() -> void:
	var rng := _rng(5)
	check(not _generate(&"forged_blade", R.MAGIC, 12, rng).ok(), "item without generation preparation refused")
	check(not _generate(&"crushing_oath", R.NORMAL, 15, rng).ok(), "unique item refused")
	check(not _generate(&"warden_mail", R.RARE, 10, rng).ok(), "set item refused")
	check(not _generate(&"echo_blade", R.LEGENDARY, 15, rng).ok(), "handcrafted legendary not generated")
	check(not _generate(&"iron_sword", R.UNIQUE, 5, rng).ok(), "unique is not a generated rarity")
	check(not _generate(&"iron_sword", R.SET, 5, rng).ok(), "set is not a generated rarity")
	var no_level := _generate(&"leather_cap", R.MAGIC, 0, rng)
	check(not no_level.ok() and no_level.error.contains("item level"), "armour without approved item level source refused")
	var high := _generate(&"iron_sword", R.MAGIC, 30, rng)
	check(not high.ok() and high.error.contains("not configured"), "ilvl 30 affix rolls not configured: %s" % high.error)
	check(ItemCreation.generate(db.get_item(&"iron_sword"), R.MAGIC, db, rng, null, 5).error.contains("not configured"), "no table: refused")
	check(_generate(&"iron_sword", R.NORMAL, 30, rng).ok(), "Normal needs no tier table")
	var sword := _generate(&"iron_sword", R.MAGIC, 0, rng)
	check(sword.ok() and sword.item.item_level == 1, "weapon uses its approved source level 1")


func test_normal_rolls_no_affix_and_keeps_the_weapon_base() -> void:
	var definition := db.get_item(&"iron_axe")
	var result := _generate(&"iron_axe", R.NORMAL, 12, _rng(9))
	check(result.ok() and result.item.affixes.is_empty(), "Normal: 0 regular affixes")
	check_eq(result.item.rarity, R.NORMAL, "rarity Normal")
	check_eq(result.item.item_level, 12, "explicit item level")
	check_near(result.item.base_weapon_damage, WeaponDamage.base_for_level(definition, 12, db), 0.000001, "instance base from ItemCreation.create")
	var magic := _generate(&"iron_axe", R.RARE, 12, _rng(10)).item
	check_near(magic.base_weapon_damage, result.item.base_weapon_damage, 0.000001, "affixes never change the stored base")
	check(magic.essences.is_empty() and magic.sockets.is_empty(), "no essences or sockets invented")


func _count_distribution(rarity: R, draws: int) -> Dictionary:
	var rng := _rng(1234)
	var counts := {}
	for i in draws:
		var result := _generate(&"iron_sword", rarity, 12, rng)
		check_eq(result.shortfall, 0, "iron sword pool is large enough")
		counts[result.item.affixes.size()] = counts.get(result.item.affixes.size(), 0) + 1
	return counts


func test_affix_count_follows_rarity() -> void:
	var draws := 3000
	var magic := _count_distribution(R.MAGIC, draws)
	check_eq(magic.keys().size(), 3, "Magic: only 1, 2 or 3 affixes (%s)" % magic)
	check_near(magic.get(1, 0) / float(draws), 0.40, 0.03, "Magic 1 affix 40 %")
	check_near(magic.get(2, 0) / float(draws), 0.40, 0.03, "Magic 2 affixes 40 %")
	check_near(magic.get(3, 0) / float(draws), 0.20, 0.03, "Magic 3 affixes 20 %")
	var rare := _count_distribution(R.RARE, draws)
	check_eq(rare.keys().size(), 2, "Rare: only 3 or 4 affixes (%s)" % rare)
	check_near(rare.get(3, 0) / float(draws), 0.60, 0.03, "Rare 3 affixes 60 %")
	check_near(rare.get(4, 0) / float(draws), 0.40, 0.03, "Rare 4 affixes 40 %")
	var epic := _count_distribution(R.EPIC, 1000)
	check(epic.keys().size() == 2 and epic.has(4) and epic.has(5), "Epic: 4 or 5 affixes (%s)" % epic)
	check_eq(_count_distribution(R.LEGENDARY, 200), {5: 200}, "Legendary: always 5 regular affixes")


func test_short_pools_end_with_a_documented_shortfall() -> void:
	# Armour has exactly four eligible global affixes (furious, guarded, keen, vital; Grove Warden Rare R1).
	var legendary := _generate(&"leather_cap", R.LEGENDARY, 5, _rng(2))
	check(legendary.ok(), "controlled return, no refusal")
	check_eq(legendary.item.affixes.size(), 4, "all four eligible affixes, nothing invented")
	check_eq(legendary.shortfall, 1, "one affix short")
	check(legendary.note.contains("only 4 of 5"), "shortfall documented: %s" % legendary.note)
	# Synthetic: only two mutually exclusive affixes allowed -> one affix at most.
	var narrow := db.get_item(&"iron_sword").duplicate() as ItemDefinition
	narrow.generation_affixes = [&"bloodthirsty", &"thundering"] as Array[StringName]
	var rng := _rng(4)
	for i in 50:
		var result := ItemCreation.generate(narrow, R.EPIC, db, rng, early, 5)
		if result.item.affixes.size() != 1 or result.shortfall != result.requested_affixes - 1:
			fail("exclusive pair must yield exactly one affix (%s)" % [result.item.affixes])
			return
	narrow.generation_affixes = [&"armored"] as Array[StringName]
	check_eq(ItemCreation.generate(narrow, R.MAGIC, db, rng, early, 5).item.affixes.size(), 0, "nothing eligible: empty, no endless loop")


func test_generated_affixes_obey_every_rule() -> void:
	var rng := _rng(77)
	for item_id: StringName in [&"iron_sword", &"hunting_bow", &"oak_staff", &"wanderer_coat", &"oak_shield"]:
		var definition := db.get_item(item_id)
		for i in 150:
			var item := _generate(item_id, R.LEGENDARY, 12, rng).item
			var seen := {}
			for entry in item.affixes:
				var affix := _affix(entry)
				if affix == null or seen.has(affix.group) or (affix.exclusion_group != &"" and seen.has(affix.exclusion_group)):
					fail("%s: duplicate, unknown or excluded affix in %s" % [item_id, item.affixes])
					return
				seen[affix.group] = true
				if affix.exclusion_group != &"":
					seen[affix.exclusion_group] = true
				if not affix.id in definition.generation_affixes or not affix.allows_slot(definition.slot_kind) or not affix.rollable:
					fail("%s: affix %s not allowed" % [item_id, affix.id])
					return
				if not definition.is_weapon() and affix.scope == AffixDefinition.Scope.LOCAL:
					fail("%s: local affix on armour or shield" % item_id)
					return
			if item.affixes.size() > CraftingProfile.MAX_AFFIX_SLOTS:
				fail("more than five regular affixes")
				return


func test_executioner_needs_a_heavy_finisher_family() -> void:
	var executioner: AffixDefinition = db.affixes[&"executioner"]
	for item_id: StringName in [&"iron_sword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear", &"steel_greatsword", &"oak_staff", &"oak_wand"]:
		check(executioner.fits_family(db.get_item(item_id), db), "%s family has heavy finishers" % item_id)
		check(&"executioner" in db.get_item(item_id).generation_affixes, "%s may roll executioner" % item_id)
	var bow := db.get_item(&"hunting_bow")
	check(not executioner.fits_family(bow, db), "bow has no heavy finisher")
	check(not &"executioner" in bow.generation_affixes, "bow never lists executioner")
	var ids := []
	for affix in AffixRoller.eligible(bow, 12, [] as Array[Dictionary], db, [] as Array[StringName], true):
		ids.append(affix.id)
	check(not &"executioner" in ids, "eligibility filters executioner even without an allow list")
	check(&"thundering" in ids, "thundering stays eligible (condition only in its effect)")
	check(not executioner.fits_family(db.get_item(&"leather_cap"), db), "non-weapons never qualify")


func test_tiers_follow_the_early_hollowwood_weights() -> void:
	var rng := _rng(2024)
	for i in 300:
		for entry in _generate(&"iron_sword", R.RARE, 7, rng).item.affixes:
			if int(entry.tier) != 5:
				fail("ilvl 7 rolled T%d" % int(entry.tier))
				return
	var t4 := 0
	var total := 0
	for i in 1500:
		for entry in _generate(&"iron_sword", R.RARE, 12, rng).item.affixes:
			total += 1
			if int(entry.tier) == 4:
				t4 += 1
			elif int(entry.tier) != 5:
				fail("ilvl 12 rolled T%d" % int(entry.tier))
				return
	check(total > 4000, "sample of %d tier draws" % total)
	check_near(t4 / float(total), 0.25, 0.02, "ilvl 12: T4 25 %% (%d / %d)" % [t4, total])
	for i in 300:
		for entry in _generate(&"iron_sword", R.LEGENDARY, 24, rng).item.affixes:
			if int(entry.tier) < 4:
				fail("ilvl 24 rolled T%d in the early table" % int(entry.tier))
				return


func test_local_affixes_follow_the_weapon_base_model() -> void:
	var definition := db.get_item(&"iron_mace")
	var rng := _rng(8)
	var found := {}
	for i in 400:
		var item := _generate(&"iron_mace", R.RARE, 12, rng).item
		var reference := WeaponDamage.reference_at(WeaponDamage.family_base(definition, db), 12)
		var flat := 0.0
		var percent := 0.0
		for entry in item.affixes:
			if str(entry.affix) == "striking":
				found[&"striking"] = true
				check_near(entry.flat, reference * float(entry.share) / 100.0, 0.000001, "striking = B_ref x share / 100")
				flat += entry.flat
			elif str(entry.affix) == "tempered_blade":
				found[&"tempered_blade"] = true
				percent += entry.percent
		var expected := (item.base_weapon_damage + flat) * (1.0 + percent / 100.0)
		check_near(WeaponDamage.of(item, definition, db), expected, 0.0001, "local affixes act on D_weapon only")
		for modifier in ItemStats.modifiers(item, definition, db):
			if modifier.stat == Stats.WEAPON_DAMAGE:
				fail("local affix leaked into the character stats")
				return
	check(found.has(&"striking") and found.has(&"tempered_blade"), "both local weapon affixes roll on weapons")


func test_same_seed_same_item() -> void:
	var a := ItemCreation.generate(db.get_item(&"steel_greatsword"), R.RARE, db, _rng(55), early, 12, ItemInstance.ORIGIN_FOUND, "same").item
	var b := ItemCreation.generate(db.get_item(&"steel_greatsword"), R.RARE, db, _rng(55), early, 12, ItemInstance.ORIGIN_FOUND, "same").item
	check_eq(a.to_dict(), b.to_dict(), "deterministic generation")
	check_eq(a.origin, ItemInstance.ORIGIN_FOUND, "origin set at creation")


# --- Save -----------------------------------------------------------------------------

func test_generated_item_survives_save_and_load() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var character := CharacterFactory.create_new(db)
	var item := ItemCreation.generate(db.get_item(&"oak_wand"), R.RARE, db, _rng(31), early, 12, ItemInstance.ORIGIN_FOUND).item
	item.favorite = true
	item.locked = true
	check_eq(character.inventory.add_instance(item), "", "added")
	var before := item.to_dict()
	check_eq(int(before.rarity), R.RARE, "rarity saved")
	var json := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(before)))
	check_eq(json.to_dict(), before, "JSON round trip exact (rarity, affixes, base, level)")
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "loads: %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(item.instance_id)
	check_eq(loaded.to_dict() if loaded != null else {}, before, "nothing re-rolled or recomputed on load")


func test_v13_save_migrates_rarity_without_upgrades() -> void:
	var affixes := [{"affix": "sharpened", "tier": 2, "tier_model": 3, "stat": "physical_damage", "flat": 9.0, "percent": 0.0}]
	var sword := {"id": "a", "def": "iron_sword", "qty": 1, "ilvl": 4, "base_damage": 12.432, "quality": 3, "affixes": affixes,
		"sockets": ["", "x"], "essences": ["storm"], "evolution": {"stage": 2, "xp": 5, "path": "p"}, "fav": true, "lock": true,
		"origin": "found", "material": "iron"}
	var payload := {
		"inventory": [sword, {"id": "b", "def": "wanderer_coat", "qty": 1}, {"id": "c", "def": "crushing_oath", "qty": 1},
			{"id": "d", "def": "iron_ore", "qty": 7}, {"id": "e", "def": "militia_sword", "qty": 1, "rarity": 0},
			{"id": "f", "def": "unknown_thing", "qty": 1}],
		"stash": {"items": [{"id": "g", "def": "warden_mail", "qty": 1}]},
		"orphaned_items": [{"id": "h", "def": "echo_blade", "qty": 1, "ilvl": 15, "base_damage": 14.016}],
	}
	var original: Dictionary = payload.duplicate(true)
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate(payload, 13, errors)
	check(errors.is_empty(), "migrates: %s" % [errors])
	var inventory: Array = data.inventory
	check_eq(inventory.size(), 6, "no instance lost or duplicated")
	check_eq(inventory[0].rarity, R.NORMAL, "normal sword stays Normal")
	check_eq(inventory[1].rarity, R.MAGIC, "magic coat keeps Magic")
	check_eq(inventory[2].rarity, R.UNIQUE, "unique identity kept")
	check(not inventory[3].has("rarity"), "material stack untouched")
	check_eq(inventory[4].rarity, 0, "existing instance rarity never overwritten")
	check(not inventory[5].has("rarity"), "unknown item untouched")
	check_eq(data.stash.items[0].rarity, R.SET, "stash: set identity kept")
	check_eq(data.orphaned_items[0].rarity, R.LEGENDARY, "orphans migrated too")
	var migrated_sword: Dictionary = inventory[0].duplicate(true)
	migrated_sword.erase("rarity")
	check_eq(migrated_sword, original.inventory[0], "every other field of the sword unchanged (affixes not re-rolled)")
	var loaded := ItemInstance.from_dict(inventory[0])
	check(loaded.affixes[0].flat == 9.0 and db.affixes[&"sharpened"].tier_of(loaded.affixes[0]) == null, "legacy three-tier roll keeps its value, no five-tier tier")


func test_frozen_rarity_table_matches_the_equipment_data() -> void:
	for definition: ItemDefinition in db.items.values():
		if definition.is_equippable():
			check_eq(SaveMigrations.V14_EQUIPMENT_RARITY.get(String(definition.id), -1), int(definition.rarity), "%s frozen rarity" % definition.id)
	check(SaveSystem.VERSION >= 14, "save version 14 or later (v15: class reward)")
