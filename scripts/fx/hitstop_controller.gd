class_name HitstopController
extends Node
## Game-feel layer: briefly slows global time when a hit carries hitstop and
## shakes the camera on heavy hits. Fed by CombatComponent.hit_landed signals;
## gameplay code never depends on it.

@export var slow_time_scale: float = 0.05
@export var camera: CameraShake
@export var shake_per_hitstop: float = 40.0

## Remaining hitstop in unscaled seconds.
var _left: float = 0.0


func watch(combat: CombatComponent) -> void:
	if not combat.hit_landed.is_connected(_on_hit_landed):
		combat.hit_landed.connect(_on_hit_landed)


func request(duration: float) -> void:
	if duration <= 0.0:
		return
	_left = maxf(_left, duration)
	Engine.time_scale = slow_time_scale


func is_active() -> bool:
	return _left > 0.0


func _on_hit_landed(hit: HitData) -> void:
	request(hit.hitstop)
	if camera != null and hit.hitstop > 0.0:
		camera.shake(minf(4.0, hit.hitstop * shake_per_hitstop), 0.18)


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	# `delta` is scaled by Engine.time_scale; undo that to count real game frames.
	_left -= delta / maxf(Engine.time_scale, 0.0001)
	if _left <= 0.0:
		_left = 0.0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
