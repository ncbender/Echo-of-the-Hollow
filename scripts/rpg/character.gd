class_name Character
extends RefCounted
## Runtime state of the player character: everything that persists between
## sessions. Owns the progression sub-systems; contains no combat logic.
## The scene-side Player is connected to it by PlayerProgressionBridge.

## Any change that can affect resolved stats (class, level, equipment ...).
signal stats_changed

var id: String
var display_name: String = "Wanderer"
var database: GameDatabase
var mastery: WeaponMastery
var classes: CharacterClasses

var _stats: Dictionary = {}
var _stats_dirty: bool = true


func _init(db: GameDatabase, character_id: String = "") -> void:
	database = db
	id = character_id if character_id != "" else IdGenerator.new_id("chr")
	mastery = WeaponMastery.new(db)
	classes = CharacterClasses.new(db)
	# Method callables (not lambdas): they do not keep this RefCounted alive,
	# so Character <-> sub-system signal links never form a reference cycle.
	classes.leveled_up.connect(_on_class_leveled_up)
	classes.active_class_changed.connect(_on_active_class_changed)


## Class XP for the active class.
func add_class_xp(amount: int) -> int:
	return classes.add_xp(classes.active_class_id, amount)


## Changes the active class. Only allowed in a safe place (class station);
## returns "" on success or the reason for refusal.
func switch_class(class_id: StringName, in_safe_zone: bool) -> String:
	if not in_safe_zone:
		return "classes can only be changed at a class station"
	if class_id == classes.active_class_id:
		return "class already active"
	var error := classes.activation_error(class_id)
	if error != "":
		return error
	classes.set_active(class_id)
	return ""


func get_stat(stat: StringName) -> float:
	return get_stats().get(stat, 0.0)


func get_stats() -> Dictionary:
	if _stats_dirty:
		_stats = StatResolver.resolve(_stat_sources())
		_stats_dirty = false
	return _stats


func invalidate_stats() -> void:
	_stats_dirty = true
	stats_changed.emit()


## All stat sources in resolution order. Extended by equipment in Phase 5.
func _stat_sources() -> Array:
	var active := classes.get_active_definition()
	return [
		database.rules.character_base_stats,
		StatResolver.class_modifiers(active, classes.get_level(classes.active_class_id)),
	]


func _on_class_leveled_up(_class_id: StringName, _level: int) -> void:
	invalidate_stats()


func _on_active_class_changed(_class_id: StringName) -> void:
	invalidate_stats()
