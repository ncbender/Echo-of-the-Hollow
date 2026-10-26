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
var world: WorldState
## Talents, skill slots, mods and presets per class (docs/TALENT_SYSTEM.md).
var builds: ClassBuilds
## Prologue trials and the permanent starting class choice.
var prologue := PrologueState.new()
## Class unlock quests.
var quests := QuestLog.new()
## Raw saved items that could not be restored (e.g. definition removed from the
## data). Kept and written back on save so no player property is ever deleted.
var orphaned_items: Array = []
## Active play time in seconds (saved, shown in save slots).
var play_time: float = 0.0

## Runtime stat sources (skill buffs, class states): key -> Array[StatModifier].
## Never saved; the class runtime re-creates them.
var _runtime_modifiers: Dictionary = {}
var _stats: Dictionary = {}
var _stats_dirty: bool = true


func _init(db: GameDatabase, character_id: String = "") -> void:
	database = db
	id = character_id if character_id != "" else IdGenerator.new_id("chr")
	mastery = WeaponMastery.new(db)
	classes = CharacterClasses.new(db)
	inventory = Inventory.new(db, db.rules.inventory_capacity)
	equipment = CharacterEquipment.new(db, inventory, classes)
	world = WorldState.new()
	builds = ClassBuilds.new(db, classes)
	# Method callables (not lambdas): they do not keep this RefCounted alive,
	# so Character <-> sub-system signal links never form a reference cycle.
	classes.leveled_up.connect(_on_class_leveled_up)
	classes.active_class_changed.connect(_on_active_class_changed)
	classes.class_unlocked.connect(_on_class_unlocked)
	equipment.changed.connect(invalidate_stats)
	builds.changed.connect(_on_build_changed)


## Class XP for the active class.
func add_class_xp(amount: int) -> int:
	return classes.add_xp(classes.active_class_id, amount)


## Changes the active class. Only allowed in a safe place (class station);
## returns "" on success or the reason for refusal. The class's own loadout
## becomes effective; mastery and inventory are shared and stay untouched.
func switch_class(class_id: StringName, in_safe_zone: bool) -> String:
	if not in_safe_zone:
		return "classes can only be changed at a class station"
	if classes.in_trial():
		return "not during a class trial"
	if class_id == classes.active_class_id:
		return "class already active"
	var error := classes.activation_error(class_id)
	if error != "":
		return error
	classes.set_active(class_id)
	return ""


## Inventory capacity = rules + bonuses of standing buildings (storage). Never
## drops items: if items exceed a reduced capacity they all stay (inventory
## only refuses new slots until there is room again).
func refresh_inventory_capacity() -> void:
	inventory.capacity = database.rules.inventory_capacity + BaseBuilder.capacity_bonus(self) \
		+ RestorationService.capacity_bonus(self)


## Destroys an item instance on purpose (player discards it). Loadout references
## are removed automatically (Inventory.item_removed).
func discard_item(instance_id: String) -> bool:
	return inventory.remove_instance(instance_id) != null


## A crafting operation changed an item instance: if it is equipped in the active
## loadout, stats and item effects are rebuilt (equipment.changed); the inventory
## UI refreshes through inventory.changed.
func notify_item_changed(instance_id: String) -> void:
	if equipment.is_equipped(instance_id):
		equipment.changed.emit()
	inventory.changed.emit()


## Adds or replaces a temporary stat source (buffs). Stats are re-resolved from
## scratch, so a buff can never be applied twice or linger after removal.
func set_runtime_modifiers(key: StringName, modifiers: Array[StatModifier]) -> void:
	_runtime_modifiers[key] = modifiers.duplicate()
	invalidate_stats()


func clear_runtime_modifiers(key: StringName) -> void:
	if _runtime_modifiers.erase(key):
		invalidate_stats()


func has_runtime_modifiers(key: StringName) -> bool:
	return _runtime_modifiers.has(key)


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


## Serializable source data only. Derived values (stats, health, class
## resource, active effects) are rebuilt after loading.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"play_time": snappedf(play_time, 0.1),
		"classes": classes.to_dict(),
		"mastery": mastery.to_dict(),
		"inventory": inventory.to_array(),
		"orphaned_items": orphaned_items.duplicate(true),
		"loadouts": equipment.to_dict(),
		"class_builds": builds.to_dict(),
		"prologue": prologue.to_dict(),
		"quests": quests.to_dict(),
		"world": world.to_dict(),
	}


## Rebuilds a character from saved data. Never fails hard: invalid parts are
## repaired or skipped and reported in `warnings`.
static func from_dict(data: Dictionary, db: GameDatabase, warnings: PackedStringArray) -> Character:
	var character := Character.new(db, str(data.get("id", "")))
	character.display_name = str(data.get("name", "Wanderer"))
	character.play_time = maxf(0.0, float(data.get("play_time", 0.0)))
	character.classes.from_dict(_dict(data, "classes"), warnings)
	if character.classes.active_class_id == &"":
		warnings.append("no usable class in save; starting class restored")
		character.classes.unlock(db.rules.starting_class_id)
		character.classes.set_active(db.rules.starting_class_id)
	character.mastery.from_dict(_dict(data, "mastery"), warnings)
	var orphans := []
	var items: Variant = data.get("inventory", [])
	character.inventory.from_array(items if items is Array else [], warnings, orphans)
	var previous: Variant = data.get("orphaned_items", [])
	if previous is Array:
		orphans.append_array(previous)
	character.orphaned_items = orphans
	character.equipment.from_dict(_dict(data, "loadouts"), warnings)
	character.prologue.from_dict(_dict(data, "prologue"), warnings)
	character.quests.from_dict(_dict(data, "quests"), warnings)
	character.builds.from_dict(_dict(data, "class_builds"), warnings)
	for class_id in character.classes.unlocked_class_ids():
		if character.builds.has_build(class_id):
			warnings.append_array(TalentService.sanitize_build(character, class_id))
	character.world.from_dict(_dict(data, "world"), warnings)
	character.refresh_inventory_capacity()
	character.invalidate_stats()
	return character


static func _dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	return value if value is Dictionary else {}


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
			# base stats (quality), affixes, material imprint, sockets, evolution
			sources.append(ItemStats.modifiers(item, definition, database))
	for bonus in active_set_bonuses():
		sources.append(bonus.stat_modifiers)
	sources.append(TalentService.stat_modifiers(self, classes.active_class_id))
	for modifiers: Array in _runtime_modifiers.values():
		sources.append(modifiers)
	return sources


func _on_class_leveled_up(class_id: StringName, _level: int) -> void:
	SkillBook.auto_fill(self, class_id)
	builds.notify(class_id)   # re-resolves stats


func _on_active_class_changed(_class_id: StringName) -> void:
	# The new class's loadout is now the effective one.
	equipment.changed.emit()


func _on_class_unlocked(class_id: StringName) -> void:
	SkillBook.auto_fill(self, class_id)
	if classes.active_class_id != &"" and class_id != classes.active_class_id:
		equipment.init_loadout_from(class_id, classes.active_class_id)


func _on_build_changed(_class_id: StringName) -> void:
	invalidate_stats()
