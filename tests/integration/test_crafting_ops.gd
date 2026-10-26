extends TestCase
## Crafting phase C: imprint / augment / reforge as transactions with real
## inventory currencies (costs, refusals without consumption, unique protection,
## stale/double requests, equipment references, save/load).

const S := EquipSlot.Slot
const SAVE := "user://test_saves/crafting_ops.save.json"

var db: GameDatabase
var character: Character
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	rng.seed = 1234


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _give(items: Dictionary) -> void:
	for item_id: StringName in items:
		character.inventory.add_item(item_id, items[item_id])


func _blade() -> ItemInstance:
	return character.inventory.add_item(&"forged_blade")[0]


func _request(operation: StringName, item: ItemInstance) -> CraftingRequest:
	return CraftingRequest.make(operation, item)


func _imprinted(material: StringName = &"storm_ore") -> ItemInstance:
	var blade := _blade()
	_give({db.materials[material].item_id: 3, &"imprint_shard": 1})
	var request := _request(CraftingOps.IMPRINT, blade)
	request.material_id = material
	CraftingService.execute(character, request, rng)
	return blade


func test_imprint_sets_material_rolls_one_affix_and_pays_exactly() -> void:
	var blade := _blade()
	_give({&"storm_ore": 5, &"imprint_shard": 2})
	var request := _request(CraftingOps.IMPRINT, blade)
	request.material_id = &"storm_ore"
	var preview := CraftingService.preview(character, request)
	check(preview.ok(), "preview ok: %s" % preview.reason())
	var costs := {}
	for cost in preview.costs:
		costs[cost.item_id] = cost.quantity
	check_eq(costs, {&"imprint_shard": 1, &"storm_ore": 3}, "costs = operation + material")
	var id := blade.instance_id
	var result := CraftingService.execute(character, request, rng)
	check(result.ok, "executed: %s" % result.error)
	check_eq(blade.material_id, &"storm_ore", "main material set")
	check_eq(blade.affixes.size(), 1, "one affix rolled")
	check(AffixPool.by_affix(preview.outcomes).has(StringName(blade.affixes[0].affix)), "rolled affix comes from the previewed pool")
	check_eq(character.inventory.count(&"storm_ore"), 2, "3 ore consumed")
	check_eq(character.inventory.count(&"imprint_shard"), 1, "1 shard consumed")
	check_eq(character.inventory.find(id), blade, "same instance (identity kept)")
	check_eq(blade.revision, 1, "revision advanced")


func test_refusals_consume_nothing() -> void:
	var blade := _blade()
	_give({&"storm_ore": 3})
	var request := _request(CraftingOps.IMPRINT, blade)
	request.material_id = &"storm_ore"
	var result := CraftingService.execute(character, request, rng)
	check(not result.ok and "Imprint Shard" in result.error, "missing shard reported: %s" % result.error)
	check_eq(character.inventory.count(&"storm_ore"), 3, "material untouched")
	check_eq(blade.material_id, &"", "item untouched")
	request.material_id = &"moon_silver"
	check(not CraftingService.preview(character, request).ok(), "unknown material refused")
	var augment := _request(CraftingOps.AUGMENT, blade)
	_give({&"imprint_shard": 5})
	check_eq(CraftingService.execute(character, augment, rng).error, "Imprint the item first.", "augment needs an imprint")
	check_eq(character.inventory.count(&"imprint_shard"), 5, "shards untouched")


func test_main_material_is_permanent() -> void:
	var blade := _imprinted(&"storm_ore")
	_give({&"frost_glass": 3, &"imprint_shard": 1})
	var request := _request(CraftingOps.IMPRINT, blade)
	request.material_id = &"frost_glass"
	var result := CraftingService.execute(character, request, rng)
	check(not result.ok and "permanent" in result.error, "second imprint refused: %s" % result.error)
	check_eq(blade.material_id, &"storm_ore", "material unchanged")


func test_augment_fills_free_slots_then_refuses() -> void:
	var blade := _imprinted()
	_give({&"imprint_shard": 10})
	for i in 3:
		check(CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng).ok, "augment %d" % (i + 1))
	check_eq(blade.affixes.size(), 4, "4 affix slots filled")
	var groups := {}
	for affix in blade.affixes:
		var definition: AffixDefinition = db.affixes[StringName(affix.affix)]
		check(not groups.has(definition.group), "no duplicate group (%s)" % definition.group)
		groups[definition.group] = true
	var shards := character.inventory.count(&"imprint_shard")
	var result := CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng)
	check(not result.ok and "affix slots" in result.error, "full item refused: %s" % result.error)
	check_eq(character.inventory.count(&"imprint_shard"), shards, "nothing consumed")


func test_reforge_replaces_the_chosen_affix_immediately() -> void:
	var blade := _imprinted()
	_give({&"imprint_shard": 4, &"transmute_core": 3})
	CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng)
	CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng)
	var untouched := [blade.affixes[0].duplicate(), blade.affixes[2].duplicate()]
	var request := _request(CraftingOps.REFORGE, blade)
	request.affix_index = 1
	var preview := CraftingService.preview(character, request)
	check(preview.ok(), "reforge preview: %s" % preview.reason())
	check(preview.notes[0].contains("no undo"), "player is told: immediate, no undo")
	var result := CraftingService.execute(character, request, rng)
	check(result.ok, "reforged: %s" % result.error)
	check_eq(blade.affixes.size(), 3, "affix count unchanged")
	check_eq([blade.affixes[0], blade.affixes[2]], untouched, "other affixes untouched")
	check_eq(blade.affixes[1], result.rolled, "chosen affix replaced by the roll")
	check_eq(character.inventory.count(&"transmute_core"), 2, "one core consumed")
	blade.affixes.append({"stat": "crit_chance", "flat": 2.0, "percent": 0.0, "legacy": true})
	request = _request(CraftingOps.REFORGE, blade)
	request.affix_index = 3
	check(not CraftingService.preview(character, request).ok(), "legacy/fixed property cannot be reforged")


