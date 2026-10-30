class_name ClassStationPanel
extends UiWindow
## Class station / character window (docs/CLASS_DESIGN.md): classes, talents,
## skills and mods, build presets, class quests, armour and weapon mastery.
## Opened with G at a class station (everything allowed) or with C anywhere
## (overview + learning talents; rearranging, respecs, presets, class changes
## and quests need a class station). Pure presentation over TalentService,
## SkillBook, PresetService, QuestService and Character.switch_class.

const PAGES := ["Classes", "Talents", "Skills", "Presets", "Quests", "Armor", "Weapons"]
## Weapons page: family order of the Weapon Mastery design.
const FORM := SkillModDefinition.Slot.FORM
const RESONANCE := SkillModDefinition.Slot.RESONANCE
const CONTENT_WIDTH := 900
## Main Window Layout Lock 1.0: two card columns + details fit the shared frame (1084 design px of body).
## Skills & Talents UX 2.0 Phase 6: class list and its cards.
const CLASS_LIST_WIDTH := 360
const CLASS_CARD_HEIGHT := 60
## Skills & Talents UX 2.0 Phase 7: mastery cards and the armor detail.
const ARMOR_CARD := Vector2(250, 84)   # Menu UX Polish 1.1: name, level, bar, worn share - compact, not stretched
const ARMOR_AREA_MIN_HEIGHT := 240
## Skills & Talents UX 2.0 Phase 2: specialization buttons; Menu UX Polish 1.0: the talent action row's button width.
const TREE_TAB_HEIGHT := 44
const TALENT_LEARN_WIDTH := 260
## Menu UX Polish 1.1: the block reason of the action row wraps at this width.
const TALENT_REASON_WIDTH := 330
## Skills & Talents UX 2.0 Phase 3: slot bar, skill list and detail panel.
const SKILL_SLOT_HEIGHT := 58
const SKILL_LIST_WIDTH := 340
const SKILL_ENTRY_HEIGHT := 56
const SKILL_AREA_MIN_HEIGHT := 240
## Skills & Talents UX 2.0 Phase 4: preset list and its entries.
const PRESET_LIST_WIDTH := 360
const PRESET_ENTRY_HEIGHT := 52
const PRESET_SAVE_WIDTH := 124
## Skills & Talents UX 2.0 Phase 5: class quest list and its entries.
const QUEST_LIST_WIDTH := 360
const QUEST_ENTRY_HEIGHT := 52
## Skills & Talents UX 2.0 Phase 1: the Weapons tab's combo grid and detail card.
const COMBO_COLUMNS := 5
const COMBO_CELL := Vector2(128, 158)   # 2x icon (80) + two name lines + the level line
const COMBO_DETAIL_WIDTH := 380
## The 40 x 40 combo art shown at whole multiples: 2x in the grid, 3x in the details (nearest, crisp).
const COMBO_ICON_GRID := 2
const COMBO_ICON_DETAIL := 3

var character: Character
var station: ClassStation
var page: String = "Classes"
## Class shown in the details area of the Classes page (default: the active one).
var selected_class: StringName
## Talents page: sizes, tier scale and the immediate node tooltip.
var talent_layout: TalentLayout
var talent_tooltip: TalentTooltip
var _tier_scale: TalentTierScale
var _tree_scroll: ScrollContainer
## True while the window gives its automatic first focus (no tooltip for that).
var _auto_focusing: bool = false
## Room the trees were last laid out for (layout_trees skips when unchanged).
var _tree_room: Vector2
## Node whose tooltip was open before a rebuild (shown again afterwards).
var _keep_tooltip: StringName
## Scroll position of the tree area kept over a rebuild (-1, -1 = none).
var _keep_scroll := Vector2i(-1, -1)
## Talents page: shown tree per class id, chosen node per tree id, keyboard focus back on Learn.
var _talent_tree: Dictionary = {}
var _talent_node: Dictionary = {}
var _focus_learn: bool = false
## Skills page: chosen skill per class id; the "All modifications" list opened (kept while the window lives).
var _skill_selected: Dictionary = {}
var _show_all_mods: bool = false
## Presets page: chosen preset slot per class id.
var _preset_selected: Dictionary = {}
## Quests page: the chosen class quest (character-wide, like the quests).
var _quest_selected: StringName = &""
## Armor page: the chosen mastery track (ItemDefinition.ArmorType, -1 = none chosen yet).
var _armor_selected: int = -1
## Weapons tab: the combo shown in the details, per weapon family (family id -> combo key).
var _weapon_combo: Dictionary = {}

var _tabs: BookTabs
var _summary: HFlowContainer
var _content: VBoxContainer
var _status: Label
var _trees: Array[TalentTreeView] = []


func _ready() -> void:
	set_title(tr("UI_CLASS_STATION"))
	set_close_text(tr("UI_CLOSE_CLASS"))
	# page registers on the left outer edge (book tabs) instead of a tab row
	_tabs = BookTabs.new()
	_tabs.name = "BookTabs"
	for name in PAGES:
		_tabs.add_tab(name, tr("UI_PAGE_%s" % name.to_upper()))   # stable localization keys
	_tabs.tab_selected.connect(show_page)
	set_side_tabs(_tabs)
	main_window = true   # Main Window Layout Lock 1.0: the shared frame (was: the whole canvas)
	_summary = HFlowContainer.new()   # one line; wraps at high UI scales
	_summary.name = "Header"
	_summary.add_theme_constant_override(&"h_separation", UiTheme.GAP + 4)
	_summary.resized.connect(_relayout_trees)
	body.add_child(_summary)
	# result messages in the bottom row next to Close: top level, so a message
	# never shifts the page (the talent trees would jump under the mouse)
	_status = UiTheme.label("", UiTheme.WARNING)
	_status.name = "Status"
	_status.top_level = true
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_status)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_content)
	talent_tooltip = TalentTooltip.new()
	talent_tooltip.name = "TalentTooltip"
	add_child(talent_tooltip)   # top level: not laid out by the window
	visibility_changed.connect(func() -> void:
		if not visible:
			_keep_tooltip = &""
			talent_tooltip.hide_tooltip())
	get_viewport().size_changed.connect(func() -> void:
		layout_trees.call_deferred()
		layout_skills.call_deferred()
		layout_presets.call_deferred()
		layout_quests.call_deferred()
		layout_classes.call_deferred()
		layout_armor.call_deferred())


func open(target_character: Character, target_station: ClassStation, start_page: String = "") -> void:
	character = target_character
	station = target_station
	set_title(tr("UI_CLASS_STATION") if station != null else tr("UI_CHARACTER_WINDOW"))
	set_close_text(tr("UI_CLOSE_CLASS") if station != null else tr("UI_CLOSE_TALENTS"))   # G at the station, T away
	_status.text = ""   # the station rules are the header status' tooltip now
	_status.visible = false
	show()
	show_page(start_page if start_page != "" else page)


func at_station() -> bool:
	return station != null and station.player_inside


func _process(_delta: float) -> void:
	if visible and station != null and not station.player_inside:
		hide()


func show_page(name: String) -> void:
	_keep_tooltip = &""   # a tooltip only returns after learning, never after switching pages
	_keep_scroll = Vector2i(-1, -1)   # a new page starts at the top
	page = name
	_tabs.select(name)
	rebuild()


## Rebuilds the current page (also called after every action).
func rebuild() -> void:
	if character == null:
		return
	if _tree_scroll != null and is_instance_valid(_tree_scroll):
		_keep_scroll = Vector2i(_tree_scroll.scroll_horizontal, _tree_scroll.scroll_vertical)
	if _keep_tooltip == &"" and talent_tooltip.visible:
		_keep_tooltip = talent_tooltip.node_id   # before the old nodes leave (their exit hides it)
	_refresh_summary()
	for child in _content.get_children():
		_content.remove_child(child)   # detach now: rebuilt rows reuse their names
		child.queue_free()
	_trees.clear()
	_tree_scroll = null
	_tier_scale = null
	talent_tooltip.hide_tooltip()   # its node is rebuilt
	match page:
		"Talents":
			_build_talents()
		"Skills":
			_build_skills()
		"Presets":
			_build_presets()
		"Quests":
			_build_quests()
		"Armor":
			_build_armor()
		"Weapons":
			_build_weapons()
		_:
			_build_classes()
	queue_fit()


## One slim header line: class · level (with a thin XP bar) · resource · free
## talent points · station status (rules in its tooltip) ... respec (Talents).
func _refresh_summary() -> void:
	for child in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	var classes := character.classes
	var class_id := classes.active_class_id
	var definition := classes.get_active_definition()
	var title := UiTheme.heading(definition.display_name)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary.add_child(title)
	var level := VBoxContainer.new()
	level.add_theme_constant_override(&"separation", 1)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level.tooltip_text = "%d / %d XP to the next level" % [classes.get_xp(class_id), classes.xp_to_next(class_id)]
	level.mouse_filter = Control.MOUSE_FILTER_PASS
	var level_text := UiTheme.styled("Lv. %d" % classes.get_level(class_id), &"SubheadingLabel")
	level_text.mouse_filter = Control.MOUSE_FILTER_PASS
	level.add_child(level_text)
	var bar := UiTheme.bar(3, UiTheme.BRONZE)
	bar.name = "XpBar"
	bar.custom_minimum_size.x = 72
	bar.max_value = maxi(1, classes.xp_to_next(class_id))
	bar.value = classes.get_xp(class_id)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	level.add_child(bar)
	_summary.add_child(_header_dot())
	_summary.add_child(level)
	# Menu UX Polish 1.1: the resource is on the Classes page; free talent points only on Talents; the station
	# binding is said at the actions it blocks (with the concrete reason), never as a page-wide status
	if page == "Talents" and not definition.talent_tree_ids.is_empty():
		var free := TalentService.points_available(character, class_id)
		_summary.add_child(_header_dot())
		var points := _header_text("%d Talent Point%s free" % [free, "" if free == 1 else "s"], UiTheme.RESONANCE if free > 0 else UiTheme.TEXT_SECONDARY,
			"%d of %d talent points free (one per class level from level %d)." % [free, TalentService.points_total(character, class_id), character.database.rules.talent_rules().first_point_level])
		points.name = "TalentPoints"
		_summary.add_child(points)
	if classes.in_trial():
		_summary.add_child(_header_dot())
		_summary.add_child(_header_text("Class Trial", UiTheme.WARNING, "A temporary trial: talents and skills reset when it ends."))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_child(spacer)
	if page == "Talents" and not definition.talent_tree_ids.is_empty():
		var cost := TalentService.respec_cost(character, class_id)
		var respec_error := TalentService.can_respec(character, class_id, at_station())
		var respec := _station_button("Reset talents (%s)" % ("free" if cost == 0 else "%d gold" % cost), func() -> void:
			_say(TalentService.respec(character, class_id, at_station()), "Talents reset."), respec_error == "", respec_error, &"DangerButton")
		respec.name = "Respec"
		_summary.add_child(respec)


