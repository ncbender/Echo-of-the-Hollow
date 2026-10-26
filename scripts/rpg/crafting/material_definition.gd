class_name MaterialDefinition
extends Resource
## Main material of a crafted item (exactly one per item, chosen at imprint).
## Gives a guaranteed imprint effect and shifts the affix weights (resonance).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Inventory item consumed by the imprint.
@export var item_id: StringName
@export var imprint_quantity: int = 3
## Item slot kinds this material can be imprinted on.
@export var allowed_slot_kinds: Array[ItemDefinition.SlotKind] = []
## Guaranteed material effect (always active while the item is equipped).
@export var imprint_modifiers: Array[StatModifier] = []
## Affix tags this material favours (shown in the UI).
@export var preferred_tags: Array[StringName] = []
## Weight multiplier per affix tag; an affix uses the largest matching multiplier.
@export var tag_weight_multipliers: Dictionary[StringName, float] = {}
## Essences that resonate with this material: their effects are stronger.
@export var essence_affinity: Array[StringName] = []
@export var affinity_power: float = 1.25
@export var color: Color = Color.WHITE


func allows_slot(kind: ItemDefinition.SlotKind) -> bool:
	return kind in allowed_slot_kinds


## Weight factor for an affix with `tags` (1.0 when no tag matches).
func weight_multiplier(tags: Array[StringName]) -> float:
	var best := 1.0
	var matched := false
	for tag in tags:
		if tag_weight_multipliers.has(tag):
			best = tag_weight_multipliers[tag] if not matched else maxf(best, tag_weight_multipliers[tag])
			matched = true
	return best


## Essence effect strength on items of this material.
func essence_power(essence_id: StringName) -> float:
	return affinity_power if essence_id in essence_affinity else 1.0
