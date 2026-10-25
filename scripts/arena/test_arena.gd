extends Node2D
## Test arena glue: connects game-feel systems and debug hotkeys.
## Contains no combat rules.

const MASTERY_REQUIREMENT := &"mastery.one_handed_sword.1"
const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const SPAWN_AREA := Rect2(-300, -180, 600, 360)

@onready var player: Player = $Player
@onready var hitstop: HitstopController = $HitstopController
@onready var enemies: Node2D = $Enemies


func _ready() -> void:
	hitstop.camera = player.get_node("Camera2D")
	hitstop.watch(player.combat)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hitboxes"):
		DebugView.show_hitboxes = not DebugView.show_hitboxes
	elif event.is_action_pressed(&"debug_spawn_enemy"):
		spawn_enemy(_spawn_point())
	elif event.is_action_pressed(&"debug_toggle_mastery"):
		var unlocked := player.combat.combo.unlocks.has(MASTERY_REQUIREMENT)
		player.combat.set_unlocked(MASTERY_REQUIREMENT, not unlocked)
	elif event.is_action_pressed(&"debug_reset_arena"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


## Debug spawning (F2). Returns the spawned enemy.
func spawn_enemy(at: Vector2) -> Enemy:
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = at
	enemy.target = player
	enemies.add_child(enemy)
	hitstop.watch(enemy.combat)
	return enemy


func _spawn_point() -> Vector2:
	# Random point at a fair distance from the player, inside the arena.
	for attempt in 10:
		var point := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(110.0, 170.0)
		if SPAWN_AREA.has_point(point):
			return point
	return Vector2(0, -150)