func _header_text(text: String, color: Color, tooltip: String = "") -> Label:
	var label := UiTheme.styled(text, &"SubheadingLabel")
	label.add_theme_color_override(&"font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	return label


func _header_dot() -> Label:
	var dot := UiTheme.styled("·", &"SubheadingLabel")
	dot.add_theme_color_override(&"font_color", UiTheme.BRONZE_DIM)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot


## The result of an action. Playtest Corrections 1.0: the bottom row next to Close is gone (main menus have no Close
## button) - the message goes to the HUD's toasts (below the window, they never shift the page); `_status` keeps the
## last text (tests, a window without a HUD).
func _say(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.visible = false
	var hud := get_parent()
	while hud != null and not hud is GameHud:
		hud = hud.get_parent()
	if hud != null and _status.text != "":
		(hud as GameHud).toasts.push(_status.text, UiTheme.DANGER if error != "" else UiTheme.SUCCESS)
	rebuild()


func _station_button(text: String, action: Callable, enabled: bool = true, reason: String = "", variation: StringName = &"") -> Button:
	var button := UiTheme.button(text, variation, action)
	button.disabled = not enabled or not at_station()
	button.tooltip_text = reason if reason != "" else ("" if at_station() else tr("UI_ONLY_AT_STATION"))
	return button


# --- Classes --------------------------------------------------------------------

## Classes (Skills & Talents UX 2.0 Phase 6, docs/SKILLS_TALENTS_UX_2_0.md): "Which class do I play, and can I
## switch?" - compact class cards on the left (emblem, name, Active / Unlocked / Locked, level, the data's
## tagline; prepared classes stay hidden), the chosen class on the right: status, level and XP, resource,
## playstyle, specializations with the points in them, its gear (the class loadout and the state of every item)
## or what unlocks it, and the switch footer - "Switch to <class>" only when Character.class_switch_error says
## yes (station, trial, unlocked, room in the bag for the old gear), else the reason. A click on a card only
## selects; the switch is the button (Character.switch_class, unchanged and atomic).
func _build_classes() -> void:
	var definitions := class_order()
	if not character.database.classes.has(selected_class) or not definitions.any(func(d: ClassDefinition) -> bool: return d.id == selected_class):
		selected_class = character.classes.active_class_id
	var area := HBoxContainer.new()
	area.name = "ClassArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_content.add_child(area)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "ClassListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(CLASS_LIST_WIDTH, SKILL_AREA_MIN_HEIGHT)
	area.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.name = "ClassCards"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	list_scroll.add_child(list)
	var group := ButtonGroup.new()
	for definition: ClassDefinition in definitions:
		list.add_child(_class_card(definition, group))
	area.add_child(_class_details(character.database.get_class_def(selected_class)))
	layout_classes()
	layout_classes.call_deferred()


## Active first, then unlocked, then locked (only playable classes). The start class (Basic Adventurer,
## `starts_unlocked`) is no regular class offer: its card only shows while it is still the active class (before the
## prologue choice) - data, flags and rules unchanged (Skills & Talents UX 2.0 Phase 7).
func class_order() -> Array:
	var classes := character.classes
	var rank := func(d: ClassDefinition) -> int:
		if classes.active_class_id == d.id:
			return 0
		if not d.playable:
			return 3
		return 1 if classes.is_unlocked(d.id) else 2
	# prepared classes (Guardian, Soulbinder) stay hidden until they are playable
	var definitions: Array = character.database.classes.values().filter(func(d: ClassDefinition) -> bool:
		return d.playable and (not d.starts_unlocked or d.id == classes.active_class_id))
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


## One class card (CardButton toggle: chosen = gold card art, keyboard focus = cyan; the active class says
## "ACTIVE" in its own colour - chosen and active can be different cards): emblem, name, status, level, tagline.
func _class_card(definition: ClassDefinition, group: ButtonGroup) -> Control:
	var status := class_status(definition)
	var locked := status == "Locked"
	var card := Button.new()
	card.name = "Class_%s" % definition.id
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.button_group = group
	card.button_pressed = definition.id == selected_class
	card.custom_minimum_size = Vector2(0, CLASS_CARD_HEIGHT)
	card.tooltip_text = "%s - %s" % [definition.display_name, status]
	card.pressed.connect(select_class.bind(definition.id))
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	inner.add_theme_constant_override(&"separation", UiTheme.GAP + 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var emblem := ClassEmblem.new().setup(definition, locked, 40.0)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(emblem)
	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(text)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UiTheme.styled(definition.display_name, &"SmallLabel")
	title.name = "ClassName"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY if locked else UiTheme.PARCHMENT)
	head.add_child(title)
	var badge := UiTheme.styled(status.to_upper(), &"CaptionLabel")
	badge.name = "Status"
	badge.add_theme_color_override(&"font_color", _status_color(status))
	head.add_child(badge)
	text.add_child(head)
	# Menu UX Polish 1.1: the level only - the playstyle (cut off here before) is whole in the details
	if not locked:
		var line := UiTheme.styled("Lv %d" % character.classes.get_level(definition.id), &"CaptionLabel")
		line.name = "ClassLine"
		line.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
		text.add_child(line)
	card.tooltip_text = "%s - %s\n%s" % [definition.display_name, status, definition.tagline]
	for label: Control in inner.find_children("*", "Control", true, false):
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func select_class(class_id: StringName) -> void:
	selected_class = class_id
	rebuild()
	var card := _content.find_child("Class_%s" % class_id, true, false) as Control
	if card != null:
		card.grab_focus.call_deferred()   # keyboard users stay on the card they picked


## Details of the chosen class, all from data and the character: head (emblem, name, status - and which class is
## active when it is another one), level + XP, then in ClassDetailScroll the resource, playstyle, specializations
## (points invested), the class's gear or its unlock requirements; the switch footer.
func _class_details(definition: ClassDefinition) -> Control:
	var classes := character.classes
	var status := class_status(definition)
	var panel := UiTheme.card(&"CardPanel")
	panel.name = "ClassDetails"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = SKILL_AREA_MIN_HEIGHT
	var box := panel.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	var width := _class_detail_width() - 20
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP + 4)
	head.add_child(ClassEmblem.new().setup(definition, status == "Locked", 56.0))
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UiTheme.heading(definition.display_name))
	var active_name := classes.get_active_definition().display_name
	# one status word: which class is active is the list's ACTIVE badge (chosen = gold, active = badge)
	var badge := UiTheme.styled(status, &"SmallLabel")
	badge.name = "ClassState"
	badge.add_theme_color_override(&"font_color", _status_color(status))
	names.add_child(badge)
	if status != "Locked":
		var level := UiTheme.styled("Level %d / %d  ·  %d / %d XP" % [classes.get_level(definition.id), definition.max_level, classes.get_xp(definition.id), classes.xp_to_next(definition.id)], &"CaptionLabel")
		level.name = "ClassLevel"
		names.add_child(level)
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.BRONZE)
		bar.max_value = maxi(1, classes.xp_to_next(definition.id))
		bar.value = classes.get_xp(definition.id)
		names.add_child(bar)
	head.add_child(names)
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.name = "ClassDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	scroll.add_child(lines)
	lines.add_child(UiTheme.section("Resource"))
	var resource := _small_wrapped(resource_text(definition.resource), definition.resource.color.lerp(UiTheme.TEXT_PRIMARY, 0.4) if definition.resource != null else UiTheme.TEXT_PRIMARY, width)
	resource.name = "ClassResource"
	lines.add_child(resource)
	lines.add_child(UiTheme.section("Playstyle"))
	var trees := TalentService.trees_of(character.database, definition.id)
	var playstyle := _small_wrapped(playstyle_text(definition.description, trees), UiTheme.TEXT_SECONDARY, width)
	playstyle.name = "ClassPlaystyle"
	lines.add_child(playstyle)
	if not trees.is_empty():
		lines.add_child(UiTheme.section("Specializations"))
		var row := HFlowContainer.new()
		row.name = "ClassTrees"
		row.add_theme_constant_override(&"h_separation", UiTheme.GAP * 3)
		var talents := character.builds.get_build(definition.id).talents if character.builds.has_build(definition.id) else {}
		for tree in trees:
			var points := TalentService.points_in_tree(talents, tree)
			var label := UiTheme.styled("%s  %d" % [tree.display_name, points] if status != "Locked" else tree.display_name, &"SmallLabel")
			label.add_theme_color_override(&"font_color", tree.color.lerp(UiTheme.PARCHMENT, 0.35))
			row.add_child(label)
		lines.add_child(row)
	if status == "Locked":
		lines.add_child(UiTheme.section("Unlock"))
		for requirement in requirements(definition):
			var line := _small_wrapped("·  " + requirement, UiTheme.WARNING, width)
			line.name = "ClassRequirement"
			lines.add_child(line)
	else:
		lines.add_child(UiTheme.section("Gear of this class"))
		var gear: Dictionary = character.equipment.loadout_for(definition.id).to_dict()
		if gear.is_empty():
			var none := UiTheme.styled("Nothing equipped.", &"SmallLabel")
			none.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
			lines.add_child(none)
		for slot_key: String in gear:
			lines.add_child(_preset_item_row(definition.id, slot_key, str(gear[slot_key]), width))
	# switch footer (Menu UX Polish 1.1): only an unlocked, inactive class has one - the button when the unchanged
	# rules allow it, the concrete reason above it when they do not (what switching does: the button's tooltip).
	# The active class needs no sentence (its status says it), a locked one shows its Unlock section.
	if status != "Unlocked":
		return panel
	var error := character.class_switch_error(definition.id, at_station())
	var reason := error[0].to_upper() + error.substr(1) + ("" if error.ends_with(".") else ".") if error != "" else ""
	var button := _station_button("Switch to %s" % definition.display_name, func() -> void:
		_say(character.switch_class(definition.id, at_station()), "Now playing as %s." % definition.display_name), error == "", reason, &"PrimaryButton")
	button.name = "Activate_%s" % definition.id
	if reason == "":
		button.tooltip_text = "Switching makes %s's level, talents, skills and gear active; %s's stay saved." % [definition.display_name, active_name]
	else:
		var hint_label := UiTheme.wrapped(reason, UiTheme.WARNING, width)
		hint_label.name = "ClassSwitchHint"
		hint_label.theme_type_variation = &"MenuMetaLabel"
		box.add_child(hint_label)
	box.add_child(button)
	return panel


## The data's playstyle text without the sentences that only list the class's specializations - those stand
## directly below it (Menu UX Polish 1.1). Works from the tree names, for every class; the data stays as it is.
static func playstyle_text(description: String, trees: Array[TalentTreeDefinition]) -> String:
	if trees.is_empty():
		return description
	var kept: PackedStringArray = []
	for sentence in description.split(". ", false):
		var names_all := trees.all(func(tree: TalentTreeDefinition) -> bool: return sentence.contains(tree.display_name))
		if not names_all:
			kept.append(sentence.trim_suffix("."))
	return (". ".join(kept) + ".") if not kept.is_empty() else description


func _class_detail_width() -> float:
	return body_room().x - CLASS_LIST_WIDTH - UiTheme.GAP * 3 - 40


## Gives the class list and the details the height the window leaves (the window itself never scrolls).
func layout_classes() -> void:
	var list_scroll := _content.find_child("ClassListScroll", true, false) as Control
	if page != "Classes" or list_scroll == null or not is_inside_tree():
		return
	var area := list_scroll.get_parent() as Control
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	var height := maxf(SKILL_AREA_MIN_HEIGHT, floorf(body_room().y - others - 6.0))
	list_scroll.custom_minimum_size.y = height
	(area.get_node("ClassDetails") as Control).custom_minimum_size.y = height
	queue_fit()


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

## Talents (Skills & Talents UX 2.0 Phase 2, docs/SKILLS_TALENTS_UX_2_0.md): "How do I build my class?" -
## the three specialization buttons on top (name · points in the tree, active = gold card, focus = cyan), ONE
## big tree below (tier scale + TalentTreeView) over the whole width, and under it one compact action row for
## the chosen talent (TalentDetail: icon, name, kind / tier / rank / state, cost and free points or the concrete
## block reason, Learn / Upgrade). Menu UX Polish 1.0: no permanent text block - effects, ranks and requirements
## are in the TalentTooltip (hover / keyboard focus). A click on a node only selects it; only the action row's
## button spends a point (TalentService.learn). Shown tree and chosen node are kept per class while the window
## lives; the tree area scrolls on its own when the room is short (150 %).
func _build_talents() -> void:
	var class_id := character.classes.active_class_id
	var trees := TalentService.trees_of(character.database, class_id)
	if trees.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no talent trees.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
		return
	var tree := shown_tree()
	var build := character.builds.get_build(class_id)
	var tabs := HBoxContainer.new()
	tabs.name = "TreeTabs"
	tabs.add_theme_constant_override(&"separation", UiTheme.GAP)
	var group := ButtonGroup.new()
	for candidate in trees:
		var tab := Button.new()
		tab.name = "TreeTab_%s" % candidate.id
		tab.theme_type_variation = &"CardButton"
		tab.toggle_mode = true
		tab.button_group = group
		tab.text = "%s  ·  %d" % [candidate.display_name, TalentService.points_in_tree(build.talents, candidate)]
		tab.tooltip_text = "%s - %d points invested" % [candidate.display_name, TalentService.points_in_tree(build.talents, candidate)]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = TREE_TAB_HEIGHT
		tab.add_theme_color_override(&"font_color", candidate.color.lerp(UiTheme.TEXT_PRIMARY, 0.35))
		tab.add_theme_color_override(&"font_pressed_color", candidate.color.lerp(UiTheme.PARCHMENT, 0.5))
		tab.add_theme_color_override(&"font_hover_pressed_color", candidate.color.lerp(UiTheme.PARCHMENT, 0.5))
		tab.set_pressed_no_signal(candidate == tree)
		tab.pressed.connect(show_tree.bind(candidate.id))
		tabs.add_child(tab)
	tabs.add_child(_talent_help())   # Menu UX Polish 1.1: the legend is a compact help (hover / keyboard focus)
	_content.add_child(tabs)
	var area := HBoxContainer.new()
	area.name = "TalentArea"
	area.alignment = BoxContainer.ALIGNMENT_CENTER   # the tree centred in the whole width
	_content.add_child(area)
	_tree_scroll = ScrollContainer.new()
	_tree_scroll.name = "TreeScroll"
	_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	area.add_child(_tree_scroll)
	var row := HBoxContainer.new()
	row.name = "Tree"
	row.add_theme_constant_override(&"separation", 0)
	_tree_scroll.add_child(row)
	_tier_scale = TalentTierScale.new()
	_tier_scale.name = "TierScale"
	_tier_scale.setup(character.database.rules.talent_rules())
	_tier_scale.set_progress(build.talents, tree)
	row.add_child(_tier_scale)
	var view := TalentTreeView.new()
	view.name = "Tree_%s" % tree.id
	row.add_child(view)
	view.setup(character, class_id, tree)
	view.node_selected.connect(select_talent)
	view.node_hovered.connect(_on_talent_hovered.bind(view))
	_trees.append(view)
	var detail := PanelContainer.new()
	detail.name = "TalentDetail"
	detail.theme_type_variation = &"InsetPanel"
	var bar := HBoxContainer.new()
	bar.name = "Box"
	bar.add_theme_constant_override(&"separation", UiTheme.GAP + 4)
	detail.add_child(bar)
	_content.add_child(detail)
	select_talent(selected_talent())
	_tree_room = Vector2.ZERO
	layout_trees()
	layout_trees.call_deferred()
	_reshow_talent_tooltip.call_deferred()


## The tree shown for the active class: the last one chosen, else the one with the most points (first on a tie).
func shown_tree() -> TalentTreeDefinition:
	var class_id := character.classes.active_class_id
	var trees := TalentService.trees_of(character.database, class_id)
	if trees.is_empty():
		return null
	for tree in trees:
		if tree.id == _talent_tree.get(class_id, &""):
			return tree
	var talents := character.builds.get_build(class_id).talents
	var best := trees[0]
	for tree in trees:
		if TalentService.points_in_tree(talents, tree) > TalentService.points_in_tree(talents, best):
			best = tree
	return best


## Shows another tree of the active class (window, header and the other pages stay as they are).
func show_tree(tree_id: StringName) -> void:
	_talent_tree[character.classes.active_class_id] = tree_id
	_keep_scroll = Vector2i(-1, -1)   # a new tree starts at its top
	_keep_tooltip = &""
	if page == "Talents":
		rebuild()


## The chosen node of the shown tree: the last one chosen there, else its first node.
func selected_talent() -> StringName:
	var tree := shown_tree()
	if tree == null or tree.nodes.is_empty():
		return &""
	var chosen: StringName = _talent_node.get(tree.id, &"")
	return chosen if tree.get_node_def(chosen) != null else tree.nodes[0].id


## Chooses `node_id` (gold card) and shows it in the detail panel - never spends a point.
func select_talent(node_id: StringName) -> void:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	if node == null or _trees.is_empty():
		return
	_talent_node[node.tree_id] = node_id
	_trees[0].set_selected(node_id)
	_show_talent_detail(node)


