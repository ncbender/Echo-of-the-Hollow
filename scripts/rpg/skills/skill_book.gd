class_name SkillBook
extends RefCounted
## Which skills and modifications a class has available, and the rules for the
## four skill slots and the two mod slots per skill (docs/SKILL_SYSTEM.md).
## Stateless; state lives in the class's ClassBuild.
## Sources of a skill: class level (unlock_level), an ACTIVE talent, or an
## explicit unlock (quest, boss ...). Sources of a mod: class level, a talent
## (unlocks_mods) or an explicit unlock.


static func available_skills(character: Character, class_id: StringName) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill: SkillDefinition in character.database.skills.values():
		if skill.class_id == class_id and is_skill_available(character, class_id, skill.id):
			result.append(skill)
	result.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return a.unlock_level < b.unlock_level if a.unlock_level != b.unlock_level else a.display_name < b.display_name)
	return result


static func is_skill_available(character: Character, class_id: StringName, skill_id: StringName) -> bool:
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	if skill == null or skill.class_id != class_id:
		return false
	if skill.unlock_level > 0 and character.classes.get_level(class_id) >= skill.unlock_level:
		return true
	var build := character.builds.get_build(class_id)
	if skill_id in build.unlocked_skills:
		return true
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node != null and build.talents[node_id] > 0 and node.unlocks_skill == skill_id:
			return true
	return false


## How the skill is unlocked (UI).
static func unlock_text(character: Character, skill: SkillDefinition) -> String:
	if skill.unlock_level > 0:
		return "Class level %d" % skill.unlock_level
	for node: TalentNodeDefinition in character.database.talent_nodes.values():
		if node.unlocks_skill == skill.id:
			return "Talent: %s" % node.display_name
	return "Special unlock"


static func is_mod_available(character: Character, class_id: StringName, mod: SkillModDefinition) -> bool:
	if mod == null:
		return false
	if mod.unlock_level > 0 and character.classes.get_level(class_id) >= mod.unlock_level:
		return true
	var build := character.builds.get_build(class_id)
	if mod.id in build.unlocked_mods:
		return true
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node != null and build.talents[node_id] > 0 and mod.id in node.unlocks_mods:
			return true
	return false


## Every mod that fits `skill_id` in `slot` (available or not), sorted by name.
static func mods_for(character: Character, skill_id: StringName, slot: SkillModDefinition.Slot) -> Array[SkillModDefinition]:
	var result: Array[SkillModDefinition] = []
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	for mod: SkillModDefinition in character.database.skill_mods.values():
		if mod.slot == slot and mod.fits(skill):
			result.append(mod)
	result.sort_custom(func(a: SkillModDefinition, b: SkillModDefinition) -> bool: return a.display_name < b.display_name)
	return result


static func mod_unlock_text(mod: SkillModDefinition) -> String:
	if mod.unlock_level > 0:
		return "Class level %d" % mod.unlock_level
	var source := String(mod.unlock_source)
	if source.begins_with("talent."):
		return "Talent"
	if source.begins_with("quest."):
		return "Class quest"
	if source.begins_with("boss."):
		return "Boss"
	if source.begins_with("explore."):
		return "Exploration"
	return "Special unlock"


## Transformative talent changes for `skill_id` (always on while learned).
static func talent_mods(character: Character, class_id: StringName, skill_id: StringName) -> Array[SkillModDefinition]:
	var result: Array[SkillModDefinition] = []
	var build := character.builds.get_build(class_id)
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node == null or build.talents[node_id] <= 0:
			continue
		for mod in node.skill_mods:
			if mod != null and skill != null and skill_id in mod.skill_ids:
				result.append(mod)
	return result


## Slotted (valid) mods followed by talent transformations: input for SkillParams.
static func cast_mods(character: Character, class_id: StringName, skill_id: StringName) -> Array[SkillModDefinition]:
	var result: Array[SkillModDefinition] = []
	var build := character.builds.get_build(class_id)
	for slot: SkillModDefinition.Slot in [SkillModDefinition.Slot.FORM, SkillModDefinition.Slot.RESONANCE]:
		var mod: SkillModDefinition = character.database.skill_mods.get(build.mod_of(skill_id, slot))
		if mod != null:
			result.append(mod)
	result.append_array(talent_mods(character, class_id, skill_id))
	return result


