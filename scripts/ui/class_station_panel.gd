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
const CONTENT_WIDTH := 900
const CLASS_CARD := Vector2(320, 104)
const CLASS_DETAILS_WIDTH := 480

var character: Character
var station: ClassStation
var page: String = "Classes"
## Class shown in the details area of the Classes page (default: the active one).
var selected_class: StringName

var _tabs: UiTabs
var _summary: HBoxContainer
var _content: VBoxContainer
var _status: Label
var _trees: Array[TalentTreeView] = []


func _ready() -> void:
	set_title(tr("UI_CLASS_STATION"))
	set_close_text(tr("UI_CLOSE_CLASS"))
	_tabs = UiTabs.new()
	for name in PAGES:
		_tabs.add_tab(name, tr("UI_PAGE_%s" % name.to_upper()))   # stable localization keys
	_tabs.tab_selected.connect(show_page)
	body.add_child(_tabs)
	_summary = HBoxContainer.new()
	_summary.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	body.add_child(_summary)
	_status = UiTheme.wrapped("", UiTheme.WARNING, CONTENT_WIDTH)
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
	_tabs.select(name)
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


## Header: active class, level bar, resource, free talent points (chips).
func _refresh_summary() -> void:
	for child in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	var classes := character.classes
	var class_id := classes.active_class_id
	var definition := classes.get_active_definition()
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override(&"separation", 2)
	name_box.add_child(UiTheme.heading(definition.display_name))
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.BRONZE)
	bar.custom_minimum_size.x = 220
	bar.max_value = maxi(1, classes.xp_to_next(class_id))
	bar.value = classes.get_xp(class_id)
	name_box.add_child(bar)
	_summary.add_child(name_box)
	_summary.add_child(_chip("Level %d" % classes.get_level(class_id), "%d / %d XP" % [classes.get_xp(class_id), classes.xp_to_next(class_id)]))
	if definition.resource != null:
		_summary.add_child(_chip(definition.resource.display_name, "class resource"))
	if not definition.talent_tree_ids.is_empty():
		_summary.add_child(_chip("%d free" % TalentService.points_available(character, class_id), "of %d talent points" % TalentService.points_total(character, class_id)))
	if classes.in_trial():
		_summary.add_child(_chip("Class trial", "temporary"))
	_summary.add_child(_chip("At a class station" if at_station() else "Away from a station", "changes allowed" if at_station() else "learning talents only"))


func _chip(value: String, caption: String) -> Control:
	var panel := UiTheme.card(&"InsetPanel")
	var box := panel.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", 0)
	box.add_child(UiTheme.styled(value, &"SubheadingLabel"))
	box.add_child(UiTheme.styled(caption, &"CaptionLabel"))
	return panel


