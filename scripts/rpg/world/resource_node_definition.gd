class_name ResourceNodeDefinition
extends Resource
## A gatherable world resource (tree, rock, ore vein ...).
## Availability rule: after gathering, the node is depleted for
## `respawn_seconds` of REAL time (unix clock, so it also passes while the game
## is closed); 0 = depleted permanently (one-time resource).

enum Look { TREE, ROCK, ORE, HERB, CARCASS }

@export var id: StringName
@export var display_name: String
@export var yield_item_id: StringName
@export var yield_quantity: int = 1
@export var respawn_seconds: float = 90.0
@export var look: Look = Look.TREE

@export_group("Profession")
## Gathering profession that works this node (Mining, Herbalism, Woodcutting,
## Skinning); empty = anyone, no XP.
@export var profession_id: StringName
## Minimum profession level to gather here.
@export var required_level: int = 1
## Profession XP for a successful gather (level bands as for recipes).
@export var gather_xp: int = 6

@export_group("Steps (Gathering 1.1)")
## Work steps until the node is exhausted (by resource type: Woodcutting 2-4,
## Mining 3-5, Herbalism 1-3, Skinning 2-3). yield_quantity and gather_xp are
## the node's fixed total budgets, spread over the steps.
@export var steps: int = 1
## Guaranteed units of yield_item_id on the last step - part of yield_quantity.
@export var completion_bonus: int = 1


## Budget rules of the gathering guarantee (empty = valid): a positive yield,
## at least one step, a completion bonus of at least 1, and room in the yield
## for the guaranteed first unit when there are two or more steps.
func budget_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if yield_quantity < 1:
		errors.append("resource node %s: yield must be at least 1" % id)
	if steps < 1:
		errors.append("resource node %s: needs at least one step" % id)
	var first := 1 if steps >= 2 else 0
	if completion_bonus < 1 or completion_bonus + first > yield_quantity:
		errors.append("resource node %s: yield %d cannot hold the completion bonus %d%s" % [id, yield_quantity, completion_bonus,
			" and the guaranteed first unit" if first > 0 else ""])
	return errors