## The action row (Menu UX Polish 1.0): icon, whole name, kind / tier / rank / state; on the right the cost and
## free points, or the concrete reason Learn is blocked (TalentTooltip.block_reason), and the one button that
## learns (Learn / Upgrade / Maxed - disabled with the reason when the rules say no). Effects, next rank and
## requirements are the TalentTooltip's (hover / focus on the node) - no permanent text block.
func _show_talent_detail(node: TalentNodeDefinition) -> void:
	var detail := _content.find_child("TalentDetail", true, false) as PanelContainer
	if detail == null:
		return
	var class_id := character.classes.active_class_id
	var tree: TalentTreeDefinition = character.database.talent_trees.get(node.tree_id)
	var rank := character.builds.get_build(class_id).rank(node.id)
	var error := TalentService.can_learn(character, class_id, node.id)
	var state := TalentTreeView.node_state(character, class_id, node)
	var box := detail.get_node("Box") as HBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var icon: Control = UiTheme.skill_icon(node.unlocks_skill, state == "Locked") if node.kind == TalentNodeDefinition.Kind.ACTIVE else null
	if icon == null:
		icon = Control.new()
		icon.custom_minimum_size = UiTheme.SKILL_ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(func() -> void:
			TalentTreeView.draw_glyph(icon, node.kind, icon.size * 0.5, 10.0, UiTheme.TEXT_MUTED if state == "Locked" else UiTheme.PARCHMENT))
	icon.name = "DetailIcon"
	box.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override(&"separation", 0)
	var title := UiTheme.styled(node.display_name, &"SubheadingLabel")
	title.name = "TalentTitle"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if tree != null:
		title.add_theme_color_override(&"font_color", tree.color.lerp(UiTheme.PARCHMENT, 0.35))
	names.add_child(title)
	var facts := VBoxContainer.new()   # two short lines: the row never gets wider than the page (Menu UX Polish 1.1)
	facts.add_theme_constant_override(&"separation", 0)
	var kind := UiTheme.styled("%s  ·  Tier %d%s" % [_talent_kind(node), node.tier, "  ·  Capstone" if node.is_capstone() else ""], &"SmallLabel")
	kind.name = "TalentKind"
	kind.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
	facts.add_child(kind)
	var rank_label := UiTheme.styled("Rank %d / %d  ·  %s" % [rank, node.max_rank, TalentTooltip.state_word(state)], &"SmallLabel")
	rank_label.name = "TalentRank"
	rank_label.add_theme_color_override(&"font_color", TalentTreeView.state_color(state))
	facts.add_child(rank_label)
	names.add_child(facts)
	box.add_child(names)
	# the cost, or the concrete reason Learn is blocked (wrapped in a fixed width: a long reason never widens
	# the page); the free points are in the header of this page
	var costs := VBoxContainer.new()
	costs.name = "Costs"
	costs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	costs.add_theme_constant_override(&"separation", 0)
	var reason := TalentTooltip.block_reason(character, class_id, node)
	var points := UiTheme.styled("Cost: 1 point per rank" if rank < node.max_rank else "Fully learned", &"SmallLabel")
	points.name = "FreePoints"
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	points.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
	costs.add_child(points)
	if reason != "":
		var blocked := UiTheme.wrapped(reason, UiTheme.WARNING, TALENT_REASON_WIDTH)
		blocked.name = "BlockReason"
		blocked.theme_type_variation = &"SmallLabel"
		blocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		costs.add_child(blocked)
	box.add_child(costs)
	var learn := UiTheme.button(_learn_text(rank, node.max_rank), &"PrimaryButton", _learn_selected.bind(node.id))
	learn.name = "LearnTalent"
	learn.custom_minimum_size.x = TALENT_LEARN_WIDTH
	learn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	learn.clip_text = true   # never wider than its place (the window must not scroll sideways)
	learn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	learn.disabled = error != ""
	learn.tooltip_text = error
	box.add_child(learn)
	if _focus_learn:
		_focus_learn = false
		learn.grab_focus.call_deferred()


static func _learn_text(rank: int, max_rank: int) -> String:
	if rank >= max_rank:
		return "Maxed"
	return "Learn" if rank == 0 else "Upgrade to rank %d" % (rank + 1)


static func _talent_kind(node: TalentNodeDefinition) -> String:
	return ["Passive", "Skill unlock", "Transformation"][node.kind]


## Menu UX Polish 1.1: the former permanent legend as a compact help ("?", hover or keyboard focus). Every state
## has its own mark on the node, never only a colour.
func _talent_help() -> HelpButton:
	var rules := character.database.rules.talent_rules()
	var thresholds: PackedStringArray = []
	for tier in range(1, TalentRules.TIERS + 1):
		thresholds.append("Tier %d: %d" % [tier, rules.tier_requirement(tier)])
	return HelpButton.make("\n".join([
		"# Node states",
		"+ mark, green: Available - learnable now.",
		"Bronze tile: Learned (rank shown). Double frame and diamond: Maxed.",
		"Padlock, muted: Locked - a requirement is missing (hover for which).",
		"No mark, \"0/n\": requirements met, but no free talent point.",
		"# Kinds",
		"Diamond: passive  ·  circle or skill art: unlocks a skill  ·  star: transformation.",
		"# Rules",
		"Points needed in lower tiers of the same tree - %s." % ", ".join(thresholds),
		"Lines join a skill and its direct upgrade.",
		"Click a talent to choose it; Learn below the tree spends the point."]), "TalentHelp")


## Sizes the tree from the room the window leaves above the action row (TalentLayout) - the whole body width,
## the tree centred; the tree area scrolls on its own only when even the compact layout does not fit.
func layout_trees() -> void:
	if _tree_scroll == null or not is_instance_valid(_tree_scroll) or not is_inside_tree() or _trees.is_empty():
		return
	var area := _tree_scroll.get_parent() as Control
	var limit := body_room()
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	var room := Vector2(limit.x - 8.0, limit.y - others - 6.0)
	if room == _tree_room and talent_layout != null:
		return   # nothing changed (called again after every resize)
	_tree_room = room
	talent_layout = TalentLayout.pick(room)
	_tier_scale.apply(talent_layout)
	for view in _trees:
		view.apply(talent_layout)
	var content := talent_layout.content_size()
	var scroll_y := content.y > room.y
	var bar := 14.0
	var height := maxf(minf(content.y, room.y), 160.0)
	_tree_scroll.custom_minimum_size = Vector2(minf(content.x + (bar if scroll_y else 0.0), room.x), height)
	queue_fit()
	if _keep_scroll != Vector2i(-1, -1):
		_restore_tree_scroll.call_deferred()   # after learning: same view as before (150 %)
	# nodes may have moved: keep / bring back the tooltip of the node under the mouse
	if talent_tooltip.visible:
		talent_tooltip._place.call_deferred()
	else:
		_reshow_talent_tooltip.call_deferred()


func _focus_first() -> void:
	_auto_focusing = true
	super()
	_auto_focusing = false


func _on_talent_hovered(node_id: StringName, view: TalentTreeView) -> void:
	if _auto_focusing or not is_instance_valid(view) or not view.is_inside_tree() or view.is_queued_for_deletion():
		return   # automatic first focus, or a node of a page that was just rebuilt
	if node_id == &"":
		talent_tooltip.hide_tooltip()
		return
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	talent_tooltip.show_for(character, character.classes.active_class_id, node, view.button_for(node_id))


## After a rebuild the node whose tooltip was open shows it again - the mouse has not moved; leaving the
## node hides it as usual.
func _reshow_talent_tooltip() -> void:
	if page != "Talents" or not visible or _keep_tooltip == &"":
		return
	for view in _trees:
		if is_instance_valid(view) and view.button_for(_keep_tooltip) != null:
			var node_id := _keep_tooltip
			_keep_tooltip = &""
			_on_talent_hovered(node_id, view)
			return


## The detail panel's Learn / Upgrade: one rank of `node_id` through TalentService (its rules decide).
func _learn_selected(node_id: StringName) -> void:
	_keep_tooltip = &""
	_focus_learn = true   # keyboard: the rebuilt button keeps the focus
	_learn(node_id)


func _learn(node_id: StringName) -> void:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	_say(TalentService.learn(character, character.classes.active_class_id, node_id), "Learned %s." % (node.display_name if node else String(node_id)))


## The shown tree's view if it is `tree_id` (only one tree is shown at a time), else null.
func tree_view(tree_id: StringName) -> TalentTreeView:
	for view in _trees:
		if view.tree.id == tree_id:
			return view
	return null


# --- Skills ---------------------------------------------------------------------

## Skills (Skills & Talents UX 2.0 Phase 3, docs/SKILLS_TALENTS_UX_2_0.md): "Which skills do I use, and how?" -
## the four Q/E/R/F slots on top (icon, key, name, cost, cooldown; a slim empty state), a compact list of the
## class's active skills on the left (icon, name, slot key or lock reason, cost / cooldown; scrolls on its own),
## the chosen skill's details on the right: description, facts, unlock state, its slot, the explicit equip row
## (one button per slot, saying what it replaces or swaps) and its Form / Resonance modifications (dropdown +
## every mod with its state). Choosing a skill never equips it; slots and mods change only through SkillBook
## (at a class station), exactly as before.
func _build_skills() -> void:
	var class_id := character.classes.active_class_id
	var skills := class_skills(class_id)
	if skills.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no skills yet.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
		return
	var runtime := ClassRuntime.new()
	runtime.character = character
	_content.add_child(_skill_slot_bar(class_id, runtime))
	var area := HBoxContainer.new()
	area.name = "SkillArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(area)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "SkillListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(SKILL_LIST_WIDTH, SKILL_AREA_MIN_HEIGHT)
	area.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.name = "SkillList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	list_scroll.add_child(list)
	var group := ButtonGroup.new()
	for skill in skills:
		list.add_child(_skill_entry(class_id, skill, runtime, group))
	var detail := UiTheme.card(&"CardPanel")
	detail.name = "SkillDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.y = SKILL_AREA_MIN_HEIGHT
	area.add_child(detail)
	select_skill(selected_skill())
	layout_skills()
	layout_skills.call_deferred()


## The class's active skills: level skills by unlock level, then talent / special unlocks, each by name.
func class_skills(class_id: StringName) -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for skill: SkillDefinition in character.database.skills.values():
		if skill.class_id == class_id:
			result.append(skill)
	result.sort_custom(func(a: SkillDefinition, b: SkillDefinition) -> bool:
		var a_level := a.unlock_level if a.unlock_level > 0 else 1000
		var b_level := b.unlock_level if b.unlock_level > 0 else 1000
		return a_level < b_level if a_level != b_level else a.display_name < b.display_name)
	return result


## The chosen skill of the active class: the last one chosen, else the skill in Q, else the first of the list.
func selected_skill() -> StringName:
	var class_id := character.classes.active_class_id
	var skills := class_skills(class_id)
	var chosen: StringName = _skill_selected.get(class_id, &"")
	if skills.any(func(s: SkillDefinition) -> bool: return s.id == chosen):
		return chosen
	for skill_id in character.builds.get_build(class_id).slots:
		if skill_id != &"":
			return skill_id
	return skills[0].id if not skills.is_empty() else &""


## Shows `skill_id` in the detail panel (gold entry) - never equips or changes it.
func select_skill(skill_id: StringName) -> void:
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	if skill == null or skill.class_id != character.classes.active_class_id:
		return
	_skill_selected[skill.class_id] = skill_id
	var list := _content.find_child("SkillList", true, false)
	if list == null:
		return
	for entry: Node in list.get_children():
		(entry as Button).set_pressed_no_signal(entry.name == "Skill_%s" % skill_id)
	_show_skill_detail(skill)


## Cost and cooldown in short form ("12 Rage · 6.0 s", "No cost · 0.5 s").
func _skill_cost_text(params: SkillParams) -> String:
	var resource := character.classes.get_active_definition().resource
	var cost := "%d %s" % [roundi(params.cost), resource.display_name if resource != null else ""] if params.cost > 0.0 else "No cost"
	return "%s  ·  %s" % [cost, "%.1f s" % params.cooldown if params.cooldown > 0.0 else "no cooldown"]


## The four slots: icon, key, name, cost / cooldown; empty = key + "Empty" in a slim inset card. A click on a
## filled slot only selects its skill.
func _skill_slot_bar(class_id: StringName, runtime: ClassRuntime) -> Control:
	var build := character.builds.get_build(class_id)
	var bar := HBoxContainer.new()
	bar.name = "SkillSlots"
	bar.add_theme_constant_override(&"separation", UiTheme.GAP)
	for index in build.slots.size():
		var skill: SkillDefinition = character.database.skills.get(build.slots[index])
		var slot: Control
		if skill != null:   # a filled slot is a card button: a click selects its skill
			var button := Button.new()
			button.theme_type_variation = &"CardButton"
			button.pressed.connect(select_skill.bind(skill.id))
			slot = button
		else:   # empty: a slim inset panel of the same height, nothing to click
			slot = Panel.new()
			slot.theme_type_variation = &"InsetPanel"
		slot.name = "SkillSlot%d" % index
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = SKILL_SLOT_HEIGHT
		slot.tooltip_text = "%s: %s" % [SkillBar.KEYS[index], skill.display_name if skill != null else "empty"]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", UiTheme.GAP)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		slot.add_child(row)
		var key := UiTheme.key_chip(SkillBar.KEYS[index])
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)
		if skill != null:
			var art := UiTheme.skill_icon(skill.id)
			if art != null:
				row.add_child(art)
		var texts := VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.add_theme_constant_override(&"separation", 0)
		var title := UiTheme.styled(skill.display_name if skill != null else tr("UI_SKILL_EMPTY_SLOT"), &"SmallLabel")
		title.name = "SlotSkill"
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_color_override(&"font_color", skill.color.lerp(UiTheme.PARCHMENT, 0.4) if skill != null else UiTheme.TEXT_MUTED)
		texts.add_child(title)
		if skill != null:   # an empty slot says "Empty" once (Menu UX Polish 1.1)
			var meta := UiTheme.styled(_skill_cost_text(runtime.params_for(skill)), &"CaptionLabel")
			meta.name = "SlotCost"
			meta.clip_text = true
			meta.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
			texts.add_child(meta)
		row.add_child(texts)
		bar.add_child(slot)
	return bar


