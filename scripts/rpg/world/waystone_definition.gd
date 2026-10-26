class_name WaystoneDefinition
extends Resource
## One of the four waystones of the Hollowwood (Haven, Whispering Stone, Chapel
## Waystone, Warden's Rest). Activated waystones are fast-travel targets
## (WorldState.waystones). Only `available` ones can be found in this slice.

@export var id: StringName
@export var display_name: String
@export var map_id: StringName
@export var spawn_id: StringName = &"waystone"
## False: planned for a later part of the Hollowwood (shown as undiscovered).
@export var available: bool = false
## Active from the very start (Haven).
@export var starts_active: bool = false
## Sort order in the travel list.
@export var order: int = 0
