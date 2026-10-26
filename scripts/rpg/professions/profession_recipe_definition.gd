class_name ProfessionRecipeDefinition
extends Resource
## A profession recipe (docs/PROFESSIONS.md): materials at a workstation turn
## into an item and give profession XP. Learned once, permanently
## (CharacterProfessions.known). Crafting goes through ProfessionService only.

## Where the recipe is learned. Only AUTOMATIC (on reaching required_level) and
## RECIPE_ITEM are used by content yet; the others are prepared for trainers,
## quests and enemy / elite / boss drops (ProfessionService.learn_recipe).
enum UnlockSource { AUTOMATIC, TRAINER, RECIPE_ITEM, QUEST, DROP }

@export var id: StringName
@export var display_name: String
@export var profession_id: StringName
@export var required_level: int = 1
## Workstation (Haven ruin id) the recipe needs; empty = the profession's station.
@export var station_id: StringName
@export var inputs: Array[ItemCost] = []
@export var output_item_id: StringName
@export var output_quantity: int = 1
## Base XP of one craft (scaled by the level difference, +100 % on the first craft).
@export var xp: int = 10
## Processing step (smelting, tanning, weaving ...) - shown apart in the list.
@export var is_processing: bool = false

@export_group("Unlock")
@export var unlock_source: UnlockSource = UnlockSource.AUTOMATIC
## Trainer, item, quest or enemy id for the non-automatic sources (documentation and UI).
@export var unlock_reference: StringName

@export_group("Availability")
## False for recipes that are data only for now (e.g. potions while consumables
## cannot be used): they are listed with `unavailable_reason` and never crafted.
@export var craftable: bool = true
@export var unavailable_reason: String

@export_group("Future")
## Prepared for later material / affix parameters of the output (unused yet;
## the Resonance Forge keeps its own affix rules for now).
@export var output_parameters: Dictionary = {}


static func source_name(source: UnlockSource) -> String:
	return ["Learned automatically", "Taught by a trainer", "Learned from a recipe item", "Quest reward", "Enemy drop"][source]
