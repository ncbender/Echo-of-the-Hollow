class_name AffixDefinition
extends Resource
## A rollable item property. Rolled values are stored on the ItemInstance and
## never re-rolled on load.

## FLAT adds points to the stat (all current stats are point or percent-point
## stats, e.g. +6 "Physical Damage %"); PERCENT multiplies the stat total.
enum ValueKind { FLAT, PERCENT }

@export var id: StringName
@export var display_name: String
@export var stat: StringName
@export var value_kind: ValueKind = ValueKind.FLAT
@export var tags: Array[StringName] = []
## Affix family: an item never has two affixes of the same group.
@export var group: StringName
## Mutually exclusive families: at most one affix per exclusion group (empty = none).
@export var exclusion_group: StringName
## Slot kinds this affix can roll on (empty = every equippable kind).
@export var allowed_slot_kinds: Array[ItemDefinition.SlotKind] = []
@export var min_item_level: int = 1
@export var weight: float = 100.0
@export var tiers: Array[AffixTier] = []


func allows_slot(kind: ItemDefinition.SlotKind) -> bool:
	return allowed_slot_kinds.is_empty() or kind in allowed_slot_kinds


func tiers_for_level(item_level: int) -> Array[AffixTier]:
	var result: Array[AffixTier] = []
	if item_level < min_item_level:
		return result
	for tier in tiers:
		if tier != null and tier.min_item_level <= item_level:
			result.append(tier)
	return result


func get_tier(tier_number: int) -> AffixTier:
	for tier in tiers:
		if tier != null and tier.tier == tier_number:
			return tier
	return null


## Saved affix entry for `tier` with a whole-number value rolled by `rng`.
func roll(tier: AffixTier, rng: RandomNumberGenerator) -> Dictionary:
	var value := float(rng.randi_range(roundi(tier.min_value), roundi(tier.max_value)))
	return {
		"affix": String(id), "tier": tier.tier, "stat": String(stat),
		"flat": value if value_kind == ValueKind.FLAT else 0.0,
		"percent": value if value_kind == ValueKind.PERCENT else 0.0,
	}


func describe_range(tier: AffixTier) -> String:
	var suffix := " (x%)" if value_kind == ValueKind.PERCENT else ""
	return "+%d-%d %s%s" % [roundi(tier.min_value), roundi(tier.max_value), Stats.display_name(stat), suffix]


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or stat == &"" or group == &"":
		errors.append("affix %s: id, stat and group are required" % id)
	if tiers.is_empty():
		errors.append("affix %s: no tiers" % id)
	var seen := {}
	for tier in tiers:
		if tier == null or tier.min_value > tier.max_value or tier.weight <= 0.0:
			errors.append("affix %s: invalid tier" % id)
		elif seen.has(tier.tier):
			errors.append("affix %s: duplicate tier %d" % [id, tier.tier])
		else:
			seen[tier.tier] = true
	return errors
