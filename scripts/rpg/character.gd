class_name Character
extends RefCounted
## Runtime state of the player character: everything that persists between
## sessions. Owns the progression sub-systems; contains no combat logic.
## The scene-side Player is connected to it by PlayerProgressionBridge.

var id: String
var display_name: String = "Wanderer"
var database: GameDatabase
var mastery: WeaponMastery


func _init(db: GameDatabase, character_id: String = "") -> void:
	database = db
	id = character_id if character_id != "" else IdGenerator.new_id("chr")
	mastery = WeaponMastery.new(db)


## Class XP for the active class (class system: Phase 3).
func add_class_xp(_amount: int) -> int:
	return 0
