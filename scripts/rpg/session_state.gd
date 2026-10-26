class_name SessionState
extends Node
## Autoload "GameSession" - the only autoload of the project.
## Reason: the Character (progress, items, location) must survive scene changes
## (map transitions, arena reload). Everything else stays scene-local.
## Systems never reach for this node implicitly: maps call bind_player(), and
## all RPG classes receive their dependencies explicitly (testable without it).

signal character_changed(character: Character)

var database: GameDatabase
var character: Character


func _ready() -> void:
	database = GameDatabase.get_default()


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


static func find(tree: SceneTree) -> SessionState:
	return tree.root.get_node_or_null("GameSession") as SessionState
