class_name SkillText
extends RefCounted
## Tooltip texts for skills, mods and hit specs (English, generated from data so
## the numbers shown are the numbers used).


static func hit(spec: SkillHitSpec, params: SkillParams) -> String:
	if spec == null:
		return ""
	var parts: PackedStringArray = []
	var damage := spec.damage * params.damage_multiplier
	if damage > 0.0:
		parts.append("%d %s damage" % [roundi(damage), spec.damage_type])
	if spec.poise_damage * params.poise_multiplier > 0.0:
		parts.append("%d poise" % roundi(spec.poise_damage * params.poise_multiplier))
	for status in spec.statuses + params.statuses:
		var chance := "" if status.chance >= 1.0 else " (%d%%)" % roundi(status.chance * 100.0)
		parts.append("applies %s%s%s" % [_status_name(status.status_id), " x%d" % status.stacks if status.stacks > 1 else "", chance])
	if spec.consume_status != &"":
		parts.append("consumes %s for +%d damage per stack" % [_status_name(spec.consume_status), roundi(spec.consume_damage_per_stack * params.damage_multiplier)])
	if spec.bonus_status != &"" and spec.bonus_multiplier != 1.0:
		parts.append("+%d%% vs %s" % [roundi((spec.bonus_multiplier - 1.0) * 100.0), _status_name(spec.bonus_status)])
	for status_id: StringName in params.status_bonus:
		parts.append("+%d%% vs %s" % [roundi((params.status_bonus[status_id] - 1.0) * 100.0), _status_name(status_id)])
	var resource := spec.resource_on_hit + params.resource_on_hit
	if resource > 0.0:
		parts.append("+%d resource per hit" % roundi(resource))
	return ", ".join(parts)


static func skill(definition: SkillDefinition, params: SkillParams, resource_name: String) -> String:
	var lines: PackedStringArray = [definition.description]
	var cost := "Cost: %d %s" % [roundi(params.cost), resource_name] if params.cost > 0.0 else "Cost: none"
	lines.append("%s   Cooldown: %.1fs" % [cost, params.cooldown])
	var rules := params.describe()
	if rules != "":
		lines.append(rules)
	return "\n".join(lines)


static func mod(definition: SkillModDefinition) -> String:
	var lines: PackedStringArray = ["%s (%s%s)" % [definition.display_name, definition.slot_name(),
		", transformation" if definition.transformative else ""], definition.description]
	if not definition.incompatible_with.is_empty():
		lines.append("Cannot be combined with: %s" % ", ".join(definition.incompatible_with.map(func(id: StringName) -> String: return String(id).capitalize())))
	return "\n".join(lines)


static func _status_name(status_id: StringName) -> String:
	var status: StatusEffectDefinition = GameDatabase.get_default().statuses.get(status_id)
	return status.display_name if status != null else String(status_id).capitalize()
