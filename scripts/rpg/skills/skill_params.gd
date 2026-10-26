class_name SkillParams
extends RefCounted
## Resolved parameters of one skill for one cast: the skill's data combined with
## its slotted Form/Resonance mods, transformative talents and cast-time stats.
## Built fresh for every cast and every tooltip - nothing is cached or added up.

var skill: SkillDefinition
var damage_multiplier: float = 1.0
var poise_multiplier: float = 1.0
var radius_multiplier: float = 1.0
var range_multiplier: float = 1.0
var cost: float = 0.0
var cooldown: float = 0.0
var extra_projectiles: int = 0
var extra_pierce: int = 0
var tags: Array[StringName] = []
var statuses: Array[SkillStatusSpec] = []
var resource_on_hit: float = 0.0
## status id -> damage multiplier against targets carrying it.
var status_bonus: Dictionary = {}
var actions: Array[SkillAction] = []
## Ids of every mod that shaped these params (slotted + talents).
var mod_ids: Array[StringName] = []


## `mods`: slotted mods first, then transformative talent mods.
## `cost_factor` / `cooldown_factor`: from stats (resource efficiency, cooldown reduction).
static func resolve(definition: SkillDefinition, mods: Array[SkillModDefinition],
		cost_factor: float = 1.0, cooldown_factor: float = 1.0) -> SkillParams:
	var params := SkillParams.new()
	params.skill = definition
	params.tags = definition.tags.duplicate()
	var cost_multiplier := 1.0
	var cooldown_multiplier := 1.0
	var replaced: Array[SkillAction] = []
	var extra: Array[SkillAction] = []
	for mod in mods:
		if mod == null:
			continue
		params.mod_ids.append(mod.id)
		params.damage_multiplier *= mod.damage_multiplier
		params.poise_multiplier *= mod.poise_multiplier
		params.radius_multiplier *= mod.radius_multiplier
		params.range_multiplier *= mod.range_multiplier
		cost_multiplier *= mod.cost_multiplier
		cooldown_multiplier *= mod.cooldown_multiplier
		params.extra_projectiles += mod.extra_projectiles
		params.extra_pierce += mod.extra_pierce
		params.resource_on_hit += mod.resource_on_hit
		for tag in mod.add_tags:
			if not tag in params.tags:
				params.tags.append(tag)
		params.statuses.append_array(mod.add_statuses)
		if mod.bonus_status != &"":
			params.status_bonus[mod.bonus_status] = params.status_bonus.get(mod.bonus_status, 1.0) * mod.bonus_multiplier
		if not mod.replace_actions.is_empty():
			replaced = mod.replace_actions
		extra.append_array(mod.extra_actions)
	params.actions.assign(replaced if not replaced.is_empty() else definition.actions)
	params.actions.append_array(extra)
	params.cost = maxf(0.0, definition.resource_cost * cost_multiplier * cost_factor)
	params.cooldown = maxf(0.0, definition.cooldown * cooldown_multiplier * cooldown_factor)
	return params


func has_tag(tag: StringName) -> bool:
	return tag in tags


func describe() -> String:
	var lines: PackedStringArray = []
	for action in actions:
		var text := action.describe(self)
		if text != "":
			lines.append(text)
	return "\n".join(lines)