## One list entry (CardButton toggle: chosen = gold card, focus = cyan): icon (dimmed while locked), name and one
## short line - the slot key and cost / cooldown, or "Locked · <how>".
func _skill_entry(class_id: StringName, skill: SkillDefinition, runtime: ClassRuntime, group: ButtonGroup) -> Button:
	var available := SkillBook.is_skill_available(character, class_id, skill.id)
	var slot := character.builds.get_build(class_id).slot_of(skill.id)
	var entry := Button.new()
	entry.name = "Skill_%s" % skill.id
	entry.theme_type_variation = &"CardButton"
	entry.toggle_mode = true
	entry.button_group = group
	entry.custom_minimum_size = Vector2(0, SKILL_ENTRY_HEIGHT)
	entry.pressed.connect(select_skill.bind(skill.id))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", UiTheme.GAP + 2)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	entry.add_child(row)
	var art := UiTheme.skill_icon(skill.id, not available)
	if art != null:
		row.add_child(art)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	var title := UiTheme.styled(skill.display_name, &"SmallLabel")
	title.name = "SkillName"
	title.add_theme_color_override(&"font_color", skill.color.lerp(UiTheme.PARCHMENT, 0.4) if available else UiTheme.TEXT_MUTED)
	texts.add_child(title)
	var meta := UiTheme.styled(_skill_cost_text(runtime.params_for(skill)) if available else "Locked  ·  %s" % SkillBook.unlock_text(character, skill), &"CaptionLabel")
	meta.name = "SkillState"
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY if available else UiTheme.WARNING)
	texts.add_child(meta)
	row.add_child(texts)
	if slot >= 0:
		var key := UiTheme.key_chip(SkillBar.KEYS[slot])
		key.name = "SlotKey"
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(key)
	return entry


## Detail panel of `skill`: head (icon, name, Unlocked / Locked, slot), then in SkillDetailScroll the description,
## cost / cooldown / rules, the unlock condition, talent transformations and the modifications; the equip row
## is the fixed footer.
func _show_skill_detail(skill: SkillDefinition) -> void:
	var detail := _content.find_child("SkillDetail", true, false) as PanelContainer
	if detail == null:
		return
	var class_id := skill.class_id
	var available := SkillBook.is_skill_available(character, class_id, skill.id)
	var slot := character.builds.get_build(class_id).slot_of(skill.id)
	var runtime := ClassRuntime.new()
	runtime.character = character
	var params := runtime.params_for(skill)
	var box := detail.get_node("Box") as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP + 2)
	var art := UiTheme.skill_icon(skill.id, not available)
	if art != null:
		art.name = "DetailIcon"
		head.add_child(art)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override(&"separation", 2)
	var title := UiTheme.styled(skill.display_name, &"MenuTitleLabel")
	title.name = "SkillTitle"
	title.add_theme_color_override(&"font_color", skill.color.lerp(UiTheme.PARCHMENT, 0.4))
	names.add_child(title)
	var state := UiTheme.styled(("Unlocked" if available else "Locked") + "  ·  " + ("Equipped on %s" % SkillBar.KEYS[slot] if slot >= 0 else "Not equipped"), &"MenuMetaLabel")
	state.name = "SkillStatus"
	state.add_theme_color_override(&"font_color", (UiTheme.SUCCESS if slot >= 0 else UiTheme.TEXT_SECONDARY) if available else UiTheme.WARNING)
	names.add_child(state)
	head.add_child(names)
	box.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.name = "SkillDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var body_box := VBoxContainer.new()
	body_box.name = "Lines"
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_box.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	scroll.add_child(body_box)
	var width := _skill_detail_width() - 24
	body_box.add_child(UiTheme.menu_text(skill.description, UiTheme.TEXT_PRIMARY, width))
	var facts := UiTheme.styled(_skill_cost_text(params), &"MenuMetaLabel")
	facts.name = "SkillCost"
	body_box.add_child(facts)
	var rules := params.describe()
	if rules != "":
		var rule_label := UiTheme.wrapped(rules, UiTheme.TEXT_SECONDARY, width)
		rule_label.theme_type_variation = &"MenuMetaLabel"
		body_box.add_child(rule_label)
	var unlock := UiTheme.wrapped(("Unlocked by: %s" if available else "Unlock: %s") % SkillBook.unlock_text(character, skill), UiTheme.SUCCESS if available else UiTheme.WARNING, width)
	unlock.name = "SkillUnlock"
	unlock.theme_type_variation = &"MenuMetaLabel"
	body_box.add_child(unlock)
	var changes := _talents_changing(class_id, skill.id)
	if not changes.is_empty():
		var changed := UiTheme.wrapped("Changed by talents: %s" % ", ".join(changes), UiTheme.BRONZE, width)
		changed.name = "SkillTalentChanges"
		changed.theme_type_variation = &"MenuMetaLabel"
		body_box.add_child(changed)
	body_box.add_child(UiTheme.section(tr("UI_SKILL_MODIFICATIONS")))
	if not skill.allows_mods:
		body_box.add_child(UiTheme.menu_text("This skill takes no modifications.", UiTheme.TEXT_MUTED, width, &"MenuMetaLabel"))
	else:
		var mods := HBoxContainer.new()
		mods.name = "Mods"
		mods.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
		for mod_slot: SkillModDefinition.Slot in [FORM, RESONANCE]:
			mods.add_child(_mod_column(class_id, skill, mod_slot, available, (width - UiTheme.GAP * 2) / 2.0))
		body_box.add_child(mods)
		body_box.add_child(_mod_list(class_id, skill, width))
	# the equip row is the page's main action: a fixed footer of the panel, never scrolled away
	box.add_child(UiTheme.section(tr("UI_SKILL_EQUIP")))
	box.add_child(_skill_equip_row(class_id, skill, available, width))


## Names of the learned talents that change `skill_id` (their transformations are always on).
func _talents_changing(class_id: StringName, skill_id: StringName) -> PackedStringArray:
	var result: PackedStringArray = []
	var build := character.builds.get_build(class_id)
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node != null and build.talents[node_id] > 0 and node.skill_mods.any(func(m: SkillModDefinition) -> bool: return m != null and skill_id in m.skill_ids):
			result.append(node.display_name)
	return result


## Gives the skill list and the detail panel the height the window leaves under the slot bar (the window
## itself never scrolls; both areas scroll on their own).
func layout_skills() -> void:
	var list_scroll := _content.find_child("SkillListScroll", true, false) as Control
	if page != "Skills" or list_scroll == null or not is_inside_tree():
		return
	var area := list_scroll.get_parent() as Control
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	var height := maxf(SKILL_AREA_MIN_HEIGHT, floorf(body_room().y - others - 6.0))
	list_scroll.custom_minimum_size.y = height
	(area.get_node("SkillDetail") as Control).custom_minimum_size.y = height
	queue_fit()


func _skill_detail_width() -> float:
	return body_room().x - SKILL_LIST_WIDTH - UiTheme.GAP * 3 - 40


## One button per slot: "<key> · Equip / Replace / Swap / Equipped" - what the click does (the slot's skill is in
## the slot bar above, the whole sentence in the tooltip); pressing equips through SkillBook.assign_slot (unchanged
## rules: a skill sits in one slot only - moving it swaps with the target slot; an occupied slot gets replaced and
## its skill goes back to the list). "Remove" empties the skill's slot.
func _skill_equip_row(class_id: StringName, skill: SkillDefinition, available: bool, width: float) -> Control:
	var build := character.builds.get_build(class_id)
	var current := build.slot_of(skill.id)
	var column := VBoxContainer.new()
	column.name = "Equip"
	column.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	column.add_child(row)
	var reason := "" if available else "Locked - unlock it first (%s)." % SkillBook.unlock_text(character, skill)
	if reason == "" and not at_station():
		reason = tr("UI_ONLY_AT_STATION")
	for index in build.slots.size():
		var other: SkillDefinition = character.database.skills.get(build.slots[index])
		# Menu UX Polish 1.1: the word says what SkillBook.assign_slot really does - Equip (empty slot, skill not
		# equipped), Replace (occupied slot), Swap (both slots occupied - they trade), Move (to an empty slot, its
		# old slot becomes empty), Equipped (its own slot)
		var action := "Equip"
		var effect := "Equips %s on %s." % [skill.display_name, SkillBar.KEYS[index]]
		if index == current:
			action = "Equipped"
			effect = "%s is on %s." % [skill.display_name, SkillBar.KEYS[index]]
		elif current >= 0 and other != null:
			action = "Swap"
			effect = "Swap: %s moves to %s, %s goes to %s." % [skill.display_name, SkillBar.KEYS[index], other.display_name, SkillBar.KEYS[current]]
		elif current >= 0:
			action = "Move"
			effect = "Moves %s from %s to %s (%s becomes empty)." % [skill.display_name, SkillBar.KEYS[current], SkillBar.KEYS[index], SkillBar.KEYS[current]]
		elif other != null:
			action = "Replace"
			effect = "Replaces %s on %s (it goes back to the list)." % [other.display_name, SkillBar.KEYS[index]]
		var button := UiTheme.button("%s · %s" % [SkillBar.KEYS[index], action], &"", func() -> void:
			_say(SkillBook.assign_slot(character, class_id, index, skill.id, at_station()), "%s on %s." % [skill.display_name, SkillBar.KEYS[index]]))
		button.name = "EquipSlot%d" % index
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.toggle_mode = true
		button.set_pressed_no_signal(index == current)
		button.disabled = reason != "" or index == current
		button.tooltip_text = reason if reason != "" else effect
		row.add_child(button)
	var remove := UiTheme.button("Remove from %s" % SkillBar.KEYS[current] if current >= 0 else "Not equipped", &"", func() -> void:
		_say(SkillBook.assign_slot(character, class_id, current, &"", at_station()), "%s removed." % skill.display_name))
	remove.name = "UnequipSkill"
	remove.disabled = current < 0 or not at_station()
	remove.tooltip_text = "" if at_station() else tr("UI_ONLY_AT_STATION")
	# only a reason is said here (what each button does is its tooltip)
	var hint := UiTheme.wrapped(reason, UiTheme.WARNING, width - 190)
	hint.name = "EquipHint"
	hint.theme_type_variation = &"MenuMetaLabel"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", UiTheme.GAP)
	bottom.add_child(hint)
	bottom.add_child(remove)
	column.add_child(bottom)
	return column


## Form or Resonance of the chosen skill: the dropdown (unchanged SkillBook.set_mod, locked entries disabled)
## and every mod of that slot with its state - Active / Available / Locked · source - and its effect.
func _mod_column(class_id: StringName, skill: SkillDefinition, slot: SkillModDefinition.Slot, available: bool, width: float) -> Control:
	var column := VBoxContainer.new()
	column.name = "Mods_%s" % ("form" if slot == FORM else "resonance")
	column.custom_minimum_size.x = width
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 4)
	var head := UiTheme.styled("Form" if slot == FORM else "Resonance", &"MenuMetaLabel")
	head.add_theme_color_override(&"font_color", UiTheme.BRONZE)
	column.add_child(head)
	var choice := _mod_choice(class_id, skill, slot)
	choice.custom_minimum_size.x = width
	if not available:
		choice.disabled = true
		choice.tooltip_text = "Unlock the skill first."
	column.add_child(choice)
	# Menu UX Polish 1.1: only the chosen mod's effect (or a short empty state) stays visible; every other mod - with
	# its effect and how it unlocks - is in the open dropdown (item tooltips) and in "All modifications" below
	var current: SkillModDefinition = character.database.skill_mods.get(character.builds.get_build(class_id).mod_of(skill.id, slot))
	var mods := SkillBook.mods_for(character, skill.id, slot)
	var shown := UiTheme.menu_text(current.description if current != null else ("None chosen  ·  %d available" % mods.filter(
		func(m: SkillModDefinition) -> bool: return SkillBook.is_mod_available(character, class_id, m)).size() if not mods.is_empty() else "No modifications for this slot."),
		UiTheme.TEXT_SECONDARY if current != null else UiTheme.TEXT_MUTED, width, &"MenuMetaLabel")
	shown.name = "ModEffect"
	column.add_child(shown)
	return column


## "All modifications" of the chosen skill (Menu UX Polish 1.1): collapsed by default, one toggle opens the full
## list - every Form and Resonance mod with its state (Active / Available / Locked and how it unlocks) and effect.
## Works away from the station too (reading never needs one).
func _mod_list(class_id: StringName, skill: SkillDefinition, width: float) -> Control:
	var box := VBoxContainer.new()
	box.name = "AllMods"
	box.add_theme_constant_override(&"separation", 2)
	var count := SkillBook.mods_for(character, skill.id, FORM).size() + SkillBook.mods_for(character, skill.id, RESONANCE).size()
	var toggle := UiTheme.button("%s  All modifications (%d)" % ["-" if _show_all_mods else "+", count], &"", func() -> void:
		_show_all_mods = not _show_all_mods
		_show_skill_detail(skill))
	toggle.name = "ToggleAllMods"
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toggle.disabled = count == 0
	box.add_child(toggle)
	if not _show_all_mods:
		return box
	for slot: SkillModDefinition.Slot in [FORM, RESONANCE]:
		var chosen := character.builds.get_build(class_id).mod_of(skill.id, slot)
		for mod in SkillBook.mods_for(character, skill.id, slot):
			var unlocked := SkillBook.is_mod_available(character, class_id, mod)
			var word := "Active" if mod.id == chosen else ("Available" if unlocked else "Locked  ·  %s" % SkillBook.mod_unlock_text(mod))
			var line := UiTheme.wrapped("%s  ·  %s  ·  %s" % ["Form" if slot == FORM else "Resonance", mod.display_name, word],
				UiTheme.SUCCESS if mod.id == chosen else (UiTheme.TEXT_PRIMARY if unlocked else UiTheme.WARNING), width)
			line.name = "Mod_%s" % mod.id
			line.theme_type_variation = &"MenuMetaLabel"
			box.add_child(line)
			var effect := UiTheme.wrapped(mod.description, UiTheme.TEXT_SECONDARY, width)
			effect.theme_type_variation = &"MenuMetaLabel"
			box.add_child(effect)
	return box


