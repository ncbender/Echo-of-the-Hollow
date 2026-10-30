extends TestCase
## Inventory Save/Load Roundtrip 1.0 (docs/INVENTORY_SAVE_ROUNDTRIP_1_0.md): the inventory and
## every loadout reference survive the real pipeline (Character.to_dict -> SaveSystem JSON file ->
## SaveSystem.load_from) unchanged. Items only come from the game's own creation paths (starting
## items, Inventory.add_item, ItemCreation.generate). Files only under user://test_saves/.
##
## The comparison is strict (value AND type, every key, item order) and reports each difference
## with its data path and both values. Exactly two findings of the first roundtrip are accepted,
## each by its own narrow rule (see the doc, section 3) - nothing is sorted, dropped or loosened:
##  * FLOAT_PARSE: a stored decimal comes back off by at most a few ULP - Godot's JSON parser does
##    not round every 17-digit number to the nearest double (12.600000000000001 -> 12.6)
##  * EVOLUTION_DEFAULT: an evolving item without evolution state comes back with the explicit
##    default state {"stage": 1, "xp": 0, "path": ""} (ItemStats.sanitize on load); the accessors
##    read the same values before
## A second save/load of the loaded character must then be bit-identical (no drift).

const DIR := "user://test_saves"
const R := ItemDefinition.Rarity
const S := EquipSlot.Slot
const EVOLUTION_DEFAULT := {"stage": 1, "xp": 0, "path": ""}
## Relative distance accepted for FLOAT_PARSE: a few ULP of a double (2.2e-16), far below any
## value the game shows or rounds.
const FLOAT_PARSE_RELATIVE := 1e-14

var db: GameDatabase
var path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	DirAccess.make_dir_recursive_absolute(DIR)
	path = DIR.path_join("inventory_roundtrip_%s.save.json" % IdGenerator.new_id("t"))


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


