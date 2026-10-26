class_name CraftingCurrencyDefinition
extends Resource
## A crafting currency: an inventory item (item_id) with a role. Crafting
## currencies change properties, upgrade currencies improve existing values
## (design rule 13). Costs reference the item through ItemCost - there are no
## hard-coded currency names in code.

enum Kind { CRAFTING, UPGRADE, CATALYST, EXTRACTION }

@export var id: StringName
@export var item_id: StringName
@export var kind: Kind = Kind.CRAFTING
@export_multiline var description: String
