extends GameplayTestCase
## World pickups and enemy drops move items into the character inventory safely.

const PICKUP_SCRIPT: GDScript = preload("res://scripts/world/item_pickup.gd")

var character: Character


func before_each() -> void:
	character = Character.new(GameDatabase.get_default())


func _bind() -> void:
	spawn_player()
	var bridge := PlayerProgressionBridge.new()
	bridge.name = "ProgressionBridge"
	player.add_child(bridge)
	bridge.bind(player, character)


func _pickup(item_id: StringName, quantity: int, at: Vector2) -> ItemPickup:
	var pickup: ItemPickup = PICKUP_SCRIPT.new()
	pickup.item_id = item_id
	pickup.quantity = quantity
	pickup.position = at
	add_child(pickup)
	return pickup


func test_walking_over_pickup_adds_item_once() -> void:
	_bind()
	var pickup := _pickup(&"copper_ring", 1, Vector2(30, 0))
	await wait_physics(2)
	await tick(frame(Vector2.RIGHT), 20)
	await wait_physics(2)
	check_eq(character.inventory.count(&"copper_ring"), 1, "ring picked up")
	check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "pickup removed")
	await tick(frame(Vector2.LEFT), 20)
	await tick(frame(Vector2.RIGHT), 20)
	check_eq(character.inventory.count(&"copper_ring"), 1, "no second copy")


func test_full_inventory_leaves_item_on_ground() -> void:
	_bind()
	character.inventory.capacity = 1
	character.inventory.add_item(&"iron_sword")
	var pickup := _pickup(&"leather_cap", 1, Vector2.ZERO)
	await wait_physics(3)
	check(not pickup.try_pick_up(player), "refused while full")
	check(is_instance_valid(pickup) and not pickup.is_queued_for_deletion(), "pickup stays in the world")
	check_eq(character.inventory.count(&"leather_cap"), 0, "not added")
	character.inventory.capacity = 2
	check(pickup.try_pick_up(player), "picked up once there is room")
	check(not pickup.try_pick_up(player), "cannot be picked up twice")
	check_eq(character.inventory.count(&"leather_cap"), 1, "exactly one")


func test_enemy_drops_spawn_pickups_in_arena() -> void:
	var arena: Node2D = load("res://scenes/arena/test_arena.tscn").instantiate()
	add_child(arena)
	await wait_physics(1)
	var enemy: Enemy = arena.call(&"spawn_enemy", Vector2(100, -150))
	var before := arena.find_children("*", "ItemPickup", true, false).size()
	enemy.defeated.emit(enemy)
	await wait_physics(2)
	var after := arena.find_children("*", "ItemPickup", true, false).size()
	check_eq(after - before, enemy.config.drops.size(), "one pickup per drop entry")
	arena.queue_free()
