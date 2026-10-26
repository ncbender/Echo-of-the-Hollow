class_name StashService
extends RefCounted
## The Haven stash (docs/STASH.md). Ownership: every item instance lives in
## exactly one container - Character.inventory or Character.stash - and an
## equipment slot or build preset only REFERENCES an inventory item. The three
## stash categories are views of the one stash container, decided by the item
## definition (never stored, so an item can never be in two categories):
##   * Collection Vault: Unique, Set and Legendary items
##   * Equipment Chest:  every other equippable item
##   * Material Vault:   all other stackable resources (no slot limit)
## Gold (currency) and quest items never leave the inventory.
## Transfers are checked completely first and then applied (all or nothing);
## stacks merge only with stacks of the same definition that carry no
## per-instance state. Equipment keeps its instance id, affixes, essences,
## sockets, quality and evolution - it is moved, never copied.
## Stateless: the rules read the character and the data.

const EQUIPMENT := &"equipment"
const MATERIALS := &"materials"
const COLLECTION := &"collection"
const CATEGORIES: Array[StringName] = [EQUIPMENT, MATERIALS, COLLECTION]
## The stash container itself never refuses for slots - category limits apply.
const CONTAINER_CAPACITY := 1000000


## Category of a definition, or &"" if it cannot be stored at all.
static func category_of(definition: ItemDefinition) -> StringName:
	if definition == null or definition.is_currency or definition.category == ItemDefinition.Category.QUEST:
		return &""
	if definition.is_equippable():
		if definition.rarity in [ItemDefinition.Rarity.UNIQUE, ItemDefinition.Rarity.SET, ItemDefinition.Rarity.LEGENDARY]:
			return COLLECTION
		return EQUIPMENT
	return MATERIALS


static func display_name(category: StringName) -> String:
	return {EQUIPMENT: "Equipment Chest", MATERIALS: "Material Vault", COLLECTION: "Collection Vault"}.get(category, "Stash")


## Slot capacity of a category (-1 = no limit). Grows when a stash ruin is restored.
static func capacity(character: Character, category: StringName) -> int:
	var rules := character.database.rules
	var restored := is_upgraded(character)
	match category:
		EQUIPMENT:
			return rules.stash_equipment_slots + (rules.stash_restored_equipment_bonus if restored else 0)
		COLLECTION:
			return rules.stash_collection_slots + (rules.stash_restored_collection_bonus if restored else 0)
	return -1


## True when a ruin with stash access is restored (or later revitalized).
static func is_upgraded(character: Character) -> bool:
	for ruin: RuinDefinition in character.database.ruins.values():
		if ruin.stash_access and RestorationService.is_restored(character, ruin.id):
			return true
	return false


## Stored items of one category, in stash order.
static func items(character: Character, category: StringName) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in character.stash.items():
		if category_of(character.database.get_item(item.definition_id)) == category:
			result.append(item)
	return result


static func used(character: Character, category: StringName) -> int:
	return items(character, category).size()


## "" if the inventory item `instance_id` may go into the stash now, otherwise why not.
static func deposit_error(character: Character, instance_id: String) -> String:
	var item := character.inventory.find(instance_id)
	if item == null:
		return "That item is no longer in your bag."
	var definition := character.database.get_item(item.definition_id)
	var category := category_of(definition)
	if definition != null and definition.is_currency:
		return "Gold stays in your purse."
	if category == &"":
		return "%s stays with you (quest item)." % (definition.display_name if definition else "This item")
	if character.equipment.is_referenced(instance_id):
		return "%s is equipped - unequip it first." % definition.display_name
	if not _merges_completely(character.stash, item, definition):
		var limit := capacity(character, category)
		if limit >= 0 and used(character, category) >= limit:
			return "The %s is full (%d / %d)." % [display_name(category), used(character, category), limit]
	return ""


## Moves an inventory item into the stash. "" on success, otherwise the reason
## (nothing changed).
static func deposit(character: Character, instance_id: String) -> String:
	var error := deposit_error(character, instance_id)
	if error != "":
		return error
	return _move(character.inventory, character.stash, instance_id, character.database)


## "" if the stash item may go into the bag now, otherwise why not.
static func withdraw_error(character: Character, instance_id: String) -> String:
	var item := character.stash.find(instance_id)
	if item == null:
		return "That item is no longer in the stash."
	var definition := character.database.get_item(item.definition_id)
	if definition == null:
		return "Unknown item."
	if _plain(item, definition) and definition.is_stackable():
		if character.inventory.room_for(item.definition_id) < item.quantity:
			return "Not enough room in your bag for %d %s." % [item.quantity, definition.display_name]
	elif character.inventory.is_full():
		return "Your bag is full (%d / %d)." % [character.inventory.used_slots(), character.inventory.capacity]
	return ""


