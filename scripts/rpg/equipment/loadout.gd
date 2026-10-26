class_name Loadout
extends RefCounted
## Equipment configuration of one class: slot -> item instance id.
## Holds references only; the items themselves live in the character inventory.

var slots: Dictionary = {}   # EquipSlot.Slot -> instance id (String)


func get_id(slot: int) -> String:
	return slots.get(slot, "")


func slot_of(instance_id: String) -> int:
	for slot: int in slots:
		if slots[slot] == instance_id:
			return slot
	return -1


func set_id(slot: int, instance_id: String) -> void:
	if instance_id == "":
		slots.erase(slot)
	else:
		slots[slot] = instance_id


func instance_ids() -> Array[String]:
	var result: Array[String] = []
	for slot: int in slots:
		result.append(slots[slot])
	return result


func to_dict() -> Dictionary:
	var data := {}
	for slot: int in slots:
		data[EquipSlot.key_of(slot)] = slots[slot]
	return data


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	slots.clear()
	for key: String in data:
		var slot := EquipSlot.from_key(key)
		if slot < 0:
			warnings.append("unknown equipment slot %s ignored" % key)
			continue
		slots[slot] = str(data[key])
