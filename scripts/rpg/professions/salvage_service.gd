class_name SalvageService
extends RefCounted
## Salvaging 1.0 (docs/PROFESSIONS.md): a bag item is destroyed at the
## workstation of the profession that makes it and returns part of its base's
## raw materials. Stateless.
##
## * Provenance comes from data only: the one craftable, non-processing
##   profession recipe whose output is the item's definition. Processed inputs
##   (ingots, leather, cloth, planks) are traced back through their processing
##   recipes to raw materials. No recipe, or more than one: not salvageable.
##   Alchemy has no salvage.
## * Return: rules.salvage_return_percent per rarity, rolled once per item
##   instance from its id (deterministic) - the preview shows exactly what the
##   salvage gives, and saving / loading cannot re-roll it. Amounts are rounded
##   down; at most 40 % of the raw materials ever come back, so crafting and
##   salvaging can never gain materials. Affixes, quality, essences, sockets,
##   catalysts and gold are not returned. Salvaging gives no profession XP.
## * Protection: ItemProtection.destroy_block (equipped, presets, quest,
##   unique / set, locked, favourite).
## * One transaction: everything is checked first (incl. room for all outputs
##   once the item is gone); then the item is removed and the outputs added;
##   if adding fails, the outputs are taken back and the same instance returns.

const SALVAGE_PROFESSIONS: Array[StringName] = [&"blacksmithing", &"leatherworking", &"tailoring", &"woodworking"]


## The recipe that defines the item base's materials, or null (not salvageable).
static func source_recipe(db: GameDatabase, definition_id: StringName) -> ProfessionRecipeDefinition:
	var found: ProfessionRecipeDefinition = null
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if recipe.output_item_id != definition_id or recipe.is_processing or not recipe.craftable:
			continue
		if found != null:
			return null   # ambiguous: two recipes make it
		found = recipe
	if found == null or not found.profession_id in SALVAGE_PROFESSIONS or found.output_quantity != 1:
		return null
	return found


## Raw materials of one item of the recipe: item id -> amount (float, processing
## recipes may make more than one unit). Inputs made by a processing recipe are
## expanded into that recipe's inputs.
static func raw_materials(db: GameDatabase, recipe: ProfessionRecipeDefinition) -> Dictionary:
	var result := {}
	for cost in recipe.inputs:
		_expand(db, cost.item_id, float(cost.quantity), result, 0)
	return result


static func _expand(db: GameDatabase, item_id: StringName, amount: float, result: Dictionary, depth: int) -> void:
	var processing := _processing_recipe(db, item_id)
	if processing == null or depth > 4:
		result[item_id] = float(result.get(item_id, 0.0)) + amount
		return
	for cost in processing.inputs:
		_expand(db, cost.item_id, amount * cost.quantity / float(processing.output_quantity), result, depth + 1)


static func _processing_recipe(db: GameDatabase, item_id: StringName) -> ProfessionRecipeDefinition:
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if recipe.is_processing and recipe.craftable and recipe.output_item_id == item_id:
			return recipe
	return null


## The rolled return share of this instance (0..1); -1 when the rarity has none.
static func return_share(character: Character, item: ItemInstance) -> float:
	var definition := character.database.get_item(item.definition_id)
	var ranges := character.database.rules.salvage_return_percent
	if definition == null or definition.rarity >= ranges.size():
		return -1.0
	var span: Vector2 = ranges[definition.rarity]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("salvage:" + item.instance_id)
	return rng.randf_range(span.x, span.y) / 100.0


## What salvaging the item gives: [{"item_id", "quantity"}] (amounts > 0 only).
static func outputs(character: Character, item: ItemInstance) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var recipe := source_recipe(character.database, item.definition_id)
	var share := return_share(character, item)
	if recipe == null or share < 0.0:
		return result
	var raw := raw_materials(character.database, recipe)
	var ids: Array = raw.keys()
	ids.sort()
	for item_id: StringName in ids:
		var amount := floori(float(raw[item_id]) * share + 0.0001)
		if amount > 0:
			result.append({"item_id": item_id, "quantity": amount})
	return result


## Workstation where `definition_id` is salvaged (&"" = nowhere).
static func station_for(db: GameDatabase, definition_id: StringName) -> StringName:
	var recipe := source_recipe(db, definition_id)
	return ProfessionService.station_of(db, recipe) if recipe != null else &""


## True if the item has investments that salvaging does not return.
static func has_investments(item: ItemInstance) -> bool:
	return not item.affixes.is_empty() or item.quality > 0 or not item.essences.is_empty() or not item.sockets.is_empty() \
		or item.material_id != &"" or not item.evolution.is_empty()


## "" if the bag item can be salvaged at `station_id` now, otherwise why not.
static func salvage_error(character: Character, instance_id: String, station_id: StringName) -> String:
	var block := ItemProtection.destroy_block(character, instance_id)
	if block != "":
		return block
	var item := character.inventory.find(instance_id)
	var db := character.database
	var recipe := source_recipe(db, item.definition_id)
	if recipe == null:
		return "This item cannot be salvaged."
	var station := ProfessionService.station_of(db, recipe)
	if station_id != station:
		return "Salvage this at %s." % ProfessionService.station_name(db, station)
	var gained := outputs(character, item)
	if gained.is_empty():
		return "Nothing could be recovered from this item."
	if not _room_after_removal(character, item, gained):
		return "Your bag is full."
	return ""


## Salvages once. Returns {"error", "outputs"}; on an error nothing changed.
## A repeated call for the same instance finds it gone and is refused.
static func salvage(character: Character, instance_id: String, station_id: StringName) -> Dictionary:
	var error := salvage_error(character, instance_id, station_id)
	if error != "":
		return {"error": error, "outputs": []}
	var item := character.inventory.find(instance_id)
	return apply(character, item, outputs(character, item))


## The transaction itself (called after the checks; tests call it with
## outputs that cannot be added to prove the rollback). Removes `item`, adds
## `gained`; on any failure everything is undone - the same instance returns.
static func apply(character: Character, item: ItemInstance, gained: Array[Dictionary]) -> Dictionary:
	var removed := character.inventory.remove_instance(item.instance_id)
	if removed == null:
		return {"error": "That item is no longer in your bag.", "outputs": []}
	var added: Array[Dictionary] = []
	for entry: Dictionary in gained:
		if character.inventory.add_item(entry.item_id, int(entry.quantity)).is_empty():
			for done: Dictionary in added:
				character.inventory.remove_quantity(done.item_id, int(done.quantity))
			character.inventory.add_instance(removed)
			return {"error": "The materials could not be stored. Nothing was salvaged.", "outputs": []}
		added.append(entry)
	return {"error": "", "outputs": added}


## Room for all outputs once the item's own slot is free (stacks first).
static func _room_after_removal(character: Character, item: ItemInstance, gained: Array[Dictionary]) -> bool:
	var inventory := character.inventory
	var free := inventory.free_slots() + 1
	for entry: Dictionary in gained:
		var definition := character.database.get_item(entry.item_id)
		if definition == null:
			return false
		var left := int(entry.quantity)
		if definition.is_stackable():
			for other in inventory.items():
				if other.definition_id == entry.item_id:
					left -= definition.max_stack - other.quantity
		if left > 0:
			free -= ceili(float(left) / definition.max_stack)
	return free >= 0
