class_name ItemStats
extends RefCounted
## Everything one item instance contributes while equipped: its definition plus
## its individual crafting state (quality, affixes, material imprint, socketed
## gems/runes, essences, evolution). The single place that turns crafting data
## into StatModifiers (for StatResolver) and ItemEffects (for ItemEffectRunner),
## so every system sees the same values and nothing is applied twice.

## Base stat improvement per quality point.
const QUALITY_PERCENT_PER_POINT := 1.0


static func modifiers(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var profile := definition.crafting
	var factor := 1.0 + item.quality * QUALITY_PERCENT_PER_POINT / 100.0
	for modifier in definition.base_stats:
		if modifier == null:
			continue
		if item.quality > 0 and profile != null and (profile.quality_stats.is_empty() or modifier.stat in profile.quality_stats):
			result.append(StatModifier.make(modifier.stat, modifier.flat * factor, modifier.percent * factor))
		else:
			result.append(modifier)
	result.append_array(item.affix_modifiers())
	var material := db.materials.get(item.material_id) as MaterialDefinition if item.is_imprinted() else null
	if material != null:
		result.append_array(material.imprint_modifiers)
	for socketable in active_socketables(item, definition, db):
		result.append_array(socketable.modifiers)
	for part in _evolution_parts(item, definition, db):
		result.append_array(part.modifiers)
	return result


## Active effects as {"effect": ItemEffect, "key": String, "power": float}.
## Keys are unique per item and source, so runtime state never mixes.
static func effects(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in definition.effects.size():
		_add(result, definition.effects[index], "%s#%d" % [item.instance_id, index], 1.0)
	var material := db.materials.get(item.material_id) as MaterialDefinition if item.is_imprinted() else null
	var essences := active_essences(item, definition)
	for essence_id in essences:
		var essence: EssenceDefinition = db.essences.get(essence_id)
		if essence != null:
			var power := material.essence_power(essence_id) if material != null else 1.0
			_add(result, essence.effect, "%s#essence:%s" % [item.instance_id, essence_id], power)
	for resonance: EssenceResonanceDefinition in db.resonances.values():
		if resonance.matches(essences):
			_add(result, resonance.effect, "%s#resonance:%s" % [item.instance_id, resonance.id], 1.0)
	var sockets := active_socketables(item, definition, db)
	for index in sockets.size():
		_add(result, sockets[index].effect, "%s#socket%d" % [item.instance_id, index], 1.0)
	var parts := _evolution_parts(item, definition, db)
	for index in parts.size():
		for effect_index in parts[index].effects.size():
			_add(result, parts[index].effects[effect_index], "%s#evolution%d.%d" % [item.instance_id, index, effect_index], 1.0)
	return result


## Essences that are inside the item's slot limit (never more than 2).
static func active_essences(item: ItemInstance, definition: ItemDefinition) -> Array[StringName]:
	var limit := mini(2, definition.crafting.essence_slots if definition.crafting != null else 0)
	return item.essences.slice(0, limit)


static func active_socketables(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> Array[SocketableDefinition]:
	var result: Array[SocketableDefinition] = []
	var limit := definition.crafting.socket_slots if definition.crafting != null else 0
	for index in mini(limit, item.sockets.size()):
		var socketable: SocketableDefinition = db.socketables.get(item.sockets[index])
		if socketable != null:
			result.append(socketable)
	return result


static func evolution_of(definition: ItemDefinition, db: GameDatabase) -> EvolutionDefinition:
	if definition.crafting == null or definition.crafting.evolution_id == &"":
		return null
	return db.evolutions.get(definition.crafting.evolution_id)


## Reached stages (2..current) and the chosen mutation, as objects with
## `modifiers` and `effects` (EvolutionStage / EvolutionMutation).
static func _evolution_parts(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> Array:
	var parts := []
	var evolution := evolution_of(definition, db)
	if evolution == null:
		return parts
	for stage_number in range(1, item.evolution_stage() + 1):
		var stage := evolution.get_stage(stage_number)
		if stage == null:
			continue
		parts.append(stage)
		var mutation := stage.get_mutation(item.evolution_path())
		if mutation != null:
			parts.append(mutation)
	return parts


static func _add(result: Array[Dictionary], effect: ItemEffect, key: String, power: float) -> void:
	if effect != null:
		result.append({"effect": effect, "key": key, "power": power})


## Repairs loaded crafting state against the current data without deleting
## anything: values are clamped, entries beyond slot limits are parked in
## item.progress (kept and saved, inactive) and reported in `warnings`.
static func sanitize(item: ItemInstance, db: GameDatabase, warnings: PackedStringArray) -> void:
	var definition := db.get_item(item.definition_id)
	if definition == null:
		return
	var profile := definition.crafting
	var max_quality := profile.max_quality if profile != null else 0
	if item.quality > max_quality:
		warnings.append("%s: quality %d clamped to %d" % [item.instance_id, item.quality, max_quality])
		item.quality = max_quality
	var essence_limit := mini(2, profile.essence_slots if profile != null else 0)
	if item.essences.size() > essence_limit:
		_park(item, "inactive_essences", item.essences.slice(essence_limit), warnings)
		item.essences = item.essences.slice(0, essence_limit)
	var socket_limit := profile.socket_slots if profile != null else 0
	if item.sockets.size() > socket_limit:
		_park(item, "inactive_sockets", item.sockets.slice(socket_limit), warnings)
		item.sockets = item.sockets.slice(0, socket_limit)
	var evolution := evolution_of(definition, db)
	if evolution == null:
		return
	var stage := clampi(item.evolution_stage(), 1, evolution.max_stage())
	if stage != item.evolution_stage():
		warnings.append("%s: evolution stage clamped to %d" % [item.instance_id, stage])
	item.evolution["stage"] = stage
	item.evolution["xp"] = maxi(0, item.evolution_xp())
	if not item.evolution.has("path"):
		item.evolution["path"] = ""


static func _park(item: ItemInstance, key: String, values: Array[StringName], warnings: PackedStringArray) -> void:
	var parked: Array = item.progress.get(key, []) if item.progress.get(key) is Array else []
	for value in values:
		parked.append(String(value))
	item.progress[key] = parked
	warnings.append("%s: %d entries beyond the slot limit kept inactive (%s)" % [item.instance_id, values.size(), key])
