extends TestCase
## Inventory: stacks, capacity, removal, identity, invalid data, transfers, persistence.

var db: GameDatabase


func before_each() -> void:
	db = GameDatabase.get_default()


func _inventory(capacity: int = 10) -> Inventory:
	return Inventory.new(db, capacity)


func _integrity(inventory: Inventory, label: String) -> void:
	var errors := inventory.integrity_errors()
	check(errors.is_empty(), "%s: %s" % [label, errors])


func test_stackable_items_fill_stacks_then_new_slots() -> void:
	var inventory := _inventory()
	check_eq(inventory.add_item(&"iron_ore", 30).size(), 1, "one stack")
	check_eq(inventory.add_item(&"iron_ore", 30).size(), 2, "fills stack to 50, opens second")
	check_eq(inventory.count(&"iron_ore"), 60, "total count")
	check_eq(inventory.used_slots(), 2, "two slots")
	var quantities: Array[int] = []
	for item in inventory.items():
		quantities.append(item.quantity)
	quantities.sort()
	check_eq(quantities, [10, 50] as Array[int], "max stack respected")
	_integrity(inventory, "after stacking")


func test_non_stackable_items_get_unique_instances() -> void:
	var inventory := _inventory()
	var added := inventory.add_item(&"iron_sword", 3)
	check_eq(added.size(), 3, "three instances")
	check_eq(inventory.used_slots(), 3, "three slots")
	var ids := {}
	for item in added:
		ids[item.instance_id] = true
		check_eq(item.quantity, 1, "quantity 1")
	check_eq(ids.size(), 3, "unique instance ids")


func test_full_inventory_is_all_or_nothing() -> void:
	var inventory := _inventory(2)
	inventory.add_item(&"iron_sword", 2)
	check(inventory.is_full(), "full")
	check(inventory.add_item(&"leather_cap").is_empty(), "no room for a new item")
	check(inventory.add_item(&"iron_ore", 5).is_empty(), "no room for a new stack")
	check_eq(inventory.used_slots(), 2, "unchanged")
	var stacks := _inventory(1)
	stacks.add_item(&"iron_ore", 45)
	check(stacks.add_item(&"iron_ore", 10).is_empty(), "10 do not fit (only 5 room): nothing added")
	check_eq(stacks.count(&"iron_ore"), 45, "partial add did not happen")
	check_eq(stacks.add_item(&"iron_ore", 5).size(), 1, "exact fit works")


func test_remove_quantity_is_atomic_and_never_negative() -> void:
	var inventory := _inventory()
	inventory.add_item(&"timber", 50)
	inventory.add_item(&"timber", 7)
	check(not inventory.remove_quantity(&"timber", 100), "not enough: refused")
	check_eq(inventory.count(&"timber"), 57, "unchanged after refusal")
	check(not inventory.remove_quantity(&"timber", -3), "negative refused")
	check(not inventory.remove_quantity(&"timber", 0), "zero refused")
	check(inventory.remove_quantity(&"timber", 20), "removal across stacks")
	check_eq(inventory.count(&"timber"), 37, "remaining")
	check_eq(inventory.used_slots(), 1, "emptied stack removed")
	_integrity(inventory, "after removal")


func test_take_and_set_quantity_bounds() -> void:
	var inventory := _inventory()
	var stack := inventory.add_item(&"minor_potion", 5)[0]
	check(not inventory.take(stack.instance_id, 6), "cannot take more than present")
	check(not inventory.take(stack.instance_id, -1), "negative take refused")
	check(inventory.take(stack.instance_id, 2), "take 2")
	check_eq(stack.quantity, 3, "quantity reduced")
	check(not inventory.set_quantity(stack.instance_id, 0), "zero refused")
	check(not inventory.set_quantity(stack.instance_id, 11), "above max stack refused")
	check(inventory.set_quantity(stack.instance_id, 10), "set to max")
	check(inventory.take(stack.instance_id, 10), "take all")
	check(not inventory.has(stack.instance_id), "empty stack removed")