func _mod_choice(class_id: StringName, skill: SkillDefinition, slot: SkillModDefinition.Slot) -> OptionButton:
	var choice := OptionButton.new()
	choice.name = "%s_%s" % [skill.id, "form" if slot == FORM else "resonance"]
	choice.custom_minimum_size = Vector2(230, 0)
	choice.fit_to_longest_item = false   # Main Window Layout Lock 1.0: the open list shows every entry whole
	choice.clip_text = true
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
		choice.get_popup().set_item_tooltip(index, SkillText.mod(mod))   # effect and requirement in the open list
		if mod.id == current:
			choice.select(index)
		tips.append(SkillText.mod(mod))
	choice.disabled = not at_station() or choice.item_count == 1
	choice.tooltip_text = "\n\n".join(tips) if not tips.is_empty() else "No modifications for this slot."
	if not at_station():
		choice.tooltip_text = tr("UI_ONLY_AT_STATION") + ("\n\n" + "\n\n".join(tips) if not tips.is_empty() else "")
	choice.item_selected.connect(func(item: int) -> void:
		_say(SkillBook.set_mod(character, class_id, skill.id, slot, choice.get_item_metadata(item), at_station()), "Modification changed."))
	return choice


# --- Presets ----------------------------------------------------------------------

## Presets (Skills & Talents UX 2.0 Phase 4, docs/SKILLS_TALENTS_UX_2_0.md): "Which builds have I stored, and what
## happens when I load one?" - the class's five preset slots as a compact list on the left (number, name,
## Saved / Empty and a short summary, each with its Save / Overwrite button; name, Rename and Delete of the chosen
## preset below), the chosen preset's build on the right (talent points per tree, Q/E/R/F with mods, the other
## mods, equipment references and their state) with the Activate footer (cost, what changes, every reason it
## cannot). Every action goes through the unchanged PresetService; a preset holds references only.
func _build_presets() -> void:
	var class_id := character.classes.active_class_id
	if not character.classes.is_unlocked(class_id):
		_content.add_child(UiTheme.wrapped("Presets need an unlocked class (not available during a trial).", UiTheme.WARNING, CONTENT_WIDTH))
		return
	var chosen := selected_preset()
	var area := HBoxContainer.new()
	area.name = "PresetArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_content.add_child(area)
	var left := VBoxContainer.new()
	left.name = "PresetColumn"
	left.custom_minimum_size.x = PRESET_LIST_WIDTH
	left.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	area.add_child(left)
	var list := VBoxContainer.new()
	list.name = "PresetList"
	list.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	left.add_child(list)
	var group := ButtonGroup.new()
	for index in PresetService.slot_count(character):
		list.add_child(_preset_entry(class_id, index, group, index == chosen))
	left.add_child(_preset_manage(class_id, chosen))
	var detail := UiTheme.card(&"CardPanel")
	detail.name = "PresetDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(detail)
	_show_preset_detail(class_id, chosen)
	layout_presets()
	layout_presets.call_deferred()


## The chosen preset slot of the active class (the last one chosen, else the first saved one, else slot 1).
func selected_preset() -> int:
	var class_id := character.classes.active_class_id
	var count := PresetService.slot_count(character)
	var chosen: int = _preset_selected.get(class_id, -1)
	if chosen >= 0 and chosen < count:
		return chosen
	for index in count:
		if not PresetService.get_preset(character, class_id, index).is_empty():
			return index
	return 0


## Chooses preset slot `index` (gold entry) and shows it - never saves, loads or changes anything.
func select_preset(index: int) -> void:
	_preset_selected[character.classes.active_class_id] = index
	if page == "Presets":
		rebuild()


## The preset as a temporary ClassBuild (talents, slots, mods read by ClassBuild itself - format unchanged).
func _preset_build(class_id: StringName, preset: Dictionary) -> ClassBuild:
	var probe := ClassBuild.new(class_id, character.database.rules.talent_rules().skill_slots)
	probe.from_dict(preset, PackedStringArray())
	return probe


## Points of the preset per tree of `class_id`, as "Tree n" parts.
func _preset_tree_points(class_id: StringName, probe: ClassBuild) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tree in TalentService.trees_of(character.database, class_id):
		result.append({"tree": tree, "points": TalentService.points_in_tree(probe.talents, tree)})
	return result


## One list row: the entry (CardButton toggle: number, name / "Empty", "Saved · n pts" / "Empty slot") and its
## compact Save / Overwrite button (PresetService.save_preset with the shown name - unchanged, free).
func _preset_entry(class_id: StringName, index: int, group: ButtonGroup, chosen: bool) -> Control:
	var preset := PresetService.get_preset(character, class_id, index)
	var row := HBoxContainer.new()
	row.name = "Preset%d" % index
	row.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	var entry := Button.new()
	entry.name = "PresetEntry"
	entry.theme_type_variation = &"CardButton"
	entry.toggle_mode = true
	entry.button_group = group
	entry.set_pressed_no_signal(chosen)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.custom_minimum_size.y = PRESET_ENTRY_HEIGHT
	entry.pressed.connect(select_preset.bind(index))
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override(&"separation", UiTheme.GAP + 2)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	entry.add_child(inner)
	var number := UiTheme.key_chip("%d" % (index + 1))
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(number)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	var title := UiTheme.styled(str(preset.get("name", "")) if not preset.is_empty() else "Empty", &"SmallLabel")
	title.name = "PresetName"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override(&"font_color", UiTheme.TEXT_PRIMARY if not preset.is_empty() else UiTheme.TEXT_MUTED)
	texts.add_child(title)
	if not preset.is_empty():   # an empty slot says "Empty" once (Menu UX Polish 1.1)
		var state := UiTheme.styled("Saved  ·  %d pts" % _preset_build(class_id, preset).spent(), &"CaptionLabel")
		state.name = "PresetState"
		state.clip_text = true
		state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		state.add_theme_color_override(&"font_color", UiTheme.SUCCESS)
		texts.add_child(state)
	inner.add_child(texts)
	entry.tooltip_text = str(preset.get("name", "")) if not preset.is_empty() else "Preset %d - empty" % (index + 1)
	row.add_child(entry)
	var save := UiTheme.button("Save" if preset.is_empty() else "Overwrite", &"", func() -> void:
		_preset_selected[class_id] = index
		_say(PresetService.save_preset(character, class_id, index, _preset_name_for(class_id, index)), "Preset %d saved." % (index + 1)))
	save.name = "Save"
	save.custom_minimum_size = Vector2(PRESET_SAVE_WIDTH, PRESET_ENTRY_HEIGHT)
	save.tooltip_text = "Store the current talents, skills, mods and equipment references here (free)." if preset.is_empty() \
		else "Replace this preset with the current build (free)."
	row.add_child(save)
	return row


## The name a Save uses: the name field when it belongs to that slot, else the stored name (or "Preset n").
func _preset_name_for(class_id: StringName, index: int) -> String:
	var field := _content.find_child("PresetNameEdit", true, false) as LineEdit
	if field != null and index == selected_preset():
		return field.text
	return str(PresetService.get_preset(character, class_id, index).get("name", ""))


## Name field, Rename and Delete of the chosen preset (existing actions; Delete asks first).
func _preset_manage(class_id: StringName, index: int) -> Control:
	var preset := PresetService.get_preset(character, class_id, index)
	var box := VBoxContainer.new()
	box.name = "PresetManage"
	box.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	box.add_child(UiTheme.section("Preset %d" % (index + 1)))
	var name_edit := LineEdit.new()
	name_edit.name = "PresetNameEdit"
	name_edit.placeholder_text = "Preset %d" % (index + 1)
	name_edit.text = str(preset.get("name", ""))
	box.add_child(name_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	var rename := UiTheme.button("Rename", &"", func() -> void:
		_say(PresetService.rename_preset(character, class_id, index, name_edit.text), "Preset renamed."))
	rename.name = "Rename"
	rename.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename.disabled = preset.is_empty()
	rename.tooltip_text = "Save the build here first." if preset.is_empty() else "Rename this preset (free)."
	row.add_child(rename)
	var delete := UiTheme.button("Delete", &"DangerButton", func() -> void: _ask_delete(class_id, index, str(preset.get("name", ""))))
	delete.name = "Delete"
	delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete.disabled = preset.is_empty()
	row.add_child(delete)
	box.add_child(row)
	return box


## Detail of the chosen preset: head (name, class, slot), the build in PresetDetailScroll (talents per tree,
## Q/E/R/F with icons and mods, other mods, equipment references with their state), the Activate footer.
func _show_preset_detail(class_id: StringName, index: int) -> void:
	var detail := _content.find_child("PresetDetail", true, false) as PanelContainer
	var box := detail.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	var preset := PresetService.get_preset(character, class_id, index)
	var definition := character.database.get_class_def(class_id)
	if preset.is_empty():
		var empty := UiTheme.styled("Preset %d is empty" % (index + 1), &"SubheadingLabel")
		empty.name = "PresetTitle"
		empty.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
		box.add_child(empty)
		var hint := UiTheme.wrapped("Save stores the current talents, skills, mods and %s equipment references here." % definition.display_name, UiTheme.TEXT_MUTED, _preset_detail_width())
		hint.theme_type_variation = &"SmallLabel"
		box.add_child(hint)
		return
	var title := UiTheme.styled(str(preset.get("name", "")), &"SubheadingLabel")
	title.name = "PresetTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = _preset_detail_width()
	box.add_child(title)
	var meta := UiTheme.styled("%s  ·  Preset %d" % [definition.display_name, index + 1], &"SmallLabel")
	meta.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
	box.add_child(meta)
	var scroll := ScrollContainer.new()
	scroll.name = "PresetDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	scroll.add_child(lines)
	var width := _preset_detail_width() - 20
	var probe := _preset_build(class_id, preset)
	# talents per tree
	lines.add_child(UiTheme.section("Talents  ·  %d points" % probe.spent()))
	var trees := HBoxContainer.new()
	trees.name = "PresetTrees"
	trees.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	for part in _preset_tree_points(class_id, probe):
		var tree := part.tree as TalentTreeDefinition
		var label := UiTheme.styled("%s  %d" % [tree.display_name, part.points], &"SmallLabel")
		label.name = "Tree_%s" % tree.id
		label.add_theme_color_override(&"font_color", tree.color.lerp(UiTheme.PARCHMENT, 0.35) if part.points > 0 else UiTheme.TEXT_MUTED)
		trees.add_child(label)
	lines.add_child(trees)
	# skills with their mods
	lines.add_child(UiTheme.section("Skills"))
	var shown := {}
	for slot in probe.slots.size():
		var skill_id := probe.slots[slot]
		shown[skill_id] = true
		lines.add_child(_preset_skill_row(probe, slot, skill_id, width))
	var others: PackedStringArray = []
	for skill_id: StringName in probe.mods:
		if not shown.has(skill_id):
			var text := _preset_mod_text(probe, skill_id)
			if text != "":
				var other_skill: SkillDefinition = character.database.skills.get(skill_id)
				others.append("%s: %s" % [other_skill.display_name if other_skill != null else String(skill_id), text])
	if not others.is_empty():
		var other_mods := UiTheme.wrapped("Mods of other skills - %s" % "  ·  ".join(others), UiTheme.TEXT_SECONDARY, width)
		other_mods.name = "PresetOtherMods"
		other_mods.theme_type_variation = &"CaptionLabel"
		lines.add_child(other_mods)
	# equipment references
	lines.add_child(UiTheme.section("Equipment"))
	var equipment: Dictionary = preset.get("equipment", {}) if preset.get("equipment") is Dictionary else {}
	if equipment.is_empty():
		var none := UiTheme.styled("No equipment stored (activating unequips this class's gear).", &"SmallLabel")
		none.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
		lines.add_child(none)
	for slot_key: String in equipment:
		lines.add_child(_preset_item_row(class_id, slot_key, str(equipment[slot_key]), width))
	# activation footer (Menu UX Polish 1.1): the cost on the button, one short line what it counts as, and - when
	# blocked - every concrete reason right above it (also "only at a class station")
	var errors := PresetService.validate(character, class_id, preset)
	var cost := PresetService.activation_cost(character, class_id, preset)
	var same := PresetService.same_talents(character, class_id, preset)
	var reasons := Array(errors)
	if errors.is_empty() and not at_station():
		reasons.append(tr("UI_ONLY_AT_STATION"))
	var effect := "Same talents as now - only skills, mods and gear change." if same else "Talents differ - counts as a talent reset."
	var effect_label := UiTheme.wrapped(effect, UiTheme.TEXT_SECONDARY, width)
	effect_label.name = "PresetEffect"
	effect_label.theme_type_variation = &"MenuMetaLabel"
	box.add_child(effect_label)
	for error: String in reasons:
		var line := UiTheme.wrapped(error, UiTheme.WARNING, width)
		line.name = "PresetError"
		line.theme_type_variation = &"MenuMetaLabel"
		box.add_child(line)
	var activate := _station_button("Activate preset %d  ·  %s" % [index + 1, "free" if cost == 0 else "%d gold" % cost], func() -> void:
		_say(PresetService.activate(character, class_id, index, at_station()), "Preset activated."), errors.is_empty(), "\n".join(errors), &"PrimaryButton")
	activate.name = "Activate"
	activate.clip_text = true
	activate.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not same:
		activate.tooltip_text = activate.tooltip_text if activate.disabled else "Counts as a talent reset (%s)." % ("free - first reset" if cost == 0 else "%d gold" % cost)
	box.add_child(activate)


func _preset_detail_width() -> float:
	return body_room().x - PRESET_LIST_WIDTH - UiTheme.GAP * 3 - 40


## "Form: X · Resonance: Y" of `skill_id` in the preset ("" without mods).
func _preset_mod_text(probe: ClassBuild, skill_id: StringName) -> String:
	var parts: PackedStringArray = []
	for mod_slot: SkillModDefinition.Slot in [FORM, RESONANCE]:
		var mod: SkillModDefinition = character.database.skill_mods.get(probe.mod_of(skill_id, mod_slot))
		if mod != null:
			parts.append("%s: %s" % ["Form" if mod_slot == FORM else "Resonance", mod.display_name])
	return "  ·  ".join(parts)


## One skill slot of the preset: key, icon, name, its mods (or "empty").
func _preset_skill_row(probe: ClassBuild, slot: int, skill_id: StringName, width: float) -> Control:
	var skill: SkillDefinition = character.database.skills.get(skill_id)
	var row := HBoxContainer.new()
	row.name = "PresetSlot%d" % slot
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	var key := UiTheme.key_chip(SkillBar.KEYS[slot])
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key)
	var art := UiTheme.skill_icon(skill_id) if skill != null else null
	if art != null:
		row.add_child(art)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	var title := UiTheme.styled(skill.display_name if skill != null else "Empty", &"SmallLabel")
	title.add_theme_color_override(&"font_color", skill.color.lerp(UiTheme.PARCHMENT, 0.4) if skill != null else UiTheme.TEXT_MUTED)
	texts.add_child(title)
	var mods := _preset_mod_text(probe, skill_id) if skill != null else ""
	if mods != "":
		var mod_label := UiTheme.wrapped(mods, UiTheme.TEXT_SECONDARY, width - 110)
		mod_label.theme_type_variation = &"CaptionLabel"
		texts.add_child(mod_label)
	row.add_child(texts)
	return row


