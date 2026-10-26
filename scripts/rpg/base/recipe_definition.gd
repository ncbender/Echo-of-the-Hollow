class_name RecipeDefinition
extends Resource
## Technical crafting test: fixed inputs -> one existing item. NOT the final
## crafting design (no living materials / essences rules yet).

@export var id: StringName
@export var display_name: String
@export var inputs: Array[ItemCost] = []
@export var output_item_id: StringName
@export var output_quantity: int = 1
