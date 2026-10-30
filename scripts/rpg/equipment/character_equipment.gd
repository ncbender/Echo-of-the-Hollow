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
##
## Equipment Inventory Separation 1.0 (docs/EQUIPMENT_SYSTEM.md): an item in a slot of the
## ACTIVE class's loadout is located in that equipment slot and takes no bag slot
## (Inventory.equipped_check -> in_equipment). Items of inactive loadouts stay bag items.
## Equip, unequip, presets and class switches are refused (nothing changes) when the
## items coming back would not fit into the bag; a direct swap reuses the freed slot.

## Emitted after any loadout change (stats, effects and weapon must refresh).
signal changed

var _db: GameDatabase
var _inventory: Inventory
var _classes: CharacterClasses
var _loadouts: Dictionary = {}   # class id -> Loadout
## Temporary loadout of a prologue trial class (never saved, see begin_trial).
var _trial_loadout: Loadout
## Instance ids unequipped as a side effect of the last equip() call.
var last_displaced: Array[String] = []
## The real class during a trial: its loadout keeps deciding where items are located
## (the trial copy is temporary, so a trial never moves items into or out of the bag).
var _trial_source: StringName = &""

const BAG_FULL := "Your bag is full - make room first."


func _init(database: GameDatabase, inventory: Inventory, classes: CharacterClasses) -> void:
	_db = database
	_inventory = inventory
	_classes = classes
	_inventory.item_removed.connect(_on_item_removed)
	_inventory.equipped_check = in_equipment


func loadout_for(class_id: StringName) -> Loadout:
	if _trial_loadout != null and class_id == _classes.trial_class_id:
		return _trial_loadout
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


## True while the instance is located in an equipment slot (the active class's loadout,
## during a trial the real class's): such an item takes no bag slot.
func in_equipment(instance_id: String) -> bool:
	return instance_id != "" and _location_loadout().slot_of(instance_id) >= 0


func _location_loadout() -> Loadout:
	if _trial_loadout != null and _trial_source != &"":
		return loadout_for(_trial_source)
	return active_loadout()


## Bag slots in use if `class_id` were the active class (its loadout decides what is in
## equipment slots). Used to refuse a class switch that would overfill the bag.
func bag_slots_if_active(class_id: StringName) -> int:
	var now := _location_loadout()
	var then := loadout_for(class_id)
	var used := _inventory.used_slots()
	for instance_id in now.instance_ids():
		if then.slot_of(instance_id) < 0 and _inventory.has(instance_id):
			used += 1   # leaves its equipment slot -> back into the bag
	for instance_id in then.instance_ids():
		if now.slot_of(instance_id) < 0 and _inventory.has(instance_id):
			used -= 1   # goes into an equipment slot
	return used


## "" if switching the active class to `class_id` leaves the bag within its capacity
## (or no fuller than now), otherwise the reason.
func class_switch_error(class_id: StringName) -> String:
	var used := bag_slots_if_active(class_id)
	if used > _inventory.capacity and used > _inventory.used_slots():
		return "Your bag is too full to change class - free %d slot%s first." % [used - _inventory.capacity, "" if used - _inventory.capacity == 1 else "s"]
	return ""


## Keeps a loadout change only if the bag still fits: restores `before` (and returns the
## reason) when items coming back from equipment slots would overfill it. A change that
## does not make the bag fuller is always kept (an over-full old save never blocks).
func _keep_if_bag_fits(loadout: Loadout, before: Dictionary, used_before: int) -> String:
	var used := _inventory.used_slots()
	if _overfills(used, used_before):
		loadout.slots = before
		last_displaced.clear()
		return BAG_FULL
	return ""


## The bag rule of every loadout change: over capacity AND fuller than before (an over-full old save never blocks).
func _overfills(used: int, used_before: int) -> bool:
	return used > _inventory.capacity and used > used_before


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


## Slot for a quick equip (right click), predictable for the player:
## the first EMPTY allowed slot that accepts the item (Ring 1 before Ring 2,
## Main Hand for every weapon - there is exactly one weapon slot);
## if none is empty, the first allowed slot is replaced (Ring 1 / Main Hand).
## -1 if the item cannot be equipped by the class at all.
func quick_slot(item: ItemInstance, class_id: StringName = &"") -> int:
	var definition := _db.get_item(item.definition_id) if item != null else null
	if definition == null:
		return -1
	class_id = _class_or_active(class_id)
	var loadout := loadout_for(class_id)
	var fitting: Array[int] = []
	for slot: int in EquipSlot.allowed_slots(definition):
		if can_equip(item.instance_id, slot, class_id) == "":
			fitting.append(slot)
	if fitting.is_empty():
		return -1
	for slot in fitting:
		if loadout.get_id(slot) == "" and not (slot == EquipSlot.Slot.OFF_HAND and _holds_two_hander(loadout)):
			return slot
	return fitting[0]


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
	var before := loadout.slots.duplicate()
	var used_before := _inventory.used_slots()
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
	# 4. The new item frees its bag slot, displaced ones need one (a swap reuses it).
	var full := _keep_if_bag_fits(loadout, before, used_before)
	if full != "":
		return full
	changed.emit()
	return ""


