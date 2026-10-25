class_name GameplayTestCase
extends TestCase
## Test base that spawns the real player scene and drives it tick by tick
## with scripted InputFrames (fixed delta, independent of real time).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WALL_SCRIPT: GDScript = preload("res://scripts/arena/wall_block.gd")

var player: Player


func spawn_player(at: Vector2 = Vector2.ZERO) -> Player:
	player = PLAYER_SCENE.instantiate()
	player.position = at
	add_child(player)
	player.set_physics_process(false)
	player.use_external_input = true
	return player


func add_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = WALL_SCRIPT.new()
	wall.size = size
	wall.position = at
	add_child(wall)
	return wall


func frame(move: Vector2 = Vector2.ZERO, aim: Vector2 = Vector2.RIGHT) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.aim_direction = aim.normalized()
	return f


## Runs `count` player ticks with `f`. Edge flags only apply to the first tick.
func tick(f: InputFrame, count: int = 1) -> void:
	for i in count:
		player.physics_step(f, FRAME)
		f.clear_edges()
		await get_tree().physics_frame


func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds / FRAME)
