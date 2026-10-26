class_name SkillDefinition
extends Resource
## An active class skill for the Q/E/R/F slots (docs/SKILL_SYSTEM.md).

@export var id: StringName
@export var class_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
## Category tags (melee, spell, movement, buff, mark ...) used by mods and talents.
@export var tags: Array[StringName] = []

@export_group("Cost")
## Class resource spent on cast (rage, mana, focus).
@export var resource_cost: float = 0.0
@export var cooldown: float = 4.0

@export_group("Unlock")
## Class level that unlocks the skill (0 = only via talent, quest or other source).
@export var unlock_level: int = 1

@export_group("Execution")
## Seconds after casting in which no attack or other skill can start.
@export var cast_lock: float = 0.25
## Locomotion factor during the cast lock.
@export var cast_move_multiplier: float = 0.6
@export var actions: Array[SkillAction] = []
## False for skills without modification slots.
@export var allows_mods: bool = true


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or class_id == &"":
		errors.append("skill without id or class")
	if actions.is_empty():
		errors.append("skill %s has no actions" % id)
	if resource_cost < 0.0 or cooldown < 0.0 or cast_lock < 0.0:
		errors.append("skill %s has negative cost, cooldown or lock" % id)
	for action in actions:
		if action == null:
			errors.append("skill %s has an empty action" % id)
	return errors
