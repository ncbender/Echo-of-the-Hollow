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
		2: _v2_to_v3,
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


## v3 (Crafting Foundation 0.1): items carry crafting state. Existing items get
## valid defaults (item level 1, quality 0, no material); nothing is rolled.
## The prepared v2 field "essence" (never written by the game) becomes the
## "essences" list; unrecognised content is kept in "progress".
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	for key: String in ["inventory", "orphaned_items"]:
		var items: Variant = data.get(key, [])
		if not items is Array:
			continue
		for entry: Variant in items:
			if entry is Dictionary:
				_upgrade_item_v3(entry)
	return data


static func _upgrade_item_v3(item: Dictionary) -> void:
	if not item.has("ilvl"):
		item["ilvl"] = 1
	if not item.has("quality"):
		item["quality"] = 0
	var legacy: Variant = item.get("essence")
	if legacy != null:
		item.erase("essence")
		if legacy is Dictionary and legacy.get("slots") is Array:
			item["essences"] = legacy["slots"]
		elif legacy is Dictionary and not legacy.is_empty():
			var progress: Dictionary = item.get("progress", {}) if item.get("progress") is Dictionary else {}
			progress["legacy_essence"] = legacy
			item["progress"] = progress
	if item.get("evolution") is Dictionary and not item["evolution"].is_empty() and not item["evolution"].has("stage"):
		item["evolution"]["stage"] = 1
	var affixes: Variant = item.get("affixes")
	if affixes is Array:
		for affix: Variant in affixes:
			if affix is Dictionary and not affix.has("affix"):
				affix["legacy"] = true   # plain stat roll from before crafting; applied, not reforgeable
