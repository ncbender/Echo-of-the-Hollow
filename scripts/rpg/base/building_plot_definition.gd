class_name BuildingPlotDefinition
extends Resource
## A predefined build plot of the home base (no free placement).

@export var id: StringName
@export var display_name: String
@export var map_id: StringName = &"home_base"
## Buildings allowed on this plot (empty = any).
@export var allowed_building_ids: Array[StringName] = []
## Largest building size this plot accepts.
@export var size: int = 1


func allows(building: BuildingDefinition) -> bool:
	return building.size <= size and (allowed_building_ids.is_empty() or building.id in allowed_building_ids)
