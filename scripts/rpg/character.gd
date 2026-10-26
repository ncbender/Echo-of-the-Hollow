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
var inventory: Inventory
var equipment: CharacterEquipment

var _stats: Dictionary = {}
var _stats_dirty: bool = true


func _init(db: GameDatabase, character_id: String = "") -> void:
	database = db
	id = character_id if character_id != "" else IdGenerator.new_id("chr")
	mastery = WeaponMastery.new(db)
	classes = CharacterClasses.new(db)
	inventory = Inventory.new(db, db.rules.inventory_capacity)
	equipment = CharacterEquipment.new(db, inventory, classes)
	# Method callables (not lambdas): they do not keep this RefCounted alive,
	# so Character <-> sub-system signal links never form a reference cycle.
	classes.leveled_up.connect(_on_class_leveled_up)
	classes.active_class_changed.connect(_on_active_class_changed)
	classes.class_unlocked.connect(_on_class_unlocked)
	equipment.changed.connect(invalidate_stats)


## Class XP for the active class.
func add_class_xp(amount: int) -> int:
	return classes.add_xp(classes.active_class_id, amount)


## Changes the active class. Only allowed in a safe place (class station);
## returns "" on success or the reason for refusal. The class's own loadout
## becomes effective; mastery and inventory are shared and stay untouched.
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


## Destroys an item instance on purpose (player discards it). Loadout references
## are removed automatically (Inventory.item_removed).
func discard_item(instance_id: String) -> bool:
	return inventory.remove_instance(instance_id) != null


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


## Equipped piece count per set id (active loadout only).
func equipped_set_counts() -> Dictionary:
	var counts := {}
	for item in equipment.equipped_items():
		var definition := database.get_item(item.definition_id)
		if definition != null and definition.set_id != &"":
			counts[definition.set_id] = counts.get(definition.set_id, 0) + 1
	return counts


## Set bonuses currently reached by the active loadout.
func active_set_bonuses() -> Array[SetBonus]:
	var result: Array[SetBonus] = []
	var counts := equipped_set_counts()
	for set_id: StringName in counts:
		var set_def: SetDefinition = database.sets.get(set_id)
		if set_def != null:
			result.append_array(set_def.active_bonuses(counts[set_id]))
	return result


## All stat sources in resolution order (always recomputed from scratch).
func _stat_sources() -> Array:
	var active := classes.get_active_definition()
	var sources: Array = [
		database.rules.character_base_stats,
		StatResolver.class_modifiers(active, classes.get_level(classes.active_class_id)),
	]
	for item in equipment.equipped_items():
		var definition := database.get_item(item.definition_id)
		if definition != null:
			sources.append(definition.base_stats)
			sources.append(item.affix_modifiers())
	for bonus in active_set_bonuses():
		sources.append(bonus.stat_modifiers)
	return sources


func _on_class_leveled_up(_class_id: StringName, _level: int) -> void:
	invalidate_stats()


func _on_active_class_changed(_class_id: StringName) -> void:
	# The new class's loadout is now the effective one.
	equipment.changed.emit()


func _on_class_unlocked(class_id: StringName) -> void:
	if classes.active_class_id != &"" and class_id != classes.active_class_id:
		equipment.init_loadout_from(class_id, classes.active_class_id)