## Empties `slot`; the item goes back into the bag - refused (still equipped) without room.
func unequip(slot: int, class_id: StringName = &"") -> String:
	var loadout := loadout_for(_class_or_active(class_id))
	if loadout.get_id(slot) == "":
		return "slot is empty"
	var before := loadout.slots.duplicate()
	var used_before := _inventory.used_slots()
	loadout.set_id(slot, "")
	var full := _keep_if_bag_fits(loadout, before, used_before)
	if full != "":
		return full
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


## Trial class loadout: a temporary COPY of the references of `source_class_id`
## (only items the trial class may use). No item is created or moved; the copy
## is dropped by end_trial() and never saved.
func begin_trial(class_id: StringName, source_class_id: StringName) -> void:
	_trial_loadout = null
	_trial_source = source_class_id
	var trial := Loadout.new()
	var source := loadout_for(source_class_id)
	for slot: int in source.slots:
		if can_equip(source.slots[slot], slot, class_id) == "":
			trial.set_id(slot, source.slots[slot])
	_trial_loadout = trial


func end_trial() -> void:
	_trial_loadout = null
	_trial_source = &""


## Replaces the loadout of `class_id` with `slots` (slot key -> instance id, a
## preset). All references are checked first; nothing changes on an error.
func apply_loadout(class_id: StringName, slots: Dictionary) -> String:
	var plan := _plan_loadout(class_id, slots)
	if plan.error != "":
		return plan.error
	var loadout := loadout_for(class_id)
	var before := loadout.slots.duplicate()
	var used_before := _inventory.used_slots()
	loadout.slots = (plan.target as Loadout).slots
	var full := _keep_if_bag_fits(loadout, before, used_before)
	if full != "":
		return full
	changed.emit()
	return ""


## Preset Activation Atomicity Fix 1.0: "" if apply_loadout(`class_id`, `slots`) would succeed now, else its
## reason - the same checks, and the bag measured in the real target state (items leaving equipment slots
## take bag slots, items going in free theirs); the loadout is restored before returning, nothing is emitted.
func loadout_error(class_id: StringName, slots: Dictionary) -> String:
	var plan := _plan_loadout(class_id, slots)
	if plan.error != "":
		return plan.error
	var loadout := loadout_for(class_id)
	var before := loadout.slots.duplicate()
	var used_before := _inventory.used_slots()
	loadout.slots = (plan.target as Loadout).slots
	var used := _inventory.used_slots()
	loadout.slots = before
	return BAG_FULL if _overfills(used, used_before) else ""


## Puts back a loadout state taken before apply_loadout (rollback of a preset activation whose later step
## failed): exactly the saved slot -> instance mapping, no checks, no item moves.
func restore_loadout(class_id: StringName, slots_before: Dictionary) -> void:
	loadout_for(class_id).slots = slots_before.duplicate()
	last_displaced.clear()
	changed.emit()


## The target loadout of a preset (`slots`: slot key -> instance id) for `class_id` and the first reason it
## cannot be applied: {target: Loadout, error: String}. Shared by apply_loadout and loadout_error.
func _plan_loadout(class_id: StringName, slots: Dictionary) -> Dictionary:
	var target := Loadout.new()
	var warnings: PackedStringArray = []
	target.from_dict(slots, warnings)
	if not warnings.is_empty():
		return {"target": target, "error": warnings[0]}
	# One weapon slot (Weapon Mastery 1.4): an older preset's off-hand weapon is left out.
	var off_item := _inventory.find(target.get_id(EquipSlot.Slot.OFF_HAND))
	var off_def := _db.get_item(off_item.definition_id) if off_item != null else null
	if off_def != null and off_def.is_weapon():
		target.set_id(EquipSlot.Slot.OFF_HAND, "")
	for slot: int in target.slots:
		var error := can_equip(target.slots[slot], slot, class_id)
		if error != "":
			return {"target": target, "error": error}
	if _holds_two_hander(target) and target.get_id(EquipSlot.Slot.OFF_HAND) != "":
		return {"target": target, "error": "A two-handed weapon leaves no room for an off-hand item."}
	var seen := {}
	for slot: int in target.slots:
		if seen.has(target.slots[slot]):
			return {"target": target, "error": "An item is used twice in the preset."}
		seen[target.slots[slot]] = true
	return {"target": target, "error": ""}