func test_invalid_definitions_are_rejected() -> void:
	var inventory := _inventory()
	check(inventory.add_item(&"does_not_exist").is_empty(), "unknown id via add_item")
	check(inventory.add_instance(ItemInstance.create(&"does_not_exist")) != "", "unknown id via add_instance")
	check(inventory.add_instance(ItemInstance.create(&"iron_sword", 2)) != "", "non-stackable with quantity 2")
	check(inventory.add_instance(ItemInstance.create(&"iron_ore", 0)) != "", "zero quantity")
	check(inventory.add_instance(null) != "", "null")
	check_eq(inventory.used_slots(), 0, "nothing added")


func test_instance_identity_and_no_duplicates() -> void:
	var inventory := _inventory()
	var sword := inventory.add_item(&"iron_sword")[0]
	check(inventory.find(sword.instance_id) == sword, "find returns the same object")
	check(inventory.add_instance(sword) != "", "same instance cannot be added twice")
	var clone := ItemInstance.create(&"iron_sword", 1, sword.instance_id)
	check(inventory.add_instance(clone) != "", "different object with same id refused")
	check_eq(inventory.used_slots(), 1, "still one item")


func test_transfer_keeps_identity_and_never_loses_or_copies() -> void:
	var source := _inventory()
	var target := _inventory(1)
	var sword := source.add_item(&"iron_sword")[0]
	check_eq(source.transfer_to(target, sword.instance_id), "", "transfer ok")
	check(not source.has(sword.instance_id) and target.find(sword.instance_id) == sword, "moved, same instance")
	var cap := source.add_item(&"leather_cap")[0]
	check(source.transfer_to(target, cap.instance_id) != "", "full target refused")
	check(source.has(cap.instance_id), "item stays in source on failure")
	check(not target.has(cap.instance_id), "no copy in target")
	check(source.transfer_to(target, "missing") != "", "unknown id refused")
	_integrity(source, "source")
	_integrity(target, "target")


func test_random_operations_keep_invariants() -> void:
	var inventory := _inventory(12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ids: Array = [&"iron_ore", &"timber", &"minor_potion", &"iron_sword", &"copper_ring"]
	for i in 500:
		var item_id: StringName = ids[rng.randi() % ids.size()]
		match rng.randi() % 4:
			0:
				inventory.add_item(item_id, rng.randi_range(-2, 30))
			1:
				inventory.remove_quantity(item_id, rng.randi_range(-2, 30))
			2:
				var items := inventory.items()
				if not items.is_empty():
					inventory.take(items[rng.randi() % items.size()].instance_id, rng.randi_range(-1, 20))
			3:
				var items := inventory.items()
				if not items.is_empty():
					inventory.remove_instance(items[rng.randi() % items.size()].instance_id)
		if not inventory.integrity_errors().is_empty():
			fail("invariant broken at step %d: %s" % [i, inventory.integrity_errors()])
			return


func test_serialization_roundtrip_and_orphans() -> void:
	var inventory := _inventory()
	var sword := inventory.add_item(&"iron_sword")[0]
	sword.affixes.append({"stat": "physical_damage", "flat": 3.0, "percent": 0.0})
	inventory.add_item(&"iron_ore", 12)
	var data := inventory.to_array()
	data.append({"id": "itm_ghost", "def": "removed_item", "qty": 1})
	data.append({"garbage": true})
	var restored := _inventory()
	var warnings: PackedStringArray = []
	var orphans := []
	restored.from_array(data, warnings, orphans)
	check_eq(restored.used_slots(), 2, "valid items restored")
	check(restored.find(sword.instance_id) != null, "instance id preserved")
	check_eq(restored.find(sword.instance_id).affixes.size(), 1, "affixes preserved")
	check_eq(restored.count(&"iron_ore"), 12, "stack preserved")
	check_eq(orphans.size(), 2, "unknown and broken entries kept as orphans")
	check_eq(warnings.size(), 2, "warnings for both")


func test_new_character_has_starting_items() -> void:
	var character := CharacterFactory.create_new(db)
	for entry in db.rules.starting_items:
		check_eq(character.inventory.count(entry.item_id), entry.quantity, "starting item %s" % entry.item_id)
