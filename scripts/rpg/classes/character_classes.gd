class_name CharacterClasses
extends RefCounted
## Class progression of one character: which classes are unlocked, their own
## level and XP, and which class is active. Weapon mastery is NOT stored here
## (it is shared by all classes, see WeaponMastery).

signal class_unlocked(class_id: StringName)
signal active_class_changed(class_id: StringName)
signal xp_gained(class_id: StringName, amount: int)
signal leveled_up(class_id: StringName, level: int)

var active_class_id: StringName
var _db: GameDatabase
var _progress: Dictionary = {}   # class id -> {"unlocked": bool, "level": int, "xp": int}
var _unknown: Dictionary = {}    # saved entries of classes missing from the data


func _init(database: GameDatabase) -> void:
	_db = database


func get_active_definition() -> ClassDefinition:
	return _db.get_class_def(active_class_id)


func is_unlocked(class_id: StringName) -> bool:
	return _progress.has(class_id) and _progress[class_id].unlocked


func unlocked_class_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for class_id: StringName in _progress:
		if _progress[class_id].unlocked:
			result.append(class_id)
	return result


## Unlocks a class (quest, boss, prologue choice or debug). Returns false if the
## class is unknown or already unlocked.
func unlock(class_id: StringName) -> bool:
	if _db.get_class_def(class_id) == null or is_unlocked(class_id):
		return false
	_progress[class_id] = {"unlocked": true, "level": 1, "xp": 0}
	class_unlocked.emit(class_id)
	return true


## "" when the class can become active, otherwise the reason.
func activation_error(class_id: StringName) -> String:
	if _db.get_class_def(class_id) == null:
		return "unknown class"
	if not is_unlocked(class_id):
		return "class is locked"
	return ""


## Low-level switch without location rules (Character.switch_class enforces those).
func set_active(class_id: StringName) -> bool:
	if activation_error(class_id) != "":
		return false
	if class_id != active_class_id:
		active_class_id = class_id
		active_class_changed.emit(class_id)
	return true


func get_level(class_id: StringName) -> int:
	return _progress[class_id].level if _progress.has(class_id) else 1


func get_xp(class_id: StringName) -> int:
	return _progress[class_id].xp if _progress.has(class_id) else 0


func xp_to_next(class_id: StringName) -> int:
	var definition := _db.get_class_def(class_id)
	return definition.xp_to_next(get_level(class_id)) if definition != null else 0


## XP only goes to unlocked classes. Returns levels gained.
func add_xp(class_id: StringName, amount: int) -> int:
	var definition := _db.get_class_def(class_id)
	if amount <= 0 or definition == null or not is_unlocked(class_id):
		return 0
	var entry: Dictionary = _progress[class_id]
	if entry.level >= definition.max_level:
		return 0
	var level: int = entry.level
	var xp: int = entry.xp + amount
	var gained := 0
	while level < definition.max_level and xp >= definition.xp_to_next(level):
		xp -= definition.xp_to_next(level)
		level += 1
		gained += 1
	entry.level = level
	entry.xp = 0 if level >= definition.max_level else xp
	xp_gained.emit(class_id, amount)
	for i in gained:
		leveled_up.emit(class_id, level - gained + 1 + i)
	return gained


func to_dict() -> Dictionary:
	var progress := _unknown.duplicate(true)
	for class_id: StringName in _progress:
		progress[String(class_id)] = _progress[class_id].duplicate()
	return {"active": String(active_class_id), "progress": progress}


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	_progress.clear()
	_unknown.clear()
	var progress: Dictionary = data.get("progress", {}) if data.get("progress") is Dictionary else {}
	for key: String in progress:
		var entry: Variant = progress[key]
		var definition := _db.get_class_def(StringName(key))
		if definition == null:
			_unknown[key] = entry
			warnings.append("progress of unknown class %s kept unchanged" % key)
			continue
		if not entry is Dictionary:
			warnings.append("invalid class entry %s ignored" % key)
			continue
		var level := clampi(int(entry.get("level", 1)), 1, definition.max_level)
		_progress[StringName(key)] = {
			"unlocked": bool(entry.get("unlocked", false)),
			"level": level,
			"xp": clampi(int(entry.get("xp", 0)), 0, maxi(0, definition.xp_to_next(level) - 1)),
		}
	active_class_id = StringName(str(data.get("active", "")))
	if activation_error(active_class_id) != "":
		warnings.append("active class %s invalid; falling back" % active_class_id)
		var unlocked := unlocked_class_ids()
		active_class_id = unlocked[0] if not unlocked.is_empty() else &""
