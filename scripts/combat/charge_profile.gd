class_name ChargeProfile
extends Resource
## Heavy-attack charge tiers. Tier 0 = normal, 1 = empowered, 2 = full (with the
## default two thresholds). Multiplier arrays are indexed by tier.

@export var tier_names: PackedStringArray = ["Normal", "Empowered", "Full"]
## Hold time in seconds at which each further tier is reached (ascending).
@export var tier_thresholds: PackedFloat32Array = [0.25, 0.7]
@export var damage_multipliers: PackedFloat32Array = [1.0, 1.35, 1.9]
@export var poise_multipliers: PackedFloat32Array = [1.0, 1.5, 2.5]
@export var reach_multipliers: PackedFloat32Array = [1.0, 1.1, 1.25]
@export var hitstop_multipliers: PackedFloat32Array = [1.0, 1.3, 1.8]
## Movement speed multiplier while holding the charge.
@export var move_multiplier: float = 0.55


func get_tier(hold_time: float) -> int:
	var tier := 0
	for threshold in tier_thresholds:
		if hold_time + 0.00001 >= threshold:
			tier += 1
	return tier


func max_tier() -> int:
	return tier_thresholds.size()


func tier_name(tier: int) -> String:
	return tier_names[tier] if tier < tier_names.size() else "Tier %d" % tier


func damage_multiplier(tier: int) -> float:
	return _pick(damage_multipliers, tier)


func poise_multiplier(tier: int) -> float:
	return _pick(poise_multipliers, tier)


func reach_multiplier(tier: int) -> float:
	return _pick(reach_multipliers, tier)


func hitstop_multiplier(tier: int) -> float:
	return _pick(hitstop_multipliers, tier)


func _pick(values: PackedFloat32Array, tier: int) -> float:
	if values.is_empty():
		return 1.0
	return values[clampi(tier, 0, values.size() - 1)]
