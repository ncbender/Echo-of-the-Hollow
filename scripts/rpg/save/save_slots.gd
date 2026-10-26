class_name SaveSlots
extends RefCounted
## Save slot layout of one profile (docs/SAVE_SYSTEM.md, Save Foundation 1.1):
## five manual slots and three rotating autosaves, all derived from the
## session's save path, so tests (user://test_saves/...) never touch the
## player's saves (user://saves/...).
##   user://saves/slot_1.save.json ... slot_5   - manual (slot 1 = F6 / legacy path)
##   user://saves/autosave_1.save.json ... _3  - periodic + milestone autosaves
## For other paths: "<base>.save.json" is manual slot 1, "<base>.slot_N.save.json"
## and "<base>.autosave_N.save.json" the others.

const MANUAL_SLOTS := 5
const AUTO_SLOTS := 3
const SUFFIX := ".save.json"

enum Kind { MANUAL, AUTO }


static func _base(save_path: String) -> String:
	return save_path.trim_suffix(SUFFIX)


static func manual_path(save_path: String, slot: int) -> String:
	var base := _base(save_path)
	if base.ends_with("slot_1"):
		return base.trim_suffix("slot_1") + "slot_%d%s" % [slot, SUFFIX]
	return save_path if slot == 1 else "%s.slot_%d%s" % [base, slot, SUFFIX]


static func auto_path(save_path: String, slot: int) -> String:
	var base := _base(save_path)
	if base.ends_with("slot_1"):
		return base.trim_suffix("slot_1") + "autosave_%d%s" % [slot, SUFFIX]
	return "%s.autosave_%d%s" % [base, slot, SUFFIX]


static func all_paths(save_path: String) -> Array[String]:
	var result: Array[String] = []
	for slot in range(1, MANUAL_SLOTS + 1):
		result.append(manual_path(save_path, slot))
	for slot in range(1, AUTO_SLOTS + 1):
		result.append(auto_path(save_path, slot))
	return result


## Autosave slot to write next: an empty or unusable slot first, otherwise the
## oldest one. The newest valid autosave is never the target, so a failed write
## still leaves the two most recent good autosaves.
static func next_auto_slot(save_path: String) -> int:
	var oldest_slot := 1
	var oldest_time := INF
	for slot in range(1, AUTO_SLOTS + 1):
		var info := SaveSystem.read_info(auto_path(save_path, slot))
		if not info.valid:
			return slot
		if float(info.order) < oldest_time:
			oldest_time = float(info.order)
			oldest_slot = slot
	return oldest_slot


## Newest valid save of the profile (manual or auto), or {} when there is none.
static func latest(save_path: String) -> Dictionary:
	var best := {}
	for path in all_paths(save_path):
		var info := SaveSystem.read_info(path)
		if info.valid and (best.is_empty() or int(info.order) > int(best.order)):
			best = info
	return best
