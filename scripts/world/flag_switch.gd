class_name FlagSwitch
extends Interactable
## Simple persistent world switch (e.g. a lever): toggles a WorldState flag of
## the session character. Its state survives map changes and saves.

@export var flag: StringName

var _world: WorldState


func _ready() -> void:
	super()
	var session := SessionState.find(get_tree())
	if session != null:
		_world = session.get_character().world


func is_on() -> bool:
	return _world != null and _world.has_flag(flag)


func interact(hud: GameHud) -> void:
	if _world == null:
		return
	_world.set_flag(flag, not is_on())
	hud.notify("%s: %s" % [prompt, "ON" if is_on() else "OFF"])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.35, 0.32, 0.42))
	var angle := -0.6 if is_on() else 0.6
	var tip := Vector2.from_angle(-PI * 0.5 + angle) * 12.0
	draw_line(Vector2(0, -2), tip + Vector2(0, -2), Color(0.8, 0.75, 0.6), 2.0)
	draw_circle(tip + Vector2(0, -2), 2.5, Color(0.4, 1.0, 0.5) if is_on() else Color(1.0, 0.4, 0.35))
