class_name AffixDefinition
extends Resource
## A rollable item property. Rolled values are stored on the ItemInstance and
## never re-rolled on load.

## FLAT adds points to the stat (all current stats are point or percent-point
## stats, e.g. +6 "Physical Damage %"); PERCENT multiplies the stat total.
enum ValueKind { FLAT, PERCENT }
## Item Foundation 1.0: the four affix categories (metadata; no calculation reads it).
enum Category { OFFENSIVE, DEFENSIVE, UTILITY, RESOURCE }
## Item Foundation 1.0: GLOBAL works on the character (StatResolver); LOCAL only changes
## the item's own base value. Both share the regular affix slots. Weapon Base Damage 1.0:
## the only local target so far is the weapon base damage (stat Stats.WEAPON_DAMAGE,
## WeaponDamage); AffixPool does not offer LOCAL affixes yet (activation not decided).
enum Scope { GLOBAL, LOCAL }

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.OFFENSIVE
@export var scope: Scope = Scope.GLOBAL
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
## Tier model of `tiers` (AffixTiers.MODEL_THREE or MODEL_FIVE). Rolls store it, so a
## saved tier number is never reinterpreted when an affix moves to another model.
@export var tier_model: int = AffixTiers.MODEL_THREE
@export var tiers: Array[AffixTier] = []
## LOCAL flat affix whose tier range is a percent share of the family reference curve
## B_ref(item level) (Striking): the roll stores flat = B_ref x roll / 100 once and
## never follows quality or character stats afterwards.
@export var reference_share: bool = false


func allows_slot(kind: ItemDefinition.SlotKind) -> bool:
	if scope == Scope.LOCAL and not ItemDefinition.allows_local_affixes(kind):
		return false
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


## Tier of a rolled entry - only when it was rolled under this affix's tier model
## (null otherwise: an old tier number is never read as a tier of another model).
func tier_of(entry: Dictionary) -> AffixTier:
	if AffixTiers.model_of(entry) != tier_model:
		return null
	return get_tier(int(entry.get("tier", 0)))


## Saved affix entry for `tier` with a whole-number value rolled by `rng`.
## `reference` = B_ref of the item (WeaponDamage.reference_of), used by reference_share
## affixes: the whole-number roll is then the percent share, kept as "share".
func roll(tier: AffixTier, rng: RandomNumberGenerator, reference: float = 0.0) -> Dictionary:
	var value := float(rng.randi_range(roundi(tier.min_value), roundi(tier.max_value)))
	var entry := {
		"affix": String(id), "tier": tier.tier, "tier_model": tier_model, "stat": String(stat),
		"flat": value if value_kind == ValueKind.FLAT else 0.0,
		"percent": value if value_kind == ValueKind.PERCENT else 0.0,
	}
	if reference_share:
		entry["share"] = value
		entry["flat"] = reference * value / 100.0
	return entry


func describe_range(tier: AffixTier) -> String:
	if reference_share:
		return "+%d-%d%% of reference %s" % [roundi(tier.min_value), roundi(tier.max_value), Stats.display_name(stat)]
	var suffix := " (x%)" if value_kind == ValueKind.PERCENT else ""
	return "+%d-%d %s%s" % [roundi(tier.min_value), roundi(tier.max_value), Stats.display_name(stat), suffix]


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or stat == &"" or group == &"":
		errors.append("affix %s: id, stat and group are required" % id)
	if not category in Category.values():
		errors.append("affix %s: unknown category %d" % [id, category])
	if scope == Scope.LOCAL:
		if allowed_slot_kinds.is_empty():
			errors.append("affix %s: a local affix must list its weapon/armour slot kinds" % id)
		for kind in allowed_slot_kinds:
			if not ItemDefinition.allows_local_affixes(kind):
				errors.append("affix %s: local affixes are not allowed on slot kind %d" % [id, kind])
	elif scope != Scope.GLOBAL:
		errors.append("affix %s: unknown scope %d" % [id, scope])
	if reference_share and (scope != Scope.LOCAL or value_kind != ValueKind.FLAT):
		errors.append("affix %s: a reference share is a local flat value" % id)
	if stat == Stats.WEAPON_DAMAGE and scope != Scope.LOCAL:
		errors.append("affix %s: %s is item-local, never a global stat" % [id, stat])
	if tiers.is_empty():
		errors.append("affix %s: no tiers" % id)
	if tier_model != AffixTiers.MODEL_THREE and tier_model != AffixTiers.MODEL_FIVE:
		errors.append("affix %s: unknown tier model %d" % [id, tier_model])
		return errors
	var seen := {}
	for tier in tiers:
		if tier == null or tier.min_value > tier.max_value or tier.weight <= 0.0:
			errors.append("affix %s: invalid tier" % id)
		elif seen.has(tier.tier):
			errors.append("affix %s: duplicate tier %d" % [id, tier.tier])
		elif tier.tier < 1 or tier.tier > tier_model:
			errors.append("affix %s: tier %d outside the %d-tier model" % [id, tier.tier, tier_model])
		else:
			seen[tier.tier] = true
			if tier_model == AffixTiers.MODEL_FIVE and tier.min_item_level != AffixTiers.min_item_level(tier.tier):
				errors.append("affix %s: T%d must start at item level %d (has %d)" % [id, tier.tier, AffixTiers.min_item_level(tier.tier), tier.min_item_level])
	if tier_model == AffixTiers.MODEL_FIVE and seen.size() != AffixTiers.COUNT and errors.is_empty():
		errors.append("affix %s: the five-tier model needs all tiers T5..T1" % id)
	return errors
