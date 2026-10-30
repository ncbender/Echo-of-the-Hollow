class_name PresetService
extends RefCounted
## Build presets (docs/TALENT_SYSTEM.md): five slots per class, stored in the
## class's ClassBuild. A preset holds REFERENCES only - talents, skill slots,
## mods, equipment instance ids and free extra config - and never creates items.
## Costs: saving, renaming and equipment are free; activating at a class station
## is free unless the talent allocation differs (then the normal respec cost).

const KEYS := ["name", "talents", "slots", "mods", "equipment", "extra"]


static func slot_count(character: Character) -> int:
	return character.database.rules.talent_rules().preset_slots


static func get_preset(character: Character, class_id: StringName, index: int) -> Dictionary:
	var presets := character.builds.get_build(class_id).presets
	if index < 0 or index >= presets.size() or not presets[index] is Dictionary:
		return {}
	return presets[index]


## Stores the class's current build and loadout in slot `index` (free).
static func save_preset(character: Character, class_id: StringName, index: int, preset_name: String) -> String:
	if index < 0 or index >= slot_count(character):
		return "Invalid preset slot."
	if not character.classes.is_unlocked(class_id):
		return "Class not unlocked."
	if character.classes.in_trial():
		return "Not during a class trial."
	var build := character.builds.get_build(class_id)
	var snapshot := build.to_dict()
	var preset := {
		"name": preset_name.strip_edges() if preset_name.strip_edges() != "" else "Preset %d" % (index + 1),
		"talents": snapshot.talents,
		"slots": snapshot.slots,
		"mods": snapshot.mods,
		"equipment": character.equipment.loadout_for(class_id).to_dict(),
		"extra": {},
	}
	while build.presets.size() < slot_count(character):
		build.presets.append(null)
	build.presets[index] = preset
	character.builds.notify(class_id)
	return ""


static func rename_preset(character: Character, class_id: StringName, index: int, preset_name: String) -> String:
	var preset := get_preset(character, class_id, index)
	if preset.is_empty():
		return "Empty preset slot."
	if preset_name.strip_edges() == "":
		return "Name must not be empty."
	preset["name"] = preset_name.strip_edges()
	character.builds.notify(class_id)
	return ""


static func delete_preset(character: Character, class_id: StringName, index: int) -> String:
	if get_preset(character, class_id, index).is_empty():
		return "Empty preset slot."
	character.builds.get_build(class_id).presets[index] = null
	character.builds.notify(class_id)
	return ""


static func _talents_of(preset: Dictionary) -> Dictionary:
	var result := {}
	var raw: Variant = preset.get("talents", {})
	if raw is Dictionary:
		for key: String in raw:
			if int(raw[key]) > 0:
				result[StringName(key)] = int(raw[key])
	return result


static func same_talents(character: Character, class_id: StringName, preset: Dictionary) -> bool:
	return _talents_of(preset) == character.builds.get_build(class_id).talents


## Gold needed to activate: 0 for an identical talent allocation, else the respec cost.
static func activation_cost(character: Character, class_id: StringName, preset: Dictionary) -> int:
	return 0 if same_talents(character, class_id, preset) else TalentService.respec_cost(character, class_id)


