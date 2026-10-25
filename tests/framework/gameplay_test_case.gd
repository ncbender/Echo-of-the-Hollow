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


# --- Combat helpers ---------------------------------------------------------

const SWORD: WeaponFamily = preload("res://data/weapons/one_handed_sword.tres")

## Hits received by targets created with add_target().
var hits: Array[HitData] = []
var started_attacks: Array[StringName] = []


## A bare CombatComponent without body or hitbox: pure action-layer logic.
func new_combat(weapon: WeaponFamily = SWORD) -> CombatComponent:
	var combat := CombatComponent.new()
	add_child(combat)
	combat.set_weapon(weapon)
	combat.attack_started.connect(func(attack: AttackDefinition, _tier: int) -> void:
		started_attacks.append(attack.id))
	return combat


func step_combat(combat: CombatComponent, f: InputFrame, count: int = 1, blocked: bool = false) -> void:
	for i in count:
		combat.step(FRAME, f, f.aim_direction, blocked)
		f.clear_edges()


## Tracks attack starts of the spawned player.
func track_player_attacks() -> void:
	player.combat.attack_started.connect(func(attack: AttackDefinition, _tier: int) -> void:
		started_attacks.append(attack.id))


func add_target(at: Vector2, radius: float = 8.0, team: StringName = &"enemy") -> Hurtbox:
	var holder := Node2D.new()
	holder.position = at
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 8
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.team = team
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hurtbox.add_child(shape)
	holder.add_child(hurtbox)
	add_child(holder)
	hurtbox.hit_received.connect(func(hit: HitData) -> void: hits.append(hit))
	return hurtbox


static func light(f: InputFrame) -> InputFrame:
	f.light_pressed = true
	return f


static func heavy_down(f: InputFrame) -> InputFrame:
	f.heavy_pressed = true
	f.heavy_held = true
	return f


static func heavy_up(f: InputFrame) -> InputFrame:
	f.heavy_held = false
	f.heavy_released = true
	return f


static func dash_press(f: InputFrame) -> InputFrame:
	f.dash_pressed = true
	return f
