class_name MapDefinition
extends Resource
## One loadable map (scene) of a region.

@export var id: StringName
@export var region_id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export var default_spawn_id: StringName = &"default"
