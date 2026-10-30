class_name RestorationService
extends RefCounted
## Hybrid restoration of Haven's ruins. Stateless: stages live in
## WorldState.restoration. Stages: ruined -> restored -> revitalized (the
## second step only where the ruin's data has revitalize_costs).
## Every step is atomic and names its target stage: everything is checked
## first (the target is exactly the next stage, story condition, materials),
## the costs are consumed once from the material plan, then the stage
## switches (the world shows it), its services apply (inventory capacity ...),
## the story hears of it and WorldState.restoration_changed makes the session
## write a milestone (critical) save. A repeated or stale request (double
## click) is refused and changes nothing - a stage is never skipped.
## Materials: the same plan as profession crafting (ProfessionService.material_plan):
## the bag and the Haven stash (bag first; UI Usability & Haven Crafting 1.0: in every
## stage of the Old Storehouse); shown, checked and consumed from one plan.

const RUINED := &"ruined"
const RESTORED := &"restored"
const REVITALIZED := &"revitalized"
const STAGES: Array[StringName] = [RUINED, RESTORED, REVITALIZED]
const UNAVAILABLE := "Restoration unavailable for now."


static func definition(character: Character, ruin_id: StringName) -> RuinDefinition:
	return character.database.ruins.get(ruin_id)


static func stage(character: Character, ruin_id: StringName) -> StringName:
	return character.world.restoration.get(ruin_id, RUINED)


static func is_restored(character: Character, ruin_id: StringName) -> bool:
	return stage(character, ruin_id) != RUINED


static func is_revitalized(character: Character, ruin_id: StringName) -> bool:
	return stage(character, ruin_id) == REVITALIZED


## The stage the next step leads to, or &"" when there is none (done, or the
## data offers no further step).
static func next_stage(character: Character, ruin: RuinDefinition) -> StringName:
	if ruin == null:
		return &""
	match stage(character, ruin.id):
		RUINED:
			return RESTORED
		RESTORED:
			return REVITALIZED if ruin.can_revitalize() else &""
	return &""


## Costs of the step that leads to `target`.
static func costs_for(ruin: RuinDefinition, target: StringName) -> Array[ItemCost]:
	if target == REVITALIZED:
		return ruin.revitalize_costs
	return ruin.costs


## True when restoring may draw on the Haven stash (bag first): the same rule as the
## Haven workstations. Restoring always happens at a ruin in Haven, so always true.
static func uses_stash(_character: Character) -> bool:
	return true


## The material plan of the step to `target` ({"plan", "missing"} as in
## ProfessionService.material_plan): display, check and consumption use it.
static func material_plan(character: Character, ruin: RuinDefinition, target: StringName) -> Dictionary:
	return ProfessionService.material_plan(character, costs_for(ruin, target), uses_stash(character))


## "" if `ruin` can advance to `target` now, otherwise the reason shown to the player.
static func advance_error(character: Character, ruin: RuinDefinition, target: StringName) -> String:
	if ruin == null:
		return "Unknown ruin."
	var current := stage(character, ruin.id)
	match target:
		RESTORED:
			if current != RUINED:
				return "%s is already restored." % ruin.display_name
		REVITALIZED:
			if current == REVITALIZED:
				return "%s is already revitalized." % ruin.display_name
			if current != RESTORED:
				return "Restore %s first." % ruin.display_name
			if not ruin.can_revitalize():
				return "%s cannot be revitalized." % ruin.display_name
		_:
			return "Unknown stage."
	if not ruin.restorable or not StoryCondition.check(ruin.condition, character):
		return UNAVAILABLE
	var missing: PackedStringArray = material_plan(character, ruin, target).missing
	if not missing.is_empty():
		return "Missing: %s" % ", ".join(missing)
	return ""


## Advances `ruin` to `target` (exactly the next stage). Returns "" on success
## or the reason (then nothing changed).
static func advance(character: Character, ruin: RuinDefinition, target: StringName) -> String:
	var error := advance_error(character, ruin, target)
	if error != "":
		return error
	ProfessionService.consume_plan(character, material_plan(character, ruin, target).plan)
	if target == RESTORED:
		character.world.set_flag(ruin.restored_flag())
	else:
		character.world.set_flag(ruin.revitalized_flag())
	character.world.set_restoration(ruin.id, target)   # requests the milestone save (written next frame)
	character.refresh_inventory_capacity()
	if target == RESTORED and ruin.event_id != &"":
		StoryService.notify(character, ruin.event_id)
	return ""


## "" if `ruin` can be restored now, otherwise the reason shown to the player.
static func restore_error(character: Character, ruin: RuinDefinition) -> String:
	return advance_error(character, ruin, RESTORED)


## Restores `ruin`. Returns "" on success or the reason (then nothing changed).
static func restore(character: Character, ruin: RuinDefinition) -> String:
	return advance(character, ruin, RESTORED)


## The building a restored ruin provides (null while ruined or without one).
static func building(character: Character, ruin_id: StringName) -> BuildingDefinition:
	var ruin := definition(character, ruin_id)
	if ruin == null or ruin.building_id == &"" or not is_restored(character, ruin_id):
		return null
	return character.database.buildings.get(ruin.building_id)


## Inventory slots granted by restored ruins (Old Storehouse).
static func capacity_bonus(character: Character) -> int:
	var bonus := 0
	for ruin_id: StringName in character.world.restoration:
		var restored := building(character, ruin_id)
		if restored != null:
			bonus += restored.inventory_capacity_bonus
	return bonus


static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	for ruin: RuinDefinition in db.ruins.values():
		if ruin.building_id != &"" and not db.buildings.has(ruin.building_id):
			errors.append("ruin %s provides unknown building %s" % [ruin.id, ruin.building_id])
		for cost in ruin.costs + ruin.revitalize_costs:
			if not db.items.has(cost.item_id):
				errors.append("ruin %s costs unknown item %s" % [ruin.id, cost.item_id])
			if cost.quantity < 1:
				errors.append("ruin %s: cost %s needs a positive quantity" % [ruin.id, cost.item_id])
		if ruin.can_revitalize() and not ruin.restorable:
			errors.append("ruin %s: revitalize costs on a ruin that cannot be restored" % ruin.id)
	return errors
