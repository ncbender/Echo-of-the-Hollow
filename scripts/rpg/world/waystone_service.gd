class_name WaystoneService
extends RefCounted
## Waystone rules: activation and free fast travel between active waystones.
## Stateless; activated ids live in WorldState.waystones (saved).

const ACTIVATION_LINE := "May the road remember those who return."
## Enemies closer than this keep the player "in combat": no fast travel.
const COMBAT_RADIUS := 220.0


static func all(db: GameDatabase) -> Array[WaystoneDefinition]:
	var result: Array[WaystoneDefinition] = []
	for waystone: WaystoneDefinition in db.waystones.values():
		result.append(waystone)
	result.sort_custom(func(a: WaystoneDefinition, b: WaystoneDefinition) -> bool: return a.order < b.order)
	return result


static func is_active(character: Character, waystone_id: StringName) -> bool:
	return waystone_id in character.world.waystones


## "" if the waystone can be awakened now.
static func activate_error(character: Character, waystone: WaystoneDefinition, condition: StoryCondition) -> String:
	if waystone == null or not waystone.available:
		return "This waystone is silent."
	if is_active(character, waystone.id):
		return "This waystone is already awake."
	if not StoryCondition.check(condition, character):
		return "The waystone is cracked and silent. Something must answer it first."
	return ""


## Awakens a waystone (saved; the story hears "waystone:<id>").
static func activate(character: Character, waystone: WaystoneDefinition, condition: StoryCondition = null) -> String:
	var error := activate_error(character, waystone, condition)
	if error != "":
		return error
	character.world.waystones.append(waystone.id)
	character.world.set_flag(StringName("waystone.%s" % waystone.id))
	StoryService.notify(character, StringName("waystone:%s" % waystone.id))
	return ""


## "" if the player may travel from `from_id` to `to_id` now.
static func travel_error(character: Character, from_id: StringName, to_id: StringName, enemies_near: bool) -> String:
	var target: WaystoneDefinition = character.database.waystones.get(to_id)
	if target == null or not target.available or not is_active(character, to_id):
		return "That waystone does not answer."
	if from_id == to_id:
		return "You are already here."
	if not is_active(character, from_id):
		return "This waystone is silent."
	if enemies_near:
		return "You cannot travel while enemies are near."
	if character.classes.in_trial():
		return "Leave the echo first."
	return ""


static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	for waystone: WaystoneDefinition in db.waystones.values():
		if waystone.available and not db.maps.has(waystone.map_id):
			errors.append("waystone %s on unknown map %s" % [waystone.id, waystone.map_id])
	return errors
