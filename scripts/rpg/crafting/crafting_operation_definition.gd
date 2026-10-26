class_name CraftingOperationDefinition
extends Resource
## Costs and texts of one crafting operation (id = CraftingOps constant).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Paid on every successful execution (currencies / materials from the inventory).
@export var costs: Array[ItemCost] = []
## Rolling operations: an optional focus catalyst raises the weight of one tag.
@export var allows_focus: bool = false
@export var focus_costs: Array[ItemCost] = []
@export var focus_weight_multiplier: float = 4.0
