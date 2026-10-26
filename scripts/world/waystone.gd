class_name Waystone
extends Interactable
## A waystone in the world. Silent (cracked) until awakened - Haven's is awake
## from the start, the Whispering Stone's answers once a path has taken root.
## Awake: G opens free fast travel to every other awake waystone (never while
## enemies are near). Rules: WaystoneService.

@export var waystone_id: StringName
## Story requirement for awakening (empty: may be awakened at any time).
@export var activation_condition: StoryCondition

var character: Character


func _ready() -> void:
	super._ready()
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()
	refresh()


func definition() -> WaystoneDefinition:
	return GameDatabase.get_default().waystones.get(waystone_id)


func is_awake() -> bool:
	return character != null and WaystoneService.is_active(character, waystone_id)


func refresh() -> void:
	var name_text := definition().display_name if definition() != null else String(waystone_id)
	prompt = "Travel from %s" % name_text if is_awake() else "Touch the waystone"


## True while an enemy is close to the player (no travel in combat).
func enemies_near() -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var scene := get_tree().current_scene
	if player == null or scene == null:
		return false
	for node in scene.find_children("*", "Enemy", true, false):
		var enemy := node as Enemy
		if enemy.state != Enemy.State.DEAD and enemy.global_position.distance_to(player.global_position) < WaystoneService.COMBAT_RADIUS:
			return true
	return false


## Awakens this waystone. Returns "" on success or the reason.
func awaken(hud: GameHud) -> String:
	var error := WaystoneService.activate(character, definition(), activation_condition)
	if error != "":
		return error
	refresh()
	var session := SessionState.find(get_tree())
	if session != null:
		session.request_critical_save("waystone %s" % waystone_id)
	if hud != null:
		hud.notify("Waystone awakened: %s" % definition().display_name)
		var lines: Array[Dictionary] = [{"name": definition().display_name, "text": WaystoneService.ACTIVATION_LINE, "color": Color(0.6, 0.85, 1.0)}]
		hud.open_lines(lines)
	return ""


func interact(hud: GameHud) -> void:
	if is_awake():
		hud.open_waystones(self)
		return
	var error := awaken(hud)
	if error != "":
		hud.notify(error)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var awake := is_awake()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
	var glow := Color(0.55, 0.85, 1.0)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0, Color(glow, 0.18 * pulse) if awake else Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var stone := Color(0.5, 0.52, 0.58) if awake else Color(0.36, 0.36, 0.38)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-6, -26), Vector2(0, -32), Vector2(6, -26), Vector2(7, 0)]), stone)
	if awake:
		draw_line(Vector2(0, -24), Vector2(0, -8), Color(glow, 0.6 + 0.4 * pulse), 2.0)
		draw_circle(Vector2(0, -18), 2.5, Color(glow, 0.7 + 0.3 * pulse))
	else:
		draw_polyline(PackedVector2Array([Vector2(-3, -28), Vector2(1, -20), Vector2(-2, -14), Vector2(3, -6)]), Color(0.15, 0.15, 0.16), 1.0)
	var title := definition().display_name if definition() != null else String(waystone_id)
	var text := title if awake else "%s (silent)" % title
	WorldText.draw(self, Vector2(-WorldText.width(text, 6) * 0.5, -38), text, 6, glow.lightened(0.3) if awake else Color(0.7, 0.7, 0.72), 2, Color.BLACK)
