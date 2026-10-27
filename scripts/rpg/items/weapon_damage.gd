class_name WeaponDamage
extends RefCounted
## Weapon Base Damage 1.0/1.1 (docs/WEAPON_BASE_DAMAGE_1_1.md): the weapon side of a
## regular weapon attack. The single place that turns an item instance into
##   D_weapon = (stored base_weapon_damage x Q + local flat) x (1 + sum local %)
## (Q = ItemStats.quality_factor). CombatComponent multiplies it with the attack's
## weapon_damage_multiplier; all AttackModifiers follow unchanged.
## The stored base is assigned once at creation (ItemCreation): B_ref(item level) x model
## factor of the definition. Weapons not on the model (D_weapon 0) keep the family
## reference damage, quality keeps working on their base stats.

## Reference curve B_ref(L) = B1 x (1 + LEVEL_SLOPE x (L - 1)), item level 1..MAX_ITEM_LEVEL.
const LEVEL_SLOPE := 0.012
const MAX_ITEM_LEVEL := 100


static func is_on_model(definition: ItemDefinition) -> bool:
	return definition != null and definition.is_weapon() and definition.base_weapon_damage > 0.0


## D_weapon of `item` from its stored base; 0 when the item is not a weapon on the model.
static func of(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> float:
	if item == null or item.base_weapon_damage <= 0.0 or not is_on_model(definition):
		return 0.0
	var flat := 0.0
	var percent := 0.0
	for entry in item.affixes:
		if is_local(entry, db) and StringName(str(entry.get("stat", ""))) == Stats.WEAPON_DAMAGE:
			flat += float(entry.get("flat", 0.0))
			percent += float(entry.get("percent", 0.0))
	return (item.base_weapon_damage * ItemStats.quality_factor(item.quality) + flat) * (1.0 + percent / 100.0)


## A rolled entry of a LOCAL affix: it only changes its item's base, never a character stat.
static func is_local(entry: Dictionary, db: GameDatabase) -> bool:
	var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
	return affix != null and affix.scope == AffixDefinition.Scope.LOCAL


## Family reference B_ref at `item_level` (B1 = WeaponFamily.reference_base_damage).
static func reference_at(family_base: float, item_level: int) -> float:
	return family_base * (1.0 + LEVEL_SLOPE * (clampi(item_level, 1, MAX_ITEM_LEVEL) - 1))


## B1 of the definition's weapon family (0 without one).
static func family_base(definition: ItemDefinition, db: GameDatabase) -> float:
	var family: WeaponFamily = db.weapons.get(definition.weapon_family_id) if definition != null else null
	return family.reference_base_damage if family != null else 0.0


## B_ref of the item's family at its item level (Striking rolls); 0 without a family reference.
static func reference_of(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> float:
	if item == null or definition == null:
		return 0.0
	return reference_at(family_base(definition, db), item.item_level)


## Fixed model factor, derived exactly from the approved base at the creation item level
## (never a rounded factor): base_weapon_damage / B_ref(creation level). 0 = not on the model.
static func model_factor(definition: ItemDefinition, db: GameDatabase) -> float:
	var reference := reference_at(family_base(definition, db), definition.creation_item_level()) if is_on_model(definition) else 0.0
	return definition.base_weapon_damage / reference if reference > 0.0 else 0.0


## Raw base damage of a new instance at `item_level`: B_ref(level) x model factor.
static func base_for_level(definition: ItemDefinition, item_level: int, db: GameDatabase) -> float:
	return reference_at(family_base(definition, db), item_level) * model_factor(definition, db)
