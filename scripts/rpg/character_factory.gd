class_name CharacterFactory
extends RefCounted
## Creates new characters with their starting state.


static func create_new(database: GameDatabase) -> Character:
	var character := Character.new(database)
	for definition: ClassDefinition in database.classes.values():
		if definition.starts_unlocked:
			character.classes.unlock(definition.id)
	for entry in database.rules.starting_items:
		character.inventory.add_item(entry.item_id, entry.quantity)
	if not character.classes.set_active(database.rules.starting_class_id):
		var unlocked := character.classes.unlocked_class_ids()
		if not unlocked.is_empty():
			character.classes.set_active(unlocked[0])
	equip_starting_gear(character)
	StoryService.begin_prologue(character)
	return character


## Equips equippable starting items into still-empty slots of the active loadout.
static func equip_starting_gear(character: Character) -> void:
	for item in character.inventory.items():
		var slot := character.equipment.auto_slot(item)
		if slot >= 0 and character.equipment.get_item(slot) == null \
				and character.equipment.can_equip(item.instance_id, slot) == "":
			character.equipment.equip(item.instance_id, slot)
