class_name ObjectiveRules
extends RefCounted
## Shared counting rules for trial and quest objectives (TrialObjective).


static func matches(objective: TrialObjective, kind: TrialObjective.Kind, target_id: StringName) -> bool:
	return objective.kind == kind and (objective.target_id == &"" or objective.target_id == target_id)


## Counters add up; RESOURCE_AT_LEAST keeps the highest value seen.
static func advance(objective: TrialObjective, current: float, amount: float) -> float:
	if objective.is_counter():
		return minf(objective.amount, current + amount)
	return minf(objective.amount, maxf(current, amount))


static func text(objective: TrialObjective, value: float) -> String:
	return "%s  (%d/%d)" % [objective.description, floori(value + 0.0001), roundi(objective.amount)]
