extends GameplayTestCase
## Save/load: full roundtrip, reconstruction of derived state, corruption
## handling, backups, invalid references. Uses its own files under
## user://test_saves/ only (never the player's save slot).

const DIR := "user://test_saves"
const S := EquipSlot.Slot

var db: GameDatabase
var path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	DirAccess.make_dir_recursive_absolute(DIR)
	path = DIR.path_join("test_%s.save.json" % IdGenerator.new_id("t"))


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _rich_character() -> Character:
	var character := CharacterFactory.create_new(db)
	character.mastery.add_xp(&"one_handed_sword", 400)
	character.mastery.add_xp(&"two_handed_sword", 90)
	character.add_class_xp(150)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	character.add_class_xp(60)
	for item_id: StringName in [&"warden_helm", &"warden_mail", &"warden_greaves", &"copper_ring", &"oak_shield"]:
		character.equipment.equip(character.inventory.add_item(item_id)[0].instance_id)
	var blade := character.inventory.add_item(&"echo_blade")[0]
	blade.affixes.append({"stat": "crit_chance", "flat": 2.0, "percent": 0.0})
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	character.inventory.add_item(&"iron_ore", 37)
	character.world.set_flag(&"met_the_smith")
	character.world.set_flag(&"arena_visits", 3)
	character.world.spawn_id = &"class_station"
	return character


func _load() -> SaveSystem.LoadResult:
	return SaveSystem.load_from(path, db)


func _write_raw(text: String, target: String = "") -> void:
	var file := FileAccess.open(target if target != "" else path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_full_roundtrip() -> void:
	var original := _rich_character()
	check_eq(SaveSystem.save_to(original, path), OK, "saved")
	check(not FileAccess.file_exists(path + SaveSystem.TEMP_SUFFIX), "no temp file left behind")
	var result := _load()
	if not check(result.ok(), "loaded: %s" % [result.errors]):
		return
	check(result.warnings.is_empty(), "no warnings: %s" % [result.warnings])
	var loaded := result.character
	check_eq(loaded.id, original.id, "character id")
	check_eq(loaded.classes.active_class_id, &"warrior", "active class")
	check_eq(loaded.classes.unlocked_class_ids().size(), 2, "unlocked classes")
	for class_id: StringName in [&"basic_adventurer", &"warrior"]:
		check_eq(loaded.classes.get_level(class_id), original.classes.get_level(class_id), "%s level" % class_id)
		check_eq(loaded.classes.get_xp(class_id), original.classes.get_xp(class_id), "%s xp" % class_id)
	for family: StringName in [&"one_handed_sword", &"two_handed_sword"]:
		check_eq(loaded.mastery.get_level(family), original.mastery.get_level(family), "%s mastery level" % family)
		check_eq(loaded.mastery.get_xp(family), original.mastery.get_xp(family), "%s mastery xp" % family)
	check_eq(loaded.inventory.to_array(), original.inventory.to_array(), "inventory identical (ids, quantities, affixes)")
	check_eq(loaded.equipment.to_dict(), original.equipment.to_dict(), "all class loadouts identical")
	check_eq(loaded.world.to_dict(), original.world.to_dict(), "world state identical")
	check_eq(loaded.get_stats(), original.get_stats(), "stats rebuilt identically")
	check_eq(loaded.active_set_bonuses().size(), 2, "set bonuses reconstructed")
	check(loaded.inventory.integrity_errors().is_empty(), "inventory consistent")
	check(loaded.equipment.integrity_errors().is_empty(), "equipment consistent")


func test_effects_rebuilt_and_class_switch_after_load() -> void:
	SaveSystem.save_to(_rich_character(), path)
	var loaded := _load().character
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, loaded)
	check(bridge.effects.has_effect(&"echo_shockwave"), "legendary effect active after load")
	check(bridge.effects.has_effect(&"wardens_resolve"), "set effect active after load")
	check_eq(player.combat.weapon.id, &"one_handed_sword", "combat weapon from loaded main hand")
	check_near(player.health.max_health, loaded.get_stat(Stats.MAX_HEALTH), 0.001, "player health from loaded stats")
	check_eq(player.combat.mastery_level, loaded.mastery.get_level(&"one_handed_sword"), "mastery gates restored (sword level 4: L-L-L and L-L-H)")
	check(player.combat.chain == "" and player.combat.buffered == "" and not player.combat.is_busy(), "no attack chain, buffer or held key revives after load")
	check_eq(loaded.switch_class(&"basic_adventurer", true), "", "class switch works after load")
	check(not bridge.effects.has_effect(&"echo_shockwave"), "adventurer loadout has no legendary")
	check_eq(loaded.equipment.main_hand_family(), &"one_handed_sword", "adventurer weapon")


func test_missing_file_is_reported() -> void:
	var result := _load()
	check(not result.ok(), "nothing loaded")
	check(not result.errors.is_empty(), "error reported")


