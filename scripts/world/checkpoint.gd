class_name Checkpoint
extends Area2D
## Respawn point of a map section (a rest area). Walking through it moves the
## player's respawn here and remembers it as the map's spawn ("world.spawn_id"),
## so loading a save also starts here, restores the player's health and refills the
## Hearth Flask (a short rest by the fire). No enemy comes back. Respawning never
## saves anything: saving and dying are separate (docs/SAVE_SYSTEM.md).

@export var spawn_id: StringName = &"rest"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	monitoring = true
	monitorable = false
	if get_node_or_null("Spawn") == null:
		var point := SpawnPoint.new()
		point.name = "Spawn"
		point.spawn_id = spawn_id
		add_child(point)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	var session := SessionState.find(get_tree())
	if player == null or session == null:
		return
	var character := session.get_character()
	character.world.spawn_id = spawn_id
	player.set_spawn_position(global_position)
	if player.health.is_dead():
		return
	var needs_rest := player.health.health < player.health.max_health \
		or character.consumables.charges < ConsumableService.max_charges(character)
	player.health.heal(player.health.max_health)
	ConsumableService.rest(character)   # the Hearth Flask is refilled (no save, no enemy respawn)
	if needs_rest:
		var map := get_tree().current_scene as GameMap
		if map != null:
			map.hud.notify("You catch your breath by the fire. The Hearth Flask is full again.")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# a small campfire: the rest area is recognisable at a glance
	var flicker := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.013)
	for i in 3:
		var angle := i * TAU / 3.0 + 0.4
		draw_line(Vector2.from_angle(angle) * 6.0, -Vector2.from_angle(angle) * 6.0, Color(0.4, 0.28, 0.18), 2.0)
	draw_circle(Vector2(0, -3), 3.5 * flicker, Color(1.0, 0.55, 0.15, 0.9))
	draw_circle(Vector2(0, -4), 1.8 * flicker, Color(1.0, 0.9, 0.5))
