class_name GameDatabase
extends RefCounted
## Registry of all content definitions (Resources under res://data), keyed by
## stable ids. Read-only at runtime. Loaded once via get_default(); tests may
## build their own instance and register definitions directly.

const DIRS := {
	&"weapons": "res://data/weapons",
	&"mastery": "res://data/mastery",
	&"classes": "res://data/classes",
	&"items": "res://data/items",
	&"sets": "res://data/sets",
	&"regions": "res://data/world/regions",
	&"maps": "res://data/world/maps",
	&"buildings": "res://data/base/buildings",
	&"plots": "res://data/base/plots",
	&"resource_nodes": "res://data/world/resource_nodes",
}
const RULES_PATH := "res://data/progression/progression_rules.tres"

static var _default: GameDatabase

var weapons: Dictionary = {}          # family id -> WeaponFamily
var mastery_tracks: Dictionary = {}   # family id -> MasteryTrack
var classes: Dictionary = {}          # class id -> ClassDefinition
var items: Dictionary = {}            # item id -> ItemDefinition
var sets: Dictionary = {}             # set id -> SetDefinition
var regions: Dictionary = {}          # region id -> RegionDefinition
var maps: Dictionary = {}             # map id -> MapDefinition
var buildings: Dictionary = {}        # building id -> BuildingDefinition
var plots: Dictionary = {}            # plot id -> BuildingPlotDefinition
var resource_nodes: Dictionary = {}   # node definition id -> ResourceNodeDefinition
var rules: ProgressionRules
var load_errors: PackedStringArray = []


static func get_default() -> GameDatabase:
	if _default == null:
		_default = GameDatabase.new()
		_default.load_all()
		for error in _default.load_errors:
			push_error("GameDatabase: " + error)
	return _default


func load_all() -> void:
	rules = load(RULES_PATH) as ProgressionRules if ResourceLoader.exists(RULES_PATH) else ProgressionRules.new()
	for category: StringName in DIRS:
		for resource in _load_dir(DIRS[category]):
			register(resource)
	load_errors.append_array(validate())


## Registers one definition in the matching table. Returns false on duplicates
## or unknown resource types.
func register(resource: Resource) -> bool:
	var table: Dictionary
	var key: StringName
	if resource is WeaponFamily:
		table = weapons; key = resource.id
	elif resource is MasteryTrack:
		table = mastery_tracks; key = resource.family_id
	elif resource is ClassDefinition:
		table = classes; key = resource.id
	elif resource is ItemDefinition:
		table = items; key = resource.id
	elif resource is SetDefinition:
		table = sets; key = resource.id
	elif resource is RegionDefinition:
		table = regions; key = resource.id
	elif resource is MapDefinition:
		table = maps; key = resource.id
	elif resource is BuildingDefinition:
		table = buildings; key = resource.id
	elif resource is BuildingPlotDefinition:
		table = plots; key = resource.id
	elif resource is ResourceNodeDefinition:
		table = resource_nodes; key = resource.id
	else:
		load_errors.append("unsupported resource %s" % resource.resource_path)
		return false
	if key == &"":
		load_errors.append("definition without id: %s" % resource.resource_path)
		return false
	if table.has(key):
		load_errors.append("duplicate id %s (%s)" % [key, resource.resource_path])
		return false
	table[key] = resource
	return true


func get_item(item_id: StringName) -> ItemDefinition:
	return items.get(item_id)


func get_class_def(class_id: StringName) -> ClassDefinition:
	return classes.get(class_id)


func get_track(family_id: StringName) -> MasteryTrack:
	return mastery_tracks.get(family_id)


## Cross-reference checks between definition tables.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for family: WeaponFamily in weapons.values():
		errors.append_array(family.validate())
	for track: MasteryTrack in mastery_tracks.values():
		var family: WeaponFamily = weapons.get(track.family_id)
		if family == null:
			errors.append("mastery track for unknown family %s" % track.family_id)
			continue
		for unlock in track.unlocks:
			if unlock.requirement_id != &"" and not _family_uses_requirement(family, unlock.requirement_id):
				errors.append("mastery %s unlocks %s, but no attack requires it" % [track.family_id, unlock.requirement_id])
	for item: ItemDefinition in items.values():
		errors.append_array(item.validate())
		if item.weapon_family_id != &"" and not weapons.has(item.weapon_family_id):
			errors.append("item %s references unknown weapon family %s" % [item.id, item.weapon_family_id])
		if item.set_id != &"" and not sets.has(item.set_id):
			errors.append("item %s references unknown set %s" % [item.id, item.set_id])
	for set_def: SetDefinition in sets.values():
		for piece in set_def.piece_item_ids:
			if not items.has(piece):
				errors.append("set %s lists unknown item %s" % [set_def.id, piece])
	for map_def: MapDefinition in maps.values():
		if map_def.scene_path == "" or not ResourceLoader.exists(map_def.scene_path):
			errors.append("map %s: scene %s missing" % [map_def.id, map_def.scene_path])
		if map_def.region_id != &"" and not regions.has(map_def.region_id):
			errors.append("map %s references unknown region %s" % [map_def.id, map_def.region_id])
	for region: RegionDefinition in regions.values():
		for map_id in region.map_ids:
			if not maps.has(map_id):
				errors.append("region %s lists unknown map %s" % [region.id, map_id])
	for building: BuildingDefinition in buildings.values():
		for cost in building.costs:
			if not items.has(cost.item_id):
				errors.append("building %s costs unknown item %s" % [building.id, cost.item_id])
		for recipe in building.recipes:
			if not items.has(recipe.output_item_id):
				errors.append("recipe %s outputs unknown item %s" % [recipe.id, recipe.output_item_id])
			for input in recipe.inputs:
				if not items.has(input.item_id):
					errors.append("recipe %s needs unknown item %s" % [recipe.id, input.item_id])
	for node_def: ResourceNodeDefinition in resource_nodes.values():
		if not items.has(node_def.yield_item_id) or node_def.yield_quantity < 1:
			errors.append("resource node %s has an invalid yield" % node_def.id)
	for plot: BuildingPlotDefinition in plots.values():
		if not maps.has(plot.map_id):
			errors.append("plot %s on unknown map %s" % [plot.id, plot.map_id])
		for building_id in plot.allowed_building_ids:
			if not buildings.has(building_id):
				errors.append("plot %s allows unknown building %s" % [plot.id, building_id])
	return errors


func _family_uses_requirement(family: WeaponFamily, requirement: StringName) -> bool:
	for attack in family.attacks:
		if attack.unlock_requirement == requirement:
			return true
	return false


static func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(path):
		return result
	for file in DirAccess.get_files_at(path):
		# Exported builds list "x.tres.remap"; load() resolves the remap.
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var resource := load(path.path_join(name))
			if resource != null:
				result.append(resource)
	return result
