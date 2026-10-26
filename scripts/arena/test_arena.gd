extends Node2D
## Test arena glue: connects game-feel systems, the RPG session and debug hotkeys.
## Contains no combat or progression rules.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const SPAWN_AREA := Rect2(-300, -180, 600, 360)
const DEBUG_MASTERY_XP := 100
const DEBUG_CLASS_XP := 100

var bridge: PlayerProgressionBridge

@onready var player: Player = $Player
@onready var hitstop: HitstopController = $HitstopController
@onready var enemies: Node2D = $Enemies
@onready var hud: GameHud = $GameHud


func _ready() -> void:
	hitstop.camera = player.get_node("Camera2D")
	hitstop.watch(player.combat)
	var session := SessionState.find(get_tree())
	if session != null:
		bridge = session.bind_player(player)
		hud.setup(bridge)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hitboxes"):
		DebugView.show_hitboxes = not DebugView.show_hitboxes
	elif event.is_action_pressed(&"debug_spawn_enemy"):
		spawn_enemy(_spawn_point())
	elif event.is_action_pressed(&"debug_add_mastery_xp") and bridge != null:
		bridge.debug_add_mastery_xp(DEBUG_MASTERY_XP)
		hud.notify("+%d mastery XP (debug)" % DEBUG_MASTERY_XP)
	elif event.is_action_pressed(&"debug_add_class_xp") and bridge != null:
		bridge.character.add_class_xp(DEBUG_CLASS_XP)
		hud.notify("+%d class XP (debug)" % DEBUG_CLASS_XP)
	elif event.is_action_pressed(&"interact"):
		if hud.is_window_open():
			hud.close_windows()
		else:
			var target := Interactable.find_active(get_tree())
			if target != null:
				target.interact(hud)
	elif event.is_action_pressed(&"debug_reset_arena"):
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
