class_name CraftingService
extends RefCounted
## Resonance Forge rules (docs/CRAFTING_DESIGN.md). Stateless; every operation is
## a transaction on ONE ItemInstance of the character's inventory:
##   1. validate operation  2. validate item + state  3. compute the result pool
##   4. check costs  5. roll once  6. pay + change the item together  7. refresh stats/effects
## preview() runs steps 1-4 and execute() starts with the very same preview, so the
## probabilities shown are the ones rolled and a refused request costs nothing.
## Items are never destroyed; static definitions are never modified.


class Context:
	var character: Character
	var request: CraftingRequest
	var item: ItemInstance
	var definition: ItemDefinition
	var profile: CraftingProfile
	var operation: CraftingOperationDefinition
	var preview := CraftingPreview.new()
	var material: MaterialDefinition
	## Items given back to the player by the operation (extraction, unsocketing).
	var returns: Array[ItemCost] = []


class Result:
	var ok: bool = false
	var error: String = ""
	## What happened, for the UI ("Rolled Keen (T2): +5 Crit Chance %").
	var message: String = ""
	## Rolled affix entry (rolling operations).
	var rolled: Dictionary = {}


static var _executing: bool = false


static func preview(character: Character, request: CraftingRequest) -> CraftingPreview:
	return _prepare(character, request).preview


## Executes `request`; `rng` decides rolls (inject a seeded one in tests).
static func execute(character: Character, request: CraftingRequest, rng: RandomNumberGenerator) -> Result:
	var result := Result.new()
	if _executing:
		result.error = "another crafting operation is still running"
		return result
	var context := _prepare(character, request)
	if not context.preview.ok():
		result.error = context.preview.reason()
		return result
	_executing = true
	var rolled := {}
	if request.operation in CraftingOps.ROLLING:
		var entry := AffixPool.pick(context.preview.outcomes, rng)
		rolled = (entry.affix as AffixDefinition).roll(entry.tier, rng)
	for cost in context.preview.costs:   # all checked in _prepare: cannot fail
		character.inventory.remove_quantity(cost.item_id, cost.quantity)
	result.message = _apply(context, rolled)
	for back in context.returns:
		character.inventory.add_item(back.item_id, back.quantity)   # room checked in _prepare
	context.item.touch()
	character.notify_item_changed(context.item.instance_id)
	_executing = false
	result.ok = true
	result.rolled = rolled
	return result


static func _prepare(character: Character, request: CraftingRequest) -> Context:
	var context := Context.new()
	context.character = character
	context.request = request
	var preview := context.preview
	context.item = character.inventory.find(request.instance_id)
	if context.item == null:
		preview.error = "Item not found in the inventory."
		return context
	context.definition = character.database.get_item(context.item.definition_id)
	context.profile = context.definition.crafting if context.definition != null else null
	context.operation = character.database.get_operation(request.operation)
	if context.operation == null:
		preview.error = "Unknown crafting operation."
		return context
	if context.profile == null:
		preview.error = "%s cannot be crafted." % _name(context.definition)
		return context
	if not context.profile.allows(request.operation):
		preview.error = _protected_text(context)
		return context
	if request.revision >= 0 and request.revision != context.item.revision:
		preview.error = "The item changed since this preview. Check the new values and confirm again."
		return context
	context.material = character.database.materials.get(context.item.material_id) if context.item.is_imprinted() else null
	for cost in context.operation.costs:
		preview.add_cost(cost.item_id, cost.quantity)
	var check: Callable = _checks().get(request.operation, Callable())
	if not check.is_valid():
		preview.error = "Operation not available yet."
		return context
	check.call(context)
	if preview.error == "":
		_check_costs(context)
	return context


static func _checks() -> Dictionary:
	return {
		CraftingOps.IMPRINT: _check_imprint,
		CraftingOps.AUGMENT: _check_augment,
		CraftingOps.REFORGE: _check_reforge,
	}


static func _apply(context: Context, rolled: Dictionary) -> String:
	var apply: Callable = _appliers()[context.request.operation]
	return apply.call(context, rolled)


## Item changes per operation (only called after a successful _prepare).
static func _appliers() -> Dictionary:
	return {
		CraftingOps.IMPRINT: _apply_imprint,
		CraftingOps.AUGMENT: _apply_augment,
		CraftingOps.REFORGE: _apply_reforge,
	}


static func _apply_imprint(context: Context, rolled: Dictionary) -> String:
	context.item.material_id = context.request.material_id
	context.item.affixes.append(rolled)
	return "Imprinted with %s. %s" % [context.material.display_name, _rolled_text(context, rolled)]


static func _apply_augment(context: Context, rolled: Dictionary) -> String:
	context.item.affixes.append(rolled)
	return "Added: %s" % _rolled_text(context, rolled)


static func _apply_reforge(context: Context, rolled: Dictionary) -> String:
	var index := context.request.affix_index
	var old := _affix_text(context.character.database, context.item.affixes[index])
	context.item.affixes[index] = rolled
	return "Reforged %s into %s" % [old, _affix_text(context.character.database, rolled)]


# --- rolling operations ---------------------------------------------------------

