class_name CraftingPreview
extends RefCounted
## Result of validating a CraftingRequest without changing anything. execute()
## builds exactly this preview first, so preview and execution can never disagree.

## Rule violation ("" = allowed). Shown to the player as is.
var error: String = ""
## Total costs (merged per item id): operation + material + focus + stage costs.
var costs: Array[ItemCost] = []
## Human-readable missing resources ("2x Imprint Shard (have 1)").
var missing: PackedStringArray = []
## Rolling operations: the weighted affix pool (AffixPool entries, normalized).
var outcomes: Array[Dictionary] = []
## Consequences the player should know before confirming (e.g. consumed essence).
var notes: PackedStringArray = []


func ok() -> bool:
	return error == "" and missing.is_empty()


func reason() -> String:
	if error != "":
		return error
	if not missing.is_empty():
		return "Missing: " + ", ".join(missing)
	return ""


func add_cost(item_id: StringName, quantity: int) -> void:
	if quantity <= 0:
		return
	for cost in costs:
		if cost.item_id == item_id:
			cost.quantity += quantity
			return
	var cost := ItemCost.new()
	cost.item_id = item_id
	cost.quantity = quantity
	costs.append(cost)
