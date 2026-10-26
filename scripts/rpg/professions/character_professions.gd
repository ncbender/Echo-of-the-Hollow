class_name CharacterProfessions
extends RefCounted
## Profession progress of one character (all nine professions, class-independent):
## level and XP per profession, the recipes learned (permanent) and which
## recipes were crafted at least once (first-craft bonus). Pure state; the
## rules are in ProfessionService. Saved as "professions" (save v7).

## Anything changed for `profession_id` (XP, level, recipe) - UI refresh.
signal changed(profession_id: StringName)
signal leveled_up(profession_id: StringName, level: int)
signal recipe_learned(recipe_id: StringName)

var _db: GameDatabase
var _progress: Dictionary = {}   # profession id -> {"level": int, "xp": int}
var _known: Dictionary = {}      # recipe id -> true
var _crafted: Dictionary = {}    # recipe id -> true (first craft done)


func _init(database: GameDatabase) -> void:
	_db = database
	for profession_id: StringName in _db.professions:
		_progress[profession_id] = {"level": 1, "xp": 0}


func level(profession_id: StringName) -> int:
	return int(_progress.get(profession_id, {}).get("level", 1))


func xp(profession_id: StringName) -> int:
	return int(_progress.get(profession_id, {}).get("xp", 0))


func xp_to_next(profession_id: StringName) -> int:
	var definition: ProfessionDefinition = _db.professions.get(profession_id)
	return definition.xp_to_next(level(profession_id)) if definition != null else 0


func knows(recipe_id: StringName) -> bool:
	return _known.has(recipe_id)


func known_recipes() -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in _known:
		result.append(recipe_id)
	return result


## Learns a recipe once. False if it was already known (nothing changes).
func learn(recipe_id: StringName) -> bool:
	if _known.has(recipe_id):
		return false
	_known[recipe_id] = true
	var recipe: ProfessionRecipeDefinition = _db.profession_recipes.get(recipe_id)
	recipe_learned.emit(recipe_id)
	changed.emit(recipe.profession_id if recipe != null else &"")
	return true


func crafted_before(recipe_id: StringName) -> bool:
	return _crafted.has(recipe_id)


func mark_crafted(recipe_id: StringName) -> void:
	_crafted[recipe_id] = true


## Adds XP and levels up (several levels at once if needed, capped at the
## maximum - XP above the cap is dropped). Returns the levels gained.
func add_xp(profession_id: StringName, amount: int) -> int:
	var definition: ProfessionDefinition = _db.professions.get(profession_id)
	if definition == null or amount <= 0:
		return 0
	var entry: Dictionary = _progress.get(profession_id, {"level": 1, "xp": 0})
	var gained := 0
	entry.xp = int(entry.xp) + amount
	while int(entry.level) < definition.max_level and int(entry.xp) >= definition.xp_to_next(int(entry.level)):
		entry.xp = int(entry.xp) - definition.xp_to_next(int(entry.level))
		entry.level = int(entry.level) + 1
		gained += 1
	if int(entry.level) >= definition.max_level:
		entry.xp = 0
	_progress[profession_id] = entry
	if gained > 0:
		leveled_up.emit(profession_id, int(entry.level))
	changed.emit(profession_id)
	return gained


func to_dict() -> Dictionary:
	var levels := {}
	for profession_id: StringName in _progress:
		levels[String(profession_id)] = {"level": level(profession_id), "xp": xp(profession_id)}
	var known: Array = []
	for recipe_id: StringName in _known:
		known.append(String(recipe_id))
	known.sort()
	var crafted: Array = []
	for recipe_id: StringName in _crafted:
		crafted.append(String(recipe_id))
	crafted.sort()
	return {"levels": levels, "known_recipes": known, "first_crafts": crafted}


## Restores saved progress. Unknown professions are kept out (reported);
## levels and XP are clamped into the valid range; unknown recipe ids are kept
## (a later data version may add them back) but never shown or crafted.
func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	var levels: Variant = data.get("levels", {})
	if levels is Dictionary:
		for key: Variant in levels:
			var profession_id := StringName(str(key))
			var definition: ProfessionDefinition = _db.professions.get(profession_id)
			var entry: Variant = levels[key]
			if definition == null or not entry is Dictionary:
				warnings.append("unknown profession %s ignored" % profession_id)
				continue
			var lvl := clampi(int((entry as Dictionary).get("level", 1)), 1, definition.max_level)
			var amount := clampi(int((entry as Dictionary).get("xp", 0)), 0, maxi(0, definition.xp_to_next(lvl) - 1))
			_progress[profession_id] = {"level": lvl, "xp": amount}
	for list_key: String in ["known_recipes", "first_crafts"]:
		var list: Variant = data.get(list_key, [])
		if list is Array:
			for recipe_id: Variant in list:
				(_known if list_key == "known_recipes" else _crafted)[StringName(str(recipe_id))] = true
