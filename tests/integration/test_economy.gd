extends TestCase
## Hollowwood Loot Economy 1.0 (controlled foundation): sell value = base value
## x rarity factor; Unique / Set only with their own value; gold, quest items
## and items without a designed base value are never sold; selling respects
## every protection and is one transaction; the economy simulation finds no
## material, gold or XP loop and lists the values the design has not set; a
## defeated persistent enemy (Grove Warden) never comes back through save/load.
## Only user://test_saves/.

const DIR := "user://test_saves/economy"
const PATH := DIR + "/slot_1.save.json"
const REPORT := "res://tests/output/economy_report.txt"

var db: GameDatabase
var session: SessionState
var character: Character
var _previous: Character
var _previous_path: String
var _test_items: Array[StringName] = []


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	character = CharacterFactory.create_new(db)
	character.world.set_flag(&"prologue.haven_discovered")
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for id in _test_items:
		db.items.erase(id)
	_test_items.clear()
	for path in [PATH] + SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


## Test-only item with a base value (the design has none yet).
func _valued(rarity: int, base: int, special: int = 0) -> ItemInstance:
	var id := StringName("test_valued_%d_%d_%d" % [rarity, base, special])
	if not db.items.has(id):
		var definition := ItemDefinition.new()
		definition.id = id
		definition.display_name = "Test Valuable"
		definition.category = ItemDefinition.Category.ARMOR
		definition.slot_kind = ItemDefinition.SlotKind.HEAD
		definition.rarity = rarity
		definition.base_value = base
		definition.special_sell_value = special
		db.items[id] = definition
		_test_items.append(id)
	return character.inventory.add_item(id, 1, ItemInstance.ORIGIN_FOUND)[0]


func test_sell_value_formula() -> void:
	var expected := [100, 160, 250, 400, 700]
	for rarity in 5:
		var item := _valued(rarity, 100)
		check_eq(EconomyService.sell_value(character, item.instance_id), expected[rarity], "%s: 100 x factor" % UiTheme.rarity_name(rarity))
	check_eq(EconomyService.unit_value(db, db.get_item(&"gold_coin")), 0, "gold is not sold")
	check_eq(EconomyService.unit_value(db, db.get_item(&"old_key")), 0, "quest items are not sold")
	check_eq(EconomyService.unit_value(db, db.get_item(&"leather_cap")), 0, "no base value designed: not sellable")
	var unique := _valued(ItemDefinition.Rarity.UNIQUE, 500)
	check_eq(EconomyService.sell_value(character, unique.instance_id), 0, "unique without its own value: never sold (base x factor not used)")
	var set_piece := _valued(ItemDefinition.Rarity.SET, 500, 900)
	check_eq(EconomyService.sell_value(character, set_piece.instance_id), 900, "set item: its own value")


func test_selling_is_protected_and_atomic() -> void:
	var item := _valued(ItemDefinition.Rarity.RARE, 40)
	var gold := character.inventory.count(&"gold_coin")
	ItemProtection.set_locked(character, item.instance_id, true)
	check(EconomyService.sell(character, item.instance_id).error.contains("locked"), "locked: refused")
	ItemProtection.set_locked(character, item.instance_id, false)
	ItemProtection.set_favorite(character, item.instance_id, true)
	check(EconomyService.sell(character, item.instance_id).error.contains("favourite"), "favourite: refused")
	ItemProtection.set_favorite(character, item.instance_id, false)
	character.equipment.equip(item.instance_id)
	check(EconomyService.sell(character, item.instance_id).error.contains("sold"), "equipped: refused")
	character.equipment.unequip(character.equipment.active_loadout().slot_of(item.instance_id))
	check_eq(character.inventory.count(&"gold_coin"), gold, "no gold from refusals")
	var results: Array[String] = []
	for i in 3:
		results.append(EconomyService.sell(character, item.instance_id).error)
	check_eq(results.count(""), 1, "sold once out of three clicks")
	check_eq(character.inventory.count(&"gold_coin"), gold + 100, "40 x 2.5 = 100 gold")
	check(character.inventory.find(item.instance_id) == null, "item gone")
	var set_piece := _valued(ItemDefinition.Rarity.SET, 0, 300)
	ItemProtection.set_locked(character, set_piece.instance_id, true)
	check(EconomyService.sell(character, set_piece.instance_id).error != "", "a locked set item stays")


func test_simulation_finds_no_loops() -> void:
	var result := EconomySimulation.run(db)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	file.store_string("\n".join(result.lines))
	file.close()
	check((result.findings as PackedStringArray).is_empty(), "no material / gold / XP loop: %s" % [result.findings])
	check(not (result.open as PackedStringArray).is_empty(), "missing design values are reported, not guessed: %s" % [result.open])
	# with test base values on every raw material and output, crafting then selling still cannot loop:
	# gold never buys items back (no vendor), so the report stays clean
	check(" ".join(result.lines).contains("gold -> items: impossible"), "no gold -> item path")


func test_defeated_boss_stays_gone_after_save_and_load() -> void:
	character.world.map_id = &"whisper_forest"
	get_tree().change_scene_to_file("res://scenes/maps/whisper_forest.tscn")
	var map: GameMap = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	var warden: Enemy = null
	for node in map.find_children("*", "Enemy", true, false):
		if (node as Enemy).persistent_id == &"whisper_forest_grove_warden":
			warden = node
	if not check(warden != null, "Grove Warden placed"):
		return
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	warden.health.apply_hit(lethal)
	for i in 3:
		await get_tree().physics_frame
	check(character.world.has_flag(&"defeated.whisper_forest_grove_warden"), "defeat flag set")
	var pickups := map.find_children("*", "ItemPickup", true, false).size()
	check(pickups > 0, "its loot lies on the ground")
	var gold := character.inventory.count(&"gold_coin")
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved (loot not picked up)")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	session.set_character(loaded.character)
	character = loaded.character
	get_tree().change_scene_to_file("res://scenes/maps/whisper_forest.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame
	var again := map.find_children("*", "Enemy", true, false).filter(func(e: Enemy) -> bool: return e.persistent_id == &"whisper_forest_grove_warden" and not e.is_queued_for_deletion())
	check(again.is_empty(), "the warden does not come back")
	check_eq(character.inventory.count(&"gold_coin"), gold, "loading grants no reward")