## One equipment reference: slot, the item (name in its rarity colour) and its state - in the bag, in the Haven
## stash, missing, or not equippable - read only; nothing is created or moved.
func _preset_item_row(class_id: StringName, slot_key: String, instance_id: String, width: float) -> Control:
	var slot := EquipSlot.from_key(slot_key)
	var item := character.inventory.find(instance_id)
	var stashed := character.stash.find(instance_id) if item == null else null
	var shown := item if item != null else stashed
	var definition := character.database.get_item(shown.definition_id) if shown != null else null
	var state := ""
	var color := UiTheme.TEXT_PRIMARY
	if item == null and stashed != null:
		state = "In the Haven stash"
		color = UiTheme.WARNING
	elif item == null:
		state = "Missing - no longer in the bag"
		color = UiTheme.DANGER
	elif slot < 0 or character.equipment.can_equip(instance_id, slot, class_id) != "":
		state = "Cannot be equipped"
		color = UiTheme.DANGER
	var label := UiTheme.wrapped("%s:  %s%s" % [EquipSlot.display_name(slot) if slot >= 0 else slot_key,
		definition.display_name if definition != null else "unknown item", "  ·  " + state if state != "" else ""], color, width)
	label.name = "PresetItem_%s" % slot_key
	label.theme_type_variation = &"SmallLabel"
	if definition != null and state == "":
		label.add_theme_color_override(&"font_color", UiTheme.rarity_color(shown.effective_rarity(definition)))
	return label


## Gives the preset detail the height the window leaves (the window itself never scrolls).
func layout_presets() -> void:
	var detail := _content.find_child("PresetDetail", true, false) as Control
	if page != "Presets" or detail == null or not is_inside_tree():
		return
	var area := detail.get_parent() as Control
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	detail.custom_minimum_size.y = maxf(SKILL_AREA_MIN_HEIGHT, floorf(body_room().y - others - 6.0))
	queue_fit()


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

## Armor (Skills & Talents UX 2.0 Phase 7, docs/SKILLS_TALENTS_UX_2_0.md): "What am I wearing, what does it cost
## me, and what have I mastered?" - read-only over ArmorMasteryService. On top the BURDEN of what is worn now (points,
## tier, its penalties, Iron Discipline, the tier ranges from the rules, the five counted slots); below the four
## MASTERY tracks as a 2x2 grid of cards (level, XP, worn share, active bonuses) and the chosen track's details
## (progress, every milestone with its effective value, the next one). Choosing a card changes nothing; worn
## ("WORN n%") and chosen (gold) are separate marks.
func _build_armor() -> void:
	_content.add_child(_armor_status())
	var area := HBoxContainer.new()
	area.name = "ArmorArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_content.add_child(area)
	var grid := GridContainer.new()
	grid.name = "Tracks"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	grid.add_theme_constant_override(&"v_separation", UiTheme.GAP)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var group := ButtonGroup.new()
	var chosen := selected_armor_type()
	for type: int in ArmorMasteryRules.TYPES:
		grid.add_child(_armor_track(type, group, type == chosen))
	area.add_child(grid)
	var detail := UiTheme.card(&"CardPanel")
	detail.name = "ArmorDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.y = ARMOR_AREA_MIN_HEIGHT
	area.add_child(detail)
	_show_armor_detail(chosen)
	layout_armor()
	layout_armor.call_deferred()


## The chosen track: the last one chosen, else the type worn most, else the first.
func selected_armor_type() -> int:
	if _armor_selected in ArmorMasteryRules.TYPES:
		return _armor_selected
	var covered := ArmorMasteryService.coverage(character)
	var best: int = ArmorMasteryRules.TYPES[0]
	for type: int in ArmorMasteryRules.TYPES:
		if float(covered[type]) > float(covered[best]):
			best = type
	return best


## Chooses track `type` (gold card) - never changes gear or mastery.
func select_armor_type(type: int) -> void:
	_armor_selected = type
	if page == "Armor":
		rebuild()
		var card := _content.find_child("Track_%s" % CharacterArmorMastery.KEYS[type], true, false) as Control
		if card != null:
			card.grab_focus.call_deferred()


static func burden_color(tier: int) -> Color:
	return UiTheme.SUCCESS if tier == 0 else (UiTheme.WARNING if tier < 3 else UiTheme.DANGER)


## Burden of the worn gear: points and tier, the penalties now, Iron Discipline, the tier ranges (from the rules,
## the current one coloured), and the five counted slots with type and points.
func _armor_status() -> Control:
	var armor_rules := ArmorMasteryService.rules(character)
	var points := ArmorMasteryService.burden(character)
	var tier := ArmorMasteryService.tier(points, armor_rules)
	var card := UiTheme.card(&"CardPanel")
	card.name = "Burden"
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	(card.get_node("Box") as VBoxContainer).add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override(&"separation", 2)
	row.add_child(left)
	var title := HBoxContainer.new()
	title.add_theme_constant_override(&"separation", UiTheme.GAP)
	var heading := UiTheme.styled("Armor Burden", &"SmallLabel")
	heading.add_theme_color_override(&"font_color", UiTheme.BRONZE)
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(heading)
	title.add_child(_burden_help(armor_rules, tier))
	left.add_child(title)
	# Menu UX Polish 1.1: value, tier and what it does now; the tier table, slot weights and the rules are the "?"
	var tier_label := UiTheme.styled("%d  ·  %s" % [points, ArmorMasteryService.TIER_NAMES[tier]], &"SubheadingLabel")
	tier_label.name = "Tier"
	tier_label.add_theme_color_override(&"font_color", burden_color(tier))
	left.add_child(tier_label)
	var move := ArmorMasteryService.move_penalty(character)
	var recovery := ArmorMasteryService.recovery_penalty(character)
	var effects := UiTheme.styled("No penalty." if move <= 0.0 and recovery <= 0.0 else
		"-%s%% movement  ·  +%s%% attack recovery time" % [_num(move), _num(recovery)], &"SmallLabel")
	effects.name = "BurdenEffects"
	effects.add_theme_color_override(&"font_color", UiTheme.TEXT_PRIMARY)
	left.add_child(effects)
	if ArmorMasteryService.iron_discipline(character) > 0.0:
		var iron := UiTheme.styled("Iron Discipline: -%s pt of the movement penalty" % _num(ArmorMasteryService.iron_discipline(character)), &"CaptionLabel")
		iron.add_theme_color_override(&"font_color", UiTheme.SUCCESS)
		left.add_child(iron)
	return card


## The burden rules behind the "?" (hover / keyboard focus): the tier ranges from the rules (the current one
## named), what each counted slot weighs now, and that dash and parry are never affected.
func _burden_help(armor_rules: ArmorMasteryRules, tier: int) -> HelpButton:
	var lines: PackedStringArray = ["# Burden tiers"]
	for index in ArmorMasteryService.TIER_NAMES.size():
		var low := 0 if index == 0 else armor_rules.tier_starts[index - 1]
		var span := "%d+" % low if index == ArmorMasteryService.TIER_NAMES.size() - 1 else "%d-%d" % [low, armor_rules.tier_starts[index] - 1]
		lines.append("%s %s%s" % [ArmorMasteryService.TIER_NAMES[index], span, "  (now)" if index == tier else ""])
	lines.append("# Counted slots now")
	var types := ArmorMasteryService.worn_types(character)
	for index in ArmorMasteryRules.SLOTS.size():
		var worn: int = types[index]
		lines.append("%s: %s  ·  %d" % [EquipSlot.NAMES[ArmorMasteryRules.SLOTS[index]], ArmorMasteryService.TYPE_NAMES.get(worn, "nothing typed"), armor_rules.burden_of(worn, index)])
	lines.append("# Rules")
	lines.append("Burden comes from the gear alone; heavier types and larger slots weigh more.")
	lines.append("Dash and parry are never affected.")
	return HelpButton.make("\n".join(lines), "BurdenHelp")


## Active bonuses of `type` now: its reached milestones with their coverage-scaled value (0 while not worn).
func _armor_bonuses(type: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in ArmorMasteryService.milestone_bonuses(character):
		if int(entry.type) == type:
			result.append(entry)
	return result


func _milestone_value_text(stat: StringName, value: float) -> String:
	return ("-%s pt" if stat == ArmorMasteryRules.IRON_DISCIPLINE else "+%s%%") % _num(value)


## One mastery card (CardButton toggle: chosen = gold card, focus = cyan): name, "Lv n / max", XP bar, worn share
## ("WORN 40%" / "not worn"), the bonuses active now (summed per stat) and the next milestone.
func _armor_track(type: int, group: ButtonGroup, chosen: bool) -> Control:
	var armor_rules := ArmorMasteryService.rules(character)
	var level := character.armor_mastery.level(type)
	var coverage := float(ArmorMasteryService.coverage(character)[type])
	var card := Button.new()
	card.name = "Track_%s" % CharacterArmorMastery.KEYS[type]
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.button_group = group
	card.set_pressed_no_signal(chosen)
	card.custom_minimum_size = ARMOR_CARD
	card.tooltip_text = "%s mastery - level %d" % [ArmorMasteryService.TYPE_NAMES[type], level]
	card.pressed.connect(select_armor_type.bind(type))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiTheme.styled(ArmorMasteryService.TYPE_NAMES[type], &"SmallLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", UiTheme.PARCHMENT)
	head.add_child(name_label)
	var worn := UiTheme.styled("WORN %d%%" % roundi(coverage * 100.0) if coverage > 0.0 else "not worn", &"CaptionLabel")
	worn.name = "Worn"
	worn.add_theme_color_override(&"font_color", UiTheme.RESONANCE if coverage > 0.0 else UiTheme.TEXT_MUTED)
	head.add_child(worn)
	box.add_child(head)
	var level_label := UiTheme.styled("Lv %d / %d" % [level, armor_rules.max_level], &"CaptionLabel")
	level_label.name = "Level"
	box.add_child(level_label)
	var need := armor_rules.xp_to_next(level)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.BRONZE)
	bar.name = "XpBar"
	bar.max_value = maxf(1.0, need)
	bar.value = character.armor_mastery.xp(type) if need > 0 else bar.max_value
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	# Menu UX Polish 1.1: name, level, bar and worn share only - bonuses and milestones are the details' (right)
	return card


## The bonuses of `type` active now, each stat once ("+0.4% Movement Speed"), "" when none.
func _armor_bonus_summary(type: int) -> String:
	var totals := {}   # stat -> summed effective value
	for entry in _armor_bonuses(type):
		if float(entry.value) > 0.0:
			totals[entry.stat] = float(totals.get(entry.stat, 0.0)) + float(entry.value)
	var parts: PackedStringArray = []
	for stat: StringName in totals:
		parts.append("%s %s" % [_milestone_value_text(stat, totals[stat]), Stats.display_name(stat).trim_suffix(" %") if stat != ArmorMasteryRules.IRON_DISCIPLINE else "movement penalty"])
	return ", ".join(parts)


## The chosen track: level, XP to the next level (or Mastered), how much is worn now (slots), every milestone with
## its state and effective value, the next one; how mastery grows. Scrolls inside.
func _show_armor_detail(type: int) -> void:
	var detail := _content.find_child("ArmorDetail", true, false) as PanelContainer
	var box := detail.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	var armor_rules := ArmorMasteryService.rules(character)
	var level := character.armor_mastery.level(type)
	var coverage := float(ArmorMasteryService.coverage(character)[type])
	var width := _armor_detail_width() - 20
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP)
	var title := UiTheme.styled("%s Mastery" % ArmorMasteryService.TYPE_NAMES[type], &"SubheadingLabel")
	title.name = "ArmorTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(HelpButton.make("# Mastery XP\nMastery grows from kills and from blocking or parrying enemy attacks while you wear this type - by the share you wear.\nIts bonuses count at that share; not worn, they are inactive.\nMastery never changes what you wear; burden comes from the gear alone.", "MasteryHelp"))
	box.add_child(head)
	var need := armor_rules.xp_to_next(level)
	var progress := UiTheme.styled(("Level %d / %d  ·  XP %d / %d to level %d" % [level, armor_rules.max_level, floori(character.armor_mastery.xp(type)), need, level + 1]) if need > 0
		else "Level %d / %d  ·  Mastered" % [level, armor_rules.max_level], &"SmallLabel")
	progress.name = "ArmorProgress"
	box.add_child(progress)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT, UiTheme.BRONZE)
	bar.max_value = maxf(1.0, need)
	bar.value = character.armor_mastery.xp(type) if need > 0 else bar.max_value
	box.add_child(bar)
	var worn_slots: PackedStringArray = []
	var types := ArmorMasteryService.worn_types(character)
	for index in ArmorMasteryRules.SLOTS.size():
		if types[index] == type:
			worn_slots.append(EquipSlot.NAMES[ArmorMasteryRules.SLOTS[index]])
	var worn := UiTheme.styled(("Worn now: %d%% (%s) - bonuses count at that share." % [roundi(coverage * 100.0), ", ".join(worn_slots)]) if coverage > 0.0
		else "Not worn now - its bonuses are inactive.", &"CaptionLabel")
	worn.name = "ArmorWorn"
	worn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	worn.custom_minimum_size.x = width
	worn.add_theme_color_override(&"font_color", UiTheme.RESONANCE if coverage > 0.0 else UiTheme.TEXT_SECONDARY)
	box.add_child(worn)
	var summary := _armor_bonus_summary(type)
	var bonus := UiTheme.wrapped("Active now: %s" % summary if summary != "" else ("Bonuses inactive - not worn." if not _armor_bonuses(type).is_empty() else "No bonus yet."),
		UiTheme.SUCCESS if summary != "" else UiTheme.TEXT_SECONDARY, width)
	bonus.name = "Bonus"
	bonus.theme_type_variation = &"SmallLabel"
	box.add_child(bonus)
	var next := "Mastered - every milestone reached."
	for milestone: Array in ArmorMasteryRules.MILESTONES:
		if int(milestone[0]) == type and level < int(milestone[1]):
			next = "Next: Lv %d  %s" % [int(milestone[1]), _milestone_text(milestone[2], float(milestone[3]))]
			break
	var next_label := UiTheme.wrapped(next, UiTheme.WARNING if level < armor_rules.max_level else UiTheme.SUCCESS, width)
	next_label.name = "Next"
	next_label.theme_type_variation = &"SmallLabel"
	box.add_child(next_label)
	var scroll := ScrollContainer.new()
	scroll.name = "ArmorDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override(&"separation", 3)
	scroll.add_child(lines)
	lines.add_child(UiTheme.section("Milestones"))
	var bonuses := _armor_bonuses(type)
	var next_shown := false
	for milestone: Array in ArmorMasteryRules.MILESTONES:
		if int(milestone[0]) != type:
			continue
		var at := int(milestone[1])
		var reached := level >= at
		var state := ""
		var color := UiTheme.TEXT_MUTED
		if reached:
			var value := 0.0
			for entry in bonuses:
				if int(entry.level) == at:
					value = float(entry.value)
			state = "now %s" % _milestone_value_text(milestone[2], value) if coverage > 0.0 else "reached - inactive, not worn"
			color = UiTheme.SUCCESS if coverage > 0.0 else UiTheme.TEXT_SECONDARY
		elif not next_shown:
			state = "next"
			color = UiTheme.WARNING
			next_shown = true
		if color == UiTheme.TEXT_MUTED:
			color = UiTheme.TEXT_SECONDARY   # later milestones stay readable (Menu UX Polish 1.1)
		var line := UiTheme.wrapped("Lv %d  ·  %s%s" % [at, _milestone_text(milestone[2], float(milestone[3])), "  ·  " + state if state != "" else ""], color, width)
		line.name = "Milestone%d" % at
		line.theme_type_variation = &"SmallLabel"
		lines.add_child(line)


