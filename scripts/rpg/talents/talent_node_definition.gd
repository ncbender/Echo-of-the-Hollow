class_name TalentNodeDefinition
extends Resource
## One node of a class talent tree (docs/TALENT_SYSTEM.md). Pure data: the rank a
## character holds lives in its ClassBuild; TalentService validates and applies.
##  * PASSIVE: stat modifiers and/or combat effects, scaled by rank
##  * ACTIVE: unlocks an active skill for the Q/E/R/F slots
##  * TRANSFORMATIVE: changes an existing skill (skill_mods) or class mechanic
##    (effects) without needing a skill slot

enum Kind { PASSIVE, ACTIVE, TRANSFORMATIVE }

@export var id: StringName
@export var class_id: StringName
@export var tree_id: StringName
@export var display_name: String
## Effect text. "{rank}" / "{max}" are replaced in the UI.
@export_multiline var description: String
@export var kind: Kind = Kind.PASSIVE
## 1..7. A node of tier t needs TalentRules.tier_points[t - 1] points invested in
## LOWER tiers of the same tree.
@export_range(1, 7) var tier: int = 1
@export var max_rank: int = 1
## Horizontal position inside its tier row (UI only).
@export var column: int = 0
## Node ids that need at least one rank first (same class).
@export var prerequisites: Array[StringName] = []
## Additional class level requirement (0 = only the point rules).
@export var required_class_level: int = 0

@export_group("Effects")
## Contribution per rank (flat and percent are multiplied by the rank).
@export var stat_modifiers: Array[StatModifier] = []
## Combat effects (power = rank) hosted by the ItemEffectRunner.
@export var effects: Array[ItemEffect] = []
## ACTIVE: the skill this node unlocks.
@export var unlocks_skill: StringName
## TRANSFORMATIVE: always-on skill changes while the node has a rank.
@export var skill_mods: Array[SkillModDefinition] = []
## Optional Form/Resonance modifications this node makes available for the slots.
@export var unlocks_mods: Array[StringName] = []


func is_capstone() -> bool:
	return tier == 7


## Stat modifiers for `rank` ranks.
func modifiers_at(rank: int) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	if rank <= 0:
		return result
	for modifier in stat_modifiers:
		result.append(StatModifier.make(modifier.stat, modifier.flat * rank, modifier.percent * rank))
	return result


func describe(rank: int) -> String:
	return description.replace("{rank}", str(rank)).replace("{max}", str(max_rank))


func kind_name() -> String:
	return ["Passive", "Active", "Transformative"][kind]
