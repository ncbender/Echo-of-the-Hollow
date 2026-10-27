class_name WeaponMastery
extends RefCounted
## Weapon mastery of one character. Progress belongs to the character and is
## shared by all classes. Levels/XP per family (1-20, curve from MasteryTrack).
## Weapon Mastery 1.4: a level only unlocks combo paths of its family
## (WeaponFamily.combo_paths) - never a passive stat bonus.

signal xp_gained(family_id: StringName, amount: int)
signal leveled_up(family_id: StringName, level: int)
signal unlocked(family_id: StringName, unlock: MasteryUnlock)
## A level-up reached the unlock level of a combo path (or the bow's Flowing Draw).
signal path_unlocked(family_id: StringName, path: ComboPathDefinition)

var _db: GameDatabase
var _levels: Dictionary = {}    # family id -> level (1..max)
var _xp: Dictionary = {}        # family id -> XP inside the current level
## Saved entries of families that have no track in the current data; kept
## untouched so a save never loses data when content is temporarily missing.
var _unknown: Dictionary = {}


func _init(database: GameDatabase) -> void:
	_db = database


func get_level(family_id: StringName) -> int:
	return _levels.get(family_id, 1)


func get_xp(family_id: StringName) -> int:
	return _xp.get(family_id, 0)


func xp_to_next(family_id: StringName) -> int:
	var track := _db.get_track(family_id)
	return track.xp_to_next(get_level(family_id)) if track != null else 0


func is_max_level(family_id: StringName) -> bool:
	var track := _db.get_track(family_id)
	return track == null or get_level(family_id) >= track.max_level


## Adds XP and resolves level-ups. Returns the number of levels gained.
func add_xp(family_id: StringName, amount: int) -> int:
	var track := _db.get_track(family_id)
	if amount <= 0 or track == null or is_max_level(family_id):
		return 0
	var level := get_level(family_id)
	var xp := get_xp(family_id) + amount
	var gained := 0
	var reached: Array[MasteryUnlock] = []
	while level < track.max_level and xp >= track.xp_to_next(level):
		xp -= track.xp_to_next(level)
		level += 1
		gained += 1
		for unlock in track.unlocks:
			if unlock.level == level:
				reached.append(unlock)
	if level >= track.max_level:
		xp = 0
	# State is final before any listener runs.
	_levels[family_id] = level
	_xp[family_id] = xp
	xp_gained.emit(family_id, amount)
	for i in gained:
		leveled_up.emit(family_id, level - gained + 1 + i)
	for unlock in reached:
		unlocked.emit(family_id, unlock)
	var family: WeaponFamily = _db.weapons.get(family_id)
	if family != null and gained > 0:
		for path in family.combo_paths:
			if path.unlock_level > level - gained and path.unlock_level <= level:
				path_unlocked.emit(family_id, path)
	return gained


func unlocked_techniques(family_id: StringName) -> Array[MasteryUnlock]:
	var result: Array[MasteryUnlock] = []
	var track := _db.get_track(family_id)
	if track != null:
		for unlock in track.unlocks_up_to(get_level(family_id)):
			if unlock.is_technique():
				result.append(unlock)
	return result


func next_unlock(family_id: StringName) -> MasteryUnlock:
	var track := _db.get_track(family_id)
	return track.next_unlock(get_level(family_id)) if track != null else null


## All combo requirement ids unlocked across every family.
func unlocked_requirements() -> Array[StringName]:
	var result: Array[StringName] = []
	for family_id: StringName in _db.mastery_tracks:
		for unlock in unlocked_techniques(family_id):
			result.append(unlock.requirement_id)
	return result


func to_dict() -> Dictionary:
	var data := _unknown.duplicate(true)
	for family_id: StringName in _levels:
		data[String(family_id)] = {"level": _levels[family_id], "xp": _xp.get(family_id, 0)}
	return data


## Restores from saved data. Out-of-range values are clamped; unknown families kept raw.
func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	_levels.clear()
	_xp.clear()
	_unknown.clear()
	for key: String in data:
		var entry: Variant = data[key]
		var family_id := StringName(key)
		var track := _db.get_track(family_id)
		if track == null:
			_unknown[key] = entry
			warnings.append("mastery for unknown weapon family %s kept unchanged" % key)
			continue
		if not entry is Dictionary:
			warnings.append("invalid mastery entry for %s ignored" % key)
			continue
		var level := clampi(int(entry.get("level", 1)), 1, track.max_level)
		var xp := clampi(int(entry.get("xp", 0)), 0, maxi(0, track.xp_to_next(level) - 1))
		_levels[family_id] = level
		_xp[family_id] = xp
