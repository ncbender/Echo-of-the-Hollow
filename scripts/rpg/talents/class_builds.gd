class_name ClassBuilds
extends RefCounted
## All class builds of one character (saved under "class_builds"). A class's
## build only matters while that class is active. During a prologue class trial
## the trial class gets a TEMPORARY build (never saved, see begin_trial_build).

## Talents, slots, mods or presets of `class_id` changed.
signal changed(class_id: StringName)

var _db: GameDatabase
var _classes: CharacterClasses
var _builds: Dictionary = {}   # class id -> ClassBuild
var _unknown: Dictionary = {}  # saved builds of classes missing from the data
var _trial: ClassBuild


func _init(database: GameDatabase, classes: CharacterClasses) -> void:
	_db = database
	_classes = classes


func rules() -> TalentRules:
	return _db.rules.talent_rules()


## Build of `class_id` (default: the active class). Created on first access.
func get_build(class_id: StringName = &"") -> ClassBuild:
	if class_id == &"":
		class_id = _classes.active_class_id
	if _trial != null and class_id == _trial.class_id:
		return _trial
	if not _builds.has(class_id):
		_builds[class_id] = ClassBuild.new(class_id, rules().skill_slots)
	return _builds[class_id]


func has_build(class_id: StringName) -> bool:
	return _builds.has(class_id)


func notify(class_id: StringName = &"") -> void:
	changed.emit(class_id if class_id != &"" else _classes.active_class_id)


## Temporary build for a prologue trial (not saved, discarded by end_trial_build).
func begin_trial_build(build: ClassBuild) -> void:
	_trial = build
	changed.emit(build.class_id)


func end_trial_build() -> void:
	if _trial == null:
		return
	var class_id := _trial.class_id
	_trial = null
	changed.emit(class_id)


func trial_build() -> ClassBuild:
	return _trial


func to_dict() -> Dictionary:
	var data := _unknown.duplicate(true)
	for class_id: StringName in _builds:
		if _classes.is_unlocked(class_id):   # locked classes never keep a build
			data[String(class_id)] = _builds[class_id].to_dict()
	return data


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	_builds.clear()
	_unknown.clear()
	_trial = null
	for key: String in data:
		if not data[key] is Dictionary:
			warnings.append("invalid build of class %s ignored" % key)
			continue
		if _db.get_class_def(StringName(key)) == null:
			_unknown[key] = data[key]
			warnings.append("build of unknown class %s kept unchanged" % key)
			continue
		var build := ClassBuild.new(StringName(key), rules().skill_slots)
		build.from_dict(data[key], warnings)
		_builds[StringName(key)] = build
