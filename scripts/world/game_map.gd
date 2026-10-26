class_name GameMap
extends Node2D
## Base script of every playable map: binds the session character to the map's
## Player, places it at the requested spawn point and handles the input that
## is the same on every map (interact, save, load). Map-specific debug tools
## live in subclasses (test arena).

@export var map_id: StringName = &"test_arena"

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
	bridge = session.bind_player(player)
	hud.setup(bridge)
	session.message.connect(hud.notify)
	for text in session.consume_messages():
		hud.notify(text)


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
