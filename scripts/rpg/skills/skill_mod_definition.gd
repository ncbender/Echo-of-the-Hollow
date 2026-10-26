class_name SkillModDefinition
extends Resource
## A skill modification (docs/SKILL_SYSTEM.md). Slotted mods go into a skill's
## FORM slot (execution, range, shape, hit behaviour) or RESONANCE slot
## (synergies, resources, status conditions); one per slot. Transformative
## talents reuse the same resource as always-on changes.
## Most mods are small numeric changes; `replace_actions` turns a mod into a real
## transformation of the skill.

enum Slot { FORM, RESONANCE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var slot: Slot = Slot.FORM
## Skills this mod can be applied to.
@export var skill_ids: Array[StringName] = []
## Mods that can never be combined with this one on the same skill.
@export var incompatible_with: Array[StringName] = []
## Marks a real transformation (UI emphasis).
@export var transformative: bool = false

@export_group("Unlock")
## Class level that makes the mod available (0 = only via talent, quest, boss or exploration).
@export var unlock_level: int = 0
## Documented source when not level-based ("talent.<node>", "quest.<id>", "boss.<id>", "explore.<id>").
@export var unlock_source: StringName

@export_group("Changes")
@export var damage_multiplier: float = 1.0
@export var poise_multiplier: float = 1.0
@export var radius_multiplier: float = 1.0
@export var range_multiplier: float = 1.0
@export var cost_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var extra_projectiles: int = 0
@export var extra_pierce: int = 0
@export var add_tags: Array[StringName] = []
@export var add_statuses: Array[SkillStatusSpec] = []
## Class resource refunded per target hit.
@export var resource_on_hit: float = 0.0
## Damage multiplier against targets carrying `bonus_status`.
@export var bonus_status: StringName
@export var bonus_multiplier: float = 1.0
## Actions appended after the skill's own actions.
@export var extra_actions: Array[SkillAction] = []
## Non-empty: replaces the skill's actions entirely (transformation).
@export var replace_actions: Array[SkillAction] = []


func fits(skill: SkillDefinition) -> bool:
	return skill != null and skill.allows_mods and skill.id in skill_ids


func slot_name() -> String:
	return "Form" if slot == Slot.FORM else "Resonance"
