class_name SaveMigrations
extends RefCounted
## Upgrades older save payloads step by step to SaveSystem.VERSION.
##
## How to change the save schema:
##   1. bump SaveSystem.VERSION to N
##   2. add `N - 1: _v{N-1}_to_v{N}` to _steps() and implement the function
##      (pure Dictionary -> Dictionary, no game objects involved)
##   3. add a test that loads a stored version N-1 payload
## Old files are never rewritten in place; they are upgraded in memory and
## saved in the new format on the next save.

static func _steps() -> Dictionary:
	return {
		1: _v1_to_v2,
	}


static func migrate(payload: Dictionary, from_version: int, errors: PackedStringArray) -> Variant:
	var data := payload
	var version := from_version
	while version < SaveSystem.VERSION:
		var steps := _steps()
		if not steps.has(version):
			errors.append("no migration from save version %d" % version)
			return null
		var step: Callable = steps[version]
		data = step.call(data)
		version += 1
	return data


## v2 (Overnight 3): world.map_states added (persistent per-map state).
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var world: Dictionary = data.get("world", {}) if data.get("world") is Dictionary else {}
	if not world.has("map_states"):
		world["map_states"] = {}
	data["world"] = world
	return data
