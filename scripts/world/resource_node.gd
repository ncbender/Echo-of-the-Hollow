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
	step_completed.connect(_on_step_feedback)
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
	_report(result)
	return result


## Loot & Progress Feedback 1.0: a successful step reports only what was really granted - the items and the
## profession XP go to the loot feed (bundled there); no "Duskleaf 1/3" step text. A failed step keeps its
## concrete reason as a message (e.g. "inventory full"). The node's own progress drawing stays.
func _report(result: Dictionary) -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if String(result.error) != "":
		_hud.notify(String(result.error))
		return
	if _hud.bridge == null:
		return
	if int(result.items) > 0:
		_hud.bridge.item_received.emit(StringName(result.item), int(result.items), null)
	if int(result.xp) > 0:
		_hud.bridge.profession_xp.emit(definition.profession_id, int(result.xp))


func _update_prompt() -> void:
	if definition == null:
		return
	if is_available():
		prompt = "Hold to gather %s" % definition.display_name   # no step counter (the node shows its progress)
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
	if _fall_left > 0.0:
		_fall_left = maxf(0.0, _fall_left - delta)
		queue_redraw()
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.5
		_update_prompt()
		queue_redraw()


## Visual PLACEHOLDERS (no sprites exist, docs/GATHERING.md): damage grows with
## the completed steps; the tree falls at the end and leaves a stump, the rock
## and the vein crumble to rubble, the plant loses its stalks, the carcass is
## skinned down to bones. Chips / stone / leaves / hide particles per step.
const FALL_SECONDS := 0.6
const PARTICLE_COLORS := {
	ResourceNodeDefinition.Look.TREE: Color(0.72, 0.55, 0.32),
	ResourceNodeDefinition.Look.ROCK: Color(0.72, 0.72, 0.75),
	ResourceNodeDefinition.Look.ORE: Color(0.85, 0.6, 0.4),
	ResourceNodeDefinition.Look.HERB: Color(0.55, 0.78, 0.4),
	ResourceNodeDefinition.Look.CARCASS: Color(0.6, 0.25, 0.2),
}

## Seconds left of the falling-tree animation (0 = none).
var _fall_left: float = 0.0


## Particles and the fall at every finished step (feedback only).
func _on_step_feedback(result: Dictionary) -> void:
	if String(result.get("error", "")) != "":
		return
	var world := CombatFx.world_of(self)
	if world != null:
		var color: Color = PARTICLE_COLORS.get(definition.look, Color.WHITE)
		CombatFx.spawn(world, global_position + Vector2(0, -8), CombatFx.Style.SPARKS, color, 10.0 + 2.0 * int(result.get("step", 1)), 0.3)
	if result.get("exhausted", false) and definition.look == ResourceNodeDefinition.Look.TREE:
		_fall_left = FALL_SECONDS


## 0..1 share of the cycle already worked (1 while depleted).
func _wear() -> float:
	if not is_available():
		return 1.0
	if _session == null:
		return 0.0
	return float(ResourceGathering.steps_done(_session.get_character().world, _map_id, node_id)) / maxf(1.0, float(definition.steps))


func _draw() -> void:
	if definition == null:
		return
	var available := is_available()
	var wear := _wear()
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	match definition.look:
		ResourceNodeDefinition.Look.TREE:
			_draw_tree(available, wear)
		ResourceNodeDefinition.Look.ROCK, ResourceNodeDefinition.Look.ORE:
			_draw_stone(available, wear, definition.look == ResourceNodeDefinition.Look.ORE)
		ResourceNodeDefinition.Look.HERB:
			_draw_herb(available, wear)
		ResourceNodeDefinition.Look.CARCASS:
			_draw_carcass(available, wear)
	if not available:
		WorldText.draw(self, Vector2(-10, -20), "...", 7, Color(1, 1, 1, 0.5))


