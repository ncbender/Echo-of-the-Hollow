class_name ClassDefinition
extends Resource
## One playable class. All classes live on the same character; each has its own
## level, XP, loadout and (later) skills and talents.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Progression")
@export var max_level: int = 30
## XP from level n to n+1 = round(xp_base * xp_growth^(n-1)).
@export var xp_base: int = 120
@export var xp_growth: float = 1.2

@export_group("Stats")
## Flat contributions at level 1.
@export var base_stats: Array[StatModifier] = []
## Flat contributions added per level above 1.
@export var stats_per_level: Array[StatModifier] = []

@export_group("Equipment Rules")
## Weapon families this class may equip (empty = all).
@export var allowed_weapon_families: Array[StringName] = []
@export var can_dual_wield: bool = true
@export var can_use_shields: bool = true

@export_group("Unlock")
@export var starts_unlocked: bool = false
## Documented hook for the later unlock source ("prologue.choice", "quest.<id>",
## "boss.<id>", "debug"). Unlocking itself goes through CharacterClasses.unlock().
@export var unlock_condition: StringName

@export_group("Prepared Interfaces")
@export var resource: ClassResourceDefinition
## Skill slot ids for Q/E/R/F.
@export var skill_slot_ids: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3", &"ability_4"]
## The three talent trees of the class (empty for classes without talents yet).
@export var talent_tree_ids: Array[StringName] = []
## False for prepared classes (Guardian, Soulbinder): defined and unlockable later,
## but without skills/talents in this build - they cannot be activated yet.
@export var playable: bool = true
## Class mechanics expressed as combat effects (e.g. Shadowrunner: finishers expose
## Weak Points). Always active while the class is; hosted by the ItemEffectRunner.
@export var innate_effects: Array[ItemEffect] = []
## Items granted the first time the class is unlocked.
@export var starting_item_ids: Array[StringName] = []


func xp_to_next(level: int) -> int:
	if level >= max_level:
		return 0
	return roundi(xp_base * pow(xp_growth, level - 1))


func allows_weapon_family(family_id: StringName) -> bool:
	return allowed_weapon_families.is_empty() or family_id in allowed_weapon_families
