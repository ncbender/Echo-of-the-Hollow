class_name TrialStation
extends Interactable
## Prologue pedestal of one class trial. Interact (G) to start the temporary
## trial - its enemies appear at the child Marker2D "Spawns/*" - or, while the
## trial runs, to leave it (nothing is kept). Rules: PrologueService.

@export var trial_id: StringName
@export var color: Color = Color(0.8, 0.8, 1.0)

var _enemies: Array[Enemy] = []


func _ready() -> void:
	super._ready()
	prompt = "Start trial"


func trial() -> TrialDefinition:
	return GameDatabase.get_default().trials.get(trial_id)


func interact(hud: GameHud) -> void:
	var map := get_tree().current_scene as GameMap
	if map == null or map.bridge == null:
		return
	var character := map.bridge.character
	if character.prologue.active_trial == trial_id:
		PrologueService.end_trial(character, false)
		clear_enemies()
		return
	var error := PrologueService.begin_trial(character, trial_id)
	if error != "":
		hud.notify(error)
		return
	hud.notify("%s: %s" % [trial().display_name, trial().description])
	spawn_enemies(map)


func spawn_enemies(map: GameMap) -> void:
	clear_enemies()
	var points := get_node_or_null("Spawns")
	var count := trial().enemy_count if trial() != null else 0
	for index in count:
		var at := global_position + Vector2(-30 + 30 * index, 80)
		if points != null and index < points.get_child_count():
			at = (points.get_child(index) as Node2D).global_position
		_enemies.append(map.spawn_enemy(at))


func clear_enemies() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()


func _process(_delta: float) -> void:
	var map := get_tree().current_scene as GameMap
	var character := map.bridge.character if map != null and map.bridge != null else null
	var running := character != null and character.prologue.active_trial == trial_id
	prompt = "Leave the trial" if running else "Start %s" % (trial().display_name if trial() != null else "trial")
	if character != null and not running and character.prologue.active_trial == &"" and not _enemies.is_empty():
		clear_enemies()   # the trial ended (completed or left elsewhere)
	queue_redraw()


func _draw() -> void:
	var map := get_tree().current_scene as GameMap
	var character := map.bridge.character if map != null and map.bridge != null else null
	var done := character != null and character.prologue.has_completed_trial(trial_id)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 24.0, Color(color, 0.15))
	draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, Color(color, 0.5 + 0.3 * pulse * (1.0 if player_inside else 0.4)), 2.0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-4, -18, 8, 16), color.darkened(0.4))
	draw_circle(Vector2(0, -21), 4.0, Color(color, 0.7 + 0.3 * pulse))
	var title := trial().display_name if trial() != null else String(trial_id)
	if done:
		title += "  (done)"
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	WorldText.draw(self, Vector2(-width * 0.5, -30), title, 7, color.lightened(0.3), 2, Color.BLACK)