func test_execution_uses_exactly_the_previewed_pool() -> void:
	var blade := _imprinted()
	_give({&"imprint_shard": 2})
	var request := _request(CraftingOps.AUGMENT, blade)
	var preview := CraftingService.preview(character, request)
	var mirror := RandomNumberGenerator.new()
	mirror.seed = 99
	rng.seed = 99
	var expected := AffixPool.pick(preview.outcomes, mirror)
	var result := CraftingService.execute(character, request, rng)
	check_eq(StringName(result.rolled.affix), (expected.affix as AffixDefinition).id, "same pool, same draw")
	check_eq(int(result.rolled.tier), (expected.tier as AffixTier).tier, "same tier")


func test_focus_catalyst() -> void:
	var blade := _imprinted(&"blood_steel")
	_give({&"imprint_shard": 2, &"focus_catalyst": 1})
	var request := _request(CraftingOps.AUGMENT, blade)
	request.focus_tag = &"crit"
	var plain := AffixPool.by_affix(CraftingService.preview(character, _request(CraftingOps.AUGMENT, blade)).outcomes)
	var preview := CraftingService.preview(character, request)
	check(preview.ok(), "focus preview: %s" % preview.reason())
	var focused := AffixPool.by_affix(preview.outcomes)
	if focused.has(&"cruel") and plain.has(&"cruel"):
		check(focused[&"cruel"] > plain[&"cruel"], "crit affixes more likely")
	check(CraftingService.execute(character, request, rng).ok, "focused augment")
	check_eq(character.inventory.count(&"focus_catalyst"), 0, "catalyst consumed")
	request = _request(CraftingOps.AUGMENT, blade)
	request.focus_tag = &"nonexistent"
	check(not CraftingService.preview(character, request).ok(), "unknown focus tag refused")


func test_unique_core_is_protected() -> void:
	var oath := character.inventory.add_item(&"crushing_oath")[0]
	_give({&"storm_ore": 3, &"imprint_shard": 2, &"transmute_core": 1})
	var request := _request(CraftingOps.IMPRINT, oath)
	request.material_id = &"storm_ore"
	var result := CraftingService.execute(character, request, rng)
	check(not result.ok and "protected" in result.error, "imprint refused: %s" % result.error)
	var reforge := _request(CraftingOps.REFORGE, oath)
	reforge.affix_index = 0
	check("protected" in CraftingService.preview(character, reforge).error, "reforge refused")
	check_eq(character.inventory.count(&"imprint_shard"), 2, "nothing consumed")
	check_eq(db.get_item(&"crushing_oath").effects.size(), 1, "handcrafted effect untouched")
	check(oath.affixes.is_empty(), "no affixes on the unique")


func test_stale_or_repeated_request_never_applies_twice() -> void:
	var blade := _imprinted()
	_give({&"imprint_shard": 4})
	var request := _request(CraftingOps.AUGMENT, blade)
	check(CraftingService.execute(character, request, rng).ok, "first click applies")
	var shards := character.inventory.count(&"imprint_shard")
	var again := CraftingService.execute(character, request, rng)
	check(not again.ok and "changed" in again.error, "second click on the same preview refused: %s" % again.error)
	check_eq(blade.affixes.size(), 2, "only one affix added")
	check_eq(character.inventory.count(&"imprint_shard"), shards, "no second payment")


func test_equipped_item_stays_equipped_and_stats_refresh() -> void:
	var blade := _imprinted(&"frost_glass")
	check_eq(character.equipment.equip(blade.instance_id, S.MAIN_HAND), "", "equipped")
	var changes := [0]
	character.stats_changed.connect(func() -> void: changes[0] += 1)
	_give({&"imprint_shard": 2})
	CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng)
	check_eq(character.equipment.get_item(S.MAIN_HAND), blade, "loadout still references the same instance")
	check(changes[0] >= 1, "stats recomputed")
	var affix := blade.affixes[1]
	var stat := StringName(affix.stat)
	var expected := 0.0
	for modifier in ItemStats.modifiers(blade, db.get_item(&"forged_blade"), db):
		if modifier.stat == stat:
			expected += modifier.flat
	check(character.get_stat(stat) >= expected - 0.001, "new affix active (%s)" % stat)


func test_crafted_item_survives_save_load() -> void:
	var blade := _imprinted(&"blood_steel")
	_give({&"imprint_shard": 2})
	CraftingService.execute(character, _request(CraftingOps.AUGMENT, blade), rng)
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	var before := blade.to_dict()
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db).character
	check_eq(loaded.inventory.find(blade.instance_id).to_dict(), before, "identical after load")
	check_eq(loaded.equipment.get_item(S.MAIN_HAND).instance_id, blade.instance_id, "still equipped")