func test_corrupted_main_falls_back_to_backup() -> void:
	var character := _rich_character()
	SaveSystem.save_to(character, path)
	character.add_class_xp(5)
	SaveSystem.save_to(character, path)   # second save -> first one becomes .bak
	check(FileAccess.file_exists(path + SaveSystem.BACKUP_SUFFIX), "backup created")
	var text := FileAccess.get_file_as_string(path)
	_write_raw(text.substr(0, text.length() / 2))   # simulate a torn write
	var result := _load()
	check(result.ok(), "recovered")
	check_eq(result.source, "backup", "loaded from backup")
	check(not result.warnings.is_empty(), "recovery reported")
	check(FileAccess.file_exists(path), "damaged main file not deleted")


func test_corruption_without_backup_does_not_crash() -> void:
	_write_raw("{ this is not json")
	var result := _load()
	check(not result.ok(), "refused")
	check(result.errors.size() >= 1, "reported: %s" % [result.errors])


func test_checksum_detects_edits() -> void:
	SaveSystem.save_to(_rich_character(), path)
	var text := FileAccess.get_file_as_string(path)
	var envelope: Dictionary = JSON.parse_string(text)
	envelope.payload = (envelope.payload as String).replace("\"qty\":37", "\"qty\":99")
	_write_raw(JSON.stringify(envelope))
	var result := _load()
	check(not result.ok(), "edited payload refused")
	check("checksum" in "; ".join(result.errors), "checksum error reported")


func test_wrong_format_and_newer_version_refused() -> void:
	_write_raw(JSON.stringify({"format": "other_game", "version": 1, "payload": "{}"}))
	check(not _load().ok(), "foreign file refused")
	var payload := "{}"
	_write_raw(JSON.stringify({"format": SaveSystem.FORMAT, "version": SaveSystem.VERSION + 1, "checksum": payload.sha256_text(), "payload": payload}))
	var result := _load()
	check(not result.ok(), "newer version refused")
	check("newer" in "; ".join(result.errors), "reason given")


func test_invalid_references_are_kept_safe() -> void:
	var character := CharacterFactory.create_new(db)
	var data := character.to_dict()
	(data.inventory as Array).append({"id": "itm_ghost", "def": "removed_from_game", "qty": 1})
	(data.loadouts as Dictionary)["basic_adventurer"]["RING_1"] = "itm_ghost"
	(data.loadouts as Dictionary)["necromancer"] = {"HEAD": "itm_nothing"}
	(data.mastery as Dictionary)["spears"] = {"level": 4, "xp": 3}
	var payload := JSON.stringify(data)
	_write_raw(JSON.stringify({"format": SaveSystem.FORMAT, "version": SaveSystem.VERSION, "checksum": payload.sha256_text(), "payload": payload}))
	var result := _load()
	if not check(result.ok(), "loads despite invalid references: %s" % [result.errors]):
		return
	var loaded := result.character
	check(result.warnings.size() >= 3, "problems reported: %s" % [result.warnings])
	check_eq(loaded.orphaned_items.size(), 1, "unknown item preserved as orphan")
	check_eq(loaded.equipment.get_item(S.RING_1), null, "dangling loadout reference dropped")
	check(loaded.equipment.integrity_errors().is_empty(), "equipment consistent")
	check_eq(SaveSystem.save_to(loaded, path), OK, "re-save")
	var again := _load().character
	check_eq(again.orphaned_items.size(), 1, "orphan survives the next save")
	check(again.mastery.to_dict().has("spears"), "unknown mastery family preserved")


func test_stray_temp_file_is_ignored() -> void:
	SaveSystem.save_to(_rich_character(), path)
	_write_raw("garbage from a crashed save", path + SaveSystem.TEMP_SUFFIX)
	check(_load().ok(), "valid main save still loads")
	check_eq(SaveSystem.save_to(_rich_character(), path), OK, "next save overwrites the stray temp file")
	check(not FileAccess.file_exists(path + SaveSystem.TEMP_SUFFIX), "temp cleaned by successful save")


func test_session_save_path_is_separate_from_user_slot() -> void:
	var session := SessionState.find(get_tree())
	check(session != null, "session autoload present")
	check_eq(SessionState.DEFAULT_SAVE_PATH, "user://saves/slot_1.save.json", "player slot path")
	check(not path.begins_with("user://saves/"), "tests never touch the player slot")


## Weapon Mastery 1.4 (one weapon slot): an older save with a weapon in the off
## hand loads with that reference dropped - the weapon stays in the bag, the
## save schema is unchanged; all nine families' mastery survives the round trip.
func test_off_hand_weapon_from_older_save_and_nine_families() -> void:
	var character := CharacterFactory.create_new(db)
	var spare := character.inventory.add_item(&"militia_sword")[0]
	character.equipment.active_loadout().set_id(S.OFF_HAND, spare.instance_id)   # as dual wield allowed before
	for family_id: StringName in db.weapons:
		character.mastery.add_xp(family_id, 150)
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := _load()
	check(result.ok(), "loaded")
	var loaded := result.character
	check_eq(loaded.equipment.get_item(S.OFF_HAND), null, "the off-hand weapon reference is dropped")
	check(loaded.inventory.has(spare.instance_id), "the weapon itself stays in the bag")
	check(loaded.equipment.get_item(S.MAIN_HAND) != null, "the main hand is untouched")
	for family_id: StringName in db.weapons:
		check_eq(loaded.mastery.get_level(family_id), 2, "%s mastery level kept" % family_id)
	check_eq(SaveSystem.VERSION, 10, "no schema change: save version stays 10")
