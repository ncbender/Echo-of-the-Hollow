class_name CraftingProfile
extends Resource
## Crafting capabilities of an item type (sub-resource of ItemDefinition.crafting;
## null = the item cannot be crafted at all). Uniques and legendaries list only the
## operations that may touch them - their handcrafted effects are never affixes and
## therefore can never be reforged (docs/CRAFTING_DESIGN.md).

## Operation ids (CraftingOps) this item accepts.
@export var allowed_operations: Array[StringName] = []
## Maximum number of rolled affixes.
@export_range(0, 6) var affix_slots: int = 0
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
## Base stats improved by quality (+1 % per point); empty = all base stats.
@export var quality_stats: Array[StringName] = []
## Only items with an evolution can evolve (design rule 14).
@export var evolution_id: StringName


func allows(operation: StringName) -> bool:
	return operation in allowed_operations
