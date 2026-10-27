extends GameplayTestCase
## Crafting phase E: sockets (open, insert, remove, limits, independent of essence
## slots), Garnet stat bonus, Rune of Impact in real combat, quality upgrades,
## unique limits, class switch and save/load.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const S := EquipSlot.Slot
const SAVE := "user://test_saves/sockets.save.json"

var db: GameDatabase
var character: Character
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(SAVE + suffix)


func _do(operation: StringName, item: ItemInstance, setup: Callable = Callable()) -> CraftingService.Result:
	var request := CraftingRequest.make(operation, item)
	if setup.is_valid():
		setup.call(request)
	return CraftingService.execute(character, request, rng)


func _socketed_blade(socketable: StringName) -> ItemInstance:
	var blade := character.inventory.add_item(&"forged_blade")[0]
	character.inventory.add_item(&"socket_chisel")
	character.inventory.add_item(socketable)
	check(_do(CraftingOps.SOCKET_OPEN, blade).ok, "socket opened")
	check(_do(CraftingOps.SOCKET_INSERT, blade, func(r: CraftingRequest) -> void: r.socketable_id = socketable).ok, "%s socketed" % socketable)
	return blade


func test_open_sockets_up_to_the_limit() -> void:
	var blade := character.inventory.add_item(&"forged_blade")[0]
	var result := _do(CraftingOps.SOCKET_OPEN, blade)
	check(not result.ok and "Socket Chisel" in result.error, "needs a chisel: %s" % result.error)
	character.inventory.add_item(&"socket_chisel", 3)
	check(_do(CraftingOps.SOCKET_OPEN, blade).ok, "socket 1")
	check(_do(CraftingOps.SOCKET_OPEN, blade).ok, "socket 2")
	check(not _do(CraftingOps.SOCKET_OPEN, blade).ok, "limit 2 reached")
	check_eq(character.inventory.count(&"socket_chisel"), 1, "only two chisels used")
	check_eq(blade.sockets.size(), 2, "two empty sockets")
	check(blade.essences.is_empty(), "essence slots untouched (independent systems)")


func test_garnet_bonus_applies_once_and_is_returned_on_removal() -> void:
	var blade := _socketed_blade(&"garnet")
	var base := character.get_stat(Stats.MAX_HEALTH)
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	check_near(character.get_stat(Stats.MAX_HEALTH) - base, 20.0, 0.001, "+20 max health")
	character.equipment.unequip(S.MAIN_HAND)
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	check_near(character.get_stat(Stats.MAX_HEALTH) - base, 20.0, 0.001, "no double application after re-equip")
	character.inventory.add_item(&"garnet")
	check(not _do(CraftingOps.SOCKET_INSERT, blade, func(r: CraftingRequest) -> void:
		r.socketable_id = &"garnet"
		r.slot_index = 0).ok, "filled socket refused")
	check(_do(CraftingOps.SOCKET_REMOVE, blade, func(r: CraftingRequest) -> void: r.slot_index = 0).ok, "removed")
	check_eq(character.inventory.count(&"garnet"), 2, "garnet returned (1 spare + 1 removed)")
	check_eq(blade.sockets, [&""] as Array[StringName], "socket stays open and empty")
	check_near(character.get_stat(Stats.MAX_HEALTH) - base, 0.0, 0.001, "bonus gone")


func test_rune_of_impact_in_combat() -> void:
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	var blade := _socketed_blade(&"impact_rune")
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	check(bridge.effects.has_effect(&"impact_rune"), "rune effect active")
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(24, 0)
	enemy.target = player
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	add_child(enemy)
	await wait_physics(4)
	var start := enemy.global_position.x
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	f.heavy_pressed = true   # tap: uncharged sword heavy, 18 px knockback
	await tick(f)
	await tick(frame(), 70)
	check_near(enemy.global_position.x - start, 18.0 * 1.25, 0.4, "heavy knockback +25 % (18 -> 22.5 px)")


func test_quality_upgrades_base_stats_only() -> void:
	var blade := character.inventory.add_item(&"forged_blade")[0]
	blade.affixes.append({"affix": "sharpened", "tier": 3, "stat": "physical_damage", "flat": 5.0, "percent": 0.0})
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	var before := character.get_stat(Stats.PHYSICAL_DAMAGE)
	check(not _do(CraftingOps.QUALITY, blade).ok, "needs a Forge Crystal")
	character.inventory.add_item(&"forge_crystal", 25)
	for i in 20:
		check(_do(CraftingOps.QUALITY, blade).ok, "quality %d" % (i + 1))
	check_eq(blade.quality, 20, "quality 20")
	var result := _do(CraftingOps.QUALITY, blade)
	check(not result.ok and "Maximum" in result.error, "capped at 20")
	check_eq(character.inventory.count(&"forge_crystal"), 5, "20 crystals used")
	# Weapon Base Damage 1.1: quality works on the stored weapon base only
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE) - before, 0.0, 0.001, "global stats unchanged (affix 5 stays, no global base)")
	check_near(blade.base_weapon_damage, 14.4, 0.0001, "stored raw base unchanged by quality")
	check_near(WeaponDamage.of(blade, db.get_item(&"forged_blade"), db), 14.4 * 1.1, 0.0001, "effective base +10 % (0.5 % per point)")
	check_eq(blade.item_level, 12, "item level independent of quality")


func test_unique_allows_only_its_defined_operations() -> void:
	var oath := character.inventory.add_item(&"crushing_oath")[0]
	character.inventory.add_item(&"socket_chisel", 2)
	character.inventory.add_item(&"forge_crystal")
	check(_do(CraftingOps.QUALITY, oath).ok, "unique: quality allowed")
	check(_do(CraftingOps.SOCKET_OPEN, oath).ok, "unique: one socket allowed")
	check(not _do(CraftingOps.SOCKET_OPEN, oath).ok, "unique socket limit 1")
	check(db.get_item(&"crushing_oath").effects[0] is ComboModifierEffect, "handcrafted core untouched")


func test_sockets_and_quality_survive_class_switch_and_save_load() -> void:
	var blade := _socketed_blade(&"garnet")
	character.inventory.add_item(&"forge_crystal", 3)
	for i in 3:
		_do(CraftingOps.QUALITY, blade)
	character.equipment.equip(blade.instance_id, S.MAIN_HAND)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	check_eq(character.inventory.find(blade.instance_id).sockets, [&"garnet"] as Array[StringName], "class switch keeps the socket content")
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved")
	var loaded := SaveSystem.load_from(SAVE, db).character
	var item := loaded.inventory.find(blade.instance_id)
	check_eq(item.sockets, [&"garnet"] as Array[StringName], "socket persisted")
	check_eq(item.quality, 3, "quality persisted")
	check_near(loaded.get_stat(Stats.MAX_HEALTH), character.get_stat(Stats.MAX_HEALTH), 0.001, "same stats after load")
