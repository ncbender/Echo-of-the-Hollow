class_name CharacterEquipment
extends RefCounted
## Class loadouts of one character and all equipment rules.
##
## Shared-item policy (docs/EQUIPMENT_SYSTEM.md): items physically live only in
## the character Inventory. A Loadout stores instance ids. The same instance may
## be referenced by the loadouts of several classes, but only the ACTIVE class's
## loadout is effective, and within one loadout an instance appears at most once.
## Displaced items (replaced slot, two-hander vs. off-hand) simply lose their
## reference and stay in the inventory - nothing can be lost or duplicated.

## Emitted after any loadout change (stats, effects and weapon must refresh).
signal changed

var _db: GameDatabase
var _inventory: Inventory
var _classes: CharacterClasses
var _loadouts: Dictionary = {}   # class id -> Loadout
## Instance ids unequipped as a side effect of the last equip() call.
var last_displaced: Array[String] = []


func _init(database: GameDatabase, inventory: Inventory, classes: CharacterClasses) -> void:
	_db = database
	_inventory = inventory
	_classes = classes
	_inventory.item_removed.connect(_on_item_removed)


func loadout_for(class_id: StringName) -> Loadout:
	if not _loadouts.has(class_id):
		_loadouts[class_id] = Loadout.new()
	return _loadouts[class_id]


func active_loadout() -> Loadout:
	return loadout_for(_classes.active_class_id)


func get_item(slot: int, class_id: StringName = &"") -> ItemInstance:
	var loadout := loadout_for(_class_or_active(class_id))
	return _inventory.find(loadout.get_id(slot))


## Items of the active loadout (the only effective ones).
func equipped_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for instance_id in active_loadout().instance_ids():
		var item := _inventory.find(instance_id)
		if item != null:
			result.append(item)
	return result


func is_equipped(instance_id: String, class_id: StringName = &"") -> bool:
	return loadout_for(_class_or_active(class_id)).slot_of(instance_id) >= 0


## True if any class loadout references the instance.
func is_referenced(instance_id: String) -> bool:
	for loadout: Loadout in _loadouts.values():
		if loadout.slot_of(instance_id) >= 0:
			return true
	return false


## Picks the slot for `item` when the caller does not choose one.
func auto_slot(item: ItemInstance, class_id: StringName = &"") -> int:
	var definition := _db.get_item(item.definition_id) if item != null else null
	if definition == null:
		return -1
	var allowed := EquipSlot.allowed_slots(definition)
	if allowed.is_empty():
		return -1
	var loadout := loadout_for(_class_or_active(class_id))
	if definition.slot_kind == ItemDefinition.SlotKind.ONE_HAND_WEAPON:
		return EquipSlot.Slot.MAIN_HAND
	for slot: int in allowed:
		if loadout.get_id(slot) == "":
			return slot
	return allowed[0]


## "" if `instance_id` may go into `slot` for `class_id`, otherwise the reason.
func can_equip(instance_id: String, slot: int, class_id: StringName = &"") -> String:
	class_id = _class_or_active(class_id)
	var item := _inventory.find(instance_id)
	if item == null:
		return "item is not in the inventory"
	var definition := _db.get_item(item.definition_id)
	if definition == null or not definition.is_equippable():
		return "item cannot be equipped"
	if not slot in EquipSlot.allowed_slots(definition):
		return "%s does not fit into %s" % [definition.display_name, EquipSlot.display_name(slot)]
	var class_def := _db.get_class_def(class_id)
	if class_def == null:
		return "no class"
	if not definition.required_class_ids.is_empty() and not class_id in definition.required_class_ids:
		return "%s cannot use %s" % [class_def.display_name, definition.display_name]
	if definition.is_weapon() and not class_def.allows_weapon_family(definition.weapon_family_id):
		return "%s cannot use this weapon family" % class_def.display_name
	if definition.slot_kind == ItemDefinition.SlotKind.SHIELD and not class_def.can_use_shields:
		return "%s cannot use shields" % class_def.display_name
	if definition.slot_kind == ItemDefinition.SlotKind.ONE_HAND_WEAPON and slot == EquipSlot.Slot.OFF_HAND \
			and not class_def.can_dual_wield:
		return "%s cannot dual wield" % class_def.display_name
	return ""


## Equips into `slot` (-1 = automatic) of the class loadout. Returns "" on success
## or the reason. Displaced items stay in the inventory (see `last_displaced`).
func equip(instance_id: String, slot: int = -1, class_id: StringName = &"") -> String:
	class_id = _class_or_active(class_id)
	last_displaced.clear()
	if slot < 0:
		slot = auto_slot(_inventory.find(instance_id), class_id)
	var error := can_equip(instance_id, slot, class_id)
	if error != "":
		return error
	var loadout := loadout_for(class_id)
	var definition := _db.get_item(_inventory.find(instance_id).definition_id)
	# 1. An instance appears at most once per loadout: moving frees its old slot.
	var previous_slot := loadout.slot_of(instance_id)
	if previous_slot == slot:
		return ""
	if previous_slot >= 0:
		loadout.set_id(previous_slot, "")
	# 2. Whatever occupied the target slot is unequipped (stays in the inventory).
	_displace(loadout, slot)
	# 3. Hand rules: a two-hander blocks the off hand and vice versa.
	if definition.slot_kind == ItemDefinition.SlotKind.TWO_HAND_WEAPON:
		_displace(loadout, EquipSlot.Slot.OFF_HAND)
	elif slot == EquipSlot.Slot.OFF_HAND and _holds_two_hander(loadout):
		_displace(loadout, EquipSlot.Slot.MAIN_HAND)
	loadout.set_id(slot, instance_id)
	changed.emit()
	return ""


