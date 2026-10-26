class_name StatResolver
extends RefCounted
## Central stat calculation. Always recomputes from scratch:
##   final = (sum of flat) * (1 + sum of percent / 100)
## over character base + class + equipment + set bonuses + active modifiers.
## Nothing is ever added incrementally, so equipping/unequipping can never
## leave bonuses behind or apply them twice.


static func resolve(sources: Array) -> Dictionary:
	var flat := {}
	var percent := {}
	for stat in Stats.ALL:
		flat[stat] = 0.0
		percent[stat] = 0.0
	for modifiers: Array in sources:
		for modifier: StatModifier in modifiers:
			if modifier == null:
				continue
			flat[modifier.stat] = flat.get(modifier.stat, 0.0) + modifier.flat
			percent[modifier.stat] = percent.get(modifier.stat, 0.0) + modifier.percent
	var result := {}
	for stat: StringName in flat:
		result[stat] = flat[stat] * (1.0 + percent[stat] / 100.0)
	return result


## Class contribution at `level`: base_stats + stats_per_level * (level - 1).
static func class_modifiers(definition: ClassDefinition, level: int) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	if definition == null:
		return result
	result.append_array(definition.base_stats)
	for modifier in definition.stats_per_level:
		result.append(StatModifier.make(modifier.stat, modifier.flat * (level - 1), modifier.percent * (level - 1)))
	return result
