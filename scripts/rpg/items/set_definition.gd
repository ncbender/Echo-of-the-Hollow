class_name SetDefinition
extends Resource
## An item set: pieces and thresholds of active bonuses.

@export var id: StringName
@export var display_name: String
@export var piece_item_ids: Array[StringName] = []
@export var bonuses: Array[SetBonus] = []


func active_bonuses(equipped_pieces: int) -> Array[SetBonus]:
	var result: Array[SetBonus] = []
	for bonus in bonuses:
		if equipped_pieces >= bonus.pieces_required:
			result.append(bonus)
	return result
