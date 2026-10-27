class_name AffixTiers
extends RefCounted
## Item Foundation 1.0 (docs/ITEM_FOUNDATION_1_0.md): the regular affix tier model.
## Five tiers T5..T1, T1 is the highest. A tier is only reachable from its item level.
## The value ranges stay per affix (AffixTier); only the tiers and thresholds are fixed here.

## Tier model ids stored in every rolled affix entry ("tier_model"): a tier number
## means something different in each model, so it is never read across models.
const MODEL_THREE := 3   # prototype model of Crafting Foundation 0.1 (T3 lowest, T1 highest)
const MODEL_FIVE := 5    # Item Foundation 1.0 model (T5 lowest, T1 highest)

const COUNT := 5
## Lowest item level of each tier of the five-tier model (key = tier number).
const MIN_ITEM_LEVELS := {5: 1, 4: 10, 3: 25, 2: 45, 1: 70}


static func min_item_level(tier: int) -> int:
	return int(MIN_ITEM_LEVELS.get(tier, -1))


## Highest (= lowest number) five-tier tier available at `item_level`; 0 below level 1.
static func highest_tier(item_level: int) -> int:
	var best := 0
	for tier: int in MIN_ITEM_LEVELS:
		if item_level >= MIN_ITEM_LEVELS[tier] and (best == 0 or tier < best):
			best = tier
	return best


## Tier model of a rolled entry; 0 = unknown (never compared to a definition's tiers).
static func model_of(entry: Dictionary) -> int:
	var value: Variant = entry.get("tier_model", 0)
	return int(value) if value is int or value is float else 0
