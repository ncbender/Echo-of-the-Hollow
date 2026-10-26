class_name ClassStationPanel
extends UiWindow
## Class station / character window (docs/CLASS_DESIGN.md): classes, talents,
## skills and mods, build presets and class quests in five pages.
## Opened with G at a class station (everything allowed) or with C anywhere
## (overview + learning talents; rearranging, respecs, presets, class changes
## and quests need a class station). Pure presentation over TalentService,
## SkillBook, PresetService, QuestService and Character.switch_class.

const PAGES := ["Classes", "Talents", "Skills", "Presets", "Quests"]
const FORM := SkillModDefinition.Slot.FORM
const RESONANCE := SkillModDefinition.Slot.RESONANCE

var character: Character
var station: ClassStation
var page: String = "Classes"

var _tabs: HBoxContainer
var _summary: Label
var _content: VBoxContainer
var _status: Label
var _trees: Array[TalentTreeView] = []


func _ready() -> void:
	set_title(tr("UI_CLASS_STATION"))
	set_close_text(tr("UI_CLOSE_CLASS"))
	_tabs = HBoxContainer.new()
	body.add_child(_tabs)
	for name in PAGES:
		var tab := Button.new()
		tab.name = "Tab%s" % name
		tab.text = tr("UI_PAGE_%s" % name.to_upper())   # stable localization keys
		tab.toggle_mode = true
		tab.pressed.connect(show_page.bind(name))
		_tabs.add_child(tab)
	_summary = UiTheme.label("", UiTheme.COLOR_ACCENT)
	body.add_child(_summary)
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN, 900)
	body.add_child(_status)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_content)


func open(target_character: Character, target_station: ClassStation, start_page: String = "") -> void:
	character = target_character
	station = target_station
	set_title(tr("UI_CLASS_STATION") if station != null else tr("UI_CHARACTER_WINDOW"))
	_status.text = "" if station != null else tr("UI_AWAY_FROM_STATION")
	_status.visible = _status.text != ""
	show()
	show_page(start_page if start_page != "" else page)


func at_station() -> bool:
	return station != null and station.player_inside


func _process(_delta: float) -> void:
	if visible and station != null and not station.player_inside:
		hide()


func show_page(name: String) -> void:
	page = name
	for tab: Button in _tabs.get_children():
		tab.button_pressed = tab.name == "Tab%s" % name
	rebuild()


## Rebuilds the current page (also called after every action).
func rebuild() -> void:
	if character == null:
		return
	_refresh_summary()
	for child in _content.get_children():
		_content.remove_child(child)   # detach now: rebuilt rows reuse their names
		child.queue_free()
	_trees.clear()
	match page:
		"Talents":
			_build_talents()
		"Skills":
			_build_skills()
		"Presets":
			_build_presets()
		"Quests":
			_build_quests()
		_:
			_build_classes()
	queue_fit()


func _refresh_summary() -> void:
	var classes := character.classes
	var class_id := classes.active_class_id
	var definition := classes.get_active_definition()
	var text := "%s  -  Level %d (%d / %d XP)" % [definition.display_name, classes.get_level(class_id),
		classes.get_xp(class_id), classes.xp_to_next(class_id)]
	if definition.resource != null:
		text += "  -  Resource: %s" % definition.resource.display_name
	if not definition.talent_tree_ids.is_empty():
		text += "  -  Talent points: %d free of %d" % [TalentService.points_available(character, class_id), TalentService.points_total(character, class_id)]
	if classes.in_trial():
		text += "  -  CLASS TRIAL (temporary)"
	_summary.text = text


