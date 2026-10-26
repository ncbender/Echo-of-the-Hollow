class_name Hurtbox
extends Area2D
## Receives hits for its entity (by default the parent node). Damage handling is
## up to the entity, which listens to `hit_received`.

signal hit_received(hit: HitData)

## Hitboxes never hit hurtboxes of their own team.
@export var team: StringName = &"enemy"
@export var debug_color: Color = Color(0.3, 1.0, 0.45, 0.8)

## Optional callable returning true while the entity cannot be hit (e.g. dash iFrames).
var invulnerability_check: Callable
## Optional callable(hit) run on an accepted hit BEFORE anyone hears of it
## (defense: block/parry change damage, knockback and reaction first).
var hit_filter: Callable


func get_entity() -> Node:
	return get_parent()


func is_invulnerable() -> bool:
	return invulnerability_check.is_valid() and invulnerability_check.call()


## Returns true when the hit was accepted.
func receive_hit(hit: HitData) -> bool:
	if is_invulnerable():
		return false
	hit.target = get_entity()
	if hit_filter.is_valid():
		hit_filter.call(hit)
	hit_received.emit(hit)
	return true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not DebugView.show_hitboxes:
		return
	var color := Color(1, 1, 1, 0.8) if is_invulnerable() else debug_color
	for child in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null or shape_node.shape == null:
			continue
		var circle := shape_node.shape as CircleShape2D
		var rect := shape_node.shape as RectangleShape2D
		if circle != null:
			draw_arc(shape_node.position, circle.radius, 0.0, TAU, 24, color, 1.0)
		elif rect != null:
			draw_rect(Rect2(shape_node.position - rect.size * 0.5, rect.size), color, false, 1.0)
