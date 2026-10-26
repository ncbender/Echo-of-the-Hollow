class_name ResourceNodeDefinition
extends Resource
## A gatherable world resource (tree, rock, ore vein ...).
## Availability rule: after gathering, the node is depleted for
## `respawn_seconds` of REAL time (unix clock, so it also passes while the game
## is closed); 0 = depleted permanently (one-time resource).

enum Look { TREE, ROCK, ORE }

@export var id: StringName
@export var display_name: String
@export var yield_item_id: StringName
@export var yield_quantity: int = 1
@export var respawn_seconds: float = 90.0
@export var look: Look = Look.TREE