## Every reason why `preset` cannot be activated now (empty = valid). Missing
## items are reported, never recreated. Preset Activation Atomicity Fix 1.0: also
## the loadout change itself (CharacterEquipment.loadout_error - the checks of
## apply_loadout, bag measured in the real target state), so activate() never
## starts a change that its equipment step would refuse.
static func validate(character: Character, class_id: StringName, preset: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var db := character.database
	if preset.is_empty():
		errors.append("Empty preset slot.")
		return errors
	if not character.classes.is_unlocked(class_id):
		errors.append("Class not unlocked.")
		return errors
	var talents := _talents_of(preset)
	errors.append_array(TalentService.validate_allocation(db, class_id, character.classes.get_level(class_id), talents))
	# Skills and mods are checked against a temporary build with the preset's talents.
	var probe := ClassBuild.new(class_id, db.rules.talent_rules().skill_slots)
	probe.from_dict(preset, PackedStringArray())
	probe.talents = talents
	var real := character.builds.get_build(class_id)
	probe.unlocked_skills = real.unlocked_skills
	probe.unlocked_mods = real.unlocked_mods
	var probe_character := _probe(character, class_id, probe)
	for skill_id in probe.slots:
		if skill_id != &"" and not SkillBook.is_skill_available(probe_character, class_id, skill_id):
			errors.append("Skill %s is not unlocked." % _skill_name(db, skill_id))
	for skill_id: StringName in probe.mods:
		for slot: SkillModDefinition.Slot in [SkillModDefinition.Slot.FORM, SkillModDefinition.Slot.RESONANCE]:
			var mod_id := probe.mod_of(skill_id, slot)
			if mod_id == &"":
				continue
			probe.set_mod(skill_id, slot, &"")
			var error := SkillBook.can_set_mod(probe_character, class_id, skill_id, slot, mod_id)
			probe.set_mod(skill_id, slot, mod_id)
			if error != "":
				errors.append("%s: %s" % [_skill_name(db, skill_id), error])
	var equipment: Variant = preset.get("equipment", {})
	var item_errors := errors.size()
	if equipment is Dictionary:
		for slot_key: String in equipment:
			var instance_id := str(equipment[slot_key])
			var slot := EquipSlot.from_key(slot_key)
			if character.stash.has(instance_id):
				errors.append("Item for %s is in the Haven stash - take it out to use this preset." % EquipSlot.display_name(slot) if slot >= 0 else "Item is in the Haven stash.")
			elif not character.inventory.has(instance_id):
				errors.append("Missing item for %s (it is no longer in the inventory)." % EquipSlot.display_name(slot) if slot >= 0 else "Missing item.")
			elif slot < 0 or character.equipment.can_equip(instance_id, slot, class_id) != "":
				errors.append("Item in %s cannot be equipped." % slot_key)
	if errors.size() == item_errors:   # every reference is fine: can the whole loadout be applied?
		var loadout_error := character.equipment.loadout_error(class_id, equipment if equipment is Dictionary else {})
		if loadout_error != "":
			errors.append(loadout_error)
	var cost := activation_cost(character, class_id, preset)
	var currency := db.rules.talent_rules().respec_currency_item
	if cost > 0 and character.inventory.count(currency) < cost:
		errors.append("Not enough gold for the talent change (%d needed)." % cost)
	return errors


## Activates preset `index` of `class_id` at a class station - all or nothing (Preset Activation Atomicity
## Fix 1.0): validate() checks everything first (talents, skills, mods, items, the loadout change with the bag in
## its target state, gold); nothing changes on a refusal. Then, in an order that can be undone: the loadout
## (apply_loadout, itself atomic), the respec cost if the talents differ (a failed payment restores the loadout),
## and last the in-memory build (talents, slots, mods only - cannot fail).
static func activate(character: Character, class_id: StringName, index: int, at_station: bool) -> String:
	if not at_station:
		return "Presets can only be activated at a class station."
	if character.classes.in_trial():
		return "Not during a class trial."
	var preset := get_preset(character, class_id, index)
	var errors := validate(character, class_id, preset)
	if not errors.is_empty():
		return errors[0]
	var build := character.builds.get_build(class_id)
	var talents := _talents_of(preset)
	var talents_change := talents != build.talents
	var cost := activation_cost(character, class_id, preset) if talents_change else 0
	var equipment: Dictionary = preset.get("equipment", {}) if preset.get("equipment") is Dictionary else {}
	var loadout_before := character.equipment.loadout_for(class_id).slots.duplicate()
	var error := character.equipment.apply_loadout(class_id, equipment)
	if error != "":
		return error   # apply_loadout changed nothing; nothing else has changed yet
	if cost > 0 and not character.inventory.remove_quantity(character.database.rules.talent_rules().respec_currency_item, cost):
		character.equipment.restore_loadout(class_id, loadout_before)
		return "Payment failed."
	# only what a preset holds (talents, Q/E/R/F, mods); the respec count, unlocks from other sources, presets
	# and extra stay (a whole from_dict used to reset them - the next reset was free again)
	var stored := ClassBuild.new(class_id, build.slots.size())
	stored.from_dict(preset, PackedStringArray())
	build.talents = talents
	build.slots = stored.slots
	build.mods = stored.mods
	if talents_change:
		build.respecs += 1
	SkillBook.sanitize(character, class_id)
	character.builds.notify(class_id)
	return ""


## Fake character view whose build for `class_id` is `build` (validation only).
static func _probe(character: Character, class_id: StringName, build: ClassBuild) -> Character:
	var probe := Character.new(character.database, character.id)
	probe.classes.from_dict(character.classes.to_dict(), PackedStringArray())
	probe.builds._builds[class_id] = build
	return probe


static func _skill_name(db: GameDatabase, skill_id: StringName) -> String:
	var skill: SkillDefinition = db.skills.get(skill_id)
	return skill.display_name if skill != null else String(skill_id)


## True if a saved build preset of any unlocked class lists `instance_id` in its
## equipment (presets reference bag items; Item Integrity protects them).
static func references_item(character: Character, instance_id: String) -> bool:
	for class_id in character.classes.unlocked_class_ids():
		if not character.builds.has_build(class_id):
			continue
		for preset: Variant in character.builds.get_build(class_id).presets:
			if preset is Dictionary and preset.get("equipment") is Dictionary and instance_id in (preset["equipment"] as Dictionary).values():
				return true
	return false