static func _check_imprint(context: Context) -> void:
	var preview := context.preview
	if context.item.is_imprinted():
		preview.error = "Already imprinted with %s - the main material is permanent." % _material_name(context)
		return
	var material: MaterialDefinition = context.character.database.materials.get(context.request.material_id)
	if material == null:
		preview.error = "Choose a main material."
		return
	if not material.allows_slot(context.definition.slot_kind) or \
			(not context.profile.allowed_materials.is_empty() and not material.id in context.profile.allowed_materials):
		preview.error = "%s cannot be imprinted on %s." % [material.display_name, _name(context.definition)]
		return
	context.material = material
	preview.add_cost(material.item_id, material.imprint_quantity)
	_roll_pool(context, -1)
	if preview.error == "":
		preview.notes.append("Sets %s as the permanent main material: %s." % [material.display_name, _modifiers_text(material.imprint_modifiers)])


static func _check_augment(context: Context) -> void:
	if not context.item.is_imprinted():
		context.preview.error = "Imprint the item first."
		return
	if context.item.affixes.size() >= context.profile.affix_slots:
		context.preview.error = "All %d affix slots are used. Reforge an affix instead." % context.profile.affix_slots
		return
	_roll_pool(context, -1)


static func _check_reforge(context: Context) -> void:
	var preview := context.preview
	var index := context.request.affix_index
	if not context.item.is_imprinted():
		preview.error = "Imprint the item first."
		return
	if index < 0 or index >= context.item.affixes.size():
		preview.error = "Choose the affix to reforge."
		return
	var affix_id := StringName(str(context.item.affixes[index].get("affix", "")))
	if affix_id == &"" or not context.character.database.affixes.has(affix_id):
		preview.error = "This property is fixed and cannot be reforged."
		return
	_roll_pool(context, index)
	if preview.error == "":
		preview.notes.append("Replaces %s immediately - there is no undo. The result can be weaker." % _affix_text(context.character.database, context.item.affixes[index]))


## Shared by all rolling operations: optional focus, pool, empty-pool error.
static func _roll_pool(context: Context, replace_index: int) -> void:
	var preview := context.preview
	var db := context.character.database
	var focus := context.request.focus_tag
	var multiplier := 1.0
	if focus != &"":
		if not context.operation.allows_focus:
			preview.error = "%s cannot use a focus catalyst." % context.operation.display_name
			return
		var plain := AffixPool.compute(context.item, context.definition, context.material, db, &"", 1.0, replace_index)
		if not focus in AffixPool.tags_of(plain):
			preview.error = "No possible affix has the tag '%s'." % focus
			return
		multiplier = context.operation.focus_weight_multiplier
		for cost in context.operation.focus_costs:
			preview.add_cost(cost.item_id, cost.quantity)
	preview.outcomes = AffixPool.compute(context.item, context.definition, context.material, db, focus, multiplier, replace_index)
	if preview.outcomes.is_empty():
		preview.error = "No affix can roll on this item."


# --- helpers ----------------------------------------------------------------------

static func _check_costs(context: Context) -> void:
	var inventory := context.character.inventory
	for cost in context.preview.costs:
		var have := inventory.count(cost.item_id)
		if have < cost.quantity:
			var definition := context.character.database.get_item(cost.item_id)
			context.preview.missing.append("%dx %s (have %d)" % [cost.quantity, _name(definition), have])
	for back in context.returns:
		if inventory.room_for(back.item_id) < back.quantity:
			context.preview.error = "Not enough inventory space for the returned item."


static func _protected_text(context: Context) -> String:
	var definition := context.definition
	var op_name := context.operation.display_name
	if definition.rarity == ItemDefinition.Rarity.UNIQUE or definition.rarity == ItemDefinition.Rarity.LEGENDARY:
		return "%s: its handcrafted core is protected. %s is not allowed (allowed: %s)." % [
			definition.display_name, op_name, _operation_names(context.character.database, context.profile.allowed_operations)]
	return "%s does not support %s." % [definition.display_name, op_name]


static func _operation_names(db: GameDatabase, ids: Array[StringName]) -> String:
	var names: PackedStringArray = []
	for id in ids:
		var operation := db.get_operation(id)
		names.append(operation.display_name if operation != null else String(id))
	return ", ".join(names) if not names.is_empty() else "none"


static func _rolled_text(context: Context, rolled: Dictionary) -> String:
	return "Rolled %s" % _affix_text(context.character.database, rolled)


## "Keen (T2): +5 Crit Chance %"
static func _affix_text(db: GameDatabase, entry: Dictionary) -> String:
	var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
	var value := float(entry.get("flat", 0.0)) + float(entry.get("percent", 0.0))
	var stat := Stats.display_name(StringName(str(entry.get("stat", ""))))
	if affix == null:
		return "+%s %s" % [_number(value), stat]
	return "%s (T%d): +%s %s" % [affix.display_name, int(entry.get("tier", 0)), _number(value), stat]


static func _modifiers_text(modifiers: Array[StatModifier]) -> String:
	var parts: PackedStringArray = []
	for modifier in modifiers:
		parts.append(modifier.describe())
	return ", ".join(parts)


static func _material_name(context: Context) -> String:
	return context.material.display_name if context.material != null else String(context.item.material_id)


static func _name(definition: ItemDefinition) -> String:
	return definition.display_name if definition != null else "Unknown item"


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
