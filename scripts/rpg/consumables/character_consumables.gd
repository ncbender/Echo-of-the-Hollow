class_name CharacterConsumables
extends RefCounted
## Hearth Flask and special potion state of one character (Consumables 1.0).
## Pure state, saved as "consumables" (save v9); the rules live in
## ConsumableService. The flask is a character feature, never an item: it
## cannot be sold, stored, dropped or salvaged.

## Something changed (charges, upgrades, slot, buff, cooldown) - HUD refresh.
signal changed

## Upgrade levels at Mara (0 = none bought).
var capacity_level: int = 0
var potency_level: int = 0
## Charges left (refilled at rest points).
var charges: int = 2
## Potion type on quick slot 2 (an item id; kept when the stack runs out).
var potion_slot: StringName = &""
## Active special potion buff: the potion's item id and seconds left (&"" = none).
var buff_item: StringName = &""
var buff_left: float = 0.0
## Shared potion cooldown left (seconds).
var cooldown_left: float = 0.0


func to_dict() -> Dictionary:
	return {"capacity": capacity_level, "potency": potency_level, "charges": charges,
		"potion_slot": String(potion_slot), "buff": String(buff_item), "buff_left": snappedf(buff_left, 0.01),
		"cooldown": snappedf(cooldown_left, 0.01)}


## Restores saved state; values are clamped by ConsumableService.sanitize.
func from_dict(data: Dictionary) -> void:
	capacity_level = int(data.get("capacity", 0)) if data.get("capacity") is float or data.get("capacity") is int else 0
	potency_level = int(data.get("potency", 0)) if data.get("potency") is float or data.get("potency") is int else 0
	charges = int(data.get("charges", -1)) if data.get("charges") is float or data.get("charges") is int else -1
	potion_slot = StringName(str(data.get("potion_slot", ""))) if data.get("potion_slot") is String else &""
	buff_item = StringName(str(data.get("buff", ""))) if data.get("buff") is String else &""
	buff_left = float(data.get("buff_left", 0.0)) if data.get("buff_left") is float or data.get("buff_left") is int else 0.0
	cooldown_left = float(data.get("cooldown", 0.0)) if data.get("cooldown") is float or data.get("cooldown") is int else 0.0
