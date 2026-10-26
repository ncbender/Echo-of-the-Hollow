class_name BaseBuilder
extends RefCounted
## Rules for building on plots and crafting in buildings. Stateless: all state
## lives in the Character (inventory, WorldState.buildings / flags).
## Every action checks everything first and only then changes state, so a
## refused action never consumes anything.


static func plot_state(character: Character, plot_id: StringName) -> StringName:
	return character.world.buildings.get(plot_id, &"")


## "" if `building` can be built on `plot` right now, otherwise the reason.
static func build_error(character: Character, plot: BuildingPlotDefinition, building: BuildingDefinition) -> String:
	if plot == null or building == null:
		return "unknown plot or building"
	if plot_state(character, plot.id) != &"":
		return "plot is already occupied"
	if not plot.allows(building):
		return "%s cannot be built on this plot" % building.display_name
	if building.required_flag != &"" and not character.world.has_flag(building.required_flag):
		return "requires: %s" % building.required_flag
	if building.unique and building.id in character.world.buildings.values():
		return "%s already exists in the base" % building.display_name
	var missing := missing_items(character, building.costs)
	if not missing.is_empty():
		return "missing materials: %s" % ", ".join(missing)
	return ""


## Builds and consumes the costs. Returns "" on success or the reason.
static func build(character: Character, plot: BuildingPlotDefinition, building: BuildingDefinition) -> String:
	var error := build_error(character, plot, building)
	if error != "":
		return error
	for cost in building.costs:
		character.inventory.remove_quantity(cost.item_id, cost.quantity)
	character.world.buildings[plot.id] = building.id
	character.world.set_flag(StringName("building.%s" % building.id))
	character.refresh_inventory_capacity()
	return ""


static func craft_error(character: Character, recipe: RecipeDefinition) -> String:
	if recipe == null or character.database.get_item(recipe.output_item_id) == null:
		return "invalid recipe"
	var missing := missing_items(character, recipe.inputs)
	if not missing.is_empty():
		return "missing: %s" % ", ".join(missing)
	# Conservative: requires room before inputs are removed.
	if character.inventory.room_for(recipe.output_item_id) < recipe.output_quantity:
		return "inventory full"
	return ""


static func craft(character: Character, recipe: RecipeDefinition) -> String:
	var error := craft_error(character, recipe)
	if error != "":
		return error
	for input in recipe.inputs:
		character.inventory.remove_quantity(input.item_id, input.quantity)
	character.inventory.add_item(recipe.output_item_id, recipe.output_quantity, ItemInstance.ORIGIN_CRAFTED)
	return ""


## "Timber 2/6"-style list of unmet costs (empty when affordable).
static func missing_items(character: Character, costs: Array[ItemCost]) -> PackedStringArray:
	var missing: PackedStringArray = []
	for cost in costs:
		var have := character.inventory.count(cost.item_id)
		if have < cost.quantity:
			var definition := character.database.get_item(cost.item_id)
			missing.append("%s %d/%d" % [definition.display_name if definition else String(cost.item_id), have, cost.quantity])
	return missing


## Inventory slots granted by all standing buildings.
static func capacity_bonus(character: Character) -> int:
	var bonus := 0
	for building_id: StringName in character.world.buildings.values():
		var building: BuildingDefinition = character.database.buildings.get(building_id)
		if building != null:
			bonus += building.inventory_capacity_bonus
	return bonus
