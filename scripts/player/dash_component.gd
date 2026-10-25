class_name DashComponent
extends Node
## Dash charges, sequential regeneration, dash timing and invulnerability window.
## Pure timing logic; the owner applies get_velocity() to its body.

signal dash_started(direction: Vector2)
signal dash_ended
signal charges_changed(charges: int, max_charges: int)

@export var config: DashConfig

var charges: int = 0
var direction: Vector2 = Vector2.ZERO
var _recharge_progress: float = 0.0
var _elapsed: float = 0.0
var _dashing: bool = false


func _ready() -> void:
	if config == null:
		config = DashConfig.new()
	charges = config.max_charges


func is_dashing() -> bool:
	return _dashing


func is_invulnerable() -> bool:
	return _dashing and _elapsed < config.iframe_duration


func can_dash() -> bool:
	return charges > 0 and not _dashing


## Starts a dash in `dash_direction` (normalized by the caller). Returns false when not allowed.
func try_start(dash_direction: Vector2) -> bool:
	if not can_dash() or dash_direction == Vector2.ZERO:
		return false
	charges -= 1
	direction = dash_direction.normalized()
	_elapsed = 0.0
	_dashing = true
	charges_changed.emit(charges, config.max_charges)
	dash_started.emit(direction)
	return true


func get_velocity() -> Vector2:
	if not _dashing:
		return Vector2.ZERO
	return direction * (config.distance / config.duration)


## 0..1 progress of the charge currently regenerating (0 when full).
func get_recharge_progress() -> float:
	return _recharge_progress / config.recharge_time if charges < config.max_charges else 0.0


func step(delta: float) -> void:
	if _dashing:
		_elapsed += delta
		if _elapsed >= config.duration - 0.0001:
			_dashing = false
			dash_ended.emit()
	if charges < config.max_charges:
		_recharge_progress += delta
		if _recharge_progress >= config.recharge_time:
			_recharge_progress -= config.recharge_time
			charges += 1
			if charges >= config.max_charges:
				_recharge_progress = 0.0
			charges_changed.emit(charges, config.max_charges)