func _say(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.visible = _status.text != ""
	rebuild()


func _station_button(text: String, action: Callable, enabled: bool = true, reason: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled or not at_station()
	button.tooltip_text = reason if reason != "" else ("" if at_station() else tr("UI_ONLY_AT_STATION"))
	button.pressed.connect(action)
	return button


# --- Classes --------------------------------------------------------------------

func _build_classes() -> void:
	_content.add_child(UiTheme.wrapped("Weapon mastery, inventory, crafting materials and the home base are shared by all classes. Each class has its own level, talents, skills, presets and equipment loadout.", UiTheme.COLOR_DIM, 900))
	var definitions: Array = character.database.classes.values()
	definitions.sort_custom(func(a: ClassDefinition, b: ClassDefinition) -> bool: return a.display_name < b.display_name)
	for definition: ClassDefinition in definitions:
		_content.add_child(_class_row(definition))


func _class_row(definition: ClassDefinition) -> Control:
	var classes := character.classes
	var row := HBoxContainer.new()
	var unlocked := classes.is_unlocked(definition.id)
	var active := classes.active_class_id == definition.id
	var info := "%s   Lv %d  (%d / %d XP)" % [definition.display_name, classes.get_level(definition.id),
		classes.get_xp(definition.id), classes.xp_to_next(definition.id)] if unlocked \
		else "%s   - %s" % [definition.display_name, _unlock_text(definition)]
	var label := UiTheme.label(info, UiTheme.COLOR_ACCENT if active else (UiTheme.COLOR_TEXT if unlocked else UiTheme.COLOR_DIM))
	label.custom_minimum_size = Vector2(620, 0)
	label.tooltip_text = definition.description
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	if active:
		var current := Button.new()
		current.text = "Active"
		current.disabled = true
		row.add_child(current)
	elif unlocked:
		var button := _station_button("Activate", func() -> void:
			_say(character.switch_class(definition.id, at_station()), "Now playing as %s." % definition.display_name))
		button.name = "Activate_%s" % definition.id
		row.add_child(button)
	else:
		var locked := Button.new()
		locked.text = "Locked"
		locked.disabled = true
		row.add_child(locked)
	return row


func _unlock_text(definition: ClassDefinition) -> String:
	if not definition.playable:
		return "coming later (class quest prepared)"
	if definition.id in character.database.rules.prologue_class_ids and not character.prologue.is_completed():
		return "try it in the prologue, then choose one starting class"
	return "locked: complete its class quest (Quests page)"


# --- Talents ----------------------------------------------------------------------

func _build_talents() -> void:
	var class_id := character.classes.active_class_id
	var trees := TalentService.trees_of(character.database, class_id)
	if trees.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no talent trees.", UiTheme.COLOR_DIM, 900))
		return
	var rules := character.database.rules.talent_rules()
	var info := "One talent point per class level from level %d (51 at level 60). Trees can be mixed freely; a tier opens when enough points are invested in the LOWER tiers of the same tree. A capstone (tier 7) needs 30 points in its tree. [A] active skill, [T] transformation." % rules.first_point_level
	_content.add_child(UiTheme.wrapped(info, UiTheme.COLOR_DIM, 900))
	var cost := TalentService.respec_cost(character, class_id)
	var respec_error := TalentService.can_respec(character, class_id, at_station())
	var respec := _station_button("Reset talents (%s)" % ("free" if cost == 0 else "%d gold" % cost), func() -> void:
		_say(TalentService.respec(character, class_id, at_station()), "Talents reset."), respec_error == "", respec_error)
	respec.name = "Respec"
	respec.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(respec)
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", UiTheme.GAP * 4)
	_content.add_child(row)
	for tree in trees:
		var view := TalentTreeView.new()
		view.name = "Tree_%s" % tree.id
		row.add_child(view)
		view.setup(character, class_id, tree)
		view.learn_requested.connect(_learn)
		_trees.append(view)


func _learn(node_id: StringName) -> void:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	_say(TalentService.learn(character, character.classes.active_class_id, node_id), "Learned %s." % (node.display_name if node else String(node_id)))


func tree_view(tree_id: StringName) -> TalentTreeView:
	for view in _trees:
		if view.tree.id == tree_id:
			return view
	return null


# --- Skills ---------------------------------------------------------------------

func _build_skills() -> void:
	var class_id := character.classes.active_class_id
	var build := character.builds.get_build(class_id)
	var available := SkillBook.available_skills(character, class_id)
	_content.add_child(UiTheme.heading(tr("UI_SKILL_SLOTS")))
	for index in build.slots.size():
		var row := HBoxContainer.new()
		row.add_child(UiTheme.label("[%s]" % SkillBar.KEYS[index], UiTheme.COLOR_ACCENT))
		var choice := OptionButton.new()
		choice.name = "Slot%d" % index
		choice.custom_minimum_size = Vector2(260, 0)
		choice.add_item("(empty)")
		choice.set_item_metadata(0, &"")
		for skill in available:
			choice.add_item(skill.display_name)
			choice.set_item_metadata(choice.item_count - 1, skill.id)
			if build.slots[index] == skill.id:
				choice.select(choice.item_count - 1)
		choice.disabled = not at_station()
		choice.tooltip_text = "" if at_station() else tr("UI_ONLY_AT_STATION")
		choice.item_selected.connect(func(item: int) -> void:
			_say(SkillBook.assign_slot(character, class_id, index, choice.get_item_metadata(item), at_station()), "Skill slots updated."))
		row.add_child(choice)
		_content.add_child(row)
	_content.add_child(UiTheme.heading(tr("UI_SKILLS_AND_MODS")))
	var skills: Array = character.database.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == class_id)
	skills.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return a.unlock_level < b.unlock_level if a.unlock_level != b.unlock_level else a.display_name < b.display_name)
	if skills.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no skills yet.", UiTheme.COLOR_DIM, 900))
	for skill: SkillDefinition in skills:
		_content.add_child(_skill_row(class_id, skill))


