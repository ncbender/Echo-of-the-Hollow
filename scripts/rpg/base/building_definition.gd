class_name BuildingDefinition
extends Resource
## A building that can be constructed on a predefined build plot of the home base.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var costs: Array[ItemCost] = []
## World flag that must be set before this building can be built (empty = always).
@export var required_flag: StringName
## Plot size class; a plot accepts buildings whose size is <= its own size.
@export var size: int = 1
@export var color: Color = Color("8a7a5a")
## Only one building of this type per base.
@export var unique: bool = true
## Scene instantiated on the plot once built (visuals, blocking bodies, dummies ...).
@export var scene: PackedScene
## Extra inventory slots while this building stands (storage).
@export var inventory_capacity_bonus: int = 0
## Recipes offered by this building (smithy crafting test).
@export var recipes: Array[RecipeDefinition] = []
