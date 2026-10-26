class_name WorldState
extends RefCounted
## Persistent world progress of one character: location and simple flags.

signal flag_changed(flag: StringName, value: Variant)

var map_id: StringName = &"test_arena"
var spawn_id: StringName = &"default"
## Simple persistent flags (bool / int / String values only).
var flags: Dictionary = {}
## Home base: build plot id -> building id (Phase 9).
var buildings: Dictionary = {}


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


func to_dict() -> Dictionary:
	var saved_flags := {}
	for flag: StringName in flags:
		saved_flags[String(flag)] = flags[flag]
	var saved_buildings := {}
	for plot: StringName in buildings:
		saved_buildings[String(plot)] = String(buildings[plot])
	return {"map": String(map_id), "spawn": String(spawn_id), "flags": saved_flags, "buildings": saved_buildings}


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	map_id = StringName(str(data.get("map", "test_arena")))
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
