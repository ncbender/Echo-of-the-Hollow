class_name HitstopController
extends Node
## Game-feel layer: on hits with hitstop, briefly freezes ONLY the attacker and
## the target (local hitstop via apply_hitstop()) and shakes the camera.
## Global time, UI, other enemies and timers keep running.
## Fed by CombatComponent.hit_landed; gameplay code never depends on it.

@export var camera: CameraShake
@export var shake_per_hitstop: float = 40.0
## Upper bound so stacked tier multipliers never freeze an actor noticeably.
@export var max_hitstop: float = 0.15


func watch(combat: CombatComponent) -> void:
	if not combat.hit_landed.is_connected(_on_hit_landed):
		combat.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(hit: HitData) -> void:
	if hit.hitstop <= 0.0:
		return
	var duration := minf(hit.hitstop, max_hitstop)
	# Actors take the max of running and new hitstop, so several hits of one
	# swing (or several swings) never add up.
	for actor: Node in [hit.attacker, hit.target]:
		if actor != null and is_instance_valid(actor) and actor.has_method(&"apply_hitstop"):
			actor.call(&"apply_hitstop", duration)
	if camera != null:
		camera.shake(minf(4.0, duration * shake_per_hitstop), 0.18)
