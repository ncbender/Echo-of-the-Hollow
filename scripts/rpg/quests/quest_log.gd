class_name QuestLog
extends RefCounted
## Class and story quest progress of a character (saved under "quests"):
## quest id -> {"state": "active" | "completed", "step": index of the current step
## (story quests; class quests have one step), "progress": {objective index: amount}}.
## Rules live in QuestService; this only stores data.

signal changed
## A story quest completed a step (`finished`: the whole quest). Milestone save.
signal story_progressed(quest_id: StringName, step: int, finished: bool)

var entries: Dictionary = {}


func state(quest_id: StringName) -> String:
	return entries.get(quest_id, {}).get("state", "")


func step(quest_id: StringName) -> int:
	return int(entries.get(quest_id, {}).get("step", 0))


func progress(quest_id: StringName, index: int) -> float:
	return float(entries.get(quest_id, {}).get("progress", {}).get(index, 0.0))


func active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for quest_id: StringName in entries:
		if state(quest_id) == "active":
			result.append(quest_id)
	return result


func to_dict() -> Dictionary:
	var data := {}
	for quest_id: StringName in entries:
		var entry: Dictionary = entries[quest_id]
		var progress_data := {}
		for index: int in entry.get("progress", {}):
			progress_data[str(index)] = entry.progress[index]
		data[String(quest_id)] = {"state": entry.state, "step": int(entry.get("step", 0)), "progress": progress_data}
	return data


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	entries.clear()
	for key: String in data:
		var entry: Variant = data[key]
		if not entry is Dictionary or not str(entry.get("state", "")) in ["active", "completed"]:
			warnings.append("invalid quest entry %s ignored" % key)
			continue
		var progress_data := {}
		var raw: Variant = entry.get("progress", {})
		if raw is Dictionary:
			for index_key: String in raw:
				progress_data[int(index_key)] = maxf(0.0, float(raw[index_key]))
		entries[StringName(key)] = {"state": str(entry.state), "step": maxi(0, int(entry.get("step", 0))), "progress": progress_data}
