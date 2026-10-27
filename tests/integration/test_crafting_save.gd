extends TestCase
## Crafting Foundation phase A: crafting state on item instances survives
## save/load exactly (never re-rolled), v2 saves migrate to v3, invalid crafting
## data is repaired without losing anything. Files only under user://test_saves/.

const DIR := "user://test_saves"
const S := EquipSlot.Slot

var db: GameDatabase
var path: String


func before_each() -> void:
	db = GameDatabase.new()
	db.load_all()
	db.register(_test_blade())
	DirAccess.make_dir_recursive_absolute(DIR)
	path = DIR.path_join("crafting_%s.save.json" % IdGenerator.new_id("t"))


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


## Test-only craftable weapon (registered in this test's own database).
func _test_blade() -> ItemDefinition:
	var item := ItemDefinition.new()
	item.id = &"test_craft_blade"
	item.display_name = "Test Blade"
	item.category = ItemDefinition.Category.WEAPON
	item.slot_kind = ItemDefinition.SlotKind.ONE_HAND_WEAPON
	item.weapon_family_id = &"one_handed_sword"
	item.base_stats = [StatModifier.make(Stats.PHYSICAL_DAMAGE, 10.0)] as Array[StatModifier]
	item.crafting = CraftingProfile.new()
	item.crafting.affix_slots = 4
	item.crafting.essence_slots = 2
	item.crafting.socket_slots = 2
	item.crafting.base_item_level = 12
	return item


func _crafted(character: Character) -> ItemInstance:
	var item := character.inventory.add_item(&"test_craft_blade")[0]
	item.quality = 7
	item.material_id = &"storm_ore"
	item.affixes.append({"affix": "keen", "tier": 2, "stat": "crit_chance", "flat": 6.0, "percent": 0.0})
	item.affixes.append({"affix": "sharp", "tier": 3, "stat": "physical_damage", "flat": 0.0, "percent": 9.0})
	item.essences = [&"storm_wolf", &"stone_golem"] as Array[StringName]
	item.sockets = [&"impact_rune", &""] as Array[StringName]
	item.evolution = {"stage": 2, "xp": 140, "path": ""}
	item.revision = 5
	return item


func _write_payload(payload: Dictionary, version: int) -> void:
	var text := JSON.stringify(payload)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": SaveSystem.FORMAT, "version": version, "saved_at": 0, "checksum": text.sha256_text(), "payload": text}))
	file.close()


func test_crafting_state_roundtrip_is_exact() -> void:
	var character := CharacterFactory.create_new(db)
	var item := _crafted(character)
	check_eq(item.item_level, 12, "new instance gets the base item level")
	check_eq(character.equipment.equip(item.instance_id, S.MAIN_HAND), "", "equipped")
	var before := item.to_dict()
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "loaded %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(item.instance_id)
	if not check(loaded != null, "same instance id"):
		return
	check_eq(loaded.to_dict(), before, "all crafting fields identical (nothing re-rolled)")
	check_eq(result.character.equipment.get_item(S.MAIN_HAND), loaded, "loadout still references the instance")
	check(result.character.inventory.integrity_errors().is_empty(), "no duplicates")
	check_eq(result.character.inventory.count(&"test_craft_blade"), 1, "exactly one blade")


func test_quality_scales_base_stats_only() -> void:
	var character := CharacterFactory.create_new(db)
	var item := character.inventory.add_item(&"test_craft_blade")[0]
	var definition := db.get_item(&"test_craft_blade")
	item.quality = 20
	item.affixes.append({"affix": "sharp", "tier": 3, "stat": "physical_damage", "flat": 5.0, "percent": 0.0})
	var flat := 0.0
	for modifier in ItemStats.modifiers(item, definition, db):
		if modifier.stat == Stats.PHYSICAL_DAMAGE:
			flat += modifier.flat
	check_near(flat, 10.0 * 1.1 + 5.0, 0.001, "quality 20 = +10 % on the base value, affix unchanged")
	check_eq(definition.base_stats[0].flat, 10.0, "shared definition untouched")


func test_plain_items_keep_their_stats() -> void:
	var character := CharacterFactory.create_new(db)
	var helm := character.inventory.add_item(&"warden_helm")[0]
	var definition := db.get_item(&"warden_helm")
	var expected := definition.base_stats.size() + helm.affixes.size()
	check_eq(ItemStats.modifiers(helm, definition, db).size(), expected, "non-craftable item: base stats only")
	check_eq(ItemStats.effects(helm, definition, db).size(), definition.effects.size(), "no extra effects")


