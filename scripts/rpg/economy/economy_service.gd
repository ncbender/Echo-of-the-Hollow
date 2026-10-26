class_name EconomyService
extends RefCounted
## Hollowwood Loot Economy 1.0 - controlled foundation (docs/ECONOMY.md).
## Stateless rules:
##   sell value = base item value x rarity factor (rules.rarity_sell_factors),
##   rounded down, per unit of a stack. Unique and Set items use their own
##   special_sell_value (0 = never sold). Gold, quest items and items without a
##   designed base value are not sold.
## Selling is one transaction (protection checked first: equipped, presets,
## favourite, locked, quest, unique/set rules - ItemProtection; then the item
## leaves and the gold arrives). There is no vendor in the game yet, so nothing
## calls sell() outside tests and the economy simulation.

const GOLD := &"gold_coin"


## Gold for one unit of `definition` (0 = not sellable).
static func unit_value(db: GameDatabase, definition: ItemDefinition) -> int:
	if definition == null or definition.is_currency or definition.category == ItemDefinition.Category.QUEST:
		return 0
	if definition.rarity in [ItemDefinition.Rarity.UNIQUE, ItemDefinition.Rarity.SET]:
		return maxi(0, definition.special_sell_value)
	var factors := db.rules.rarity_sell_factors
	if definition.base_value <= 0 or definition.rarity >= factors.size():
		return 0
	return floori(definition.base_value * factors[definition.rarity] + 0.0001)


## Gold for the whole bag item `instance_id` (0 = not sellable).
static func sell_value(character: Character, instance_id: String) -> int:
	var item := character.inventory.find(instance_id)
	if item == null:
		return 0
	return unit_value(character.database, character.database.get_item(item.definition_id)) * item.quantity


## "" if the bag item can be sold now, otherwise why not.
static func sell_error(character: Character, instance_id: String) -> String:
	var item := character.inventory.find(instance_id)
	if item == null:
		return "That item is no longer in your bag."
	var definition := character.database.get_item(item.definition_id)
	if definition != null and (definition.is_currency or definition.category == ItemDefinition.Category.QUEST):
		return "This item cannot be sold."
	if definition != null and not definition.is_stackable():
		var block := ItemProtection.destroy_block(character, instance_id, true)
		if block != "":
			return block.replace("salvaged", "sold")
	if sell_value(character, instance_id) <= 0:
		return "This item has no value yet."
	if character.inventory.room_for(GOLD) < sell_value(character, instance_id):
		return "You cannot carry more gold."
	return ""


## Sells the whole bag item. Returns {"error", "gold"}; on an error nothing changed.
static func sell(character: Character, instance_id: String) -> Dictionary:
	var error := sell_error(character, instance_id)
	if error != "":
		return {"error": error, "gold": 0}
	var gold := sell_value(character, instance_id)
	var removed := character.inventory.remove_instance(instance_id)
	if character.inventory.add_item(GOLD, gold).is_empty():
		character.inventory.add_instance(removed)   # cannot happen after the room check
		return {"error": "You cannot carry more gold.", "gold": 0}
	return {"error": "", "gold": gold}