func _say(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.add_theme_color_override(&"font_color", UiTheme.DANGER if error != "" else UiTheme.SUCCESS)
	_status.visible = _status.text != ""
	rebuild()


func _station_button(text: String, action: Callable, enabled: bool = true, reason: String = "", variation: StringName = &"") -> Button:
	var button := UiTheme.button(text, variation, action)
	button.disabled = not enabled or not at_station()
	button.tooltip_text = reason if reason != "" else ("" if at_station() else tr("UI_ONLY_AT_STATION"))
	return button


# --- Classes --------------------------------------------------------------------

## Compact cards (emblem, name, status, level, two short lines) on the left; the
## selected card's details (resource, playstyle, trees, requirements, Activate)
## on the right. Prepared classes (Guardian, Soulbinder) are listed as Locked.
func _build_classes() -> void:
	var intro := UiTheme.styled("Mastery, inventory, materials and Haven are shared. Each class keeps its own level, talents, skills, presets and loadout.", &"SmallLabel")
	intro.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
	_content.add_child(intro)
	var definitions := class_order()
	if not character.database.classes.has(selected_class):
		selected_class = character.classes.active_class_id
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	var grid := GridContainer.new()
	grid.name = "ClassCards"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	grid.add_theme_constant_override(&"v_separation", UiTheme.GAP * 2)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var group := ButtonGroup.new()
	for definition: ClassDefinition in definitions:
		grid.add_child(_class_card(definition, group))
	row.add_child(grid)
	row.add_child(_class_details(character.database.get_class_def(selected_class)))
	_content.add_child(row)


## Active first, then unlocked, then locked; prepared classes last.
func class_order() -> Array:
	var classes := character.classes
	var rank := func(d: ClassDefinition) -> int:
		if classes.active_class_id == d.id:
			return 0
		if not d.playable:
			return 3
		return 1 if classes.is_unlocked(d.id) else 2
	var definitions: Array = character.database.classes.values()
	definitions.sort_custom(func(a: ClassDefinition, b: ClassDefinition) -> bool:
		return rank.call(a) < rank.call(b) if rank.call(a) != rank.call(b) else a.display_name < b.display_name)
	return definitions


## "Active" / "Unlocked" / "Locked" (prepared classes are always Locked).
func class_status(definition: ClassDefinition) -> String:
	if character.classes.active_class_id == definition.id:
		return "Active"
	return "Unlocked" if definition.playable and character.classes.is_unlocked(definition.id) else "Locked"


func _status_color(status: String) -> Color:
	return {"Active": UiTheme.RESONANCE, "Unlocked": UiTheme.SUCCESS}.get(status, UiTheme.TEXT_MUTED)


func _class_card(definition: ClassDefinition, group: ButtonGroup) -> Control:
	var status := class_status(definition)
	var locked := status == "Locked"
	var card := Button.new()
	card.name = "Class_%s" % definition.id
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = definition.id == selected_class
	card.custom_minimum_size = CLASS_CARD
	card.pressed.connect(select_class.bind(definition.id))
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	inner.add_theme_constant_override(&"separation", UiTheme.GAP + 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var emblem := ClassEmblem.new().setup(definition, locked)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inner.add_child(emblem)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(text)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiTheme.styled(definition.display_name, &"SubheadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED if locked else UiTheme.PARCHMENT)
	head.add_child(title)
	var badge := UiTheme.styled(status.to_upper(), &"CaptionLabel")
	badge.name = "Status"
	badge.add_theme_color_override(&"font_color", _status_color(status))
	head.add_child(badge)
	text.add_child(head)
	var level := UiTheme.styled("Level %d" % character.classes.get_level(definition.id) if not locked else ("Not playable yet" if not definition.playable else "Not unlocked"), &"CaptionLabel")
	text.add_child(level)
	var line := UiTheme.styled(definition.tagline if definition.tagline != "" else definition.description, &"CaptionLabel")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 2
	line.custom_minimum_size = Vector2(CLASS_CARD.x - 92, 0)
	line.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY if not locked else UiTheme.TEXT_MUTED)
	text.add_child(line)
	for label: Control in inner.find_children("*", "Control", true, false):
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func select_class(class_id: StringName) -> void:
	selected_class = class_id
	rebuild()
	var card := _content.find_child("Class_%s" % class_id, true, false) as Control
	if card != null:
		card.grab_focus.call_deferred()   # keyboard users stay on the card they picked


## Details of the selected class, all read from data: resource, playstyle,
## talent trees, level, requirements (prologue rule, class quest state).
func _class_details(definition: ClassDefinition) -> Control:
	var classes := character.classes
	var status := class_status(definition)
	var panel := UiTheme.card(&"InsetPanel")
	panel.name = "ClassDetails"
	panel.custom_minimum_size = Vector2(CLASS_DETAILS_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := panel.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP + 4)
	head.add_child(ClassEmblem.new().setup(definition, status == "Locked", 56.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	names.add_child(UiTheme.heading(definition.display_name))
	var badge := UiTheme.styled(status.to_upper(), &"CaptionLabel")
	badge.add_theme_color_override(&"font_color", _status_color(status))
	names.add_child(badge)
	head.add_child(names)
	box.add_child(head)
	if status != "Locked":
		box.add_child(UiTheme.styled("Level %d  ·  %d / %d XP" % [classes.get_level(definition.id), classes.get_xp(definition.id), classes.xp_to_next(definition.id)], &"SmallLabel"))
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.BRONZE)
		bar.max_value = maxi(1, classes.xp_to_next(definition.id))
		bar.value = classes.get_xp(definition.id)
		box.add_child(bar)
	var text_width := CLASS_DETAILS_WIDTH - 32
	box.add_child(UiTheme.section("CLASS RESOURCE"))
	box.add_child(_small_wrapped(resource_text(definition.resource), UiTheme.TEXT_PRIMARY, text_width))
	box.add_child(UiTheme.section("PLAYSTYLE"))
	box.add_child(_small_wrapped(definition.description, UiTheme.TEXT_SECONDARY, text_width))
	box.add_child(UiTheme.section("TALENT TREES"))
	var trees := TalentService.trees_of(character.database, definition.id)
	var tree_names: PackedStringArray = []
	for tree in trees:
		tree_names.append(tree.display_name)
	box.add_child(_small_wrapped("  ·  ".join(tree_names) if not tree_names.is_empty() else "No talent trees.", UiTheme.TEXT_PRIMARY, text_width))
	if status == "Locked":
		box.add_child(UiTheme.section("REQUIREMENTS"))
		for requirement in requirements(definition):
			box.add_child(_small_wrapped("·  " + requirement, UiTheme.WARNING, text_width))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if status == "Active":
		var current := UiTheme.button("Active")
		current.name = "Active_%s" % definition.id
		current.disabled = true
		row.add_child(current)
	elif status == "Unlocked":
		var button := _station_button("Activate", func() -> void:
			_say(character.switch_class(definition.id, at_station()), "Now playing as %s." % definition.display_name), true, "", &"PrimaryButton")
		button.name = "Activate_%s" % definition.id
		row.add_child(button)
		if not at_station():
			row.add_child(UiTheme.styled("Change classes at the class station in Haven.", &"CaptionLabel"))
			row.move_child(row.get_child(1), 0)
	else:
		var locked := UiTheme.button("Locked")
		locked.disabled = true
		row.add_child(locked)
	box.add_child(row)
	return panel


func _small_wrapped(text: String, color: Color, width: float) -> Label:
	var label := UiTheme.wrapped(text, color, width)
	label.theme_type_variation = &"SmallLabel"
	return label


## The class resource in words, from its data (no per-class text).
static func resource_text(resource: ClassResourceDefinition) -> String:
	if resource == null:
		return "None."
	var parts: PackedStringArray = ["%s (max %d)" % [resource.display_name, roundi(resource.max_value)]]
	if resource.regen_per_second > 0.0:
		parts.append("regenerates %s per second" % _number(resource.regen_per_second))
	if resource.gain_per_hit_dealt > 0.0:
		parts.append("+%s per hit dealt" % _number(resource.gain_per_hit_dealt))
	if resource.gain_per_hit_taken > 0.0:
		parts.append("+%s per hit taken" % _number(resource.gain_per_hit_taken))
	if resource.gain_per_kill > 0.0:
		parts.append("+%s per kill" % _number(resource.gain_per_kill))
	return ", ".join(parts) + "."


static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Why a class is locked, from the class data, the prologue rules and its
## class quest (state and start condition).
func requirements(definition: ClassDefinition) -> PackedStringArray:
	var result: PackedStringArray = []
	if not definition.playable:
		result.append("Not playable in this version.")
	if definition.id in character.database.rules.prologue_class_ids and not character.prologue.is_completed():
		result.append("Walk its echo at the Whispering Stone, then choose one path.")
	for quest in QuestService.quests_for(character):
		if quest.class_id != definition.id:
			continue
		var state := character.quests.state(quest.id)
		if state == "active":
			result.append("Class quest \"%s\" in progress - turn it in at a class station." % quest.display_name)
		elif state == "":
			var reason := QuestService.can_start(character, quest.id)
			result.append("Class quest \"%s\"%s" % [quest.display_name, ": " + reason if reason != "" else " - take it on the Quests page."])
	if result.is_empty():
		result.append("Not unlocked yet.")
	return result


# --- Talents ----------------------------------------------------------------------

func _build_talents() -> void:
	var class_id := character.classes.active_class_id
	var trees := TalentService.trees_of(character.database, class_id)
	if trees.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no talent trees.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
		return
	var rules := character.database.rules.talent_rules()
	var info := "One talent point per class level from level %d. Trees can be mixed freely; a tier opens when enough points are invested in the LOWER tiers of the same tree. A capstone (tier 7) needs 30 points in its tree. [A] active skill, [T] transformation." % rules.first_point_level
	_content.add_child(UiTheme.wrapped(info, UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	for entry: Array in [["Learned", UiTheme.BRONZE], ["Available", UiTheme.RESONANCE], ["Locked", UiTheme.TEXT_MUTED]]:
		var legend := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = entry[1]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(UiTheme.styled(entry[0], &"SmallLabel"))
		top.add_child(legend)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var cost := TalentService.respec_cost(character, class_id)
	var respec_error := TalentService.can_respec(character, class_id, at_station())
	var respec := _station_button("Reset talents (%s)" % ("free" if cost == 0 else "%d gold" % cost), func() -> void:
		_say(TalentService.respec(character, class_id, at_station()), "Talents reset."), respec_error == "", respec_error, &"DangerButton")
	respec.name = "Respec"
	top.add_child(respec)
	_content.add_child(top)
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
	var runtime := ClassRuntime.new()
	runtime.character = character
	var resource := character.classes.get_active_definition().resource
	_content.add_child(UiTheme.section(tr("UI_SKILL_SLOTS")))
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	for index in build.slots.size():
		var card := UiTheme.card(&"CardPanel")
		card.custom_minimum_size = Vector2(210, 0)
		var box := card.get_node("Box") as VBoxContainer
		var head := HBoxContainer.new()
		head.add_child(UiTheme.key_chip(SkillBar.KEYS[index]))
		var skill: SkillDefinition = character.database.skills.get(build.slots[index])
		var title := UiTheme.label(skill.display_name if skill != null else "Empty", skill.color.lightened(0.3) if skill != null else UiTheme.TEXT_MUTED)
		head.add_child(title)
		box.add_child(head)
		if skill != null:
			var params := runtime.params_for(skill)
			box.add_child(UiTheme.styled("%s  ·  %s" % ["%d %s" % [roundi(params.cost), resource.display_name if resource != null else ""] if params.cost > 0.0 else "No cost",
				"%.1f s cooldown" % params.cooldown if params.cooldown > 0.0 else "no cooldown"], &"SmallLabel"))
		var choice := OptionButton.new()
		choice.name = "Slot%d" % index
		choice.add_item("(empty)")
		choice.set_item_metadata(0, &"")
		for candidate in available:
			choice.add_item(candidate.display_name)
			choice.set_item_metadata(choice.item_count - 1, candidate.id)
			if build.slots[index] == candidate.id:
				choice.select(choice.item_count - 1)
		choice.disabled = not at_station()
		choice.tooltip_text = "" if at_station() else tr("UI_ONLY_AT_STATION")
		choice.item_selected.connect(func(item: int) -> void:
			_say(SkillBook.assign_slot(character, class_id, index, choice.get_item_metadata(item), at_station()), "Skill slots updated."))
		box.add_child(choice)
		slots.add_child(card)
	_content.add_child(slots)
	_content.add_child(UiTheme.section(tr("UI_SKILLS_AND_MODS")))
	var skills: Array = character.database.skills.values().filter(func(s: SkillDefinition) -> bool: return s.class_id == class_id)
	skills.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		return a.unlock_level < b.unlock_level if a.unlock_level != b.unlock_level else a.display_name < b.display_name)
	if skills.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no skills yet.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
	for skill: SkillDefinition in skills:
		_content.add_child(_skill_row(class_id, skill, runtime))


func _skill_row(class_id: StringName, skill: SkillDefinition, runtime: ClassRuntime) -> Control:
	var available := SkillBook.is_skill_available(character, class_id, skill.id)
	var params := runtime.params_for(skill)
	var resource := character.classes.get_active_definition().resource
	var card := UiTheme.card(&"InsetPanel" if available else &"InsetPanel")
	card.name = "Skill_%s" % skill.id
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var name_label := UiTheme.label(skill.display_name, skill.color.lightened(0.3) if available else UiTheme.TEXT_MUTED)
	name_label.custom_minimum_size = Vector2(260, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.tooltip_text = SkillText.skill(skill, params, resource.display_name if resource != null else "")
	head.add_child(name_label)
	var meta := UiTheme.styled(("%s  ·  %s" % ["%d %s" % [roundi(params.cost), resource.display_name if resource != null else ""] if params.cost > 0.0 else "No cost",
		"%.1f s" % params.cooldown if params.cooldown > 0.0 else "no cooldown"]) if available else "Locked: %s" % SkillBook.unlock_text(character, skill), &"SmallLabel")
	if not available:
		meta.add_theme_color_override(&"font_color", UiTheme.WARNING)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(meta)
	if available and skill.allows_mods:
		head.add_child(_mod_choice(class_id, skill, FORM))
		head.add_child(_mod_choice(class_id, skill, RESONANCE))
	box.add_child(head)
	var description := UiTheme.wrapped(skill.description, UiTheme.TEXT_SECONDARY if available else UiTheme.TEXT_MUTED, CONTENT_WIDTH - 40)
	description.theme_type_variation = &"SmallLabel"
	box.add_child(description)
	return card


func _mod_choice(class_id: StringName, skill: SkillDefinition, slot: SkillModDefinition.Slot) -> Control:
	var choice := OptionButton.new()
	choice.name = "%s_%s" % [skill.id, "form" if slot == FORM else "resonance"]
	choice.custom_minimum_size = Vector2(230, 0)
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
	_content.add_child(UiTheme.wrapped("A preset stores talents, skill slots, modifications and this class's equipment references - never the items themselves. Saving and renaming are free; activating is free at a class station unless the talents differ (then the normal reset cost applies).", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
	if not character.classes.is_unlocked(class_id):
		_content.add_child(UiTheme.wrapped("Presets need an unlocked class (not available during a trial).", UiTheme.WARNING, CONTENT_WIDTH))
		return
	for index in PresetService.slot_count(character):
		_content.add_child(_preset_card(class_id, index))


func _preset_card(class_id: StringName, index: int) -> Control:
	var preset := PresetService.get_preset(character, class_id, index)
	var card := UiTheme.card(&"CardPanel" if not preset.is_empty() else &"InsetPanel")
	var box := card.get_node("Box") as VBoxContainer
	var row := HBoxContainer.new()
	row.name = "Preset%d" % index
	row.add_child(UiTheme.styled("%d" % (index + 1), &"SubheadingLabel"))
	var name_edit := LineEdit.new()
	name_edit.name = "Name"
	name_edit.custom_minimum_size = Vector2(220, 0)
	name_edit.placeholder_text = "Preset %d" % (index + 1)
	name_edit.text = str(preset.get("name", ""))
	row.add_child(name_edit)
	var save := UiTheme.button("Save current" if preset.is_empty() else "Overwrite with current", &"", func() -> void:
		_say(PresetService.save_preset(character, class_id, index, name_edit.text), "Preset saved."))
	save.name = "Save"
	row.add_child(save)
	box.add_child(row)
	if preset.is_empty():
		box.add_child(UiTheme.styled("Empty slot", &"CaptionLabel"))
		return card
	var rename := UiTheme.button("Rename", &"", func() -> void:
		_say(PresetService.rename_preset(character, class_id, index, name_edit.text), "Preset renamed."))
	row.add_child(rename)
	var errors := PresetService.validate(character, class_id, preset)
	var cost := PresetService.activation_cost(character, class_id, preset)
	var activate := _station_button("Activate (%s)" % ("free" if cost == 0 else "%d gold" % cost), func() -> void:
		_say(PresetService.activate(character, class_id, index, at_station()), "Preset activated."), errors.is_empty(), "\n".join(errors), &"PrimaryButton")
	activate.name = "Activate"
	row.add_child(activate)
	var delete := UiTheme.button("Delete", &"DangerButton", func() -> void: _ask_delete(class_id, index, str(preset.get("name", ""))))
	delete.name = "Delete"
	row.add_child(delete)
	# summary: talents, skills, equipment references (missing items flagged)
	var talents: Dictionary = preset.get("talents", {}) if preset.get("talents") is Dictionary else {}
	var points := 0
	for rank: Variant in talents.values():
		points += int(rank)
	var skills: PackedStringArray = []
	for skill_id: Variant in preset.get("slots", []):
		var skill: SkillDefinition = character.database.skills.get(StringName(str(skill_id)))
		skills.append(skill.display_name if skill != null else "-")
	var equipment: Dictionary = preset.get("equipment", {}) if preset.get("equipment") is Dictionary else {}
	box.add_child(UiTheme.styled("%d talent points  ·  Skills: %s  ·  %d equipment references" % [points, ", ".join(skills), equipment.size()], &"SmallLabel"))
	for error in errors:
		var line := UiTheme.wrapped("! " + error, UiTheme.DANGER, CONTENT_WIDTH - 40)
		line.theme_type_variation = &"SmallLabel"
		box.add_child(line)
	return card


func _ask_delete(class_id: StringName, index: int, preset_name: String) -> void:
	var hud := get_parent()
	while hud != null and not hud is GameHud:
		hud = hud.get_parent()
	var action := func() -> void: _say(PresetService.delete_preset(character, class_id, index), "Preset deleted.")
	if hud == null:
		action.call()
		return
	(hud as GameHud).confirm_dialog.ask("Delete preset?", "\"%s\" will be deleted. Items, talents and skills you have now are not affected." % (preset_name if preset_name != "" else "Preset %d" % (index + 1)), "Delete", action, true)


# --- Quests -----------------------------------------------------------------------

func _build_quests() -> void:
	_content.add_child(UiTheme.wrapped("Classes you did not choose at the Whispering Stone are unlocked by their class quests. Take and turn them in at a class station.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
	for quest in QuestService.quests_for(character).filter(func(q: ClassQuestDefinition) -> bool: return q.available):
		_content.add_child(_quest_row(quest))


func _quest_row(quest: ClassQuestDefinition) -> Control:
	var card := UiTheme.card(&"CardPanel")
	var box := VBoxContainer.new()
	box.name = "Quest_%s" % quest.id
	(card.get_node("Box") as VBoxContainer).add_child(box)
	var state := character.quests.state(quest.id)
	var head := HBoxContainer.new()
	var title := UiTheme.styled(quest.display_name, &"SubheadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var badge := UiTheme.styled({"active": "ACTIVE", "completed": "COMPLETED"}.get(state, "NOT TAKEN"), &"CaptionLabel")
	badge.add_theme_color_override(&"font_color", UiTheme.RESONANCE if state == "active" else (UiTheme.SUCCESS if state == "completed" else UiTheme.TEXT_MUTED))
	head.add_child(badge)
	box.add_child(head)
	box.add_child(UiTheme.wrapped(quest.description, UiTheme.TEXT_SECONDARY, CONTENT_WIDTH - 40))
	for index in quest.objectives.size():
		box.add_child(UiTheme.styled("·  " + ObjectiveRules.text(quest.objectives[index], character.quests.progress(quest.id, index)), &"SmallLabel"))
	for cost in quest.deliveries:
		var item := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		var line := UiTheme.styled("·  Deliver %d x %s (you have %d)" % [cost.quantity, item.display_name if item else String(cost.item_id), have], &"SmallLabel")
		line.add_theme_color_override(&"font_color", UiTheme.SUCCESS if have >= cost.quantity else UiTheme.TEXT_SECONDARY)
		box.add_child(line)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if state == "":
		var error := QuestService.can_start(character, quest.id)
		var start := _station_button("Take quest", func() -> void:
			_say(QuestService.start(character, quest.id), "Quest taken: %s." % quest.display_name), error == "", error, &"PrimaryButton")
		start.name = "Start"
		row.add_child(start)
	elif state == "active":
		var error := QuestService.can_turn_in(character, quest.id, at_station())
		var turn_in := _station_button("Turn in", func() -> void:
			_say(QuestService.turn_in(character, quest.id, at_station()), "Quest complete - class unlocked!"), error == "", error, &"PrimaryButton")
		turn_in.name = "TurnIn"
		row.add_child(turn_in)
	box.add_child(row)
	return card


## Flow rows (talent trees, class cards) as wide as all their children side by
## side; the window shrinks and stacks them only when the canvas is narrower.
func preferred_body_size() -> Vector2:
	var wanted := body.get_combined_minimum_size()
	for flow: HFlowContainer in _content.find_children("*", "HFlowContainer", false, false):
		var width := 0.0
		for child: Control in flow.get_children():
			width += child.get_combined_minimum_size().x
		width += flow.get_theme_constant(&"h_separation") * maxi(0, flow.get_child_count() - 1)
		wanted.x = maxf(wanted.x, width)
	return wanted
