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


static func create(definition: ItemDefinition, amount: int, db: GameDatabase, item_level: int = 0, id: String = "") -> ItemInstance:
	var item := ItemInstance.create(definition.id, amount, id)
	var level := item_level if item_level > 0 else definition.creation_item_level()
	if level > 0:
		item.item_level = clampi(level, 1, WeaponDamage.MAX_ITEM_LEVEL)
	if WeaponDamage.is_on_model(definition):
		item.base_weapon_damage = WeaponDamage.base_for_level(definition, item.item_level, db)
	return item
