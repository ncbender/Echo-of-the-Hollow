class_name StatModifier
extends Resource
## Flat and/or percent contribution to one stat (see Stats).

@export var stat: StringName
@export var flat: float = 0.0
@export var percent: float = 0.0


static func make(stat_id: StringName, flat_value: float, percent_value: float = 0.0) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = stat_id
	modifier.flat = flat_value
	modifier.percent = percent_value
	return modifier


func describe() -> String:
	var parts: PackedStringArray = []
	if flat != 0.0:
		parts.append("%+g %s" % [flat, Stats.display_name(stat)])
	if percent != 0.0:
		parts.append("%+g%% %s" % [percent, Stats.display_name(stat)])
	return ", ".join(parts)
