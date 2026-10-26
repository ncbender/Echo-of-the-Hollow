class_name EvolutionMutation
extends Resource
## One permanent mutation path offered by an evolution stage.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var modifiers: Array[StatModifier] = []
@export var effects: Array[ItemEffect] = []
