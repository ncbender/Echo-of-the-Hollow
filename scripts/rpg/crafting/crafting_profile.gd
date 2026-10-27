class_name CraftingProfile
extends Resource
## Crafting capabilities of an item type (sub-resource of ItemDefinition.crafting;
## null = the item cannot be crafted at all). Uniques and legendaries list only the
## operations that may touch them - their handcrafted effects are never affixes and
## therefore can never be reforged (docs/CRAFTING_DESIGN.md).

## Item Foundation 1.0 (docs/ITEM_FOUNDATION_1_0.md): at most five regular affix
## slots (local and global together); Monster Essences are separate, at most two.
const MAX_AFFIX_SLOTS := 5
const MAX_ESSENCE_SLOTS := 2

## Operation ids (CraftingOps) this item accepts.
@export var allowed_operations: Array[StringName] = []
## Maximum number of rolled regular affixes.
@export_range(0, 5) var affix_slots: int = 0
## Essence slots (design maximum 2, independent of sockets).
@export_range(0, 2) var essence_slots: int = 0
## Sockets that can be opened with socket chisels.
@export_range(0, 4) var socket_slots: int = 0
## Main materials this item may be imprinted with (empty = every material that
## allows the item's slot kind).
@export var allowed_materials: Array[StringName] = []
## Item level of new instances (affix tiers depend on it).
@export var base_item_level: int = 1
@export_range(0, 20) var max_quality: int = 20
## Base stats improved by quality (ItemStats.QUALITY_PERCENT_PER_POINT); empty = all base stats.
@export var quality_stats: Array[StringName] = []
## Only items with an evolution can evolve (design rule 14).
@export var evolution_id: StringName


func allows(operation: StringName) -> bool:
	return operation in allowed_operations


## Usable regular affix slots (never above MAX_AFFIX_SLOTS, even for unvalidated data).
func affix_limit() -> int:
	return clampi(affix_slots, 0, MAX_AFFIX_SLOTS)


func validate(item_id: StringName) -> PackedStringArray:
	var errors: PackedStringArray = []
	if affix_slots < 0 or affix_slots > MAX_AFFIX_SLOTS:
		errors.append("item %s: affix_slots %d outside 0..%d" % [item_id, affix_slots, MAX_AFFIX_SLOTS])
	if essence_slots < 0 or essence_slots > MAX_ESSENCE_SLOTS:
		errors.append("item %s: essence_slots %d outside 0..%d" % [item_id, essence_slots, MAX_ESSENCE_SLOTS])
	if max_quality < 0 or max_quality > ItemStats.MAX_QUALITY:
		errors.append("item %s: max_quality %d outside 0..%d" % [item_id, max_quality, ItemStats.MAX_QUALITY])
	return errors
