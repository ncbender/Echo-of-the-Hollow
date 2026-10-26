class_name ProfessionService
extends RefCounted
## Profession rules (docs/PROFESSIONS.md). Stateless: progress lives in
## Character.professions, items in the inventory / stash.
##
## Crafting is one transaction: everything is checked first (recipe known and
## craftable, level, workstation, materials, room for the output), then the
## material plan is consumed, the output added and XP granted. A refused craft
## changes nothing. Counting and consuming use the SAME material plan.
## Materials come from the bag; at a Haven workstation, once the Old Storehouse
## is restored (StashService.is_upgraded), missing amounts are taken from the
## Haven stash too (bag first).

const RANKS: Array = [["Apprentice", 1], ["Journeyman", 21], ["Artisan", 41], ["Expert", 61], ["Master", 81]]
## Share of the base XP by how far the profession level is above the recipe
## level: up to 5 -> 100 %, 6-15 -> 50 %, 16-25 -> 15 %, more -> 0 %.
const XP_BANDS: Array = [[5, 1.0], [15, 0.5], [25, 0.15]]
## The first successful craft of a recipe adds this share of its base XP once.
const FIRST_CRAFT_BONUS := 1.0


static func rank_name(level: int) -> String:
	var result: String = RANKS[0][0]
	for rank: Array in RANKS:
		if level >= int(rank[1]):
			result = rank[0]
	return result


static func professions(db: GameDatabase, kind: ProfessionDefinition.Kind) -> Array[ProfessionDefinition]:
	var result: Array[ProfessionDefinition] = []
	for definition: ProfessionDefinition in db.professions.values():
		if definition.kind == kind:
			result.append(definition)
	result.sort_custom(func(a: ProfessionDefinition, b: ProfessionDefinition) -> bool: return a.display_name < b.display_name)
	return result


## Recipes of a profession, sorted by level, processing first, then name.
static func recipes_of(db: GameDatabase, profession_id: StringName) -> Array[ProfessionRecipeDefinition]:
	var result: Array[ProfessionRecipeDefinition] = []
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if recipe.profession_id == profession_id:
			result.append(recipe)
	result.sort_custom(func(a: ProfessionRecipeDefinition, b: ProfessionRecipeDefinition) -> bool:
		if a.required_level != b.required_level:
			return a.required_level < b.required_level
		if a.is_processing != b.is_processing:
			return a.is_processing
		return a.display_name < b.display_name)
	return result


static func station_of(db: GameDatabase, recipe: ProfessionRecipeDefinition) -> StringName:
	if recipe.station_id != &"":
		return recipe.station_id
	var profession: ProfessionDefinition = db.professions.get(recipe.profession_id)
	return profession.station_id if profession != null else &""


static func station_name(db: GameDatabase, station_id: StringName) -> String:
	var ruin: RuinDefinition = db.ruins.get(station_id)
	return ruin.display_name if ruin != null else String(station_id)


# --- learning ---------------------------------------------------------------------

## Learns a recipe permanently. "" if learned now, otherwise why not (an
## already known recipe changes nothing - no XP, no items).
static func learn_recipe(character: Character, recipe_id: StringName) -> String:
	var recipe: ProfessionRecipeDefinition = character.database.profession_recipes.get(recipe_id)
	if recipe == null:
		return "Unknown recipe."
	if character.professions.knows(recipe_id):
		return "You already know %s." % recipe.display_name
	character.professions.learn(recipe_id)
	return ""


## Every AUTOMATIC recipe the current levels allow (after loading, level ups).
static func learn_automatic(character: Character) -> int:
	var learned := 0
	for recipe: ProfessionRecipeDefinition in character.database.profession_recipes.values():
		if recipe.unlock_source == ProfessionRecipeDefinition.UnlockSource.AUTOMATIC \
				and character.professions.level(recipe.profession_id) >= recipe.required_level \
				and character.professions.learn(recipe.id):
			learned += 1
	return learned


