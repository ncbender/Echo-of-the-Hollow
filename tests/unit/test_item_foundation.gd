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
