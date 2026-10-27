class_name ItemPickup
extends Area2D
## Item lying in the world. Touching it moves it into the toucher's character
## inventory (via the Player's ProgressionBridge). If the inventory has no room
## it stays on the ground - items are never destroyed by a failed pickup.

signal picked_up(item_id: StringName, quantity: int)

@export var item_id: StringName
@export var quantity: int = 1
## Non-empty for pickups placed in a map: once taken, a world flag remembers it
## so reloading the map or a save can never hand out the same item again.
## Empty for transient pickups (enemy drops).
@export var persistent_id: StringName

## Hollowwood Loot Integration 1.0: a generated instance (equipment drop) handed over exactly as
## it is - level, rarity, base damage and affixes are never rolled again. Null = a plain
## item_id/quantity pickup, created by Inventory.add_item.
var item: ItemInstance

var _taken: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	monitoring = true
	monitorable = false
	if get_child_count() == 0:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)
	body_entered.connect(_on_body_entered)


## Tries to give the item to `player`. Returns true when it was picked up.
func try_pick_up(player: Node) -> bool:
	if _taken:
		return false
	var bridge := player.get_node_or_null("ProgressionBridge") as PlayerProgressionBridge
	if bridge == null or not bridge.is_bound():
		return false
	var inventory := bridge.character.inventory
	var added := inventory.add_instance(item) == "" if item != null \
		else not inventory.add_item(item_id, quantity, ItemInstance.ORIGIN_FOUND).is_empty()
	if not added:
		bridge.message.emit("Inventory full - %s stays on the ground" % _name())
		return false
	_taken = true
	if persistent_id != &"":
		bridge.character.world.set_flag(flag_name())
	bridge.item_received.emit(item_id, quantity)   # HUD loot feed (icon, rarity, amount)
	picked_up.emit(item_id, quantity)
	queue_free()
	return true


func flag_name() -> StringName:
	return StringName("pickup_taken.%s" % persistent_id)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		try_pick_up(body)


func _name() -> String:
	var definition := GameDatabase.get_default().get_item(item_id)
	return definition.display_name if definition != null else String(item_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var definition := GameDatabase.get_default().get_item(item_id)
	var rarity: int = item.effective_rarity(definition) if item != null else (definition.rarity if definition != null else -1)
	var color: Color = ItemDefinition.RARITY_COLORS.get(rarity, Color.WHITE)
	var bob := sin(Time.get_ticks_msec() * 0.005) * 1.5
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4, -1), Vector2(0, 4), Vector2(-4, -1)]), color)
	draw_polyline(PackedVector2Array([Vector2(0, -6), Vector2(4, -1), Vector2(0, 4), Vector2(-4, -1), Vector2(0, -6)]), Color(1, 1, 1, 0.7), 1.0)
