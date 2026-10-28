class_name MapDefinition
extends Resource
## One loadable map (scene) of a region.

@export var id: StringName
@export var region_id: StringName
@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export var default_spawn_id: StringName = &"default"
## Maps that are never a saved location (Class Trials 2.0 trial grounds): while
## the player is here the character's location points to this map/spawn, so a
## save - and loading an older save that names this map - resumes there.
@export var resume_map_id: StringName
@export var resume_spawn_id: StringName = &"default"

@export_group("World map (presentation only)")
## Cell of the schematic region map (WorldMapPanel).
@export var map_cell: Vector2i = Vector2i.ZERO
## Maps reachable by walking from here (lines on the world map).
@export var neighbors: Array[StringName] = []
## False for developer areas (not drawn on the world map).
@export var show_on_map: bool = true


## Moves a saved location on a resume map (see resume_map_id) to its resume
## point. Returns true when the location changed.
static func resolve_saved_location(db: GameDatabase, world: WorldState) -> bool:
	var map_def: MapDefinition = db.maps.get(world.map_id)
	if map_def == null or map_def.resume_map_id == &"":
		return false
	world.map_id = map_def.resume_map_id
	world.spawn_id = map_def.resume_spawn_id
	return true