## Puts `skill_id` (&"" = clear) into Q/E/R/F slot `index`. Only at a class
## station; a skill already slotted elsewhere moves (never twice).
static func assign_slot(character: Character, class_id: StringName, index: int, skill_id: StringName, at_station: bool) -> String:
	if not at_station:
		return "Skills can only be rearranged at a class station."
	var build := character.builds.get_build(class_id)
	if index < 0 or index >= build.slots.size():
		return "Invalid skill slot."
	if skill_id != &"" and not is_skill_available(character, class_id, skill_id):
		return "Skill not unlocked."
	var previous := build.slot_of(skill_id)
	if previous >= 0:
		build.slots[previous] = build.slots[index]
	build.slots[index] = skill_id
	character.builds.notify(class_id)
	return ""


## "" if `mod_id` may go into `slot` of `skill_id` (&"" clears), else the reason.
static func can_set_mod(character: Character, class_id: StringName, skill_id: StringName,
		slot: SkillModDefinition.Slot, mod_id: StringName) -> String:
	if not is_skill_available(character, class_id, skill_id):
		return "Skill not unlocked."
	if mod_id == &"":
		return ""
	var mod: SkillModDefinition = character.database.skill_mods.get(mod_id)
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	if mod == null or not mod.fits(skill):
		return "This modification does not fit the skill."
	if mod.slot != slot:
		return "This is a %s modification." % mod.slot_name()
	if not is_mod_available(character, class_id, mod):
		return "Modification not unlocked (%s)." % mod_unlock_text(mod)
	var other_slot := SkillModDefinition.Slot.RESONANCE if slot == SkillModDefinition.Slot.FORM else SkillModDefinition.Slot.FORM
	var other: SkillModDefinition = character.database.skill_mods.get(character.builds.get_build(class_id).mod_of(skill_id, other_slot))
	if other != null and (other.id in mod.incompatible_with or mod.id in other.incompatible_with):
		return "%s cannot be combined with %s." % [mod.display_name, other.display_name]
	return ""


static func set_mod(character: Character, class_id: StringName, skill_id: StringName,
		slot: SkillModDefinition.Slot, mod_id: StringName, at_station: bool) -> String:
	if not at_station:
		return "Modifications can only be changed at a class station."
	var error := can_set_mod(character, class_id, skill_id, slot, mod_id)
	if error != "":
		return error
	character.builds.get_build(class_id).set_mod(skill_id, slot, mod_id)
	character.builds.notify(class_id)
	return ""


## Fills EMPTY slots with available skills that are not slotted yet (new skills
## are usable right away; rearranging needs a class station).
static func auto_fill(character: Character, class_id: StringName) -> void:
	var build := character.builds.get_build(class_id)
	for skill in available_skills(character, class_id):
		if build.slot_of(skill.id) >= 0:
			continue
		var empty := build.slots.find(&"")
		if empty < 0:
			return
		build.slots[empty] = skill.id


## Removes slotted skills and mods that are no longer available or valid (after
## a respec, data changes, loading). Returns what was removed.
static func sanitize(character: Character, class_id: StringName) -> PackedStringArray:
	var removed: PackedStringArray = []
	var build := character.builds.get_build(class_id)
	var seen := {}
	for index in build.slots.size():
		var skill_id := build.slots[index]
		if skill_id == &"":
			continue
		if seen.has(skill_id) or not is_skill_available(character, class_id, skill_id):
			removed.append("skill %s removed from slot %d" % [skill_id, index + 1])
			build.slots[index] = &""
		seen[skill_id] = true
	for skill_id: StringName in build.mods.keys():
		for slot: SkillModDefinition.Slot in [SkillModDefinition.Slot.FORM, SkillModDefinition.Slot.RESONANCE]:
			var mod_id := build.mod_of(skill_id, slot)
			if mod_id == &"":
				continue
			build.set_mod(skill_id, slot, &"")
			if can_set_mod(character, class_id, skill_id, slot, mod_id) == "":
				build.set_mod(skill_id, slot, mod_id)
			else:
				removed.append("mod %s removed from %s" % [mod_id, skill_id])
	return removed
