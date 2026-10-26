class_name ItemProtection
extends RefCounted
## Item Integrity 1.0 (docs/ITEM_SYSTEM.md): the player's favourite / lock
## marks and the protection rules that every destructive action (salvaging)
## must respect. Stateless; the marks live on the ItemInstance (saved).
## Marks exist only for single items (equipment, trinkets ...), never for
## stacks - a stack would otherwise stop merging.


## The owning container of `instance_id` (bag or Haven stash), or null.
static func container_of(character: Character, instance_id: String) -> Inventory:
	if character.inventory.has(instance_id):
		return character.inventory
	if character.stash.has(instance_id):
		return character.stash
	return null


static func can_mark(character: Character, item: ItemInstance) -> bool:
	var definition := character.database.get_item(item.definition_id) if item != null else null
	return definition != null and not definition.is_stackable() and not definition.is_currency


## Sets the favourite mark. "" on success, otherwise why not (nothing changed).
static func set_favorite(character: Character, instance_id: String, value: bool) -> String:
	return _mark(character, instance_id, &"favorite", value)


## Sets the lock mark. "" on success, otherwise why not (nothing changed).
static func set_locked(character: Character, instance_id: String, value: bool) -> String:
	return _mark(character, instance_id, &"locked", value)


static func _mark(character: Character, instance_id: String, field: StringName, value: bool) -> String:
	var container := container_of(character, instance_id)
	var item := container.find(instance_id) if container != null else null
	if item == null:
		return "That item is no longer there."
	if not can_mark(character, item):
		return "Only single items can be marked."
	if bool(item.get(field)) == value:
		return ""
	item.set(field, value)
	if container == character.inventory:
		character.notify_item_changed(instance_id)
	else:
		container.changed.emit()
	return ""


## Why the bag item `instance_id` must not be destroyed (salvaged), or "" when
## nothing protects it. Order: the strongest reason first.
static func destroy_block(character: Character, instance_id: String) -> String:
	var item := character.inventory.find(instance_id)
	if item == null:
		return "That item is no longer in your bag."
	var definition := character.database.get_item(item.definition_id)
	if definition == null:
		return "Unknown item."
	if definition.category == ItemDefinition.Category.QUEST:
		return "Quest items cannot be salvaged."
	if definition.rarity in [ItemDefinition.Rarity.UNIQUE, ItemDefinition.Rarity.SET]:
		return "Unique and set items cannot be salvaged."
	if character.equipment.is_referenced(instance_id):
		return "Equipped items cannot be salvaged."
	if PresetService.references_item(character, instance_id):
		return "This item is part of a build preset."
	if item.locked:
		return "This item is locked."
	if item.favorite:
		return "This item is a favourite."
	return ""


const ORIGIN_NAMES := {ItemInstance.ORIGIN_FOUND: "Found", ItemInstance.ORIGIN_CRAFTED: "Crafted",
	ItemInstance.ORIGIN_QUEST: "Quest reward", ItemInstance.ORIGIN_STARTING: "Starting gear",
	ItemInstance.ORIGIN_LEGACY: "Unknown (older save)"}


static func origin_name(origin: StringName) -> String:
	return ORIGIN_NAMES.get(origin, "Unknown")