## Representative bag: stackable materials, consumables, equipped starting gear, a generated
## Rare weapon (rolled affixes with tier / tier model, stored base damage, rarity, item level),
## an evolving weapon, the items of the playtest's save flow, and an inactive class loadout.
func _character() -> Character:
	var character := CharacterFactory.create_new(db)   # iron sword + coat/cap equipped, greatsword, 3 minor potions
	character.inventory.add_item(&"iron_ore", 37)
	character.inventory.add_item(&"timber", 5)
	for item_id: StringName in [&"militia_sword", &"oak_shield", &"copper_ring", &"echo_blade", &"stormcaller_fang"]:
		character.inventory.add_item(item_id, 1, ItemInstance.ORIGIN_FOUND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var generated := ItemCreation.generate(db.get_item(&"steel_greatsword"), R.RARE, db, rng,
			db.rules.crafting_tier_weights, 7, ItemInstance.ORIGIN_FOUND)
	if check(generated.ok(), "rare greatsword generated: %s" % generated.error):
		check_eq(character.inventory.add_instance(generated.item), "", "generated item added")
	# the Basic Adventurer loadout becomes an inactive loadout once the warrior is active
	character.classes.unlock(&"warrior")
	check_eq(character.switch_class(&"warrior", true), "", "warrior active")
	if generated.ok():
		check_eq(character.equipment.equip(generated.item.instance_id, S.MAIN_HAND), "", "rare greatsword equipped (warrior)")
	check_eq(character.equipment.equip(_id(character, &"copper_ring")), "", "ring equipped (warrior)")
	return character


func _id(character: Character, item_id: StringName) -> String:
	for item in character.inventory.items():
		if item.definition_id == item_id:
			return item.instance_id
	return ""


func _roundtrip(character: Character) -> SaveSystem.LoadResult:
	check_eq(SaveSystem.save_to(character, path), OK, "saved to the test file")
	return SaveSystem.load_from(path, db)


## Strict structural diff: type and value at every path; arrays by index (order matters).
## Appends {"path", "before", "after"} per difference ("before"/"after" null = key/index missing).
static func diff(before: Variant, after: Variant, at: String, out: Array[Dictionary]) -> void:
	if typeof(before) != typeof(after):
		out.append({"path": at, "before": before, "after": after})
	elif before is Dictionary:
		for key: Variant in before:
			if (after as Dictionary).has(key):
				diff(before[key], after[key], "%s.%s" % [at, key], out)
			else:
				out.append({"path": "%s.%s" % [at, key], "before": before[key], "after": null})
		for key: Variant in after:
			if not (before as Dictionary).has(key):
				out.append({"path": "%s.%s" % [at, key], "before": null, "after": after[key]})
	elif before is Array:
		for index in maxi(before.size(), after.size()):
			diff(before[index] if index < before.size() else null, after[index] if index < after.size() else null, "%s[%d]" % [at, index], out)
	elif before != after:
		out.append({"path": at, "before": before, "after": after})


static func describe(entry: Dictionary) -> String:
	var shown := func(value: Variant) -> String:
		return "(missing)" if value == null else "%s <%s>" % [JSON.stringify(value, "", true, true), type_string(typeof(value))]
	return "%s: %s -> %s" % [entry.path, shown.call(entry.before), shown.call(entry.after)]


## The rule that accepts a difference of a bag item, or "" (a real difference).
func _accepted(entry: Dictionary, items_before: Array) -> String:
	var before: Variant = entry.before
	var after: Variant = entry.after
	if before is float and after is float and String(entry.path).ends_with(".base_damage") \
			and absf(before - after) <= maxf(absf(before), absf(after)) * FLOAT_PARSE_RELATIVE:
		return "FLOAT_PARSE"
	if before == null and after is Dictionary and String(entry.path).ends_with(".evolution") and after == EVOLUTION_DEFAULT:
		var index := int(String(entry.path).get_slice("[", 1).get_slice("]", 0))
		var item_id := StringName(str((items_before[index] as Dictionary).get("def", "")))
		var definition := db.get_item(item_id)
		if definition != null and ItemStats.evolution_of(definition, db) != null:
			return "EVOLUTION_DEFAULT"
	return ""


## Strict diff of two inventory arrays; prints every difference with its path and values and fails
## on each one no named rule accepts. Returns the accepted rule per path.
func _check_inventory(before: Array, after: Array, at: String) -> Dictionary:
	var out: Array[Dictionary] = []
	diff(before, after, at, out)
	var accepted := {}
	for entry in out:
		var rule := _accepted(entry, before)
		print("  DIFF %s %s" % [describe(entry), "(accepted: %s)" % rule if rule != "" else "(REAL DIFFERENCE)"])
		if rule == "":
			fail("%s changed through save/load: %s" % [at, describe(entry)])
		else:
			accepted[entry.path] = rule
	return accepted


func test_inventory_survives_the_save_pipeline() -> void:
	var original := _character()
	var before_inventory := original.inventory.to_array()
	var before_loadouts := original.equipment.to_dict()
	var result := _roundtrip(original)
	if not check(result.ok(), "loaded: %s" % [result.errors]):
		return
	check(result.warnings.is_empty(), "no load warnings: %s" % [result.warnings])
	var loaded := result.character
	check(loaded.orphaned_items.is_empty(), "no orphaned items")
	var accepted := _check_inventory(before_inventory, loaded.inventory.to_array(), "inventory")
	# the findings of docs/INVENTORY_SAVE_ROUNDTRIP_1_0.md, so a change of either shows up here
	check_eq(accepted, {"inventory[7].base_damage": "FLOAT_PARSE", "inventory[11].evolution": "EVOLUTION_DEFAULT"},
			"exactly the two documented findings (militia sword base damage, stormcaller fang evolution)")
	var loadout_diff: Array[Dictionary] = []
	diff(before_loadouts, loaded.equipment.to_dict(), "loadouts", loadout_diff)
	check(loadout_diff.is_empty(), "loadouts identical: %s" % [loadout_diff.map(describe)])
	check_eq(loaded.inventory.items().size(), original.inventory.items().size(), "item count")
	check(loaded.inventory.integrity_errors().is_empty(), "inventory consistent: %s" % [loaded.inventory.integrity_errors()])
	check(loaded.equipment.integrity_errors().is_empty(), "equipment consistent: %s" % [loaded.equipment.integrity_errors()])
	check_eq(loaded.inventory.used_slots(), original.inventory.used_slots(), "bag slots in use")
	check_eq(loaded.get_stats(), original.get_stats(), "stats rebuilt identically")
	# the accepted differences change nothing the game reads
	for index in original.inventory.items().size():
		var item: ItemInstance = original.inventory.items()[index]
		var after: ItemInstance = loaded.inventory.items()[index]
		check_eq(after.instance_id, item.instance_id, "item %d instance id (order kept)" % index)
		check_eq([after.evolution_stage(), after.evolution_xp(), after.evolution_path()],
				[item.evolution_stage(), item.evolution_xp(), item.evolution_path()], "item %d evolution as read" % index)
		var definition := db.get_item(item.definition_id)
		var damage := WeaponDamage.of(item, definition, db)   # what PlayerProgressionBridge hands to combat
		check_near(WeaponDamage.of(after, definition, db), damage, maxf(1.0, damage) * FLOAT_PARSE_RELATIVE, "item %d weapon damage" % index)
		check_eq(ItemDescriber.text(loaded, after), ItemDescriber.text(original, item), "item %d text the player reads" % index)


## After the first load the data is canonical: a second save/load is bit-identical, without any rule.
func test_second_roundtrip_is_bit_identical() -> void:
	var first := _roundtrip(_character())
	if not check(first.ok(), "first load: %s" % [first.errors]):
		return
	var before := first.character.to_dict()
	var second := _roundtrip(first.character)
	if not check(second.ok(), "second load: %s" % [second.errors]):
		return
	var out: Array[Dictionary] = []
	var playtest := preload("res://tests/playtest/loop_playtest.gd")
	diff(playtest.comparable(before), playtest.comparable(second.character.to_dict()), "character", out)
	for entry in out:
		print("  DIFF ", describe(entry))
	check(out.is_empty(), "second roundtrip identical: %s" % [out.map(describe)])


## Every referenced instance id of every class loadout (active and inactive) resolves to an item
## of the loaded bag, in the same slot, with the same definition.
func test_loadout_references_resolve_after_load() -> void:
	var original := _character()
	var result := _roundtrip(original)
	if not check(result.ok(), "loaded: %s" % [result.errors]):
		return
	var loaded := result.character
	var checked := 0
	for class_id: StringName in [&"basic_adventurer", &"warrior"]:
		for slot: int in S.values():
			var item := original.equipment.get_item(slot, class_id)
			var after := loaded.equipment.get_item(slot, class_id)
			if item == null:
				check(after == null, "%s slot %d stays empty" % [class_id, slot])
				continue
			checked += 1
			if check(after != null, "%s slot %d still holds %s" % [class_id, slot, item.instance_id]):
				check_eq(after.instance_id, item.instance_id, "%s slot %d instance id" % [class_id, slot])
				check_eq(after.definition_id, item.definition_id, "%s slot %d definition" % [class_id, slot])
				check(loaded.inventory.has(after.instance_id), "%s slot %d references a bag item" % [class_id, slot])
	check(checked >= 4, "active and inactive loadouts both hold items (%d references checked)" % checked)
	var generated := original.equipment.get_item(S.MAIN_HAND)
	var after := loaded.equipment.get_item(S.MAIN_HAND)
	if check(generated != null and after != null, "generated main hand present"):
		check_eq(after.rarity, R.RARE, "generated rarity kept on the instance")
		check_eq(after.affixes, generated.affixes, "rolled affixes identical (tier, tier model, stat, value, types)")
		check(not generated.affixes.is_empty(), "the generated weapon has rolled affixes")
		check_eq(after.base_weapon_damage, generated.base_weapon_damage, "stored base damage of the generated weapon bit-identical")
		check_eq(after.item_level, 7, "item level")


## The rpg_playtest compared the whole character dictionary (minus play time and visit counters).
## Same comparison here, through the same pipeline: only the inventory differs, and only by the
## two documented findings.
func test_whole_character_snapshot_as_in_the_playtest() -> void:
	var original := _character()
	var snapshot := original.to_dict()
	var result := _roundtrip(original)
	if not check(result.ok(), "loaded: %s" % [result.errors]):
		return
	var playtest := preload("res://tests/playtest/loop_playtest.gd")
	var before: Dictionary = playtest.comparable(snapshot)
	var after: Dictionary = playtest.comparable(result.character.to_dict())
	var differing: Array[String] = []
	for key: String in before:
		var out: Array[Dictionary] = []
		diff(before[key], after.get(key), key, out)
		if not out.is_empty():
			differing.append(key)
	check_eq(differing, ["inventory"] as Array[String], "only the inventory key differs (as in the old playtest report)")
	_check_inventory(before.inventory, after.inventory, "inventory")
