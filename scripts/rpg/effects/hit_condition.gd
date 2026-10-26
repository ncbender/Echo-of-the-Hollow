class_name HitCondition
extends Resource
## Reusable condition for talent and item effects: which hits count. All set
## fields must match. Class state (resource ratio, pressure, recent casts) is
## read from ItemEffectRunner.shared_state(&"class"), written by ClassRuntime.

## HitData.Source bits that count (Direct, Skill, Triggered, Status).
@export_flags("Direct", "Skill", "Triggered", "Status") var sources: int = 1
## The hit must carry ALL of these tags.
@export var required_tags: Array[StringName] = []
## The hit must carry at least one of these tags (empty = no check).
@export var any_tags: Array[StringName] = []
## Fully charged heavy attacks only.
@export var full_charge_only: bool = false
## The target must carry this status (with at least target_status_stacks stacks).
@export var target_status: StringName
@export var target_status_stacks: int = 1
## Class resource ratio range (0..1) at the time of the hit.
@export_range(0.0, 1.0) var min_resource_ratio: float = 0.0
@export var min_pressure: int = 0
## A skill with this tag or id was cast within `recent_seconds`.
@export var recent_cast: StringName
@export var recent_seconds: float = 0.0
@export var requires_kill: bool = false
@export var requires_poise_break: bool = false
@export var requires_crit: bool = false


func matches(hit: HitData, runner: ItemEffectRunner) -> bool:
	if (sources & (1 << hit.source)) == 0:
		return false
	for tag in required_tags:
		if not tag in hit.tags:
			return false
	if not any_tags.is_empty() and not any_tags.any(func(tag: StringName) -> bool: return tag in hit.tags):
		return false
	if full_charge_only:
		var profile := hit.attack.charge_profile if hit.attack != null else null
		if profile == null or profile.max_tier() <= 0 or hit.charge_tier < profile.max_tier():
			return false
	if requires_kill and not hit.killed:
		return false
	if requires_poise_break and not hit.broke_poise:
		return false
	if requires_crit and not &"crit" in hit.tags:
		return false
	if target_status != &"":
		var status := StatusComponent.of(hit.target)
		if status == null or status.stacks(target_status) < target_status_stacks:
			return false
	var state := runner.shared_state(&"class") if runner != null else {}
	if min_resource_ratio > 0.0 and float(state.get("resource_ratio", 0.0)) + 0.0001 < min_resource_ratio:
		return false
	if min_pressure > 0 and int(state.get("pressure", 0)) < min_pressure:
		return false
	if recent_cast != &"":
		var cast_at: float = state.get("recent_casts", {}).get(recent_cast, -1000.0)
		if float(state.get("time", 0.0)) - cast_at > recent_seconds:
			return false
	return true
