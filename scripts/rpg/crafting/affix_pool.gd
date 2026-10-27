class_name AffixPool
extends RefCounted
## Central affix pool calculation (docs/CRAFTING_DESIGN.md). The crafting preview
## and the actual roll use the SAME entry list, so the probabilities shown in the
## UI are exactly the ones the roll uses. Eligibility and tier weights come from the
## shared core AffixRoller (Loot Foundation 1.0, docs/LOOT_FOUNDATION_1_0.md).
##
## Entry: {"affix": AffixDefinition, "tier": AffixTier, "weight": float, "probability": float}
## Weight of an entry = affix.weight * share of the tier in the tier weight table
## (ProgressionRules.crafting_tier_weights) * material tag multiplier * focus multiplier
## (if the affix has the focus tag). The crafting pool offers GLOBAL affixes only.


## Pool for adding one affix to `item` (or replacing affix `replace_index`).
## Empty when the item is not craftable, has no free affix slot, nothing fits, or no
## tier weights are configured for its item level.
static func compute(item: ItemInstance, definition: ItemDefinition, material: MaterialDefinition,
		db: GameDatabase, focus_tag: StringName = &"", focus_multiplier: float = 1.0,
		replace_index: int = -1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var profile := definition.crafting
	if profile == null or profile.affix_limit() <= 0:
		return entries
	if replace_index < 0 and item.affixes.size() >= profile.affix_limit():
		return entries   # no free affix slot
	var present: Array[Dictionary] = []
	for index in item.affixes.size():
		if index != replace_index:
			present.append(item.affixes[index])
	var weights: AffixTierWeights = db.rules.crafting_tier_weights if db.rules != null else null
	for affix in AffixRoller.eligible(definition, item.item_level, present, db):
		var tiers := AffixRoller.tier_options(affix, item.item_level, weights)
		var tier_total := 0.0
		for option in tiers:
			tier_total += option.weight
		var factor := affix.weight * (material.weight_multiplier(affix.tags) if material != null else 1.0)
		if focus_tag != &"" and focus_tag in affix.tags:
			factor *= focus_multiplier
		for option in tiers:
			entries.append({"affix": affix, "tier": option.tier, "weight": factor * option.weight / tier_total, "probability": 0.0})
	_normalize(entries)
	return entries


## Weighted draw from the computed entries (null-safe: {} when empty).
static func pick(entries: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	if entries.is_empty():
		return {}
	var roll := rng.randf()
	var cumulative := 0.0
	for entry in entries:
		cumulative += entry.probability
		if roll < cumulative:
			return entry
	return entries[entries.size() - 1]


## Probability per affix id (sum over its tiers), for the UI and tests.
static func by_affix(entries: Array[Dictionary]) -> Dictionary:
	var result := {}
	for entry in entries:
		var affix_id: StringName = (entry.affix as AffixDefinition).id
		result[affix_id] = result.get(affix_id, 0.0) + entry.probability
	return result


## Tags offered by the pool (focus catalyst choices).
static func tags_of(entries: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries:
		for tag in (entry.affix as AffixDefinition).tags:
			if not tag in result:
				result.append(tag)
	result.sort()
	return result


static func _normalize(entries: Array[Dictionary]) -> void:
	var total := 0.0
	for entry in entries:
		total += entry.weight
	for entry in entries:
		entry.probability = entry.weight / total if total > 0.0 else 0.0
