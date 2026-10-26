class_name ClassBuild
extends RefCounted
## Class-specific build of one character (saved): talent ranks, the four skill
## slots, Form/Resonance mods per skill, extra unlocks (quests, bosses,
## exploration), respec count and build presets. Talent points themselves are
## derived from the class level and never stored.

const SLOT_KEYS := ["form", "resonance"]

var class_id: StringName
var talents: Dictionary = {}          # node id -> rank
var slots: Array[StringName] = []     # skill id per Q/E/R/F slot (&"" = empty)
var mods: Dictionary = {}             # skill id -> {"form": mod id, "resonance": mod id}
var unlocked_skills: Array[StringName] = []
var unlocked_mods: Array[StringName] = []
var respecs: int = 0
## Build presets (docs/TALENT_SYSTEM.md): Array of preset dictionaries or null.
var presets: Array = []
## Unknown saved keys of this build, written back unchanged.
var extra: Dictionary = {}


func _init(id: StringName = &"", slot_count: int = 4) -> void:
	class_id = id
	slots.resize(slot_count)
	slots.fill(&"")


func rank(node_id: StringName) -> int:
	return talents.get(node_id, 0)


func spent() -> int:
	var total := 0
	for node_id: StringName in talents:
		total += talents[node_id]
	return total


func mod_of(skill_id: StringName, slot: SkillModDefinition.Slot) -> StringName:
	var entry: Dictionary = mods.get(skill_id, {})
	return entry.get(SLOT_KEYS[slot], &"")


func set_mod(skill_id: StringName, slot: SkillModDefinition.Slot, mod_id: StringName) -> void:
	var entry: Dictionary = mods.get(skill_id, {})
	if mod_id == &"":
		entry.erase(SLOT_KEYS[slot])
	else:
		entry[SLOT_KEYS[slot]] = mod_id
	if entry.is_empty():
		mods.erase(skill_id)
	else:
		mods[skill_id] = entry


func slot_of(skill_id: StringName) -> int:
	return slots.find(skill_id) if skill_id != &"" else -1


func copy() -> ClassBuild:
	var result := ClassBuild.new(class_id, slots.size())
	result.from_dict(to_dict(), PackedStringArray())
	return result


func to_dict() -> Dictionary:
	var data := extra.duplicate(true)
	var talent_data := {}
	for node_id: StringName in talents:
		talent_data[String(node_id)] = talents[node_id]
	var mod_data := {}
	for skill_id: StringName in mods:
		var entry := {}
		for key: String in mods[skill_id]:
			entry[key] = String(mods[skill_id][key])
		mod_data[String(skill_id)] = entry
	data["talents"] = talent_data
	data["slots"] = slots.map(func(id: StringName) -> String: return String(id))
	data["mods"] = mod_data
	data["unlocked_skills"] = unlocked_skills.map(func(id: StringName) -> String: return String(id))
	data["unlocked_mods"] = unlocked_mods.map(func(id: StringName) -> String: return String(id))
	data["respecs"] = respecs
	data["presets"] = presets.duplicate(true)
	return data


## Structural restore only; content validation (unknown nodes, ranks, points)
## is TalentService.sanitize_build's job, which needs the database and level.
func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	extra = data.duplicate(true)
	for key: String in ["talents", "slots", "mods", "unlocked_skills", "unlocked_mods", "respecs", "presets"]:
		extra.erase(key)
	talents.clear()
	var talent_data: Variant = data.get("talents", {})
	if talent_data is Dictionary:
		for key: String in talent_data:
			var value := int(talent_data[key])
			if value > 0:
				talents[StringName(key)] = value
	var slot_count := slots.size()
	slots.fill(&"")
	var slot_data: Variant = data.get("slots", [])
	if slot_data is Array:
		for index in mini(slot_count, slot_data.size()):
			slots[index] = StringName(str(slot_data[index]))
	mods.clear()
	var mod_data: Variant = data.get("mods", {})
	if mod_data is Dictionary:
		for skill_key: String in mod_data:
			if not mod_data[skill_key] is Dictionary:
				warnings.append("invalid mods of skill %s ignored" % skill_key)
				continue
			var entry := {}
			for slot_key: String in mod_data[skill_key]:
				if slot_key in SLOT_KEYS:
					entry[slot_key] = StringName(str(mod_data[skill_key][slot_key]))
			if not entry.is_empty():
				mods[StringName(skill_key)] = entry
	unlocked_skills = _names(data.get("unlocked_skills", []))
	unlocked_mods = _names(data.get("unlocked_mods", []))
	respecs = maxi(0, int(data.get("respecs", 0)))
	var preset_data: Variant = data.get("presets", [])
	presets = preset_data.duplicate(true) if preset_data is Array else []


static func _names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry: Variant in value:
			var name := StringName(str(entry))
			if name != &"" and not name in result:
				result.append(name)
	return result
