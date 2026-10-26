class_name CharacterFactory
extends RefCounted
## Creates new characters with their starting state.


static func create_new(database: GameDatabase) -> Character:
	return Character.new(database)