func test_v2_save_migrates_to_v3() -> void:
	var character := CharacterFactory.create_new(db)
	var sword := character.inventory.add_item(&"iron_sword")[0]
	character.equipment.equip(sword.instance_id, S.MAIN_HAND)
	var payload := character.to_dict()
	# Reproduce a v2 item: no crafting keys, legacy affix, prepared "essence" field.
	for entry: Dictionary in payload.inventory:
		if entry.id == sword.instance_id:
			entry["affixes"] = [{"stat": "crit_chance", "flat": 3.0, "percent": 0.0}]
			entry["essence"] = {"slots": ["storm_wolf"]}
			entry.erase("ilvl")
			entry.erase("quality")
	_write_payload(payload, 2)
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "v2 save loads: %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(sword.instance_id)
	check(loaded != null, "item identity kept")
	check_eq(loaded.item_level, 1, "default item level")
	check_eq(loaded.quality, 0, "default quality")
	check_eq(loaded.affixes[0].get("flat"), 3.0, "legacy affix value kept (not re-rolled)")
	check(loaded.affixes[0].get("legacy", false), "legacy affix marked")
	check_eq(loaded.progress.get("inactive_essences"), ["storm_wolf"], "essence beyond the 0 slots of a plain sword is kept inactive, not lost")
	check_eq(result.character.equipment.get_item(S.MAIN_HAND), loaded, "loadout reference intact")
	check_eq(SaveSystem.save_to(result.character, path), OK, "re-saved")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(int(envelope.version), SaveSystem.VERSION, "written as v%d" % SaveSystem.VERSION)


func test_invalid_crafting_data_is_repaired_without_loss() -> void:
	var character := CharacterFactory.create_new(db)
	var item := character.inventory.add_item(&"test_craft_blade")[0]
	var payload := character.to_dict()
	for entry: Dictionary in payload.inventory:
		if entry.id == item.instance_id:
			entry["quality"] = 99
			entry["essences"] = ["storm_wolf", "stone_golem", "phantom_essence"]
			entry["sockets"] = "broken"
			entry["material"] = 17
	_write_payload(payload, SaveSystem.VERSION)
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "loads: %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(item.instance_id)
	check_eq(loaded.quality, 20, "quality clamped to max")
	check_eq(loaded.essences.size(), 2, "never more than two essences")
	check_eq(loaded.progress.get("inactive_essences"), ["phantom_essence"], "third essence kept inactive")
	check(loaded.sockets.is_empty(), "malformed sockets -> empty")
	check_eq(loaded.material_id, &"", "malformed material -> none")
	check(not result.warnings.is_empty(), "repairs reported")
	# unknown essence ids never crash effect collection
	loaded.essences = [&"phantom_essence"] as Array[StringName]
	check_eq(ItemStats.effects(loaded, db.get_item(&"test_craft_blade"), db).size(), 0, "unknown essence ignored")


## Item Foundation 1.0: v10 affixes come from the three-tier model and are marked
## so (never re-read as five-tier tiers); values and legacy rolls stay untouched.
func test_v10_save_marks_three_tier_affixes() -> void:
	var character := CharacterFactory.create_new(db)
	var blade := character.inventory.add_item(&"test_craft_blade")[0]
	var stored := character.inventory.add_item(&"test_craft_blade")[0]
	var payload := character.to_dict()
	var rolled := {"affix": "sharpened", "tier": 1, "stat": "physical_damage", "flat": 15.0, "percent": 0.0}
	var legacy := {"stat": "crit_chance", "flat": 3.0, "percent": 0.0, "legacy": true}
	var stash_entry: Dictionary = {}
	for entry: Dictionary in payload.inventory:
		if entry.id == blade.instance_id:
			entry["affixes"] = [rolled.duplicate(), legacy.duplicate()]
		if entry.id == stored.instance_id:
			stash_entry = entry.duplicate(true)
			stash_entry["affixes"] = [rolled.duplicate()]
	payload.inventory = payload.inventory.filter(func(e: Dictionary) -> bool: return e.id != stored.instance_id)
	payload["stash"] = {"items": [stash_entry]}
	_write_payload(payload, 10)
	var result := SaveSystem.load_from(path, db)
	if not check(result.ok(), "v10 save loads: %s" % [result.errors]):
		return
	var loaded := result.character.inventory.find(blade.instance_id)
	check_eq(loaded.affixes[0].get("tier_model"), AffixTiers.MODEL_THREE, "rolled affix marked three-tier")
	check_eq(loaded.affixes[0].get("tier"), 1, "tier number kept")
	check_eq(loaded.affixes[0].get("flat"), 15.0, "value kept (nothing re-rolled)")
	check(not loaded.affixes[1].has("tier_model"), "legacy stat roll has no tier and gets no model")
	check_eq(loaded.affixes[1].get("flat"), 3.0, "legacy value kept")
	var in_stash := result.character.stash.find(stored.instance_id)
	check(in_stash != null and in_stash.affixes[0].get("tier_model") == AffixTiers.MODEL_THREE, "stash affixes marked too")
	check(db.affixes[&"sharpened"].tier_of(loaded.affixes[0]) == null, "Loot Foundation 1.0: a three-tier entry keeps its value but is never read as a five-tier tier")
	check_eq(SaveSystem.save_to(result.character, path), OK, "re-saved")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check_eq(int(envelope.version), SaveSystem.VERSION, "written in the current version")
