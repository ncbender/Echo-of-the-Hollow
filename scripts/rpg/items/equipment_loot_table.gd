class_name EquipmentLootTable
extends Resource
## Hollowwood Loot Integration 1.0 (docs/HOLLOWWOOD_LOOT_INTEGRATION_1_0.md): one equipment
## drop roll of a loot source (a Hollow Grunt kill, a cleared wolf encounter). All values are
## approved design data; EquipmentLoot.roll is the only reader.

@export var id: StringName
## Chance (0..1) that the drop event yields one equipment item at all.
@export_range(0.0, 1.0) var chance: float = 0.0
## Item models, all with the same weight.
@export var item_ids: Array[StringName] = []
## Rarity weights {ItemDefinition.Rarity: weight}.
@export var rarity_weights: Dictionary = {}
## Item level = source_level + a uniform whole offset in -level_spread..+level_spread.
@export var source_level: int = 1
@export var level_spread: int = 0
## Approved affix tier weights for the reachable item levels.
@export var tier_weights: AffixTierWeights


func validate(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	if item_ids.is_empty() or rarity_weights.is_empty() or tier_weights == null:
		errors.append("loot table %s: items, rarities and tier weights are required" % id)
		return errors
	for item_id in item_ids:
		var definition := db.get_item(item_id)
		if definition == null or definition.generation_affixes.is_empty():
			errors.append("loot table %s: %s is not prepared for generation" % [id, item_id])
	for rarity: Variant in rarity_weights:
		if not int(rarity) in ItemCreation.AFFIX_COUNTS or float(rarity_weights[rarity]) <= 0.0:
			errors.append("loot table %s: invalid rarity weight %s" % [id, rarity])
	var low := source_level - level_spread
	var high := source_level + level_spread
	if level_spread < 0 or low < 1 or high > WeaponDamage.MAX_ITEM_LEVEL:
		errors.append("loot table %s: invalid item level range" % id)
	for level in range(maxi(low, 1), mini(high, WeaponDamage.MAX_ITEM_LEVEL) + 1):
		if not tier_weights.covers(level):
			errors.append("loot table %s: tier weights do not cover item level %d" % [id, level])
	return errors
