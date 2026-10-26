class_name GameMap
extends Node2D
## Base script of every playable map: binds the session character to the map's
## Player, places it at the requested spawn point and handles the input that
## is the same on every map (interact, save, load, debug hotkeys).

@export var map_id: StringName = &"test_arena"
## Debug enemy spawns (F2) stay inside this rectangle.
@export var spawn_area: Rect2 = Rect2(-280, -160, 560, 320)

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const DEBUG_MASTERY_XP := 100
const DEBUG_CLASS_XP := 100
## F7 debug kit: one of every equippable test item plus building materials.
const DEBUG_MATERIALS := {&"iron_ore": 10, &"timber": 10, &"stone": 10}
## F4 crafting kit: craftable bases + crafting materials (Resonance Forge vertical slice).
const DEBUG_CRAFTING_ITEMS := {
	&"forged_blade": 1, &"forged_greatsword": 1, &"stormcaller_fang": 1,
	&"blood_steel_ingot": 6, &"storm_ore": 6, &"frost_glass": 6, &"imprint_shard": 10,
	&"transmute_core": 6, &"focus_catalyst": 3, &"storm_wolf_essence": 1, &"stone_golem_essence": 1,
	&"essence_siphon": 1, &"socket_chisel": 3, &"garnet": 1, &"impact_rune": 1, &"forge_crystal": 10,
	&"awakening_stone": 1, &"hollow_essence": 5,
}

var session: SessionState
var bridge: PlayerProgressionBridge

@onready var player: Player = $Player
@onready var hud: GameHud = $GameHud


func _ready() -> void:
	session = SessionState.find(get_tree())
	if session == null:
		return
	var character := session.get_character()
	var spawn_id := session.consume_pending_spawn()
	if spawn_id == &"":
		spawn_id = character.world.spawn_id if character.world.map_id == map_id else &"default"
	place_player(spawn_id)
	_remove_taken_pickups(character)
	character.world.map_id = map_id
	character.world.spawn_id = spawn_id
	character.world.set_map_value(map_id, "visits", int(character.world.get_map_value(map_id, "visits", 0)) + 1)
	bridge = session.bind_player(player)
	hud.setup(bridge)
	session.message.connect(hud.notify)
	for text in session.consume_messages():
		hud.notify(text)
	_wire_hitstop()
	_remove_defeated_enemies(character)
	session.map_ready()


## Local hitstop for the player and every enemy placed in the map.
func _wire_hitstop() -> void:
	var hitstop := get_node_or_null("HitstopController") as HitstopController
	if hitstop != null:
		hitstop.camera = player.get_node_or_null("Camera2D") as CameraShake
		hitstop.watch(player.combat)
	for node in find_children("*", "Enemy", true, false):
		register_enemy(node as Enemy)


## Hooks an enemy into map services: local hitstop and item drops on death.
func register_enemy(enemy: Enemy) -> void:
	var hitstop := get_node_or_null("HitstopController") as HitstopController
	if hitstop != null:
		hitstop.watch(enemy.combat)
	if not enemy.defeated.is_connected(_spawn_drops):
		enemy.defeated.connect(_spawn_drops)
	if enemy.persistent_id != &"" and not enemy.defeated.is_connected(_on_persistent_enemy_defeated):
		enemy.defeated.connect(_on_persistent_enemy_defeated)


static func defeat_flag(enemy: Enemy) -> StringName:
	return StringName("defeated.%s" % enemy.persistent_id)


func _on_persistent_enemy_defeated(enemy: Enemy) -> void:
	if session != null:
		session.get_character().world.set_flag(defeat_flag(enemy))


## Boss/quest enemies that were defeated before stay gone.
func _remove_defeated_enemies(character: Character) -> void:
	for node in find_children("*", "Enemy", true, false):
		var enemy := node as Enemy
		if enemy.persistent_id != &"" and character.world.has_flag(defeat_flag(enemy)):
			enemy.queue_free()


func spawn_pickup(item_id: StringName, quantity: int, at: Vector2) -> ItemPickup:
	var pickup := ItemPickup.new()
	pickup.item_id = item_id
	pickup.quantity = quantity
	pickup.position = at
	add_child.call_deferred(pickup)
	return pickup


func _spawn_drops(enemy: Enemy) -> void:
	var offset := 0.0
	for drop in enemy.config.drops:
		spawn_pickup(drop.item_id, drop.quantity, enemy.global_position + Vector2(offset - 6.0, 6.0))
		offset += 12.0


