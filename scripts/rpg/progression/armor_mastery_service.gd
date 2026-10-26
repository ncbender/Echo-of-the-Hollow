class_name ArmorMasteryService
extends RefCounted
## Armor Mastery 1.0 rules (docs/ARMOR_MASTERY.md). Stateless; progress in
## Character.armor_mastery, values in ArmorMasteryRules.
##
## * Coverage: the five armour slots (Head 15 %, Chest 40 %, Hands 10 %, Legs
##   25 %, Feet 10 %) of the active loadout, by the armour type of the worn
##   piece. Empty slots and pieces without a clear type count for nothing.
## * Burden: points per slot and type, summed -> tier (Light / Balanced /
##   Burdened / Heavy) -> slower walking and longer attack recovery. Weapons,
##   shields and the other slots carry none. Dash, iFrames, dash charges and
##   recharge and the parry windows are never touched.
## * XP: a share of every valid combat XP event goes to each worn type by its
##   coverage; the shares of empty slots are lost (never moved to other types).
## * Milestones (5 / 10 / 15 / 20): stat bonuses scaled by the type's coverage,
##   applied as a stat source of the character (StatResolver).

const TIER_NAMES := ["Light", "Balanced", "Burdened", "Heavy"]
const TYPE_NAMES := {ItemDefinition.ArmorType.CLOTH: "Cloth", ItemDefinition.ArmorType.LEATHER: "Leather",
	ItemDefinition.ArmorType.MAIL: "Mail", ItemDefinition.ArmorType.PLATE: "Plate"}


static func rules(character: Character) -> ArmorMasteryRules:
	return character.database.rules.armor_rules()


## Worn armour type per counted slot index (order of ArmorMasteryRules.SLOTS).
static func worn_types(character: Character) -> Array[int]:
	var result: Array[int] = []
	for slot: int in ArmorMasteryRules.SLOTS:
		var item := character.equipment.get_item(slot)
		var definition := character.database.get_item(item.definition_id) if item != null else null
		result.append(definition.armor_type if definition != null else ItemDefinition.ArmorType.NONE)
	return result


## Coverage 0..1 per armour type (sum of the weights of the slots it fills).
static func coverage(character: Character) -> Dictionary:
	return coverage_of(worn_types(character), rules(character))


static func coverage_of(types: Array[int], armor_rules: ArmorMasteryRules) -> Dictionary:
	var result := {}
	for type: int in ArmorMasteryRules.TYPES:
		result[type] = 0.0
	for index in types.size():
		if result.has(types[index]):
			result[types[index]] += armor_rules.slot_weights[index]
	return result


static func burden(character: Character) -> int:
	return burden_of(worn_types(character), rules(character))


static func burden_of(types: Array[int], armor_rules: ArmorMasteryRules) -> int:
	var total := 0
	for index in types.size():
		total += armor_rules.burden_of(types[index], index)
	return total


## Tier index 0..3 (Light, Balanced, Burdened, Heavy) for `points`.
static func tier(points: int, armor_rules: ArmorMasteryRules) -> int:
	var result := 0
	for index in armor_rules.tier_starts.size():
		if points >= armor_rules.tier_starts[index]:
			result = index + 1
	return result


## % slower walking from the burden after Iron Discipline (never below 0).
static func move_penalty(character: Character) -> float:
	var armor_rules := rules(character)
	var penalty: float = armor_rules.tier_move_penalty[tier(burden(character), armor_rules)]
	return maxf(0.0, penalty - iron_discipline(character))


## % longer attack recovery from the burden.
static func recovery_penalty(character: Character) -> float:
	var armor_rules := rules(character)
	return armor_rules.tier_recovery_penalty[tier(burden(character), armor_rules)]


## Percentage points of walking penalty Iron Discipline removes (plate 20, by plate coverage).
static func iron_discipline(character: Character) -> float:
	var total := 0.0
	for entry: Dictionary in milestone_bonuses(character):
		if entry.stat == ArmorMasteryRules.IRON_DISCIPLINE:
			total += float(entry.value)
	return total


## Reached milestones with their effective (coverage-scaled) value:
## [{"type", "level", "stat", "value", "full"}].
static func milestone_bonuses(character: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var covered := coverage(character)
	for milestone: Array in ArmorMasteryRules.MILESTONES:
		var type: int = milestone[0]
		if character.armor_mastery.level(type) >= int(milestone[1]):
			result.append({"type": type, "level": milestone[1], "stat": milestone[2], "full": float(milestone[3]),
				"value": float(milestone[3]) * float(covered.get(type, 0.0))})
	return result


## Stat source of the character (milestones; Iron Discipline is not a stat).
static func stat_modifiers(character: Character) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for entry: Dictionary in milestone_bonuses(character):
		if entry.stat != ArmorMasteryRules.IRON_DISCIPLINE and float(entry.value) > 0.0:
			result.append(StatModifier.make(entry.stat, float(entry.value), 0.0))
	return result


## A valid combat XP event of `amount`: each worn type gets amount x coverage.
## Returns the levels gained (all types).
static func add_xp(character: Character, amount: float) -> int:
	if amount <= 0.0:
		return 0
	var armor_rules := rules(character)
	var gained := 0
	var covered := coverage(character)
	for type: int in covered:
		if float(covered[type]) > 0.0:
			gained += character.armor_mastery.add_xp(type, amount * float(covered[type]), armor_rules)
	if gained > 0:
		character.invalidate_stats()   # new milestones
	return gained
