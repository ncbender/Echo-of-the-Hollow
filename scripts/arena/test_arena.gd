extends Node2D
## Test arena glue: connects game-feel systems and debug hotkeys.
## Contains no combat rules.

const MASTERY_REQUIREMENT := &"mastery.one_handed_sword.1"

@onready var player: Player = $Player
@onready var hitstop: HitstopController = $HitstopController


func _ready() -> void:
	hitstop.camera = player.get_node("Camera2D")
	hitstop.watch(player.combat)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hitboxes"):
		DebugView.show_hitboxes = not DebugView.show_hitboxes
	elif event.is_action_pressed(&"debug_toggle_mastery"):
		var unlocked := player.combat.combo.unlocks.has(MASTERY_REQUIREMENT)
		player.combat.set_unlocked(MASTERY_REQUIREMENT, not unlocked)
	elif event.is_action_pressed(&"debug_reset_arena"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