func _armor_detail_width() -> float:
	return body_room().x - ARMOR_CARD.x * 2 - UiTheme.GAP - UiTheme.GAP * 3 - 40


## Gives the detail the height the window leaves under the burden card (the window itself never scrolls); the
## 2x2 cards keep their compact height (Menu UX Polish 1.1: no stretched empty cards).
func layout_armor() -> void:
	var detail := _content.find_child("ArmorDetail", true, false) as Control
	if page != "Armor" or detail == null or not is_inside_tree():
		return
	var area := detail.get_parent() as Control
	var grid := area.get_node("Tracks") as GridContainer
	for card: Control in grid.get_children():
		card.custom_minimum_size.y = ARMOR_CARD.y
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	var height := maxf(ARMOR_AREA_MIN_HEIGHT, floorf(body_room().y - others - 6.0))
	detail.custom_minimum_size.y = height
	queue_fit()


func _milestone_text(stat: StringName, value: float) -> String:
	if stat == ArmorMasteryRules.IRON_DISCIPLINE:
		return "Iron Discipline: up to %s point less burden movement penalty" % _num(value)
	return "+%s%% %s" % [_num(value), Stats.display_name(stat).trim_suffix(" %")]


static func _num(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


## Quests (Skills & Talents UX 2.0 Phase 5, docs/SKILLS_TALENTS_UX_2_0.md): "How do I unlock another class?" -
## the class unlock quests (character-wide, one per class; prepared quests of unplayable classes stay hidden) as a
## compact list on the left (name, status, the class it unlocks, a short progress), the chosen quest on the right:
## status, description, objectives with progress, deliveries against the bag, requirements, the reward (the class
## unlock) and the one action the quest allows now (Take quest / Turn in - QuestService, at a class station) with
## its reason when locked. Choosing a quest never takes, advances or turns it in.
func _build_quests() -> void:
	var quests := class_quests()
	if quests.is_empty():
		_content.add_child(UiTheme.wrapped("No class quests right now.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
		return
	var chosen := selected_quest()
	var area := HBoxContainer.new()
	area.name = "QuestArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_content.add_child(area)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "QuestListScroll"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(QUEST_LIST_WIDTH, SKILL_AREA_MIN_HEIGHT)
	area.add_child(list_scroll)
	var list := VBoxContainer.new()
	list.name = "QuestList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	list_scroll.add_child(list)
	var group := ButtonGroup.new()
	for quest in quests:
		list.add_child(_quest_entry(quest, group, quest.id == chosen))
	var detail := UiTheme.card(&"CardPanel")
	detail.name = "QuestDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.y = SKILL_AREA_MIN_HEIGHT
	area.add_child(detail)
	_show_quest_detail(character.database.quests.get(chosen))
	layout_quests()
	layout_quests.call_deferred()


## The class quests the tab shows: every available one (QuestService order); unavailable = a class that is not
## playable yet (hidden, as before).
func class_quests() -> Array[ClassQuestDefinition]:
	var result: Array[ClassQuestDefinition] = []
	for quest in QuestService.quests_for(character):
		if quest.available:
			result.append(quest)
	return result


## The chosen quest: the last one chosen, else the first ready / active / available one, else the first.
func selected_quest() -> StringName:
	var quests := class_quests()
	if quests.any(func(q: ClassQuestDefinition) -> bool: return q.id == _quest_selected):
		return _quest_selected
	for wanted: String in ["Ready to Turn In", "Active", "Available"]:
		for quest in quests:
			if quest_status(quest) == wanted:
				return quest.id
	return quests[0].id if not quests.is_empty() else &""


## Chooses `quest_id` (gold entry) and shows it - never takes, advances or turns in a quest.
func select_quest(quest_id: StringName) -> void:
	_quest_selected = quest_id
	if page == "Quests":
		rebuild()


## The quest's status from the real state (QuestLog + QuestService): "Locked" (cannot be taken: the reason is
## QuestService.can_start), "Available", "Active", "Ready to Turn In" (objectives done, deliveries in the bag),
## "Completed", or "Class unlocked" (not taken - the class is already unlocked, e.g. by the prologue choice).
func quest_status(quest: ClassQuestDefinition) -> String:
	match character.quests.state(quest.id):
		"completed":
			return "Completed"
		"active":
			return "Ready to Turn In" if QuestService.can_turn_in(character, quest.id, true) == "" else "Active"
	if character.classes.is_unlocked(quest.class_id):
		return "Class unlocked"
	return "Available" if QuestService.can_start(character, quest.id) == "" else "Locked"


static func quest_status_color(status: String) -> Color:
	match status:
		"Available":
			return UiTheme.PARCHMENT
		"Active":
			return UiTheme.RESONANCE
		"Ready to Turn In":
			return UiTheme.WARNING
		"Completed":
			return UiTheme.SUCCESS
	return UiTheme.TEXT_MUTED


func _quest_class_name(quest: ClassQuestDefinition) -> String:
	var definition := character.database.get_class_def(quest.class_id)
	return definition.display_name if definition != null else String(quest.class_id)


## Short progress: "5/8 · 2/2 items" while active, the lock reason while locked, else the class it unlocks.
func _quest_progress_text(quest: ClassQuestDefinition, status: String) -> String:
	if status == "Locked":
		return QuestService.can_start(character, quest.id).trim_suffix(".")
	if status != "Active" and status != "Ready to Turn In":
		return "Unlocks %s" % _quest_class_name(quest)
	var parts: PackedStringArray = []
	for index in quest.objectives.size():
		parts.append("%d/%d" % [floori(character.quests.progress(quest.id, index) + 0.0001), roundi(quest.objectives[index].amount)])
	var have := 0
	for cost in quest.deliveries:
		if character.inventory.count(cost.item_id) >= cost.quantity:
			have += 1
	if not quest.deliveries.is_empty():
		parts.append("%d/%d items" % [have, quest.deliveries.size()])
	return "  ·  ".join(parts)


## One list entry (CardButton toggle: chosen = gold card, focus = cyan): name, "status · short progress".
func _quest_entry(quest: ClassQuestDefinition, group: ButtonGroup, chosen: bool) -> Button:
	var status := quest_status(quest)
	var entry := Button.new()
	entry.name = "Quest_%s" % quest.id
	entry.theme_type_variation = &"CardButton"
	entry.toggle_mode = true
	entry.button_group = group
	entry.set_pressed_no_signal(chosen)
	entry.custom_minimum_size.y = QUEST_ENTRY_HEIGHT
	entry.tooltip_text = "%s - %s" % [quest.display_name, status]
	entry.pressed.connect(select_quest.bind(quest.id))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	texts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	entry.add_child(texts)
	var title := UiTheme.styled(quest.display_name, &"SmallLabel")
	title.name = "QuestName"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override(&"font_color", UiTheme.TEXT_PRIMARY if status != "Locked" else UiTheme.TEXT_SECONDARY)
	texts.add_child(title)
	var line := UiTheme.styled("%s  ·  %s" % [status, _quest_progress_text(quest, status)], &"CaptionLabel")
	line.name = "QuestStatus"
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_theme_color_override(&"font_color", quest_status_color(status))
	texts.add_child(line)
	return entry


## The chosen quest: title, status, then in QuestDetailScroll the description, objectives (progress bars),
## deliveries (bag count), requirements and the reward; the action footer (Take quest / Turn in) with its reason.
func _show_quest_detail(quest: ClassQuestDefinition) -> void:
	var detail := _content.find_child("QuestDetail", true, false) as PanelContainer
	var box := detail.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	if quest == null:
		var none := UiTheme.styled("Choose a quest on the left.", &"MenuMetaLabel")
		none.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
		box.add_child(none)
		return
	var status := quest_status(quest)
	var state := character.quests.state(quest.id)
	var width := _quest_detail_width() - 20
	var title := UiTheme.styled(quest.display_name, &"MenuTitleLabel")
	title.name = "QuestTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = width
	box.add_child(title)
	var meta := UiTheme.styled("%s  ·  Class quest: %s" % [status, _quest_class_name(quest)], &"MenuMetaLabel")
	meta.name = "QuestState"
	meta.add_theme_color_override(&"font_color", quest_status_color(status))
	box.add_child(meta)
	var scroll := ScrollContainer.new()
	scroll.name = "QuestDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override(&"separation", UiTheme.GAP - 2)
	scroll.add_child(lines)
	# Menu UX Polish 1.1: the short context text, then the tasks as progress rows ("Defeat hollow creatures 5/8",
	# "Hollow Essence 2/3", "Gold Coin 137/20") - counts and amounts only here, never in the text
	lines.add_child(UiTheme.menu_text(quest.description, UiTheme.TEXT_SECONDARY, width))
	# objectives: progress counts only once the quest is taken
	if not quest.objectives.is_empty():
		lines.add_child(UiTheme.section("Objectives"))
	for index in quest.objectives.size():
		var objective := quest.objectives[index]
		var value := character.quests.progress(quest.id, index) if state != "" else 0.0
		var done := value + 0.0001 >= objective.amount
		var row := _progress_row(objective.description, "%d/%d" % [floori(value + 0.0001), roundi(objective.amount)], done)
		row.name = "QuestObjective%d" % index
		lines.add_child(row)
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.SUCCESS if done else UiTheme.BRONZE)
		bar.max_value = maxf(1.0, objective.amount)
		bar.value = minf(value, objective.amount)
		bar.custom_minimum_size.x = width
		lines.add_child(bar)
	# deliveries against the bag: what you have / what is needed
	if not quest.deliveries.is_empty():
		lines.add_child(UiTheme.section("Deliver at a class station"))
	for cost in quest.deliveries:
		var item := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		var row := _progress_row(item.display_name if item else String(cost.item_id), "%d/%d" % [have, cost.quantity], have >= cost.quantity)
		row.name = "QuestDelivery_%s" % cost.item_id
		lines.add_child(row)
	# requirements (what can_start checks): all met = one compact line; anything open is listed on its own
	var checks: Array = []
	if quest.requires_prologue:
		checks.append(["Prologue completed", character.prologue.is_completed()])
	checks.append(["%s not unlocked yet" % _quest_class_name(quest), state != "" or not character.classes.is_unlocked(quest.class_id)])
	lines.add_child(UiTheme.section("Requirements"))
	var met: PackedStringArray = []
	for check: Array in checks:
		if check[1]:
			met.append(check[0])
		else:
			lines.add_child(_quest_check(check[0], false))
	if not met.is_empty():
		var all_met := UiTheme.wrapped(("All met: " if met.size() == checks.size() else "Met: ") + "  ·  ".join(met), UiTheme.SUCCESS, width)
		all_met.name = "QuestRequirementsMet"
		all_met.theme_type_variation = &"MenuMetaLabel"
		lines.add_child(all_met)
	lines.add_child(UiTheme.section("Reward"))
	var reward := UiTheme.wrapped("Unlocks the %s class for good.%s" % [_quest_class_name(quest), " Turning in uses up the deliveries." if not quest.deliveries.is_empty() else ""],
		UiTheme.TEXT_PRIMARY, width)
	reward.name = "QuestReward"
	reward.theme_type_variation = &"MenuTextLabel"
	lines.add_child(reward)
	# the one action this quest allows now, and why not when locked
	var action: Button = null
	var reason := ""
	if status == "Class unlocked":   # nothing to do: no action, no lock reason
		var unlocked := UiTheme.wrapped("%s is already unlocked - this quest is not needed." % _quest_class_name(quest), UiTheme.TEXT_MUTED, width)
		unlocked.name = "QuestActionHint"
		unlocked.theme_type_variation = &"MenuMetaLabel"
		box.add_child(unlocked)
		return
	if state == "":
		reason = QuestService.can_start(character, quest.id)
		action = _station_button("Take quest", func() -> void:
			_say(QuestService.start(character, quest.id), "Quest taken: %s." % quest.display_name), reason == "", reason, &"PrimaryButton")
		action.name = "Start"
	elif state == "active":
		reason = QuestService.can_turn_in(character, quest.id, at_station())
		action = _station_button("Turn in", func() -> void:
			_say(QuestService.turn_in(character, quest.id, at_station()), "Quest complete - class unlocked!"), reason == "", reason, &"PrimaryButton")
		action.name = "TurnIn"
	if action != null and reason == "" and not at_station():
		reason = tr("UI_ONLY_AT_STATION")
	# only a reason (or the completed state) is said; what the action does is its tooltip
	var hint_text := reason if reason != "" else ("Completed - %s is unlocked." % _quest_class_name(quest) if state == "completed" else "")
	if action != null and reason == "":
		action.tooltip_text = "Takes the quest; its objectives count from now on." if state == "" else "Hands in the deliveries and unlocks %s." % _quest_class_name(quest)
	if hint_text != "":
		var hint := UiTheme.wrapped(hint_text, UiTheme.WARNING if reason != "" else UiTheme.TEXT_MUTED, width)
		hint.name = "QuestActionHint"
		hint.theme_type_variation = &"MenuMetaLabel"
		box.add_child(hint)
	if action != null:
		box.add_child(action)


## One task row: the task on the left, "have/need" on the right; done = success colour and a check word.
func _progress_row(text: String, count: String, done: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	var label := UiTheme.styled(text, &"MenuTextLabel")
	label.name = "Task"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", UiTheme.SUCCESS if done else UiTheme.TEXT_PRIMARY)
	row.add_child(label)
	var amount := UiTheme.styled(count + ("  done" if done else ""), &"MenuTextLabel")
	amount.name = "Count"
	amount.add_theme_color_override(&"font_color", UiTheme.SUCCESS if done else UiTheme.TEXT_SECONDARY)
	row.add_child(amount)
	return row


## "Met · text" / "Open · text" in success / warning colour (a requirement met or still open).
func _quest_check(text: String, met: bool) -> Label:
	var label := UiTheme.styled(("Met  ·  " if met else "Not met  ·  ") + text, &"MenuTextLabel")
	label.add_theme_color_override(&"font_color", UiTheme.SUCCESS if met else UiTheme.WARNING)
	return label


func _quest_detail_width() -> float:
	return body_room().x - QUEST_LIST_WIDTH - UiTheme.GAP * 3 - 40


## Gives the quest list and the detail the height the window leaves (the window itself never scrolls).
func layout_quests() -> void:
	var list_scroll := _content.find_child("QuestListScroll", true, false) as Control
	if page != "Quests" or list_scroll == null or not is_inside_tree():
		return
	var area := list_scroll.get_parent() as Control
	var others := body.get_combined_minimum_size().y - area.get_combined_minimum_size().y
	var height := maxf(SKILL_AREA_MIN_HEIGHT, floorf(body_room().y - others - 6.0))
	list_scroll.custom_minimum_size.y = height
	(area.get_node("QuestDetail") as Control).custom_minimum_size.y = height
	queue_fit()


## One fixed frame for all pages: the main window frame (Main Window Layout Lock 1.0) - it never resizes
## or moves when the page changes and the registers stay put. Taller pages scroll inside the body; the
## talent trees fit themselves into the body room (layout_trees).


func _relayout_trees() -> void:
	if page == "Talents":
		layout_trees.call_deferred()
	elif page == "Skills":
		layout_skills.call_deferred()
	elif page == "Presets":
		layout_presets.call_deferred()
	elif page == "Quests":
		layout_quests.call_deferred()
	elif page == "Classes":
		layout_classes.call_deferred()
	elif page == "Armor":
		layout_armor.call_deferred()


func _restore_tree_scroll() -> void:
	if _tree_scroll == null or not is_instance_valid(_tree_scroll) or _keep_scroll == Vector2i(-1, -1):
		return
	# the room is still settling and the (four-tier) row fits for a moment: keep the
	# position for the next layout instead of losing it at 0
	var bars := [_tree_scroll.get_h_scroll_bar(), _tree_scroll.get_v_scroll_bar()]
	if _keep_scroll.x > bars[0].max_value - bars[0].page or _keep_scroll.y > bars[1].max_value - bars[1].page:
		return
	_tree_scroll.scroll_horizontal = _keep_scroll.x
	_tree_scroll.scroll_vertical = _keep_scroll.y
	_keep_scroll = Vector2i(-1, -1)
	if talent_tooltip.visible:
		talent_tooltip._place.call_deferred()


# --- Weapon Mastery ---------------------------------------------------------------

## Weapon Mastery 1.4: the nine families with level, XP and their combo paths
## (unlock level, inputs, name). Character-wide, shared by every class; a level
## only unlocks attacks, never a passive bonus. Read-only over WeaponMastery.
## Skills & Talents UX 2.0 Phase 1 (docs/SKILLS_TALENTS_UX_2_0.md): "What can my weapon do?" - only the family of
## the equipped main-hand weapon (CharacterEquipment.main_hand_family; there is exactly one weapon slot):
## overview (name, mastery level, XP), the combo grid (an icon per combo, unlock level, locked dimmed), and the
## details of the chosen combo. Choosing a combo only shows it - it never changes inputs or fights.
## No weapon: a short empty state (unarmed attacks use the rules' fallback family - said so, not shown as mastery).
func _build_weapons() -> void:
	var family_id := character.equipment.main_hand_family()
	var family: WeaponFamily = character.database.weapons.get(family_id) if family_id != &"" else null
	if family == null:
		_content.add_child(_weapons_empty())
		return
	var mastery := character.mastery
	var level := mastery.get_level(family.id)
	var entries := ComboIcons.entries(family)
	_content.add_child(_weapon_overview(family, level, entries))
	if not entries.any(func(e: Dictionary) -> bool: return e.key == _weapon_combo.get(family.id, "")):
		_weapon_combo[family.id] = entries[0].key
	var area := HBoxContainer.new()
	area.name = "ComboArea"
	area.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_content.add_child(area)
	var grid := GridContainer.new()
	grid.name = "Combos"
	grid.columns = COMBO_COLUMNS
	grid.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	grid.add_theme_constant_override(&"v_separation", UiTheme.GAP)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var group := ButtonGroup.new()
	for entry: Dictionary in entries:
		grid.add_child(_combo_cell(family, entry, level, group))
	area.add_child(grid)
	var detail := UiTheme.card(&"CardPanel")
	detail.name = "ComboDetail"
	detail.custom_minimum_size = Vector2(COMBO_DETAIL_WIDTH, 0)
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	area.add_child(detail)
	_show_combo(family, _weapon_combo[family.id])
	var legend := UiTheme.styled("L  left click, quick  ·  P  left click while holding right, precision" if family.is_bow()
		else "L  left click, quick  ·  H  right click, heavy", &"CaptionLabel")
	legend.name = "Legend"
	legend.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	_content.add_child(legend)


## Name, mastery level, XP bar and the next unlock of the wielded family.
func _weapon_overview(family: WeaponFamily, level: int, entries: Array[Dictionary]) -> Control:
	var card := UiTheme.card(&"CardPanel")
	card.name = "WeaponMastery"
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var title := UiTheme.styled(family.display_name, &"SubheadingLabel")
	title.name = "Family"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var max_level := character.database.get_track(family.id).max_level if character.database.get_track(family.id) != null else level
	var level_label := UiTheme.styled("Mastery %d / %d" % [level, max_level], &"SmallLabel")
	level_label.name = "Level"
	head.add_child(level_label)
	box.add_child(head)
	var need := character.mastery.xp_to_next(family.id)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT, UiTheme.BRONZE)
	bar.name = "MasteryBar"
	bar.max_value = maxf(1.0, need)
	bar.value = character.mastery.get_xp(family.id) if need > 0 else bar.max_value
	box.add_child(bar)
	var next: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.level > level and (next.is_empty() or entry.level < next.level):
			next = entry
	var hint := "XP %d / %d  ·  %s" % [character.mastery.get_xp(family.id), need,
		"next: %s at %d" % [next.name, next.level] if not next.is_empty() else "every combo unlocked"] if need > 0 else "Mastered  ·  every combo unlocked"
	var hint_label := UiTheme.styled(hint, &"CaptionLabel")
	hint_label.name = "Progress"
	box.add_child(hint_label)
	return card


## One combo of the grid: its icon (dimmed while locked), name and unlock level; a toggle in one group (selected =
## gold card, focus = the separate cyan outline); hover tells name, inputs and the state.
func _combo_cell(family: WeaponFamily, entry: Dictionary, level: int, group: ButtonGroup) -> Button:
	var unlocked: bool = level >= entry.level
	var button := Button.new()
	button.name = "Combo_%s" % entry.key
	button.theme_type_variation = &"CardButton"
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = COMBO_CELL
	button.tooltip_text = "%s  (%s)\n%s" % [entry.name, ComboIcons.input_label(entry),
		"Unlocked" if unlocked else "Locked - mastery %d" % entry.level]
	button.pressed.connect(_show_combo.bind(family, entry.key))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 4)
	button.add_child(box)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = UiSkin.texture(ComboIcons.icon_id(family, entry.sequence))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = UiTheme.SKILL_ICON_SIZE * COMBO_ICON_GRID
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		icon.modulate = Color(0.45, 0.45, 0.45)   # the icon is dimmed, the name stays readable (Menu UX Polish 1.1)
	box.add_child(icon)
	var name_label := UiTheme.styled(entry.name, &"CaptionLabel")
	name_label.name = "ComboTitle"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # whole names, two lines at most
	name_label.max_lines_visible = 2
	name_label.custom_minimum_size.x = COMBO_CELL.x - 12
	name_label.add_theme_color_override(&"font_color", UiTheme.TEXT_PRIMARY if unlocked else UiTheme.TEXT_SECONDARY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	# locked: a padlock word with the level, not only the colour
	var state := UiTheme.styled("Locked · Lv %d" % entry.level if not unlocked else ("Base" if entry.level <= 1 else "Lv %d" % entry.level), &"CaptionLabel")
	state.name = "State"
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_color_override(&"font_color", UiTheme.SUCCESS if unlocked else UiTheme.WARNING)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(state)
	return button


## Shows the chosen combo in the detail card (and marks its cell); it never changes a fight or an input.
func _show_combo(family: WeaponFamily, key: String) -> void:
	_weapon_combo[family.id] = key
	var detail := _content.find_child("ComboDetail", true, false) as PanelContainer
	if detail == null:
		return
	var entry: Dictionary = {}
	for candidate: Dictionary in ComboIcons.entries(family):
		if candidate.key == key:
			entry = candidate
	var grid := _content.find_child("Combos", true, false)
	for cell: Node in grid.get_children():
		(cell as Button).set_pressed_no_signal(cell.name == "Combo_%s" % key)
	var box := detail.get_node("Box") as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if entry.is_empty():
		return
	var level := character.mastery.get_level(family.id)
	var unlocked: bool = level >= entry.level
	var head := VBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP)
	var icon := TextureRect.new()
	icon.name = "DetailIcon"
	icon.texture = UiSkin.texture(ComboIcons.icon_id(family, entry.sequence))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = UiTheme.SKILL_ICON_SIZE * COMBO_ICON_DETAIL   # whole multiple: crisp
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		icon.modulate = Color(0.45, 0.45, 0.45)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := UiTheme.styled(entry.name, &"SubheadingLabel")
	title.name = "ComboName"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(title)
	var inputs := HBoxContainer.new()
	inputs.name = "Inputs"
	inputs.add_theme_constant_override(&"separation", 4)
	if entry.sequence == ComboIcons.FLOWING_DRAW:
		inputs.add_child(UiTheme.key_chip("Hold LMB"))
	else:
		for input: String in String(entry.sequence).split("", false):
			inputs.add_child(UiTheme.key_chip(input))
	names.add_child(inputs)
	head.add_child(names)
	box.add_child(head)
	var state := UiTheme.styled(("Unlocked" if unlocked else "Locked") + ("  ·  base attack" if entry.level <= 1
		else "  ·  mastery %d%s" % [entry.level, "" if unlocked else " (now %d)" % level]), &"SmallLabel")
	state.name = "ComboState"
	state.add_theme_color_override(&"font_color", UiTheme.SUCCESS if unlocked else UiTheme.WARNING)
	box.add_child(state)
	# the data's text, unless it only repeats inputs and name ("L-L-H: Splitting Strike.")
	if String(entry.description) != "" and entry.description != "%s: %s." % [ComboIcons.input_label(entry), entry.name]:
		box.add_child(UiTheme.wrapped(entry.description, UiTheme.TEXT_SECONDARY, COMBO_DETAIL_WIDTH - 40))
	for line: String in _combo_facts(entry):
		var fact := UiTheme.styled(line, &"SmallLabel")
		fact.add_theme_color_override(&"font_color", UiTheme.TEXT_PRIMARY)
		box.add_child(fact)


## What the finishing attack really does, from its data (no invented values).
func _combo_facts(entry: Dictionary) -> PackedStringArray:
	var facts: PackedStringArray = []
	var attack := entry.attack as AttackDefinition
	if attack == null:
		return facts
	facts.append("Final hit: %s" % ("precision" if attack.effect_tags.has(&"precision") else ("heavy" if attack.effect_tags.has(&"heavy") else "quick")))
	if attack.lunge_distance > 0.0:
		facts.append("Moves you %s %d px" % ["forward" if is_zero_approx(attack.lunge_angle) else "aside", roundi(attack.lunge_distance)])
	if attack.max_hits_per_target > 1:
		facts.append("Hits each target up to %d times" % attack.max_hits_per_target)
	if attack.projectile_count > 1:
		facts.append("Fires %d projectiles" % attack.projectile_count)
	return facts


## No weapon in the main hand: say what happens and where to change it - no mastery is shown as active.
func _weapons_empty() -> Control:
	var card := UiTheme.card(&"InsetPanel")
	card.name = "NoWeapon"
	var box := card.get_node("Box") as VBoxContainer
	box.add_child(UiTheme.styled("No weapon equipped", &"SubheadingLabel"))
	var fallback: WeaponFamily = character.database.weapons.get(character.database.rules.fallback_weapon_family)
	var text := "Equip a weapon in the Inventory [I] to see its mastery and combos."
	if fallback != null:
		text += " Unarmed, you strike with the %s basics." % fallback.display_name
	box.add_child(UiTheme.wrapped(text, UiTheme.TEXT_SECONDARY, CONTENT_WIDTH - 40))
	return card
