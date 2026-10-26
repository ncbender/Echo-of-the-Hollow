class_name MapDefinition
extends Resource
## One loadable map (scene) of a region.

@export var id: StringName
@export var region_id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export var default_spawn_id: StringName = &"default"

@export_group("World map (presentation only)")
## Cell of the schematic region map (WorldMapPanel).
@export var map_cell: Vector2i = Vector2i.ZERO
## Maps reachable by walking from here (lines on the world map).
@export var neighbors: Array[StringName] = []
## False for developer areas (not drawn on the world map).
@export var show_on_map: bool = true
