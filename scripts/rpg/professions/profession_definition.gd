class_name ProfessionDefinition
extends Resource
## One profession (docs/PROFESSIONS.md). Pure data; the character's level, XP
## and known recipes live in CharacterProfessions, the rules in ProfessionService.
## Professions do not depend on the class: every character can learn all nine.
##   * CRAFTING: recipes at a workstation (processing like smelting, tanning
##     and weaving are recipes of the crafting profession, not own professions)
##   * GATHERING: resource nodes in the world (ResourceNodeDefinition.profession_id)

enum Kind { CRAFTING, GATHERING }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.CRAFTING
@export var color: Color = Color(0.77, 0.68, 0.52)
## Crafting: the Haven ruin whose workstation crafts this profession's recipes.
@export var station_id: StringName
@export var max_level: int = 100

@export_group("Gathering")
## Gathering 1.1: seconds of one work step (hit, swing, cut) on a resource node
## of this profession while G is held. Prototype values.
@export var gather_step_seconds: float = 0.0

@export_group("XP curve")
## XP from level n to n+1 = round(xp_base * xp_growth^(n-1)).
@export var xp_base: int = 60
@export var xp_growth: float = 1.045


func xp_to_next(level: int) -> int:
	if level >= max_level:
		return 0
	return roundi(xp_base * pow(xp_growth, level - 1))


func is_crafting() -> bool:
	return kind == Kind.CRAFTING