func unequip(slot: int, class_id: StringName = &"") -> String:
	var loadout := loadout_for(_class_or_active(class_id))
	if loadout.get_id(slot) == "":
		return "slot is empty"
	loadout.set_id(slot, "")
	changed.emit()
	return ""


## Weapon family of the active main-hand weapon, or &"".
func main_hand_family() -> StringName:
	var item := get_item(EquipSlot.Slot.MAIN_HAND)
	if item == null:
		return &""
	var definition := _db.get_item(item.definition_id)
	return definition.weapon_family_id if definition != null and definition.is_weapon() else &""


## Copies another class's references into an EMPTY loadout, skipping items the
## new class may not use (used when a class is unlocked: convenient start gear).
func init_loadout_from(class_id: StringName, source_class_id: StringName) -> void:
	if not loadout_for(class_id).slots.is_empty():
		return
	var source := loadout_for(source_class_id)
	for slot: int in source.slots:
		if can_equip(source.slots[slot], slot, class_id) == "":
			loadout_for(class_id).set_id(slot, source.slots[slot])
	changed.emit()


## Invariants for tests and after loading. Empty = consistent.
func integrity_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for class_id: StringName in _loadouts:
		var loadout: Loadout = _loadouts[class_id]
		var seen := {}
		for slot: int in loadout.slots:
			var instance_id: String = loadout.slots[slot]
			if seen.has(instance_id):
				errors.append("%s: instance %s in two slots" % [class_id, instance_id])
			seen[instance_id] = true
			if not _inventory.has(instance_id):
				errors.append("%s: missing instance %s" % [class_id, instance_id])
			elif _db.get_class_def(class_id) != null and can_equip(instance_id, slot, class_id) != "":
				errors.append("%s: %s violates rules in %s" % [class_id, instance_id, EquipSlot.display_name(slot)])
		if _holds_two_hander(loadout) and loadout.get_id(EquipSlot.Slot.OFF_HAND) != "":
			errors.append("%s: two-hander together with an off-hand item" % class_id)
	return errors


func to_dict() -> Dictionary:
	var data := {}
	for class_id: StringName in _loadouts:
		if not _loadouts[class_id].slots.is_empty():
			data[String(class_id)] = _loadouts[class_id].to_dict()
	return data


## Restores loadouts. References to missing items or rule violations (e.g. data
## changed since saving) are dropped with a warning - the items themselves stay
## in the inventory, so nothing is lost.
func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	_loadouts.clear()
	for key: String in data:
		if not data[key] is Dictionary:
			warnings.append("invalid loadout %s ignored" % key)
			continue
		var loadout := Loadout.new()
		loadout.from_dict(data[key], warnings)
		_loadouts[StringName(key)] = loadout
	for class_id: StringName in _loadouts:
		var loadout: Loadout = _loadouts[class_id]
		var seen := {}
		for slot: int in loadout.slots.keys():
			var instance_id: String = loadout.slots[slot]
			var known_class := _db.get_class_def(class_id) != null
			var error := "duplicate reference" if seen.has(instance_id) \
				else ("missing item" if not _inventory.has(instance_id) \
				else (can_equip(instance_id, slot, class_id) if known_class else ""))
			if error != "":
				warnings.append("loadout %s/%s dropped: %s" % [class_id, EquipSlot.key_of(slot), error])
				loadout.set_id(slot, "")
			else:
				seen[instance_id] = true
		if _holds_two_hander(loadout) and loadout.get_id(EquipSlot.Slot.OFF_HAND) != "":
			warnings.append("loadout %s: off hand dropped (two-hander)" % class_id)
			loadout.set_id(EquipSlot.Slot.OFF_HAND, "")
	changed.emit()


func _displace(loadout: Loadout, slot: int) -> void:
	var instance_id := loadout.get_id(slot)
	if instance_id != "":
		loadout.set_id(slot, "")
		last_displaced.append(instance_id)


func _holds_two_hander(loadout: Loadout) -> bool:
	var item := _inventory.find(loadout.get_id(EquipSlot.Slot.MAIN_HAND))
	if item == null:
		return false
	var definition := _db.get_item(item.definition_id)
	return definition != null and definition.slot_kind == ItemDefinition.SlotKind.TWO_HAND_WEAPON


func _class_or_active(class_id: StringName) -> StringName:
	return class_id if class_id != &"" else _classes.active_class_id


func _on_item_removed(instance_id: String) -> void:
	var touched := false
	for loadout: Loadout in _loadouts.values():
		var slot := loadout.slot_of(instance_id)
		while slot >= 0:
			loadout.set_id(slot, "")
			touched = true
			slot = loadout.slot_of(instance_id)
	if touched:
		changed.emit()
