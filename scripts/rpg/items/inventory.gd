class_name Inventory
extends RefCounted
## Simple slot inventory: every ItemInstance (single item or stack) uses one slot -
## except currency stacks (ItemDefinition.is_currency, gold), which are kept here
## but take no bag slot.
## Guarantees: no negative or zero quantities, no stack above max_stack, no two
## instances with the same id, no unknown definitions. All multi-step operations
## are validated first and then applied, so they either fully succeed or change
## nothing. Equipped items stay in the inventory (equipment only references them).

signal changed
## Emitted after an instance left the inventory (equipment drops its references).
signal item_removed(instance_id: String)

## Upper bound for one currency addition (no slot limit applies).
const CURRENCY_ROOM := 1 << 30

var capacity: int = 40
var _db: GameDatabase
var _items: Array[ItemInstance] = []
var _by_id: Dictionary = {}


func _init(database: GameDatabase, slot_capacity: int = 40) -> void:
	_db = database
	capacity = slot_capacity


func items() -> Array[ItemInstance]:
	return _items.duplicate()


func used_slots() -> int:
	var used := 0
	for item in _items:
		if _takes_slot(item.definition_id):
			used += 1
	return used


func free_slots() -> int:
	return maxi(0, capacity - used_slots())


## False for currency: its stacks live in the inventory without a bag slot.
func _takes_slot(item_id: StringName) -> bool:
	var definition := _db.get_item(item_id)
	return definition == null or not definition.is_currency


func is_full() -> bool:
	return free_slots() == 0


func find(instance_id: String) -> ItemInstance:
	return _by_id.get(instance_id)


func has(instance_id: String) -> bool:
	return _by_id.has(instance_id)


func count(item_id: StringName) -> int:
	var total := 0
	for item in _items:
		if item.definition_id == item_id:
			total += item.quantity
	return total


## How many of `item_id` would fit right now (existing stacks first, then free slots).
func room_for(item_id: StringName) -> int:
	var definition := _db.get_item(item_id)
	if definition == null:
		return 0
	if definition.is_currency:
		return CURRENCY_ROOM   # new currency stacks need no slot
	var room := free_slots() * definition.max_stack
	if definition.is_stackable():
		for item in _items:
			if item.definition_id == item_id:
				room += definition.max_stack - item.quantity
	return room


## Adds `amount` of a definition: fills existing stacks, then creates new
## instances. All-or-nothing; returns the touched instances (empty on failure).
func add_item(item_id: StringName, amount: int = 1) -> Array[ItemInstance]:
	var touched: Array[ItemInstance] = []
	var definition := _db.get_item(item_id)
	if definition == null or amount <= 0 or room_for(item_id) < amount:
		return touched
	var left := amount
	if definition.is_stackable():
		for item in _items:
			if left == 0:
				break
			if item.definition_id == item_id and item.quantity < definition.max_stack:
				var moved := mini(left, definition.max_stack - item.quantity)
				item.quantity += moved
				left -= moved
				touched.append(item)
	while left > 0:
		var stack := mini(left, definition.max_stack)
		var item := ItemInstance.create(item_id, stack)
		if definition.crafting != null:
			item.item_level = definition.crafting.base_item_level
		_insert(item)
		touched.append(item)
		left -= stack
	changed.emit()
	return touched


## Adds an existing instance unchanged (transfer, loading). Keeps its identity.
## Returns "" on success or the reason for refusal.
func add_instance(item: ItemInstance) -> String:
	if item == null:
		return "no item"
	var definition := _db.get_item(item.definition_id)
	if definition == null:
		return "unknown item definition %s" % item.definition_id
	if item.instance_id == "" or has(item.instance_id):
		return "duplicate or missing instance id"
	if item.quantity <= 0 or item.quantity > definition.max_stack:
		return "invalid quantity %d" % item.quantity
	if is_full() and _takes_slot(item.definition_id):
		return "inventory full"
	_insert(item)
	changed.emit()
	return ""


