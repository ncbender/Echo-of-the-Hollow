class_name EvolutionStage
extends Resource
## Stage of an evolving item. Stage 1 is the starting stage (no requirements).
## Bonuses of all reached stages stack; a stage with mutations requires a
## permanent choice when it is reached.

@export var stage: int = 1
@export var display_name: String
@export_multiline var description: String
## Item XP needed to evolve INTO this stage.
@export var xp_required: int = 0
@export var costs: Array[ItemCost] = []
@export var modifiers: Array[StatModifier] = []
@export var effects: Array[ItemEffect] = []
@export var mutations: Array[EvolutionMutation] = []


func get_mutation(mutation_id: StringName) -> EvolutionMutation:
	for mutation in mutations:
		if mutation != null and mutation.id == mutation_id:
			return mutation
	return null
