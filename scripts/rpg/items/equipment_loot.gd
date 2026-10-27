class_name EquipmentLoot
extends RefCounted
## Hollowwood Loot Integration 1.0 (docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md): the equipment
## roll of one drop event. Exactly one chance check; on success the model (equal weights),
## the rarity (table weights) and the item level (uniform offset) are drawn and the one
## instance is created by ItemCreation.generate - nothing is rolled again afterwards
## (pickup, inventory and saves keep that same instance).


## The new instance of one drop event, or null when nothing drops (or the roll is refused).
static func roll(table: EquipmentLootTable, db: GameDatabase, rng: RandomNumberGenerator) -> ItemInstance:
	if table == null or table.item_ids.is_empty() or rng.randf() >= table.chance:
		return null
	var definition := db.get_item(table.item_ids[rng.randi_range(0, table.item_ids.size() - 1)])
	var rarities: Array[Dictionary] = []
	for rarity: Variant in table.rarity_weights:
		rarities.append({"rarity": int(rarity), "weight": float(table.rarity_weights[rarity])})
	var rarity := int(AffixRoller.pick(rarities, rng).get("rarity", ItemDefinition.Rarity.NORMAL))
	var level := table.source_level + rng.randi_range(-table.level_spread, table.level_spread)
	var result := ItemCreation.generate(definition, rarity as ItemDefinition.Rarity, db, rng, table.tier_weights, level, ItemInstance.ORIGIN_FOUND)
	if not result.ok():
		push_warning("loot table %s: %s" % [table.id, result.error])
	return result.item
