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


## Gathers once: adds the yield to the inventory and depletes the node.
## Refused (nothing changes) when depleted or when the inventory has no room.
static func gather(character: Character, map_id: StringName, node_id: StringName,
		definition: ResourceNodeDefinition, now: float) -> String:
	if definition == null or character.database.get_item(definition.yield_item_id) == null:
		return "invalid resource node"
	if not is_available(character.world, map_id, node_id, now):
		return "%s is depleted" % definition.display_name
	if character.inventory.room_for(definition.yield_item_id) < definition.yield_quantity:
		return "inventory full"
	character.inventory.add_item(definition.yield_item_id, definition.yield_quantity)
	var until := PERMANENT if definition.respawn_seconds <= 0.0 else now + definition.respawn_seconds
	character.world.set_map_value(map_id, state_key(node_id), until)
	return ""