func _draw_tree(available: bool, wear: float) -> void:
	var bark := Color(0.4, 0.28, 0.17)
	if not available and _fall_left <= 0.0:
		# stump: a short trunk with a light cut face
		draw_rect(Rect2(-3, -2, 6, 6), bark)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 3.0, Color(0.78, 0.64, 0.42))
		draw_set_transform(Vector2.ZERO)
		return
	var lean := 0.0
	if _fall_left > 0.0:
		lean = (1.0 - _fall_left / FALL_SECONDS) * PI * 0.5   # falls over to the right
	draw_set_transform(Vector2(0, 4), lean, Vector2.ONE)
	draw_rect(Rect2(-2.5, -10, 5, 12), bark)
	# axe notches grow with the chopped steps
	var notch := clampf(wear, 0.0, 1.0) * 4.0
	if notch > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(2.5, -5), Vector2(2.5 - notch, -3), Vector2(2.5, -1)]), Color(0.78, 0.64, 0.42))
	draw_circle(Vector2(0, -20), 12.0, Color(0.2, 0.45, 0.22))
	draw_circle(Vector2(-6, -15), 8.0, Color(0.24, 0.52, 0.26))
	draw_circle(Vector2(6, -16), 8.0, Color(0.18, 0.4, 0.2))
	draw_set_transform(Vector2.ZERO)


func _draw_stone(available: bool, wear: float, ore: bool) -> void:
	var base := Color(0.36, 0.33, 0.36) if ore else Color(0.5, 0.5, 0.54)
	if not available:
		# rest: a few dark rubble pieces
		for piece: Vector2 in [Vector2(-6, 2), Vector2(1, 3), Vector2(6, 1), Vector2(-1, -1)]:
			draw_circle(piece, 2.5, base.darkened(0.35))
		return
	var points := PackedVector2Array([Vector2(-11, 5), Vector2(-8, -9), Vector2(4, -12), Vector2(11, -3), Vector2(9, 5)])
	draw_colored_polygon(points, base)
	# cracks: one more per worked share
	var cracks := [[Vector2(-2, -11), Vector2(0, -4), Vector2(-3, 2)], [Vector2(9, -3), Vector2(3, -1), Vector2(4, 4)],
		[Vector2(-9, -5), Vector2(-4, -2)], [Vector2(5, -10), Vector2(2, -6)], [Vector2(-6, 4), Vector2(-1, 1)]]
	for index in floori(wear * cracks.size() + 0.001):
		draw_polyline(PackedVector2Array(cracks[index]), Color(0.12, 0.11, 0.12), 1.0)
	if ore:
		var spots: Array[Vector2] = [Vector2(-4, -4), Vector2(3, -7), Vector2(5, 0)]
		for index in spots.size() - floori(wear * spots.size() + 0.001):
			draw_circle(spots[index], 2.0, Color(0.85, 0.55, 0.3))


func _draw_herb(available: bool, wear: float) -> void:
	var stalk := Color(0.32, 0.5, 0.26)
	if not available:
		# harvested: short cut stubble
		for i in 5:
			var x := -8.0 + i * 4.0
			draw_line(Vector2(x, 4), Vector2(x * 0.8, 1), Color(0.33, 0.3, 0.22), 2.0)
		return
	var left := 5 - roundi(wear * 5.0)
	for i in 5:
		var x := -8.0 + i * 4.0
		if i >= left:
			draw_line(Vector2(x, 4), Vector2(x * 0.8, 1), Color(0.33, 0.3, 0.22), 2.0)   # this part was picked
			continue
		draw_line(Vector2(x, 4), Vector2(x * 0.6, -9 - (i % 2) * 4), stalk, 2.0)
		draw_circle(Vector2(x * 0.6, -10 - (i % 2) * 4), 2.0, Color(0.78, 0.74, 0.5))


func _draw_carcass(available: bool, wear: float) -> void:
	var bone := Color(0.82, 0.78, 0.68)
	if not available:
		# exhausted: bare ribs and the antler, no hide left
		for i in 4:
			var x := -8.0 + i * 5.0
			draw_arc(Vector2(x, 0), 4.0, PI, TAU, 6, bone, 1.5)
		draw_line(Vector2(-10, 2), Vector2(10, 2), bone, 1.5)
		draw_line(Vector2(9, -1), Vector2(14, -8), bone, 2.0)
		return
	var body := Color(0.45, 0.32, 0.22).lerp(Color(0.6, 0.3, 0.26), wear)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 3), Vector2(-9, -5), Vector2(4, -7), Vector2(12, -2), Vector2(10, 4)]), body)
	# skinned strips: one more per worked share
	for index in floori(wear * 3.0 + 0.001):
		var x := -7.0 + index * 6.0
		draw_line(Vector2(x, -5), Vector2(x + 2, 3), Color(0.75, 0.35, 0.3), 2.0)
	draw_line(Vector2(9, -5), Vector2(14, -12), bone, 2.0)   # antler
	draw_line(Vector2(12, -9), Vector2(16, -9), bone, 1.5)
