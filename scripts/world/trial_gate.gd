@tool
class_name TrialGate
extends WallBlock
## Class Trials 2.0 M3: the barrier between the training area and the trial area
## of a trial ground. Closed (a solid wall) unless the trial `trial_id` is
## RUNNING and all its training goals are met (PrologueService.training_done) -
## so a preview visit, a left or failed trial never opens it. No state of its
## own: it reads the running trial every frame and is never saved.

@export var trial_id: StringName

var is_open: bool = false
var _character: Character


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var session := SessionState.find(get_tree())
	_character = session.get_character() if session != null else null


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	set_open(_character != null and PrologueService.training_done(_character, trial_id))


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	for child in get_children(true):
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred(&"disabled", open)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	if is_open:
		draw_rect(rect, Color(top_color, 0.25), false, 1.0)   # the way into the trial area is free
		return
	super._draw()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
	draw_rect(rect.grow(-2.0), Color(top_color.lightened(0.3), 0.3 + 0.3 * pulse), false, 1.0)


func _process(_delta: float) -> void:
	if not is_open:
		queue_redraw()   # pulse of the sealed gate
