class_name ResourceGathering
extends RefCounted
## Gathering rules. State per node is stored in WorldState.map_states:
##   "node.<node_id>" -> unix time when the node is available again, or -1
##   for permanently depleted nodes. Missing key = available.
## `now` is passed in (unix seconds) so the rule is deterministic in tests.

const PERMANENT := -1.0


static func state_key(node_id: StringName) -> String:
	return "node.%s" % node_id


static func is_available(world: WorldState, map_id: StringName, node_id: StringName, now: float) -> bool:
	var value: Variant = world.get_map_value(map_id, state_key(node_id), null)
	if value == null:
		return true
	if float(value) == PERMANENT:
		return false
	return now >= float(value)


## Seconds until the node is back (0 when available, INF when permanent).
static func seconds_left(world: WorldState, map_id: StringName, node_id: StringName, now: float) -> float:
	var value: Variant = world.get_map_value(map_id, state_key(node_id), null)
	if value == null:
		return 0.0
	if float(value) == PERMANENT:
		return INF
	return maxf(0.0, float(value) - now)


## Gathers once: adds the yield to the inventory, depletes the node and gives
## the node profession's XP. The depletion is world state (saved), so loading
## a save never makes a node gatherable again before its time.
## Refused (nothing changes) when depleted or when the inventory has no room.
static func gather(character: Character, map_id: StringName, node_id: StringName,
		definition: ResourceNodeDefinition, now: float) -> String:
	if definition == null or character.database.get_item(definition.yield_item_id) == null:
		return "invalid resource node"
	if definition.profession_id != &"" and character.professions.level(definition.profession_id) < definition.required_level:
		var profession: ProfessionDefinition = character.database.professions.get(definition.profession_id)
		return "Requires %s level %d" % [profession.display_name if profession != null else "profession", definition.required_level]
	if not is_available(character.world, map_id, node_id, now):
		return "%s is depleted" % definition.display_name
	if character.inventory.room_for(definition.yield_item_id) < definition.yield_quantity:
		return "inventory full"
	character.inventory.add_item(definition.yield_item_id, definition.yield_quantity)
	var until := PERMANENT if definition.respawn_seconds <= 0.0 else now + definition.respawn_seconds
	character.world.set_map_value(map_id, state_key(node_id), until)
	ProfessionService.grant_gather_xp(character, definition.profession_id, ProfessionService.gather_xp_budget(character, definition))   # only after a successful gather
	return ""


# --- Gathering 1.1: steps, fixed budgets, persistent partial state ---------------

## Per node instance (WorldState.map_states[map], JSON string):
##   "gather.<node_id>" = {"steps", "done", "item", "items": [per step], "xp": [per step],
##                         "bonus", "given_items", "given_xp"}
## The plan (materials and XP per step, completion bonus on the last step) is
## fixed once from the node's budgets (yield_quantity, gather_xp) with a seed
## from map, node and "gather_cycle.<node_id>" (exhaustions so far): an
## interrupted, reloaded or repeated action never rolls again.
const PROGRESS_KEY := "gather.%s"
const CYCLE_KEY := "gather_cycle.%s"


static func progress_key(node_id: StringName) -> String:
	return PROGRESS_KEY % node_id


## The node's stored partial state; {} = untouched (no step done in this cycle);
## {"invalid": true} = unreadable or inconsistent (never rewards anything).
static func progress(world: WorldState, map_id: StringName, node_id: StringName) -> Dictionary:
	var raw: Variant = world.get_map_value(map_id, progress_key(node_id), null)
	if raw == null or raw == "":
		return {}
	var data: Variant = JSON.parse_string(String(raw)) if raw is String else null
	if not data is Dictionary or not _consistent(data):
		return {"invalid": true}
	return data


static func _consistent(data: Dictionary) -> bool:
	if not (data.get("items") is Array and data.get("xp") is Array):
		return false
	var steps := int(data.get("steps", 0))
	var done := int(data.get("done", -1))
	var items: Array = data.items
	var xp: Array = data.xp
	if steps < 1 or items.size() != steps or xp.size() != steps or done < 0 or done >= steps:
		return false
	var given_items := 0
	var given_xp := 0
	for index in steps:
		if int(items[index]) < 0 or int(xp[index]) < 0:
			return false
		if index < done:
			given_items += int(items[index])
			given_xp += int(xp[index])
	return given_items == int(data.get("given_items", -1)) and given_xp == int(data.get("given_xp", -1)) \
		and String(data.get("item", "")) != ""


static func _store(world: WorldState, map_id: StringName, node_id: StringName, data: Dictionary) -> void:
	world.set_map_value(map_id, progress_key(node_id), JSON.stringify(data))


## Steps of the running cycle that are done (0 when untouched).
static func steps_done(world: WorldState, map_id: StringName, node_id: StringName) -> int:
	return int(progress(world, map_id, node_id).get("done", 0))


## Materials still in the node's budget for this cycle.
static func remaining_items(world: WorldState, map_id: StringName, node_id: StringName, definition: ResourceNodeDefinition) -> int:
	var data := progress(world, map_id, node_id)
	if data.is_empty():
		return definition.yield_quantity
	if data.has("invalid"):
		return 0
	var left := 0
	for index in range(int(data.done), int(data.steps)):
		left += int(data.items[index])
	return left


## The fixed plan of a fresh cycle: total materials = yield_quantity (the
## completion bonus on the last step, the rest spread over the steps; a step may
## give nothing), total XP = gather_xp x level-band share, spread evenly.
static func make_plan(character: Character, map_id: StringName, node_id: StringName, definition: ResourceNodeDefinition) -> Dictionary:
	var steps := maxi(1, definition.steps)
	var total := maxi(0, definition.yield_quantity)
	var bonus := clampi(definition.completion_bonus, 0, total)
	var rng := RandomNumberGenerator.new()
	var cycle := int(character.world.get_map_value(map_id, CYCLE_KEY % node_id, 0))
	rng.seed = hash("gather:%s:%s:%d" % [map_id, node_id, cycle])
	var items: Array = []
	items.resize(steps)
	items.fill(0)
	for unit in total - bonus:
		items[rng.randi_range(0, steps - 1)] += 1
	items[steps - 1] += bonus
	var xp_total := ProfessionService.gather_xp_budget(character, definition)
	var xp: Array = []
	for index in steps:
		xp.append(xp_total / steps + (1 if index >= steps - xp_total % steps else 0))
	return {"steps": steps, "done": 0, "item": String(definition.yield_item_id), "items": items, "xp": xp,
		"bonus": bonus, "given_items": 0, "given_xp": 0}
