class_name AffixTier
extends Resource
## One tier of an affix (five-tier model, AffixTiers). Tier 1 is the strongest.
## How often a tier is drawn is not a property of the affix: it comes from the
## caller's AffixTierWeights table (Loot Foundation 1.0).

@export var tier: int = 1
@export var min_item_level: int = 1
@export var min_value: float = 1.0
@export var max_value: float = 1.0