## Uses a recipe item from the bag: learns its recipe and consumes the item in
## one step. Refused (item kept) if the recipe is already known.
static func learn_from_item(character: Character, instance_id: String) -> String:
	var item := character.inventory.find(instance_id)
	var definition := character.database.get_item(item.definition_id) if item != null else null
	if definition == null or definition.teaches_recipe_id == &"":
		return "This item teaches no recipe."
	var recipe: ProfessionRecipeDefinition = character.database.profession_recipes.get(definition.teaches_recipe_id)
	if recipe == null:
		return "Unknown recipe."
	if character.professions.knows(recipe.id):
		return "You already know %s." % recipe.display_name
	if not character.inventory.take(instance_id, 1):
		return "The item is gone."
	character.professions.learn(recipe.id)
	return ""


# --- XP -----------------------------------------------------------------------------

## XP share for crafting `recipe` at profession level `level` (0..1).
static func xp_share(level: int, recipe_level: int) -> float:
	var above := level - recipe_level
	for band: Array in XP_BANDS:
		if above <= int(band[0]):
			return float(band[1])
	return 0.0


## XP the next successful craft gives (band share + first-craft bonus).
static func craft_xp(character: Character, recipe: ProfessionRecipeDefinition) -> int:
	var share := xp_share(character.professions.level(recipe.profession_id), recipe.required_level)
	var amount := roundi(recipe.xp * share)
	if not character.professions.crafted_before(recipe.id):
		amount += roundi(recipe.xp * FIRST_CRAFT_BONUS)
	return amount


## Gathering XP (successful gathers only; the node gives its gather_xp with the
## same level bands as recipes).
static func gather_xp(character: Character, node: ResourceNodeDefinition) -> int:
	if node.profession_id == &"":
		return 0
	var share := xp_share(character.professions.level(node.profession_id), node.required_level)
	var gained := character.professions.add_xp(node.profession_id, roundi(node.gather_xp * share))
	if gained > 0:
		learn_automatic(character)
	return roundi(node.gather_xp * share)


# --- materials --------------------------------------------------------------------

## True when crafting at `station_id` may also draw on the Haven stash: a Haven
## workstation (a ruin) and the Old Storehouse restored.
static func uses_stash(character: Character, station_id: StringName) -> bool:
	return station_id != &"" and character.database.ruins.has(station_id) and StashService.is_upgraded(character)


## The material plan: [{"item_id", "bag", "stash"}] per input plus "missing"
## ("Iron Ore 2/3"-style). Counting and consuming both use this plan; stacks are
## counted by Inventory.count (each unit once).
static func material_plan(character: Character, inputs: Array[ItemCost], with_stash: bool) -> Dictionary:
	var plan: Array = []
	var missing: PackedStringArray = []
	for cost in inputs:
		var in_bag := character.inventory.count(cost.item_id)
		var in_stash := character.stash.count(cost.item_id) if with_stash else 0
		var from_bag := mini(in_bag, cost.quantity)
		var from_stash := mini(in_stash, cost.quantity - from_bag)
		if from_bag + from_stash < cost.quantity:
			var definition := character.database.get_item(cost.item_id)
			missing.append("%s %d/%d" % [definition.display_name if definition else String(cost.item_id), in_bag + in_stash, cost.quantity])
		plan.append({"item_id": cost.item_id, "bag": from_bag, "stash": from_stash})
	return {"plan": plan, "missing": missing}


## Consumes a checked material plan (bag part from the bag, stash part from the
## stash). Only call it after the plan reported nothing missing.
static func consume_plan(character: Character, plan: Array) -> void:
	for entry: Dictionary in plan:
		if int(entry.bag) > 0:
			character.inventory.remove_quantity(entry.item_id, int(entry.bag))
		if int(entry.stash) > 0:
			character.stash.remove_quantity(entry.item_id, int(entry.stash))


## Gives a consumed plan back where it came from (rollback of a failed step).
static func refund_plan(character: Character, plan: Array) -> void:
	for entry: Dictionary in plan:
		if int(entry.bag) > 0:
			character.inventory.add_item(entry.item_id, int(entry.bag))
		if int(entry.stash) > 0:
			character.stash.add_item(entry.item_id, int(entry.stash))


## Units of `item_id` available for a craft at `station_id` (same rule as the plan).
static func available(character: Character, item_id: StringName, station_id: StringName) -> int:
	return character.inventory.count(item_id) + (character.stash.count(item_id) if uses_stash(character, station_id) else 0)


