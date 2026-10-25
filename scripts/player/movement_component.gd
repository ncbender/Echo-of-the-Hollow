class_name MovementComponent
extends Node
## Computes locomotion velocity from move input. Knows nothing about combat;
## the owner passes the speed multiplier the current action allows.

@export var config: MovementConfig


func _ready() -> void:
	if config == null:
		config = MovementConfig.new()


func compute_velocity(current: Vector2, move_input: Vector2, speed_multiplier: float, delta: float) -> Vector2:
	var target := move_input.limit_length(1.0) * config.move_speed * speed_multiplier
	var rate := config.acceleration if target != Vector2.ZERO else config.deceleration
	return current.move_toward(target, rate * delta)


func full_speed_velocity(direction: Vector2) -> Vector2:
	return direction.limit_length(1.0) * config.move_speed