## Persistent pickups that were already taken (world flag) never come back.
func _remove_taken_pickups(character: Character) -> void:
	for node in find_children("*", "ItemPickup", true, false):
		var pickup := node as ItemPickup
		if pickup.persistent_id != &"" and character.world.has_flag(pickup.flag_name()):
			pickup.queue_free()


## Moves the player to the spawn point `spawn_id` (fallback: "default", then
## the scene position). Returns false if the requested id did not exist.
func place_player(spawn_id: StringName) -> bool:
	var target := find_spawn(spawn_id)
	var found := target != null
	if target == null:
		target = find_spawn(&"default")
	if target != null:
		player.global_position = target.global_position
	player.set_spawn_position(player.global_position)
	player.reset_physics_interpolation()
	return found


func find_spawn(spawn_id: StringName) -> SpawnPoint:
	for node in find_children("*", "SpawnPoint", true, false):
		var point := node as SpawnPoint
		if point.spawn_id == spawn_id:
			return point
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _handle_debug_input(event):
		return
	if event.is_action_pressed(&"interact"):
		if hud.is_window_open():
			hud.close_windows()
		else:
			var target := Interactable.find_active(get_tree())
			if target != null:
				target.interact(hud)
	elif event.is_action_pressed(&"debug_save") and session != null:
		var error := session.save_game()
		hud.notify("Saved to %s" % session.save_path if error == OK else "SAVE FAILED: %s" % error_string(error))
	elif event.is_action_pressed(&"debug_load") and session != null:
		session.load_game()


## Developer hotkeys (F-keys only, never gameplay keys). Returns true if handled.
func _handle_debug_input(event: InputEvent) -> bool:
	if event.is_action_pressed(&"debug_toggle_hitboxes"):
		DebugView.show_hitboxes = not DebugView.show_hitboxes
	elif event.is_action_pressed(&"debug_spawn_enemy"):
		spawn_enemy(_random_spawn_point())
	elif event.is_action_pressed(&"debug_add_mastery_xp") and bridge != null:
		bridge.debug_add_mastery_xp(DEBUG_MASTERY_XP)
		hud.notify("+%d mastery XP (debug)" % DEBUG_MASTERY_XP)
	elif event.is_action_pressed(&"debug_add_class_xp") and bridge != null:
		bridge.character.add_class_xp(DEBUG_CLASS_XP)
		hud.notify("+%d class XP (debug)" % DEBUG_CLASS_XP)
	elif event.is_action_pressed(&"debug_spawn_items") and bridge != null:
		hud.notify("Debug item kit: %d items added" % give_debug_items(bridge.character))
	elif event.is_action_pressed(&"debug_crafting_kit") and bridge != null:
		hud.notify("Debug crafting kit: %d stacks added" % give_crafting_kit(bridge.character))
	elif event.is_action_pressed(&"debug_reset_arena"):
		get_tree().reload_current_scene()
	else:
		return false
	return true


## Debug spawning (F2). Returns the spawned enemy.
func spawn_enemy(at: Vector2) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	var parent := get_node_or_null("Enemies")
	(parent if parent != null else self).add_child(enemy)
	register_enemy(enemy)
	return enemy


## Gives every equippable item definition once plus materials. Returns the
## number of instances added (stops silently when the inventory is full).
static func give_debug_items(character: Character) -> int:
	var added := 0
	var ids: Array = character.database.items.keys()
	ids.sort()
	for item_id: StringName in ids:
		if character.database.get_item(item_id).is_equippable():
			added += character.inventory.add_item(item_id, 1).size()
	for item_id: StringName in DEBUG_MATERIALS:
		if character.database.get_item(item_id) != null:
			added += character.inventory.add_item(item_id, DEBUG_MATERIALS[item_id]).size()
	return added


func _random_spawn_point() -> Vector2:
	# Random point at a fair distance from the player, inside the map.
	for attempt in 10:
		var point := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(110.0, 170.0)
		if spawn_area.has_point(point):
			return point
	return spawn_area.get_center()


## Debug crafting kit (F4). Returns the number of added stacks; items that do
## not fit into the inventory are skipped (never partially added).
static func give_crafting_kit(character: Character) -> int:
	var added := 0
	for item_id: StringName in DEBUG_CRAFTING_ITEMS:
		if character.database.get_item(item_id) != null:
			added += character.inventory.add_item(item_id, DEBUG_CRAFTING_ITEMS[item_id]).size()
	return added
