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
	&"materials": "res://data/crafting/materials",
	&"affixes": "res://data/crafting/affixes",
	&"essences": "res://data/crafting/essences",
	&"resonances": "res://data/crafting/resonances",
	&"socketables": "res://data/crafting/socketables",
	&"currencies": "res://data/crafting/currencies",
	&"operations": "res://data/crafting/operations",
	&"evolutions": "res://data/crafting/evolutions",
	&"statuses": "res://data/status",
	&"skills": "res://data/skills",
	&"skill_mods": "res://data/skill_mods",
	&"talent_trees": "res://data/talents",
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
# Crafting (docs/CRAFTING_DESIGN.md)
var materials: Dictionary = {}        # material id -> MaterialDefinition
var affixes: Dictionary = {}          # affix id -> AffixDefinition
var essences: Dictionary = {}         # essence id -> EssenceDefinition
var resonances: Dictionary = {}       # resonance id -> EssenceResonanceDefinition
var socketables: Dictionary = {}      # socketable id -> SocketableDefinition
var currencies: Dictionary = {}       # currency id -> CraftingCurrencyDefinition
var operations: Dictionary = {}       # operation id -> CraftingOperationDefinition
var evolutions: Dictionary = {}       # evolution id -> EvolutionDefinition
var statuses: Dictionary = {}         # status id -> StatusEffectDefinition
# Classes (docs/CLASS_DESIGN.md, TALENT_SYSTEM.md, SKILL_SYSTEM.md)
var skills: Dictionary = {}           # skill id -> SkillDefinition
var skill_mods: Dictionary = {}       # mod id -> SkillModDefinition
var talent_trees: Dictionary = {}     # tree id -> TalentTreeDefinition
var talent_nodes: Dictionary = {}     # node id -> TalentNodeDefinition (indexed from the trees)
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
	elif resource is MaterialDefinition:
		table = materials; key = resource.id
	elif resource is AffixDefinition:
		table = affixes; key = resource.id
	elif resource is EssenceDefinition:
		table = essences; key = resource.id
	elif resource is EssenceResonanceDefinition:
		table = resonances; key = resource.id
	elif resource is SocketableDefinition:
		table = socketables; key = resource.id
	elif resource is CraftingCurrencyDefinition:
		table = currencies; key = resource.id
	elif resource is CraftingOperationDefinition:
		table = operations; key = resource.id
	elif resource is EvolutionDefinition:
		table = evolutions; key = resource.id
	elif resource is StatusEffectDefinition:
		table = statuses; key = resource.id
	elif resource is SkillDefinition:
		table = skills; key = resource.id
	elif resource is SkillModDefinition:
		table = skill_mods; key = resource.id
	elif resource is TalentTreeDefinition:
		table = talent_trees; key = resource.id
		for node: TalentNodeDefinition in resource.nodes:
			if node != null and talent_nodes.has(node.id):
				load_errors.append("duplicate talent node %s (%s)" % [node.id, resource.resource_path])
			elif node != null:
				talent_nodes[node.id] = node
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
	for status: StatusEffectDefinition in statuses.values():
		errors.append_array(status.validate())
	for status_id in [rules.bleed_status_id, rules.chill_status_id]:
		if status_id != &"" and not statuses.has(status_id):
			errors.append("rules reference unknown status %s" % status_id)
	errors.append_array(_validate_crafting())
	errors.append_array(_validate_classes())
	return errors


func get_operation(operation_id: StringName) -> CraftingOperationDefinition:
	return operations.get(operation_id)


## Crafting cross-references: every referenced item/definition must exist.
func _validate_crafting() -> PackedStringArray:
	var errors: PackedStringArray = []
	for material: MaterialDefinition in materials.values():
		if not items.has(material.item_id):
			errors.append("material %s uses unknown item %s" % [material.id, material.item_id])
		for essence_id in material.essence_affinity:
			if not essences.has(essence_id):
				errors.append("material %s: unknown essence affinity %s" % [material.id, essence_id])
	for affix: AffixDefinition in affixes.values():
		errors.append_array(affix.validate())
	for essence: EssenceDefinition in essences.values():
		if not items.has(essence.item_id) or essence.effect == null:
			errors.append("essence %s needs an existing item and an effect" % essence.id)
	for resonance: EssenceResonanceDefinition in resonances.values():
		if not essences.has(resonance.essence_a) or not essences.has(resonance.essence_b) or resonance.effect == null:
			errors.append("resonance %s needs two known essences and an effect" % resonance.id)
	for socketable: SocketableDefinition in socketables.values():
		if not items.has(socketable.item_id):
			errors.append("socketable %s uses unknown item %s" % [socketable.id, socketable.item_id])
	for currency: CraftingCurrencyDefinition in currencies.values():
		if not items.has(currency.item_id):
			errors.append("currency %s uses unknown item %s" % [currency.id, currency.item_id])
	for operation: CraftingOperationDefinition in operations.values():
		if not operation.id in CraftingOps.ALL:
			errors.append("unknown crafting operation %s" % operation.id)
		for cost in operation.costs + operation.focus_costs:
			if not items.has(cost.item_id):
				errors.append("operation %s costs unknown item %s" % [operation.id, cost.item_id])
			elif items[cost.item_id].is_equippable():
				errors.append("operation %s must not consume equipment (%s)" % [operation.id, cost.item_id])
	for evolution: EvolutionDefinition in evolutions.values():
		errors.append_array(evolution.validate())
		for stage in evolution.stages:
			for cost in stage.costs:
				if not items.has(cost.item_id):
					errors.append("evolution %s costs unknown item %s" % [evolution.id, cost.item_id])
	for item: ItemDefinition in items.values():
		var profile := item.crafting
		if profile == null:
			continue
		for material_id in profile.allowed_materials:
			if not materials.has(material_id):
				errors.append("item %s allows unknown material %s" % [item.id, material_id])
		if profile.evolution_id != &"" and not evolutions.has(profile.evolution_id):
			errors.append("item %s evolves with unknown evolution %s" % [item.id, profile.evolution_id])
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


## Skills, mods, talent trees and class references (TalentService checks trees).
func _validate_classes() -> PackedStringArray:
	var errors: PackedStringArray = []
	for skill: SkillDefinition in skills.values():
		errors.append_array(skill.validate())
		if get_class_def(skill.class_id) == null:
			errors.append("skill %s for unknown class %s" % [skill.id, skill.class_id])
	for mod: SkillModDefinition in skill_mods.values():
		if mod.skill_ids.is_empty():
			errors.append("mod %s fits no skill" % mod.id)
		for skill_id in mod.skill_ids:
			if not skills.has(skill_id):
				errors.append("mod %s references unknown skill %s" % [mod.id, skill_id])
		for other in mod.incompatible_with:
			if not skill_mods.has(other):
				errors.append("mod %s: unknown incompatible mod %s" % [mod.id, other])
		for status in mod.add_statuses:
			if status != null and not statuses.has(status.status_id):
				errors.append("mod %s applies unknown status %s" % [mod.id, status.status_id])
	errors.append_array(TalentService.validate_data(self))
	return errors
