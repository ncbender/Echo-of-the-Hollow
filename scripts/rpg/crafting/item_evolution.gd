class_name ItemEvolution
extends RefCounted
## Individual item XP for evolving items (design rules 14-16). Completely separate
## from weapon mastery: XP is stored on the item instance and only the main-hand
## item of the active loadout learns, from accepted hits on real enemies
## (training targets never count). Evolving itself is a crafting operation
## (CraftingOps.EVOLVE) with costs and, at mutation stages, a permanent choice.


## Awards item XP for one accepted player hit. Returns the XP granted.
static func grant_hit_xp(character: Character, hit: HitData) -> int:
	if hit == null or hit.target == null or not is_instance_valid(hit.target):
		return 0
	if hit.target.is_in_group(&"training_target") or not hit.target is Enemy:
		return 0
	var item := character.equipment.get_item(EquipSlot.Slot.MAIN_HAND)
	if item == null:
		return 0
	var definition := character.database.get_item(item.definition_id)
	var evolution := ItemStats.evolution_of(definition, character.database) if definition != null else null
	if evolution == null or item.evolution_stage() >= evolution.max_stage():
		return 0
	var amount := evolution.xp_per_hit
	if &"heavy" in hit.tags and &"finisher" in hit.tags:
		amount += evolution.xp_per_finisher
	_ensure_state(item)
	item.evolution["xp"] = item.evolution_xp() + amount
	return amount


## The stage the item can evolve into next (null when fully evolved / not evolving).
static func next_stage(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> EvolutionStage:
	var evolution := ItemStats.evolution_of(definition, db)
	if evolution == null:
		return null
	return evolution.get_stage(item.evolution_stage() + 1)


static func is_ready(item: ItemInstance, definition: ItemDefinition, db: GameDatabase) -> bool:
	var stage := next_stage(item, definition, db)
	return stage != null and item.evolution_xp() >= stage.xp_required


static func _ensure_state(item: ItemInstance) -> void:
	if not item.evolution.has("stage"):
		item.evolution["stage"] = 1
	if not item.evolution.has("xp"):
		item.evolution["xp"] = 0
	if not item.evolution.has("path"):
		item.evolution["path"] = ""
