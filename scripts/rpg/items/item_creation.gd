class_name ItemCreation
extends RefCounted
## The one initialisation contract of a NEW item instance (Weapon Base Damage 1.1,
## docs/WEAPON_BASE_DAMAGE_1_1.md). Every way a new item comes into being uses it
## (Inventory.add_item, tooltip previews); transfers and loading never do.
##  * item level: explicitly passed by the caller, else the item's own approved source
##    (ItemDefinition.creation_item_level); without either it stays at 1 - never derived
##    from the character or invented.
##  * weapons on the base damage model: base_weapon_damage = B_ref(item level) x model
##    factor, stored once on the instance (WeaponDamage.base_for_level).
##  * Loot Foundation 1.0 (docs/LOOT_FOUNDATION_1_0.md): equippable instances own their
##    rarity (create: the definition's; generate: the requested one) and generate() rolls
##    the regular affixes of that rarity once through AffixRoller.

## Regular affix count of a generated item per rarity: {count: weight} (approved
## distribution). Unique and Set are never generated; Normal rolls no regular affix.
const AFFIX_COUNTS := {
	ItemDefinition.Rarity.NORMAL: {0: 100.0},
	ItemDefinition.Rarity.MAGIC: {1: 40.0, 2: 40.0, 3: 20.0},
	ItemDefinition.Rarity.RARE: {3: 60.0, 4: 40.0},
	ItemDefinition.Rarity.EPIC: {4: 60.0, 5: 40.0},
	ItemDefinition.Rarity.LEGENDARY: {5: 100.0},
}


## Result of generate(). `item` is null when the request was refused (`error`). When fewer
## eligible affixes exist than the rarity asks for, the item keeps the ones that rolled and
## `shortfall` (> 0) and `note` say so - no rule is bent to fill the count.
class Generated:
	var item: ItemInstance
	var requested_affixes: int = 0
	var shortfall: int = 0
	var error: String = ""
	var note: String = ""

	func ok() -> bool:
		return item != null


static func create(definition: ItemDefinition, amount: int, db: GameDatabase, item_level: int = 0, id: String = "") -> ItemInstance:
	var item := ItemInstance.create(definition.id, amount, id)
	var level := item_level if item_level > 0 else definition.creation_item_level()
	if level > 0:
		item.item_level = clampi(level, 1, WeaponDamage.MAX_ITEM_LEVEL)
	if WeaponDamage.is_on_model(definition):
		item.base_weapon_damage = WeaponDamage.base_for_level(definition, item.item_level, db)
	if definition.is_equippable():
		item.rarity = definition.rarity
	return item


## A new equippable instance of `definition` with instance rarity `rarity` and its regular
## affixes (count from AFFIX_COUNTS, identities/tiers/values from AffixRoller with
## `tier_weights`, only ids of definition.generation_affixes, LOCAL included). Item level:
## `item_level` if given, else the definition's approved source; none = refused. Refused
## too: items not prepared for generation, Unique/Set items, Unique/Set as rarity, and
## affix rolls without tier weights for the item level. Nothing is added to an inventory.
static func generate(definition: ItemDefinition, rarity: ItemDefinition.Rarity, db: GameDatabase,
		rng: RandomNumberGenerator, tier_weights: AffixTierWeights, item_level: int = 0,
		origin: StringName = &"", id: String = "") -> Generated:
	var result := Generated.new()
	var level := item_level if item_level > 0 else (definition.creation_item_level() if definition != null else 0)
	if definition == null or definition.generation_affixes.is_empty():
		result.error = "item is not prepared for generation"
	elif definition.rarity in [ItemDefinition.Rarity.UNIQUE, ItemDefinition.Rarity.SET] or not AFFIX_COUNTS.has(rarity):
		result.error = "unique and set identities are never generated"
	elif level < 1 or level > WeaponDamage.MAX_ITEM_LEVEL:
		result.error = "no approved item level"
	elif rarity != ItemDefinition.Rarity.NORMAL and (tier_weights == null or not tier_weights.covers(level)):
		result.error = "affix tier weights not configured for item level %d" % level
	if result.error != "":
		return result
	var item := create(definition, 1, db, level, id)
	item.rarity = rarity
	item.origin = origin
	var counts: Array[Dictionary] = []
	for count: int in AFFIX_COUNTS[rarity]:
		counts.append({"count": count, "weight": AFFIX_COUNTS[rarity][count]})
	result.requested_affixes = int(AffixRoller.pick(counts, rng).count)
	# Each roll takes one more group out of the pool, so this ends after at most
	# requested_affixes passes even when the pool runs dry.
	while item.affixes.size() < result.requested_affixes:
		var entry := AffixRoller.roll_one(item, definition, db, tier_weights, rng, definition.generation_affixes, true)
		if entry.is_empty():
			break
		item.affixes.append(entry)
	result.shortfall = result.requested_affixes - item.affixes.size()
	if result.shortfall > 0:
		result.note = "only %d of %d affixes eligible for %s at item level %d" % [item.affixes.size(), result.requested_affixes, definition.id, level]
	result.item = item
	return result
