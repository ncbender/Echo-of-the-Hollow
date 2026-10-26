class_name Encounter
extends Node2D
## A scripted group of enemies (children: EncounterSpawn markers). Starts when
## `condition` holds and the player comes within `trigger_radius` (0: at once).
## When every enemy is defeated it reports "encounter:<id>" to the story;
## `persistent` encounters are then cleared for good ("encounter.<id>"), others
## come back whenever the map is loaded again. Loading during a fight simply
## restarts it - nothing of a running encounter is saved.

signal started
signal cleared

@export var encounter_id: StringName
@export var condition: StoryCondition
@export var trigger_radius: float = 120.0
@export var persistent: bool = true
## Optional bark when the fight starts (e.g. Mara at the cart).
@export var bark_npc_id: StringName
@export var bark_text: String
## Optional tutorial hint shown when the fight starts (once per character).
@export_multiline var hint: String

var character: Character
var enemies: Array[Enemy] = []
var running: bool = false
## Cleared during this visit of the map (non-persistent encounters too).
var done: bool = false
var _remaining: int = 0


func _ready() -> void:
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()


func cleared_flag() -> StringName:
	return StringName("encounter.%s" % encounter_id)


func is_cleared() -> bool:
	return persistent and character != null and character.world.has_flag(cleared_flag())


func can_start() -> bool:
	return not running and not done and not is_cleared() and character != null and StoryCondition.check(condition, character)


func _physics_process(_delta: float) -> void:
	if not can_start():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	if trigger_radius <= 0.0 or player.global_position.distance_to(global_position) <= trigger_radius:
		start()


func start() -> void:
	var map := get_tree().current_scene as GameMap
	if map == null or running:
		return
	running = true
	enemies.clear()
	for child in get_children():
		var spawn := child as EncounterSpawn
		if spawn == null:
			continue
		var enemy := map.spawn_enemy(spawn.global_position, spawn.config)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)
	_remaining = enemies.size()
	if bark_text != "":
		for node in get_tree().get_nodes_in_group(&"interactable"):
			var npc := node as StoryNpc
			if npc != null and npc.npc_id == bark_npc_id and npc.visible:
				npc.say(bark_text, 3.5)
	var hint_flag := StringName("hint.encounter_%s" % encounter_id)
	if hint != "" and not character.world.has_flag(hint_flag):
		character.world.set_flag(hint_flag)
		map.hud.show_hint(hint)
	started.emit()
	if _remaining == 0:
		_finish()


func _on_enemy_defeated(_enemy: Enemy) -> void:
	_remaining -= 1
	if _remaining <= 0 and running:
		_finish()


func _finish() -> void:
	running = false
	done = true
	if persistent:
		character.world.set_flag(cleared_flag())
	cleared.emit()
	StoryService.notify(character, StringName("encounter:%s" % encounter_id))
