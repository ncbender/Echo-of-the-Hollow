class_name RestorationService
extends RefCounted
## Hybrid restoration of Haven's ruins. Stateless: stages live in
## WorldState.restoration. A restoration is atomic: everything is checked
## first, the costs are consumed once, then the stage switches (the world shows
## the restored building), its services apply (inventory capacity ...), the
## story hears of it and WorldState.restoration_changed makes the session write
## a milestone (critical) save.

const RUINED := &"ruined"
const RESTORED := &"restored"
const REVITALIZED := &"revitalized"
const UNAVAILABLE := "Restoration unavailable for now."


static func definition(character: Character, ruin_id: StringName) -> RuinDefinition:
	return character.database.ruins.get(ruin_id)


static func stage(character: Character, ruin_id: StringName) -> StringName:
	return character.world.restoration.get(ruin_id, RUINED)


static func is_restored(character: Character, ruin_id: StringName) -> bool:
	return stage(character, ruin_id) != RUINED


## "" if `ruin` can be restored now, otherwise the reason shown to the player.
static func restore_error(character: Character, ruin: RuinDefinition) -> String:
	if ruin == null:
		return "Unknown ruin."
	if is_restored(character, ruin.id):
		return "%s is already restored." % ruin.display_name
	if not ruin.restorable or not StoryCondition.check(ruin.condition, character):
		return UNAVAILABLE
	var missing := BaseBuilder.missing_items(character, ruin.costs)
	if not missing.is_empty():
		return "Missing: %s" % ", ".join(missing)
	return ""


## Restores `ruin`. Returns "" on success or the reason (then nothing changed).
static func restore(character: Character, ruin: RuinDefinition) -> String:
	var error := restore_error(character, ruin)
	if error != "":
		return error
	for cost in ruin.costs:
		character.inventory.remove_quantity(cost.item_id, cost.quantity)
	character.world.set_flag(ruin.restored_flag())
	character.world.set_restoration(ruin.id, RESTORED)   # requests the milestone save (written next frame)
	character.refresh_inventory_capacity()
	if ruin.event_id != &"":
		StoryService.notify(character, ruin.event_id)
	return ""


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
		for cost in ruin.costs:
			if not db.items.has(cost.item_id):
				errors.append("ruin %s costs unknown item %s" % [ruin.id, cost.item_id])
	return errors
