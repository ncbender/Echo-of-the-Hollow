class_name ResourceNode
extends Interactable
## Reusable gathering component for the world: stand next to it and press G.
## Rules live in ResourceGathering; this node only shows state and forwards
## the interaction for its map (`node_id` must be unique within the map).

@export var definition: ResourceNodeDefinition
@export var node_id: StringName

var _session: SessionState
var _map_id: StringName
var _redraw_timer: float = 0.0


func _ready() -> void:
	super()
	_session = SessionState.find(get_tree())
	var map := _find_map()
	_map_id = map.map_id if map != null else &""
	_update_prompt()


func is_available() -> bool:
	if _session == null:
		return true
	return ResourceGathering.is_available(_session.get_character().world, _map_id, node_id, _now())


## Gathers for the session character; returns "" on success or the reason.
func gather() -> String:
	if _session == null:
		return "no session"
	var error := ResourceGathering.gather(_session.get_character(), _map_id, node_id, definition, _now())
	_update_prompt()
	queue_redraw()
	return error


func interact(hud: GameHud) -> void:
	var error := gather()
	if error == "":
		var item := _session.database.get_item(definition.yield_item_id)
		hud.notify("Gathered %s x%d" % [item.display_name, definition.yield_quantity])
	else:
		hud.notify(error)


func _update_prompt() -> void:
	if definition == null:
		return
	if is_available():
		prompt = "Gather %s" % definition.display_name
	elif definition.respawn_seconds <= 0.0:
		prompt = "%s (exhausted)" % definition.display_name
	else:
		var left := ResourceGathering.seconds_left(_session.get_character().world, _map_id, node_id, _now())
		prompt = "%s (regrows in %ds)" % [definition.display_name, ceili(left)]


func _find_map() -> GameMap:
	var node := get_parent()
	while node != null and not node is GameMap:
		node = node.get_parent()
	return node as GameMap


func _now() -> float:
	return Time.get_unix_time_from_system()


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.5
		_update_prompt()
		queue_redraw()


func _draw() -> void:
	if definition == null:
		return
	var available := is_available()
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	match definition.look:
		ResourceNodeDefinition.Look.TREE:
			draw_rect(Rect2(-2.5, -6, 5, 12), Color(0.4, 0.28, 0.17))
			if available:
				draw_circle(Vector2(0, -16), 12.0, Color(0.2, 0.45, 0.22))
				draw_circle(Vector2(-6, -11), 8.0, Color(0.24, 0.52, 0.26))
				draw_circle(Vector2(6, -12), 8.0, Color(0.18, 0.4, 0.2))
		ResourceNodeDefinition.Look.ROCK:
			var color := Color(0.5, 0.5, 0.54) if available else Color(0.3, 0.3, 0.32)
			var shrink := 1.0 if available else 0.5
			var points := PackedVector2Array([Vector2(-10, 4), Vector2(-7, -8), Vector2(3, -11), Vector2(10, -2), Vector2(8, 5)])
			for i in points.size():
				points[i] *= shrink
			draw_colored_polygon(points, color)
		ResourceNodeDefinition.Look.ORE:
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 5), Vector2(-8, -9), Vector2(4, -12),
				Vector2(11, -3), Vector2(9, 5)]), Color(0.36, 0.33, 0.36))
			if available:
				for spot: Vector2 in [Vector2(-4, -4), Vector2(3, -7), Vector2(5, 0)]:
					draw_circle(spot, 2.0, Color(0.85, 0.55, 0.3))
	if not available:
		WorldText.draw(self, Vector2(-10, -20), "...", 7, Color(1, 1, 1, 0.5))
