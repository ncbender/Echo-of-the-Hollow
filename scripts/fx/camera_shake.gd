class_name CameraShake
extends Camera2D
## Small trauma-style screen shake. Purely visual.

var _strength: float = 0.0
var _time_left: float = 0.0
var _duration: float = 0.0


func shake(strength: float, duration: float) -> void:
	if strength >= _strength * (_time_left / maxf(_duration, 0.001)):
		_strength = strength
		_duration = duration
		_time_left = duration


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_time_left -= delta
	var falloff := clampf(_time_left / _duration, 0.0, 1.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _strength * falloff
