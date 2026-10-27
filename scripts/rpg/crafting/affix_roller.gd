class_name AffixRoller
extends RefCounted
## Loot Foundation 1.0 (docs/LOOT_FOUNDATION_1_0.md): the one eligibility and roll core for
## regular affixes, shared by loot generation (ItemCreation.generate) and the crafting pool
## (AffixPool; later Reforge). It decides which affix identities, tiers and values are
## allowed - never which operation happens. Identity, tier and value are drawn separately:
##  * identity: eligible() filtered by the rules below, drawn by AffixDefinition.weight
##  * tier: from the caller's AffixTierWeights for the item level (only reachable tiers);
##    no table or an uncovered item level = not configured, nothing is drawn
##  * value: AffixDefinition.roll, once - stored rolls are never re-rolled
## A weight never admits an affix: every rule is a hard filter first.


## Affixes that may roll as one more regular affix on an item of `definition` at
## `item_level` already carrying `present` (rolled entries; legacy entries without "affix"
## are ignored). Rules: rollable, slot kind incl. LOCAL scope, weapon family effect
## condition, minimum item level with at least one reachable tier, `allowed_ids` (empty =
## every affix of `db`), `include_local`, no second affix of a group or exclusion group,
## at most CraftingProfile.MAX_AFFIX_SLOTS regular affixes. Sorted by id (deterministic).
static func eligible(definition: ItemDefinition, item_level: int, present: Array[Dictionary], db: GameDatabase,
		allowed_ids: Array[StringName] = [], include_local: bool = false) -> Array[AffixDefinition]:
	var result: Array[AffixDefinition] = []
	if definition == null or not definition.is_equippable() or present.size() >= CraftingProfile.MAX_AFFIX_SLOTS:   # legacy stat rolls use a slot too
		return result
	var taken := {}
	for entry in present:
		var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
		if affix != null:
			taken["id:%s" % affix.id] = true
			taken["group:%s" % affix.group] = true
			if affix.exclusion_group != &"":
				taken["exclusion:%s" % affix.exclusion_group] = true
	var ids: Array = db.affixes.keys() if allowed_ids.is_empty() else allowed_ids.duplicate()
	ids.sort()
	for affix_id: StringName in ids:
		var affix: AffixDefinition = db.affixes.get(affix_id)
		if affix == null or not affix.rollable or (affix.scope == AffixDefinition.Scope.LOCAL and not include_local):
			continue
		if taken.has("id:%s" % affix.id) or taken.has("group:%s" % affix.group):
			continue
		if affix.exclusion_group != &"" and taken.has("exclusion:%s" % affix.exclusion_group):
			continue
		if not affix.allows_slot(definition.slot_kind) or not affix.fits_family(definition, db):
			continue
		if affix.tiers_for_level(item_level).is_empty():
			continue
		result.append(affix)
	return result


## Tier draw of `affix` at `item_level`: [{"tier": AffixTier, "weight": float}] with the
## table's weights of the tiers the affix has and the item level reaches. Empty when the
## table is missing or does not cover the item level (not configured).
static func tier_options(affix: AffixDefinition, item_level: int, weights: AffixTierWeights) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if weights == null:
		return result
	var table := weights.weights_for(item_level)
	for tier in affix.tiers_for_level(item_level):
		if float(table.get(tier.tier, 0.0)) > 0.0:
			result.append({"tier": tier, "weight": float(table[tier.tier])})
	return result


## Weighted draw of one entry by its "weight" (null-safe: {} when empty or weightless).
static func pick(options: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for option in options:
		total += float(option.weight)
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for option in options:
		roll -= float(option.weight)
		if roll < 0.0:
			return option
	return options[options.size() - 1]


## One complete regular affix for `item` (identity, then tier, then value) from the eligible
## affixes; {} when nothing is eligible or no tier is configured. Does not change `item`.
static func roll_one(item: ItemInstance, definition: ItemDefinition, db: GameDatabase, weights: AffixTierWeights,
		rng: RandomNumberGenerator, allowed_ids: Array[StringName] = [], include_local: bool = false) -> Dictionary:
	var identities: Array[Dictionary] = []
	for affix in eligible(definition, item.item_level, item.affixes, db, allowed_ids, include_local):
		if not tier_options(affix, item.item_level, weights).is_empty():
			identities.append({"affix": affix, "weight": affix.weight})
	var chosen := pick(identities, rng)
	if chosen.is_empty():
		return {}
	var affix: AffixDefinition = chosen.affix
	var tier: AffixTier = pick(tier_options(affix, item.item_level, weights), rng).tier
	return affix.roll(tier, rng, WeaponDamage.reference_of(item, definition, db))