static func withdraw(character: Character, instance_id: String) -> String:
	var error := withdraw_error(character, instance_id)
	if error != "":
		return error
	return _move(character.stash, character.inventory, instance_id, character.database)


## Deposits every crafting material stack of the bag (Material Vault). Returns how many
## stacks moved and why others did not (each move is atomic on its own).
static func deposit_all_materials(character: Character) -> Dictionary:
	var moved := 0
	var refused: PackedStringArray = []
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		# crafting materials, components, essences - potions and other consumables stay in the bag
		if category_of(definition) != MATERIALS or definition.category != ItemDefinition.Category.MATERIAL:
			continue
		var error := deposit(character, item.instance_id)
		if error == "":
			moved += 1
		else:
			refused.append(error)
	return {"moved": moved, "refused": refused}


## Reorders the stash (presentation only - ids, stacks and contents stay):
## by category, then rarity (high first), then name.
static func sort(character: Character) -> void:
	var db := character.database
	character.stash.sort_items(func(a: ItemInstance, b: ItemInstance) -> bool:
		var da := db.get_item(a.definition_id)
		var dbb := db.get_item(b.definition_id)
		var ca := CATEGORIES.find(category_of(da))
		var cb := CATEGORIES.find(category_of(dbb))
		if ca != cb:
			return ca < cb
		if da.rarity != dbb.rarity:
			return da.rarity > dbb.rarity
		if da.display_name != dbb.display_name:
			return da.display_name < dbb.display_name
		return a.quantity > b.quantity)


## Moves `instance_id` from `source` to `target`. Plain stacks first fill the
## target's stacks of the same definition; what is left keeps its instance.
## Callers have checked the room; this re-checks and changes nothing on failure.
static func _move(source: Inventory, target: Inventory, instance_id: String, db: GameDatabase) -> String:
	var item := source.find(instance_id)
	if item == null:
		return "Item not found."
	var definition := db.get_item(item.definition_id)
	if definition != null and definition.is_stackable() and _plain(item, definition):
		var stacks: Array[ItemInstance] = []
		var room := 0
		for other in target.items():
			if other.definition_id == item.definition_id and _plain(other, definition) and other.quantity < definition.max_stack:
				stacks.append(other)
				room += definition.max_stack - other.quantity
		var left := item.quantity
		if left > room and target.is_full():   # the rest would need a free slot
			return "Not enough room."
		for other in stacks:
			if left <= 0:
				break
			var add := mini(left, definition.max_stack - other.quantity)
			target.set_quantity(other.instance_id, other.quantity + add)
			left -= add
		if left <= 0:
			source.remove_instance(instance_id)   # fully merged into existing stacks
			return ""
		if left != item.quantity:
			source.set_quantity(instance_id, left)
	return source.transfer_to(target, instance_id)


## A stack without per-instance state (only such stacks may merge).
static func _plain(item: ItemInstance, definition: ItemDefinition) -> bool:
	return definition != null and definition.is_stackable() and item.affixes.is_empty() and item.essences.is_empty() \
		and item.sockets.is_empty() and item.quality == 0 and item.material_id == &"" and item.evolution.is_empty() \
		and item.progress.is_empty()


## True if `item` would be merged into existing stash stacks without needing a slot.
static func _merges_completely(stash: Inventory, item: ItemInstance, definition: ItemDefinition) -> bool:
	if not _plain(item, definition):
		return false
	var room := 0
	for other in stash.items():
		if other.definition_id == item.definition_id and _plain(other, definition):
			room += definition.max_stack - other.quantity
	return room >= item.quantity


## Consistency of the whole ownership (tests, after loading): no instance in
## both containers, every loadout reference points into the inventory.
static func ownership_errors(character: Character) -> PackedStringArray:
	var errors: PackedStringArray = []
	errors.append_array(character.inventory.integrity_errors())
	errors.append_array(character.stash.integrity_errors())
	for item in character.stash.items():
		if character.inventory.has(item.instance_id):
			errors.append("instance %s in bag and stash" % item.instance_id)
		if character.equipment.is_referenced(item.instance_id):
			errors.append("stash item %s referenced by a loadout" % item.instance_id)
	errors.append_array(character.equipment.integrity_errors())
	return errors
