class_name WeaponDamage
extends RefCounted
## Weapon Base Damage 1.0 (docs/WEAPON_BASE_DAMAGE_1_0.md): the weapon side of a
## regular weapon attack. The single place that turns an item instance into
##   D_weapon = (base_weapon_damage x Q + local flat) x (1 + sum local %)
## (Q = ItemStats.quality_factor). CombatComponent multiplies it with the attack's
## weapon_damage_multiplier; all AttackModifiers follow unchanged.
## Weapons without base_weapon_damage are not on the model yet (D_weapon 0): their
## attacks keep the family reference damage, quality keeps working on their base stats.

## Reference curve B_ref(L) = B1 x (1 + LEVEL_SLOPE x (L - 1)), item level 1..MAX_ITEM_LEVEL.
const LEVEL_SLOPE := 0.012
const MAX_ITEM_LEVEL := 100


static func is_on_model(definition: ItemDefinition) -> bool:
	return definition != null and definition.is_weapon() and definition.base_weapon_damage > 0.0


## D_weapon of `item`; 0 when the item is not a weapon on the base damage model.
static func of(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> float:
	if item == null or not is_on_model(definition):
		return 0.0
	var flat := 0.0
	var percent := 0.0
	for entry in item.affixes:
		if is_local(entry, db):
			flat += float(entry.get("flat", 0.0))
			percent += float(entry.get("percent", 0.0))
	return (definition.base_weapon_damage * ItemStats.quality_factor(item.quality) + flat) * (1.0 + percent / 100.0)


## A rolled entry of a LOCAL weapon damage affix (never a character stat).
static func is_local(entry: Dictionary, db: GameDatabase) -> bool:
	var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
	return affix != null and affix.scope == AffixDefinition.Scope.LOCAL


## Family reference B_ref at `item_level` (B1 = WeaponFamily.reference_base_damage).
static func reference_at(family_base: float, item_level: int) -> float:
	return family_base * (1.0 + LEVEL_SLOPE * (clampi(item_level, 1, MAX_ITEM_LEVEL) - 1))


## B_ref of the item's family at its item level (Striking rolls); 0 without a family reference.
static func reference_of(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> float:
	if item == null or definition == null:
		return 0.0
	var family: WeaponFamily = db.weapons.get(definition.weapon_family_id)
	return reference_at(family.reference_base_damage, item.item_level) if family != null else 0.0
