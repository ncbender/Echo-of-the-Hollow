class_name SetBonus
extends Resource
## Bonus that is active while at least `pieces_required` set pieces are equipped.

@export var pieces_required: int = 2
@export var stat_modifiers: Array[StatModifier] = []
@export var effects: Array[ItemEffect] = []
@export var description: String
