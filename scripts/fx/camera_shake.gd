class_name CameraShake
extends Camera2D
## Game camera: fixed world view plus small trauma-style screen shake. Purely visual.
##
## The visible world is always 512x288 world px (docs/DISPLAY_AND_UI_STANDARD.md):
## base_zoom is defined for the 1920x1080 design canvas, and the player's UI scale
## (Window.content_scale_factor, which also scales the world canvas) is divided
## out, so UI scaling never shows more or less of the map.

## World px -> design px at UI scale 100 %. 3.75 = 1920 / 512.
@export var base_zoom: float = 3.75

var _strength: float = 0.0
var _time_left: float = 0.0
var _duration: float = 0.0


func shake(strength: float, duration: float) -> void:
	if strength >= _strength * (_time_left / maxf(_duration, 0.001)):
		_strength = strength
		_duration = duration
		_time_left = duration


func _ready() -> void:
	_update_zoom()


func _update_zoom() -> void:
	var factor := get_window().content_scale_factor if get_window() != null else 1.0
	zoom = Vector2.ONE * (base_zoom / maxf(factor, 0.01))


func _process(delta: float) -> void:
	_update_zoom()
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_time_left -= delta
	var falloff := clampf(_time_left / _duration, 0.0, 1.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _strength * falloff