## Removes a whole instance and returns it (null if not present).
func remove_instance(instance_id: String) -> ItemInstance:
	var item: ItemInstance = _by_id.get(instance_id)
	if item == null:
		return null
	_items.erase(item)
	_by_id.erase(instance_id)
	item_removed.emit(instance_id)
	changed.emit()
	return item


## Removes `amount` units of one instance. Fails (no change) if not enough.
func take(instance_id: String, amount: int) -> bool:
	var item: ItemInstance = _by_id.get(instance_id)
	if item == null or amount <= 0 or amount > item.quantity:
		return false
	if amount == item.quantity:
		remove_instance(instance_id)
	else:
		item.quantity -= amount
		changed.emit()
	return true


## Removes `amount` units of a definition across stacks (smallest first).
## All-or-nothing: fails without change if the inventory holds fewer.
func remove_quantity(item_id: StringName, amount: int) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	var stacks: Array[ItemInstance] = []
	for item in _items:
		if item.definition_id == item_id:
			stacks.append(item)
	stacks.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool: return a.quantity < b.quantity)
	var left := amount
	for item in stacks:
		var used := mini(left, item.quantity)
		take(item.instance_id, used)
		left -= used
		if left == 0:
			break
	return true


## Sets the quantity of a stack (1..max_stack).
func set_quantity(instance_id: String, amount: int) -> bool:
	var item: ItemInstance = _by_id.get(instance_id)
	if item == null:
		return false
	var definition := _db.get_item(item.definition_id)
	if amount < 1 or amount > definition.max_stack:
		return false
	item.quantity = amount
	changed.emit()
	return true


## Moves a whole instance to `target`, keeping its identity. Checked before
## anything changes: on failure both inventories are untouched (no loss, no copy).
func transfer_to(target: Inventory, instance_id: String) -> String:
	var item: ItemInstance = _by_id.get(instance_id)
	if item == null:
		return "item not found"
	if target == self:
		return "same inventory"
	if target.is_full() and _takes_slot(item.definition_id):
		return "target inventory full"
	if target.has(instance_id):
		return "target already holds this instance"
	remove_instance(instance_id)
	var error := target.add_instance(item)
	if error != "":
		_insert(item)   # cannot happen after the checks above; restore defensively
		changed.emit()
	return error


## Invariant check used by tests and after loading. Empty = consistent.
func integrity_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen := {}
	if used_slots() > capacity:
		errors.append("over capacity: %d / %d" % [used_slots(), capacity])
	for item in _items:
		if seen.has(item.instance_id):
			errors.append("duplicate instance id %s" % item.instance_id)
		seen[item.instance_id] = true
		var definition := _db.get_item(item.definition_id)
		if definition == null:
			errors.append("unknown definition %s" % item.definition_id)
		elif item.quantity < 1 or item.quantity > definition.max_stack:
			errors.append("invalid quantity %d for %s" % [item.quantity, item.instance_id])
	if seen.size() != _by_id.size():
		errors.append("index out of sync")
	return errors


func to_array() -> Array:
	var data := []
	for item in _items:
		data.append(item.to_dict())
	return data


## Restores items. Entries that cannot be restored (unknown definition, bad
## data, duplicates, over capacity) are returned raw in `orphans` so the save
## system can keep them instead of silently deleting player property.
func from_array(data: Array, warnings: PackedStringArray, orphans: Array) -> void:
	_items.clear()
	_by_id.clear()
	for entry: Variant in data:
		var item := ItemInstance.from_dict(entry)
		var error := "invalid item data" if item == null else add_instance(item)
		if error != "":
			warnings.append("item not restored (%s): %s" % [error, JSON.stringify(entry)])
			orphans.append(entry)
		else:
			ItemStats.sanitize(item, _db, warnings)   # crafting state vs. current data
	changed.emit()


func _insert(item: ItemInstance) -> void:
	_items.append(item)
	_by_id[item.instance_id] = item


## Reorders the items (presentation, e.g. "Sort" in the stash). Instances,
## ids and quantities are untouched.
func sort_items(compare: Callable) -> void:
	_items.sort_custom(compare)
	changed.emit()
