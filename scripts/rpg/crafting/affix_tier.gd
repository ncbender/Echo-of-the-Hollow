class_name AffixTier
extends Resource
## One tier of an affix. Tier 1 is the strongest.

@export var tier: int = 1
@export var min_item_level: int = 1
@export var min_value: float = 1.0
@export var max_value: float = 1.0
## Relative weight inside the affix (rarer high tiers have lower weights).
@export var weight: float = 100.0