func _skill_row(class_id: StringName, skill: SkillDefinition) -> Control:
	var row := HBoxContainer.new()
	var available := SkillBook.is_skill_available(character, class_id, skill.id)
	var runtime := ClassRuntime.new()
	runtime.character = character
	var params := runtime.params_for(skill)
	var resource := character.classes.get_active_definition().resource
	var label := UiTheme.label("%s%s" % [skill.display_name, "" if available else "  (%s)" % SkillBook.unlock_text(character, skill)],
			skill.color.lightened(0.3) if available else UiTheme.COLOR_DIM)
	label.custom_minimum_size = Vector2(300, 0)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.tooltip_text = SkillText.skill(skill, params, resource.display_name if resource != null else "")
	row.add_child(label)
	if available and skill.allows_mods:
		row.add_child(_mod_choice(class_id, skill, FORM))
		row.add_child(_mod_choice(class_id, skill, RESONANCE))
	return row


func _mod_choice(class_id: StringName, skill: SkillDefinition, slot: SkillModDefinition.Slot) -> Control:
	var choice := OptionButton.new()
	choice.name = "%s_%s" % [skill.id, "form" if slot == FORM else "resonance"]
	choice.custom_minimum_size = Vector2(250, 0)
	choice.add_item("%s: none" % ("Form" if slot == FORM else "Resonance"))
	choice.set_item_metadata(0, &"")
	var current := character.builds.get_build(class_id).mod_of(skill.id, slot)
	var tips: PackedStringArray = []
	for mod in SkillBook.mods_for(character, skill.id, slot):
		var unlocked := SkillBook.is_mod_available(character, class_id, mod)
		choice.add_item(mod.display_name if unlocked else "%s (locked: %s)" % [mod.display_name, SkillBook.mod_unlock_text(mod)])
		var index := choice.item_count - 1
		choice.set_item_metadata(index, mod.id)
		choice.set_item_disabled(index, not unlocked)
		if mod.id == current:
			choice.select(index)
		tips.append(SkillText.mod(mod))
	choice.disabled = not at_station() or choice.item_count == 1
	choice.tooltip_text = "\n\n".join(tips) if not tips.is_empty() else "No modifications for this slot."
	choice.item_selected.connect(func(item: int) -> void:
		_say(SkillBook.set_mod(character, class_id, skill.id, slot, choice.get_item_metadata(item), at_station()), "Modification changed."))
	return choice


# --- Presets ----------------------------------------------------------------------

func _build_presets() -> void:
	var class_id := character.classes.active_class_id
	_content.add_child(UiTheme.wrapped("A preset stores talents, skill slots, modifications and this class's equipment references (never items themselves). Saving and renaming are free; activating is free at a class station unless the talents differ (then the normal reset cost applies).", UiTheme.COLOR_DIM, 900))
	if not character.classes.is_unlocked(class_id):
		_content.add_child(UiTheme.wrapped("Presets need an unlocked class (not available during a trial).", UiTheme.COLOR_WARN, 900))
		return
	for index in PresetService.slot_count(character):
		_content.add_child(_preset_row(class_id, index))


