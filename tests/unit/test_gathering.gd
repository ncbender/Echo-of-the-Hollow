extends TestCase
## Resource gathering rules (time injected) and forest node data.

const MAP := &"whisper_forest"

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func _def(id: StringName) -> ResourceNodeDefinition:
	return db.resource_nodes[id]


func test_gather_adds_items_and_depletes() -> void:
	var tree := _def(&"oak_tree")
	check_eq(ResourceGathering.gather(character, MAP, &"treea", tree, 1000.0), "", "gathered")
	check_eq(character.inventory.count(&"timber"), tree.yield_quantity, "timber in inventory")
	check(not ResourceGathering.is_available(character.world, MAP, &"treea", 1000.0), "depleted")
	check(ResourceGathering.gather(character, MAP, &"treea", tree, 1001.0) != "", "second gather refused")
	check_eq(character.inventory.count(&"timber"), tree.yield_quantity, "no extra timber")
	check(ResourceGathering.is_available(character.world, MAP, &"treeb", 1000.0), "other nodes unaffected")


func test_respawn_after_fixed_time() -> void:
	var rock := _def(&"forest_rock")
	ResourceGathering.gather(character, MAP, &"rocka", rock, 1000.0)
	check(not ResourceGathering.is_available(character.world, MAP, &"rocka", 1000.0 + rock.respawn_seconds - 1.0), "still depleted 1 s before")
	check(ResourceGathering.is_available(character.world, MAP, &"rocka", 1000.0 + rock.respawn_seconds), "back after respawn time")
	check_eq(ResourceGathering.gather(character, MAP, &"rocka", rock, 1000.0 + rock.respawn_seconds), "", "gather again")
	check_eq(character.inventory.count(&"stone"), rock.yield_quantity * 2, "two yields")


func test_permanent_node_never_returns() -> void:
	var deposit := _def(&"ancient_deposit")
	ResourceGathering.gather(character, MAP, &"deposit", deposit, 1000.0)
	check(not ResourceGathering.is_available(character.world, MAP, &"deposit", 1.0e12), "permanently depleted")
	check(ResourceGathering.seconds_left(character.world, MAP, &"deposit", 1000.0) == INF, "no respawn time")


func test_full_inventory_refuses_without_depleting() -> void:
	character.inventory.capacity = character.inventory.used_slots()
	var vein := _def(&"iron_vein")
	check_eq(ResourceGathering.gather(character, MAP, &"veina", vein, 1000.0), "inventory full", "refused")
	check(ResourceGathering.is_available(character.world, MAP, &"veina", 1000.0), "node not consumed")
	check_eq(character.inventory.count(&"iron_ore"), 0, "nothing added")


func test_node_state_survives_save_load() -> void:
	ResourceGathering.gather(character, MAP, &"deposit", _def(&"ancient_deposit"), 1000.0)
	ResourceGathering.gather(character, MAP, &"treea", _def(&"oak_tree"), 1000.0)
	var path := "user://test_saves/gathering_test.save.json"
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	SaveSystem.save_to(character, path)
	var loaded := SaveSystem.load_from(path, db).character
	check(not ResourceGathering.is_available(loaded.world, MAP, &"deposit", 1.0e12), "permanent depletion saved")
	check(not ResourceGathering.is_available(loaded.world, MAP, &"treea", 1001.0), "respawn timer saved")
	check(ResourceGathering.is_available(loaded.world, MAP, &"treea", 1000.0 + _def(&"oak_tree").respawn_seconds), "respawn timer value intact")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func test_forest_nodes_are_valid_and_unique() -> void:
	var forest: Node = load(db.maps[MAP].scene_path).instantiate()
	var ids := {}
	var kinds := {}
	for node: ResourceNode in forest.find_children("*", "ResourceNode", true, false):
		check(node.definition != null, "%s has a definition" % node.name)
		check(not ids.has(node.node_id), "unique node id %s" % node.node_id)
		ids[node.node_id] = true
		kinds[node.definition.yield_item_id] = true
	check(ids.size() >= 6, "several nodes placed (%d)" % ids.size())
	check(kinds.has(&"timber") and kinds.has(&"stone") and kinds.has(&"iron_ore"), "wood, stone and ore available")
	forest.free()
