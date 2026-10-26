class_name CharacterArmorMastery
extends RefCounted
## Armor Mastery progress of one character: level 1-20 and XP per armour type
## (Cloth, Leather, Mail, Plate), character-wide (every class, any mix of
## armour). Pure state, saved as "armor_mastery" (save v10); the rules are in
## ArmorMasteryService.

signal changed
signal leveled_up(armor_type: int, level: int)

const KEYS := {ItemDefinition.ArmorType.CLOTH: "cloth", ItemDefinition.ArmorType.LEATHER: "leather",
	ItemDefinition.ArmorType.MAIL: "mail", ItemDefinition.ArmorType.PLATE: "plate"}

var _level: Dictionary = {}   # armor type -> level
var _xp: Dictionary = {}      # armor type -> XP towards the next level (float)


func _init() -> void:
	for type: int in KEYS:
		_level[type] = 1
		_xp[type] = 0.0


func level(type: int) -> int:
	return int(_level.get(type, 1))


func xp(type: int) -> float:
	return float(_xp.get(type, 0.0))


## Adds XP to one type; returns the levels gained. Stops at `rules.max_level`.
func add_xp(type: int, amount: float, rules: ArmorMasteryRules) -> int:
	if not KEYS.has(type) or amount <= 0.0 or level(type) >= rules.max_level:
		return 0
	var gained := 0
	var value := xp(type) + amount
	while level(type) < rules.max_level and value >= rules.xp_to_next(level(type)):
		value -= rules.xp_to_next(level(type))
		_level[type] = level(type) + 1
		gained += 1
		leveled_up.emit(type, level(type))
	_xp[type] = value if level(type) < rules.max_level else 0.0
	changed.emit()
	return gained


func to_dict() -> Dictionary:
	var data := {}
	for type: int in KEYS:
		data[KEYS[type]] = {"level": level(type), "xp": snappedf(xp(type), 0.01)}
	return data


func from_dict(data: Dictionary, rules: ArmorMasteryRules, warnings: PackedStringArray) -> void:
	for type: int in KEYS:
		var entry: Variant = data.get(KEYS[type], {})
		if not entry is Dictionary:
			warnings.append("armor mastery %s: invalid data ignored" % KEYS[type])
			continue
		var saved_level: Variant = entry.get("level", 1)
		var saved_xp: Variant = entry.get("xp", 0.0)
		_level[type] = clampi(int(saved_level) if saved_level is float or saved_level is int else 1, 1, rules.max_level)
		_xp[type] = clampf(float(saved_xp) if saved_xp is float or saved_xp is int else 0.0, 0.0, maxf(0.0, rules.xp_to_next(level(type)) - 0.01))
