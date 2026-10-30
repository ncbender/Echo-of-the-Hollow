class_name MapMarkers
extends RefCounted
## The markers of the minimap and the area map (Map & Fog of War 1.0), collected from the
## scene objects that exist anyway - never from quest or event definitions alone:
##   exit      an active MapTransition (a closed story gate has none: its transition is off)
##   waystone  a Waystone (awake or silent) and a dormant waystone stone (Readable WAYSTONE look)
##   rest      a Checkpoint
##   npc       a present StoryNpc (with its "!" / "?" marker)
##   landmark  a MapLandmark
##   quest     an object the current step of an active quest waits for: an unread Readable or
##             an untaken StoryPickup with that event, a not yet cleared Encounter
##             ("encounter:<id>"), an exit whose target map is to be entered ("enter:<map>")
## Every marker is shown only where its spot was explored (MapFog). Enemies, resources and
## loot are never markers.

const EXIT := &"exit"
const WAYSTONE := &"waystone"
const REST := &"rest"
const NPC := &"npc"
const LANDMARK := &"landmark"
const QUEST := &"quest"


## [{"kind", "position", "label", "quest": bool, "note"}] of `map`, explored spots only
## (`fog` null: no fog on this map, everything known).
static func collect(map: Node, character: Character, fog: MapFog) -> Array[Dictionary]:
	var wanted := current_goal_events(character)
	var result: Array[Dictionary] = []
	for node in map.find_children("*", "", true, false):
		var entry := _marker_of(node, wanted, map)
		if entry.is_empty():
			continue
		if fog != null and not fog.is_explored_at(entry.position):
			continue
		result.append(entry)
	return result


## Event ids the current steps of all active story quests still wait for.
static func current_goal_events(character: Character) -> Dictionary:
	var events := {}
	if character == null:
		return events
	for quest_id in character.quests.active_ids():
		var step := StoryService.current_step(character, quest_id)
		if step == null:
			continue
		for index in step.objectives.size():
			var objective := step.objectives[index]
			if StoryService.objective_value(character, quest_id, index) < objective.amount:
				events[objective.event_id] = true
	return events


static func _marker_of(node: Node, wanted: Dictionary, map: Node) -> Dictionary:
	var item := node as Node2D
	if item == null or not AreaMap.shown(item, map):
		return {}
	if node is MapTransition:
		var exit := node as MapTransition
		if not exit.can_process():
			return {}
		var to_quest := wanted.has(StringName("enter:%s" % exit.target_map_id))
		return {"kind": EXIT, "position": exit.global_position, "label": exit.label, "quest": to_quest}
	if node is Waystone:
		var stone := node as Waystone
		var definition := stone.definition()
		var name := definition.display_name if definition != null else "Waystone"
		return {"kind": WAYSTONE, "position": stone.global_position, "label": name if stone.is_awake() else "%s (silent)" % name, "quest": false}
	if node is Checkpoint:
		return {"kind": REST, "position": item.global_position, "label": "Resting place", "quest": false}
	if node is StoryNpc:
		var npc := node as StoryNpc
		var definition := npc.definition()
		return {"kind": NPC, "position": npc.global_position, "label": definition.display_name if definition != null else "",
			"quest": npc.marker() != "", "note": npc.marker()}
	if node is MapLandmark:
		return {"kind": LANDMARK, "position": item.global_position, "label": (node as MapLandmark).label, "quest": false}
	if node is Readable:
		var readable := node as Readable
		if readable.look == Readable.Look.WAYSTONE:
			return {"kind": WAYSTONE, "position": readable.global_position, "label": "%s (silent)" % readable.title,
				"quest": wanted.has(readable.event_id) and not readable.is_read()}
		if readable.event_id != &"" and wanted.has(readable.event_id) and not readable.is_read():
			return {"kind": QUEST, "position": readable.global_position, "label": readable.title, "quest": true}
		return {}
	if node is StoryPickup:
		var pickup := node as StoryPickup
		if pickup.event_id != &"" and wanted.has(pickup.event_id) and not pickup.is_taken():
			return {"kind": QUEST, "position": pickup.global_position, "label": pickup.label, "quest": true}
		return {}
	if node is Encounter:
		var encounter := node as Encounter
		if wanted.has(StringName("encounter:%s" % encounter.encounter_id)) and encounter.can_start():
			return {"kind": QUEST, "position": encounter.global_position, "label": "", "quest": true}
	return {}