func _preset_row(class_id: StringName, index: int) -> Control:
	var preset := PresetService.get_preset(character, class_id, index)
	var row := HBoxContainer.new()
	row.name = "Preset%d" % index
	var name_edit := LineEdit.new()
	name_edit.name = "Name"
	name_edit.custom_minimum_size = Vector2(220, 0)
	name_edit.placeholder_text = "Preset %d" % (index + 1)
	name_edit.text = str(preset.get("name", ""))
	row.add_child(name_edit)
	var save := Button.new()
	save.name = "Save"
	save.text = "Save current"
	save.pressed.connect(func() -> void:
		_say(PresetService.save_preset(character, class_id, index, name_edit.text), "Preset saved."))
	row.add_child(save)
	if preset.is_empty():
		row.add_child(UiTheme.label("empty", UiTheme.COLOR_DIM))
		return row
	var rename := Button.new()
	rename.text = "Rename"
	rename.pressed.connect(func() -> void:
		_say(PresetService.rename_preset(character, class_id, index, name_edit.text), "Preset renamed."))
	row.add_child(rename)
	var errors := PresetService.validate(character, class_id, preset)
	var cost := PresetService.activation_cost(character, class_id, preset)
	var activate := _station_button("Activate (%s)" % ("free" if cost == 0 else "%d gold" % cost), func() -> void:
		_say(PresetService.activate(character, class_id, index, at_station()), "Preset activated."), errors.is_empty(), "\n".join(errors))
	activate.name = "Activate"
	row.add_child(activate)
	var delete := Button.new()
	delete.text = "Delete"
	delete.pressed.connect(func() -> void:
		_say(PresetService.delete_preset(character, class_id, index), "Preset deleted."))
	row.add_child(delete)
	if not errors.is_empty():
		row.add_child(UiTheme.label(errors[0], UiTheme.COLOR_ERROR))
	return row


# --- Quests -----------------------------------------------------------------------

func _build_quests() -> void:
	_content.add_child(UiTheme.wrapped("Classes you did not choose in the prologue - and later classes - are unlocked by their class quests. Take and turn them in at a class station.", UiTheme.COLOR_DIM, 900))
	for quest in QuestService.quests_for(character):
		_content.add_child(_quest_row(quest))


func _quest_row(quest: ClassQuestDefinition) -> Control:
	var box := VBoxContainer.new()
	box.name = "Quest_%s" % quest.id
	var state := character.quests.state(quest.id)
	var title := "%s  (%s)" % [quest.display_name, {"active": "active", "completed": "completed"}.get(state, "not taken")]
	box.add_child(UiTheme.label(title, UiTheme.COLOR_ACCENT if state == "active" else UiTheme.COLOR_TEXT))
	box.add_child(UiTheme.wrapped(quest.description, UiTheme.COLOR_DIM, 900))
	var lines: PackedStringArray = []
	for index in quest.objectives.size():
		lines.append(ObjectiveRules.text(quest.objectives[index], character.quests.progress(quest.id, index)))
	for cost in quest.deliveries:
		var item := character.database.get_item(cost.item_id)
		lines.append("Deliver %d x %s (you have %d)" % [cost.quantity, item.display_name if item else String(cost.item_id), character.inventory.count(cost.item_id)])
	box.add_child(UiTheme.wrapped("\n".join(lines), UiTheme.COLOR_TEXT, 900))
	var row := HBoxContainer.new()
	if state == "":
		var error := QuestService.can_start(character, quest.id)
		var start := _station_button("Take quest", func() -> void:
			_say(QuestService.start(character, quest.id), "Quest taken: %s." % quest.display_name), error == "", error)
		start.name = "Start"
		row.add_child(start)
	elif state == "active":
		var error := QuestService.can_turn_in(character, quest.id, at_station())
		var turn_in := _station_button("Turn in", func() -> void:
			_say(QuestService.turn_in(character, quest.id, at_station()), "Quest complete - class unlocked!"), error == "", error)
		turn_in.name = "TurnIn"
		row.add_child(turn_in)
	box.add_child(row)
	return box


## Flow rows (talent trees) as wide as all their children side by side; the
## window shrinks and stacks them only when the canvas is narrower.
func preferred_body_size() -> Vector2:
	var wanted := body.get_combined_minimum_size()
	for flow: HFlowContainer in _content.find_children("*", "HFlowContainer", false, false):
		var width := 0.0
		for child: Control in flow.get_children():
			width += child.get_combined_minimum_size().x
		width += flow.get_theme_constant(&"h_separation") * maxi(0, flow.get_child_count() - 1)
		wanted.x = maxf(wanted.x, width)
	return wanted
