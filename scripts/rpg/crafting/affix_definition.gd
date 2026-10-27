class_name AffixDefinition
extends Resource
## A rollable item property. Rolled values are stored on the ItemInstance and
## never re-rolled on load. Eligibility and rolls go through AffixRoller (Loot
## Foundation 1.0, docs/LOOT_FOUNDATION_1_0.md), shared by loot and crafting.

## FLAT adds points to the stat (all current stats are point or percent-point
## stats, e.g. +6 "Physical Damage %"); PERCENT multiplies the stat total.
enum ValueKind { FLAT, PERCENT }
## Item Foundation 1.0: the four affix categories (metadata; no calculation reads it).
enum Category { OFFENSIVE, DEFENSIVE, UTILITY, RESOURCE }
## Item Foundation 1.0: GLOBAL works on the character (StatResolver); LOCAL only changes
## the item's own base value. Both share the regular affix slots. Weapon Base Damage 1.0:
## the only local target so far is the weapon base damage (stat Stats.WEAPON_DAMAGE,
## WeaponDamage). Loot generation offers LOCAL affixes; the crafting pool does not yet.
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
## Effect condition as an eligibility rule: the item's weapon family must own at least one
## attack whose effect tags contain all of these (Executioner: heavy + finisher, the tags
## CharacterStatModifier requires). Empty = no condition. Non-weapons never qualify.
@export var required_attack_tags: Array[StringName] = []
@export var min_item_level: int = 1
## Base weight of the affix identity among the eligible affixes (Loot Foundation 1.0).
@export var weight: float = 100.0
## False = defined, but never drawn by any pool yet (Armored: local armour base missing).
@export var rollable: bool = true
## Tier model of `tiers`; every definition uses AffixTiers.MODEL_FIVE. Rolls store it, so a
## saved tier number of another model (legacy MODEL_THREE rolls) is never reinterpreted.
@export var tier_model: int = AffixTiers.MODEL_FIVE
@export var tiers: Array[AffixTier] = []
## Granularity of rolled values (1 = whole numbers; Keen rolls tenths of a percent point).
@export var value_step: float = 1.0
## LOCAL flat affix whose tier range is a percent share of the family reference curve
## B_ref(item level) (Striking): the roll stores flat = B_ref x roll / 100 once and
## never follows quality or character stats afterwards.
@export var reference_share: bool = false


func allows_slot(kind: ItemDefinition.SlotKind) -> bool:
	if scope == Scope.LOCAL and not ItemDefinition.allows_local_affixes(kind):
		return false
	return allowed_slot_kinds.is_empty() or kind in allowed_slot_kinds


## The effect condition (required_attack_tags) can apply to items of `definition`.
func fits_family(definition: ItemDefinition, db: GameDatabase) -> bool:
	if required_attack_tags.is_empty():
		return true
	var family: WeaponFamily = db.weapons.get(definition.weapon_family_id) if definition != null and definition.is_weapon() else null
	if family == null:
		return false
	for attack in family.attacks:
		if attack == null:
			continue
		var matches := true
		for tag in required_attack_tags:
			matches = matches and tag in attack.effect_tags
		if matches:
			return true
	return false


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


## Saved affix entry for `tier` with a value rolled once by `rng` in steps of value_step.
## `reference` = B_ref of the item (WeaponDamage.reference_of), used by reference_share
## affixes: the whole-number roll is then the percent share, kept as "share".
func roll(tier: AffixTier, rng: RandomNumberGenerator, reference: float = 0.0) -> Dictionary:
	var steps := roundi((tier.max_value - tier.min_value) / value_step)
	var value := snappedf(tier.min_value + rng.randi_range(0, steps) * value_step, value_step)
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
	return "+%s-%s %s%s" % [_number(tier.min_value), _number(tier.max_value), Stats.display_name(stat), suffix]


func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else str(snappedf(value, value_step))


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
	if reference_share and (scope != Scope.LOCAL or value_kind != ValueKind.FLAT or value_step != 1.0):
		errors.append("affix %s: a reference share is a local flat whole-number value" % id)
	if stat == Stats.WEAPON_DAMAGE and scope != Scope.LOCAL:
		errors.append("affix %s: %s is item-local, never a global stat" % [id, stat])
	if weight <= 0.0 or value_step <= 0.0:
		errors.append("affix %s: weight and value_step must be positive" % id)
	if tiers.is_empty():
		errors.append("affix %s: no tiers" % id)
	if tier_model != AffixTiers.MODEL_FIVE:
		errors.append("affix %s: definitions use the five-tier model (has %d)" % [id, tier_model])
		return errors
	var seen := {}
	for tier in tiers:
		if tier == null or tier.min_value > tier.max_value:
			errors.append("affix %s: invalid tier" % id)
		elif seen.has(tier.tier):
			errors.append("affix %s: duplicate tier %d" % [id, tier.tier])
		elif tier.tier < 1 or tier.tier > tier_model:
			errors.append("affix %s: tier %d outside the %d-tier model" % [id, tier.tier, tier_model])
		else:
			seen[tier.tier] = true
			if tier.min_item_level != AffixTiers.min_item_level(tier.tier):
				errors.append("affix %s: T%d must start at item level %d (has %d)" % [id, tier.tier, AffixTiers.min_item_level(tier.tier), tier.min_item_level])
			if not _on_step(tier.min_value) or not _on_step(tier.max_value):
				errors.append("affix %s: T%d range is not a multiple of value_step %s" % [id, tier.tier, value_step])
	if seen.size() != AffixTiers.COUNT and errors.is_empty():
		errors.append("affix %s: the five-tier model needs all tiers T5..T1" % id)
	return errors


func _on_step(value: float) -> bool:
	return value_step > 0.0 and is_equal_approx(value / value_step, roundf(value / value_step))
