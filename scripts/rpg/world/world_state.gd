class_name WorldState
extends RefCounted
## Persistent world progress of one character: location and simple flags.

signal flag_changed(flag: StringName, value: Variant)

var map_id: StringName = &"home_base"
var spawn_id: StringName = &"default"
## Simple persistent flags (bool / int / String values only).
var flags: Dictionary = {}
## Home base: build plot id -> building id (Phase 9).
var buildings: Dictionary = {}
## Persistent per-map state: map id -> {key -> bool/int/float/String}
## (resource node timers, visit counters ...). Normal enemies are NOT stored.
var map_states: Dictionary = {}


func set_flag(flag: StringName, value: Variant = true) -> void:
	if not (value is bool or value is int or value is String):
		push_error("world flag %s: unsupported value type" % flag)
		return
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag) and flags[flag] != false


func get_map_value(map: StringName, key: String, default: Variant = null) -> Variant:
	return map_states.get(map, {}).get(key, default)


func set_map_value(map: StringName, key: String, value: Variant) -> void:
	if not (value is bool or value is int or value is float or value is String):
		push_error("map state %s/%s: unsupported value type" % [map, key])
		return
	if not map_states.has(map):
		map_states[map] = {}
	map_states[map][key] = value


func to_dict() -> Dictionary:
	var saved_flags := {}
	for flag: StringName in flags:
		saved_flags[String(flag)] = flags[flag]
	var saved_buildings := {}
	for plot: StringName in buildings:
		saved_buildings[String(plot)] = String(buildings[plot])
	var saved_maps := {}
	for map: StringName in map_states:
		saved_maps[String(map)] = (map_states[map] as Dictionary).duplicate()
	return {"map": String(map_id), "spawn": String(spawn_id), "flags": saved_flags, "buildings": saved_buildings, "map_states": saved_maps}


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	map_id = StringName(str(data.get("map", "home_base")))
	spawn_id = StringName(str(data.get("spawn", "default")))
	flags.clear()
	buildings.clear()
	var saved_flags: Variant = data.get("flags", {})
	if saved_flags is Dictionary:
		for key: String in saved_flags:
			var value: Variant = saved_flags[key]
			# JSON turns ints into floats; whole numbers become ints again.
			if value is float and is_equal_approx(value, roundf(value)):
				value = int(value)
			if value is bool or value is int or value is String:
				flags[StringName(key)] = value
			else:
				warnings.append("world flag %s has unsupported value, ignored" % key)
	var saved_buildings: Variant = data.get("buildings", {})
	if saved_buildings is Dictionary:
		for plot: String in saved_buildings:
			buildings[StringName(plot)] = StringName(str(saved_buildings[plot]))
	map_states.clear()
	var saved_maps: Variant = data.get("map_states", {})
	if saved_maps is Dictionary:
		for map: String in saved_maps:
			if saved_maps[map] is Dictionary:
				map_states[StringName(map)] = (saved_maps[map] as Dictionary).duplicate()
