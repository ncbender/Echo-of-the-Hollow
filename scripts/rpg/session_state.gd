class_name SessionState
extends Node
## Autoload "GameSession" - the only autoload of the project.
## Reason: the Character (progress, items, location) must survive scene changes
## (map transitions, arena reload, loading a save). Everything else stays
## scene-local. Maps call bind_player(); all RPG classes receive their
## dependencies explicitly and are testable without this node.

signal character_changed(character: Character)
## Immediate user-facing message (current map shows it in the HUD).
signal message(text: String)

const DEFAULT_SAVE_PATH := "user://saves/slot_1.save.json"

var database: GameDatabase
var character: Character
## Real player saves go to DEFAULT_SAVE_PATH; tests/playtests point this elsewhere.
var save_path: String = DEFAULT_SAVE_PATH
var last_load: SaveSystem.LoadResult
## Player preferences (UI scale, window mode); not part of any save slot.
var settings: UserSettings

var _pending_spawn: StringName = &""
var _traveling: bool = false
var _fade: ColorRect

const FADE_TIME := 0.2
var _messages: PackedStringArray = []


func _ready() -> void:
	database = GameDatabase.get_default()
	_init_settings()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


## Loads the player's display/UI preferences (user://settings.cfg, independent of
## save slots) and applies them. Scripted runs (tests, playtests: the main loop is
## a script) get in-memory defaults and never touch the player's settings file.
func _init_settings() -> void:
	var scripted := Engine.get_main_loop().get_script() != null
	settings = UserSettings.new() if scripted else UserSettings.load_from(UserSettings.DEFAULT_PATH)
	settings.changed.connect(_on_settings_changed)
	settings.apply_to(get_window())
	if not scripted and settings.window_mode == UserSettings.WindowMode.WINDOWED \
			and not Engine.is_embedded_in_editor():
		UserSettings.fit_window_to_screen(get_window())


func _on_settings_changed() -> void:
	settings.apply_to(get_window())
	if settings.path != "":
		settings.save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


func get_character() -> Character:
	if character == null:
		set_character(CharacterFactory.create_new(database))
	return character


func set_character(new_character: Character) -> void:
	character = new_character
	character_changed.emit(character)


## Connects a freshly spawned Player to the session's character.
func bind_player(player: Player) -> PlayerProgressionBridge:
	var bridge := player.get_node_or_null("ProgressionBridge") as PlayerProgressionBridge
	if bridge == null:
		bridge = PlayerProgressionBridge.new()
		bridge.name = "ProgressionBridge"
		player.add_child(bridge)
	bridge.bind(player, get_character())
	return bridge


func save_game() -> Error:
	return SaveSystem.save_to(get_character(), save_path)


## Loads `save_path`. On success the character is replaced and its saved map is
## (re)loaded at the saved spawn point. Returns the detailed result.
func load_game() -> SaveSystem.LoadResult:
	last_load = SaveSystem.load_from(save_path, database)
	if not last_load.ok():
		message.emit("LOAD FAILED: %s" % "; ".join(last_load.errors))
		return last_load
	set_character(last_load.character)
	_messages.append("Loaded save (%s)%s" % [last_load.source, " with %d warnings" % last_load.warnings.size() if not last_load.warnings.is_empty() else ""])
	travel(character.world.map_id, character.world.spawn_id)
	return last_load


## Central map transition API: changes to the scene of `map_id` and spawns the
## player at `spawn_id`. Unknown map ids reload the current scene. Requests
## while a transition is running are ignored (no double loads). Returns false
## when the request was ignored.
func travel(map_id: StringName, spawn_id: StringName, fade: bool = true) -> bool:
	if _traveling:
		return false
	_traveling = true
	_pending_spawn = spawn_id
	if fade and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
		tween.tween_callback(_change_scene.bind(map_id))
	else:
		_change_scene.call_deferred(map_id)
	return true


func is_traveling() -> bool:
	return _traveling


## Called by GameMap once the new map is ready.
func map_ready() -> void:
	_traveling = false
	if _fade.color.a > 0.0:
		var tween := create_tween()
		tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)


func _change_scene(map_id: StringName) -> void:
	var map_def: MapDefinition = database.maps.get(map_id)
	if map_def != null and map_def.scene_path != "":
		get_tree().change_scene_to_file(map_def.scene_path)
	else:
		get_tree().reload_current_scene()


func consume_pending_spawn() -> StringName:
	var spawn := _pending_spawn
	_pending_spawn = &""
	return spawn


func consume_messages() -> PackedStringArray:
	var messages := _messages
	_messages = PackedStringArray()
	return messages


static func find(tree: SceneTree) -> SessionState:
	return tree.root.get_node_or_null("GameSession") as SessionState
