class_name AffixTierWeights
extends Resource
## Loot Foundation 1.0 (docs/LOOT_FOUNDATION_1_0.md): how often each affix tier is drawn,
## per item level band. A table is an explicit, approved input of the caller (loot source,
## crafting rules) - never a general default. An item level outside every band is NOT
## configured: the tier roll is refused instead of inventing a distribution.

## One band: {"min_level": int, "max_level": int, "weights": {tier: weight}}.
## Only tiers reachable at the band's lowest level (AffixTiers) may carry a weight.
@export var id: StringName
@export var bands: Array[Dictionary] = []


## Tier -> weight for `item_level`; empty = not configured for this level.
func weights_for(item_level: int) -> Dictionary:
	for band in bands:
		if int(band.get("min_level", 0)) <= item_level and item_level <= int(band.get("max_level", -1)):
			var result := {}
			var weights: Dictionary = band.get("weights", {})
			for tier: Variant in weights:
				result[int(tier)] = float(weights[tier])
			return result
	return {}


func covers(item_level: int) -> bool:
	return not weights_for(item_level).is_empty()


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var taken := {}
	for band in bands:
		var low := int(band.get("min_level", 0))
		var high := int(band.get("max_level", -1))
		var weights: Variant = band.get("weights")
		if low < 1 or high < low or high > WeaponDamage.MAX_ITEM_LEVEL or not weights is Dictionary or weights.is_empty():
			errors.append("tier weights %s: invalid band %s" % [id, band])
			continue
		for level in range(low, high + 1):
			if taken.has(level):
				errors.append("tier weights %s: item level %d in two bands" % [id, level])
				break
			taken[level] = true
		for tier: Variant in weights:
			if not AffixTiers.MIN_ITEM_LEVELS.has(int(tier)) or float(weights[tier]) <= 0.0:
				errors.append("tier weights %s: invalid tier weight %s" % [id, tier])
			elif AffixTiers.min_item_level(int(tier)) > low:
				errors.append("tier weights %s: T%d is not reachable at item level %d" % [id, int(tier), low])
	return errors
