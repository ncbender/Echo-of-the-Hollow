class_name ResourceNode
extends Interactable
## Reusable gathering component for the world: stand next to it and HOLD G
## (Gathering 1.1): the player works the node step by step (Player.begin_gather,
## one ResourceGathering.complete_step per finished step). Rules live in
## ResourceGathering; this node only shows state and forwards the interaction
## for its map (`node_id` must be unique within the map).

@export var definition: ResourceNodeDefinition
@export var node_id: StringName

## A finished work step: `result` from ResourceGathering.complete_step (views, feedback).
signal step_completed(result: Dictionary)

var _session: SessionState
var _hud: GameHud
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


## Harvests all remaining steps at once (non-interactive: tests, the loop
## test); returns "" on success or the reason. Players use interact (hold G).
func gather() -> String:
	if _session == null:
		return "no session"
	var error := ResourceGathering.gather(_session.get_character(), _map_id, node_id, definition, _now())
	_update_prompt()
	queue_redraw()
	return error


## G pressed (edge): starts working this node if it can be worked and the
## player is free. Holding G keeps working; the player stops on interruptions.
func interact(hud: GameHud) -> void:
	_hud = hud
	if _session == null:
		return
	var error := ResourceGathering.gather_error(_session.get_character(), _map_id, node_id, definition, _now())
	if error != "":
		if hud != null:
			hud.notify(error)
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.begin_gather(self)


# --- the Player's gather target ---------------------------------------------------

func step_seconds() -> float:
	var profession: ProfessionDefinition = _session.database.professions.get(definition.profession_id) if _session != null else null
	return profession.gather_step_seconds if profession != null and profession.gather_step_seconds > 0.0 else 0.75


func in_range(_player: Node) -> bool:
	return player_inside and is_visible_in_tree()


func complete_step() -> Dictionary:
	if _session == null:
		return {"error": "no session", "exhausted": false}
	var character := _session.get_character()
	var result := ResourceGathering.complete_step(character, _map_id, node_id, definition, _now())
	_update_prompt()
	queue_redraw()
	step_completed.emit(result)
	if _hud != null and is_instance_valid(_hud):
		_hud.notify(_step_text(result, character))
	return result


func _step_text(result: Dictionary, character: Character) -> String:
	if String(result.error) != "":
		return String(result.error)
	var text := "%s %d/%d" % [definition.display_name, int(result.step), int(result.steps)]
	if int(result.items) > 0:
		text += "  ·  +%d %s" % [int(result.items), _session.database.get_item(result.item).display_name]
	var profession: ProfessionDefinition = _session.database.professions.get(definition.profession_id)
	if profession != null:
		text += "  ·  %s %d" % [profession.display_name, character.professions.level(profession.id)]
	if result.exhausted:
		text += "  ·  exhausted"
	return text


func _update_prompt() -> void:
	if definition == null:
		return
	if is_available():
		var done := ResourceGathering.steps_done(_session.get_character().world, _map_id, node_id) if _session != null else 0
		prompt = "Hold to gather %s  (%d/%d)" % [definition.display_name, done, maxi(1, definition.steps)]
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
		ResourceNodeDefinition.Look.HERB:   # a clump of stalks, blossoms while available
			var stalk := Color(0.32, 0.5, 0.26) if available else Color(0.33, 0.3, 0.22)
			for i in 5:
				var x := -8.0 + i * 4.0
				draw_line(Vector2(x, 4), Vector2(x * 0.6, -9 - (i % 2) * 4), stalk, 2.0)
				if available:
					draw_circle(Vector2(x * 0.6, -10 - (i % 2) * 4), 2.0, Color(0.78, 0.74, 0.5))
		ResourceNodeDefinition.Look.CARCASS:   # remains of a beast; picked clean when depleted
			var body := Color(0.45, 0.32, 0.22) if available else Color(0.42, 0.4, 0.36)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 3), Vector2(-9, -5), Vector2(4, -7), Vector2(12, -2), Vector2(10, 4)]), body)
			draw_line(Vector2(9, -5), Vector2(14, -12), Color(0.82, 0.78, 0.68), 2.0)   # antler
			draw_line(Vector2(12, -9), Vector2(16, -9), Color(0.82, 0.78, 0.68), 1.5)
		ResourceNodeDefinition.Look.ORE:
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 5), Vector2(-8, -9), Vector2(4, -12),
				Vector2(11, -3), Vector2(9, 5)]), Color(0.36, 0.33, 0.36))
			if available:
				for spot: Vector2 in [Vector2(-4, -4), Vector2(3, -7), Vector2(5, 0)]:
					draw_circle(spot, 2.0, Color(0.85, 0.55, 0.3))
	if not available:
		WorldText.draw(self, Vector2(-10, -20), "...", 7, Color(1, 1, 1, 0.5))
