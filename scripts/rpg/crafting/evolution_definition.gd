class_name EvolutionDefinition
extends Resource
## Individual evolution of explicitly marked items (CraftingProfile.evolution_id).
## Independent of weapon mastery: item XP is stored on the item instance.

@export var id: StringName
@export var display_name: String
@export var stages: Array[EvolutionStage] = []
## Item XP per accepted hit on a real enemy while the item is the main-hand weapon.
@export var xp_per_hit: int = 1
## Extra item XP for heavy finisher hits.
@export var xp_per_finisher: int = 4


func get_stage(stage_number: int) -> EvolutionStage:
	for stage in stages:
		if stage != null and stage.stage == stage_number:
			return stage
	return null


func max_stage() -> int:
	var result := 1
	for stage in stages:
		if stage != null:
			result = maxi(result, stage.stage)
	return result


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if get_stage(1) == null:
		errors.append("evolution %s: needs a stage 1" % id)
	for stage_number in range(2, max_stage() + 1):
		if get_stage(stage_number) == null:
			errors.append("evolution %s: missing stage %d" % [id, stage_number])
	return errors