# --- crafting -----------------------------------------------------------------------

## "" if `recipe_id` can be crafted now at `station_id` (&"" = away from any
## workstation), otherwise the reason shown to the player.
static func craft_error(character: Character, recipe_id: StringName, station_id: StringName) -> String:
	var db := character.database
	var recipe: ProfessionRecipeDefinition = db.profession_recipes.get(recipe_id)
	if recipe == null or db.get_item(recipe.output_item_id) == null:
		return "Unknown recipe."
	if not recipe.craftable:
		return recipe.unavailable_reason if recipe.unavailable_reason != "" else "This recipe cannot be crafted yet."
	if not character.professions.knows(recipe_id):
		return "You have not learned %s yet." % recipe.display_name
	var profession: ProfessionDefinition = db.professions.get(recipe.profession_id)
	if character.professions.level(recipe.profession_id) < recipe.required_level:
		return "Requires %s level %d." % [profession.display_name if profession else "profession", recipe.required_level]
	var needed_station := station_of(db, recipe)
	if station_id != needed_station:
		return "Craft this at %s." % station_name(db, needed_station)
	var plan := material_plan(character, recipe.inputs, uses_stash(character, station_id))
	if not (plan.missing as PackedStringArray).is_empty():
		return "Missing materials: %s." % ", ".join(plan.missing)
	# conservative: room for the output BEFORE anything is consumed
	if character.inventory.room_for(recipe.output_item_id) < recipe.output_quantity:
		return "Your bag is full."
	return ""


## Crafts once. Returns {"error", "xp", "levels", "first"}; on an error nothing
## changed. Fast repeated calls are independent transactions: each one is
## checked again, none can give a reward without paying for it.
static func craft(character: Character, recipe_id: StringName, station_id: StringName) -> Dictionary:
	var error := craft_error(character, recipe_id, station_id)
	if error != "":
		return {"error": error, "xp": 0, "levels": 0, "first": false}
	var recipe: ProfessionRecipeDefinition = character.database.profession_recipes[recipe_id]
	var plan: Array = material_plan(character, recipe.inputs, uses_stash(character, station_id)).plan
	var xp := craft_xp(character, recipe)
	var first := not character.professions.crafted_before(recipe_id)
	consume_plan(character, plan)
	var added := character.inventory.add_item(recipe.output_item_id, recipe.output_quantity, ItemInstance.ORIGIN_CRAFTED)
	if added.is_empty():
		# cannot happen after the room check - give everything back, change nothing
		refund_plan(character, plan)
		return {"error": "Your bag is full.", "xp": 0, "levels": 0, "first": false}
	character.professions.mark_crafted(recipe_id)
	var levels := character.professions.add_xp(recipe.profession_id, xp)
	if levels > 0:
		learn_automatic(character)
	return {"error": "", "xp": xp, "levels": levels, "first": first}


# --- data checks ------------------------------------------------------------------

static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	for profession: ProfessionDefinition in db.professions.values():
		if profession.is_crafting() and not db.ruins.has(profession.station_id):
			errors.append("profession %s: unknown station %s" % [profession.id, profession.station_id])
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if not db.professions.has(recipe.profession_id):
			errors.append("recipe %s: unknown profession %s" % [recipe.id, recipe.profession_id])
		if db.get_item(recipe.output_item_id) == null:
			errors.append("recipe %s: unknown output %s" % [recipe.id, recipe.output_item_id])
		for cost in recipe.inputs:
			if db.get_item(cost.item_id) == null:
				errors.append("recipe %s: unknown input %s" % [recipe.id, cost.item_id])
		if recipe.required_level < 1 or recipe.required_level > 100:
			errors.append("recipe %s: level out of range" % recipe.id)
	for node: ResourceNodeDefinition in db.resource_nodes.values():
		if node.profession_id != &"" and not db.professions.has(node.profession_id):
			errors.append("resource node %s: unknown profession %s" % [node.id, node.profession_id])
	for item: ItemDefinition in db.items.values():
		if item.teaches_recipe_id != &"" and not db.profession_recipes.has(item.teaches_recipe_id):
			errors.append("item %s teaches unknown recipe %s" % [item.id, item.teaches_recipe_id])
	return errors
