class_name ClassStationPanel
extends UiWindow
## Class station / character window (docs/CLASS_DESIGN.md): classes, talents,
## skills and mods, build presets and class quests in five pages.
## Opened with G at a class station (everything allowed) or with C anywhere
## (overview + learning talents; rearranging, respecs, presets, class changes
## and quests need a class station). Pure presentation over TalentService,
## SkillBook, PresetService, QuestService and Character.switch_class.

const PAGES := ["Classes", "Talents", "Skills", "Presets", "Quests", "Armor"]
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
	get_viewport().size_changed.connect(func() -> void: layout_trees.call_deferred())


func open(target_character: Character, target_station: ClassStation, start_page: String = "") -> void:
	character = target_character
	station = target_station
	set_title(tr("UI_CLASS_STATION") if station != null else tr("UI_CHARACTER_WINDOW"))
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
	if definition.resource != null:
		_summary.add_child(_header_dot())
		_summary.add_child(_header_text(definition.resource.display_name, definition.resource.color.lerp(UiTheme.TEXT_PRIMARY, 0.4), resource_text(definition.resource)))
	if not definition.talent_tree_ids.is_empty():
		var free := TalentService.points_available(character, class_id)
		_summary.add_child(_header_dot())
		var points := _header_text("%d Talent Point%s" % [free, "" if free == 1 else "s"], UiTheme.RESONANCE if free > 0 else UiTheme.TEXT_SECONDARY,
			"%d of %d talent points free (one per class level from level %d)." % [free, TalentService.points_total(character, class_id), character.database.rules.talent_rules().first_point_level])
		points.name = "TalentPoints"
		_summary.add_child(points)
	if classes.in_trial():
		_summary.add_child(_header_dot())
		_summary.add_child(_header_text("Class Trial", UiTheme.WARNING, "A temporary trial: talents and skills reset when it ends."))
	_summary.add_child(_header_dot())
	var station_text := _header_text("At Class Station" if at_station() else "Away from Station", UiTheme.SUCCESS if at_station() else UiTheme.TEXT_SECONDARY,
		"Everything can be changed here." if at_station() else tr("UI_AWAY_FROM_STATION"))
	station_text.name = "StationStatus"
	_summary.add_child(station_text)
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


func _say(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.add_theme_color_override(&"font_color", UiTheme.DANGER if error != "" else UiTheme.SUCCESS)
	_status.visible = _status.text != ""
	_status.tooltip_text = _status.text   # full text if it is cut
	rebuild()


func _station_button(text: String, action: Callable, enabled: bool = true, reason: String = "", variation: StringName = &"") -> Button:
	var button := UiTheme.button(text, variation, action)
	button.disabled = not enabled or not at_station()
	button.tooltip_text = reason if reason != "" else ("" if at_station() else tr("UI_ONLY_AT_STATION"))
	return button


# --- Classes --------------------------------------------------------------------

## Compact cards (emblem, name, status, level, two short lines) on the left; the
## selected card's details (resource, playstyle, trees, requirements, Activate)
## on the right. Prepared classes (Guardian, Soulbinder) are not listed yet.
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


## Active first, then unlocked, then locked (only playable classes).
func class_order() -> Array:
	var classes := character.classes
	var rank := func(d: ClassDefinition) -> int:
		if classes.active_class_id == d.id:
			return 0
		if not d.playable:
			return 3
		return 1 if classes.is_unlocked(d.id) else 2
	# prepared classes (Guardian, Soulbinder) stay hidden until they are playable
	var definitions: Array = character.database.classes.values().filter(func(d: ClassDefinition) -> bool: return d.playable)
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

## Talents (Talent UI Polish 1.2): the three complete trees fill the window -
## a shared tier scale, one column per tree, tiers aligned across columns.
## TalentLayout picks normal (named nodes) or compact (icons) from the room
## left; only when even compact does not fit (200 %) the tree area scrolls.
## Node details: TalentTooltip on hover / keyboard focus (no details bar).
func _build_talents() -> void:
	var class_id := character.classes.active_class_id
	var trees := TalentService.trees_of(character.database, class_id)
	if trees.is_empty():
		_content.add_child(UiTheme.wrapped("This class has no talent trees.", UiTheme.TEXT_SECONDARY, CONTENT_WIDTH))
		return
	_tree_scroll = ScrollContainer.new()
	_tree_scroll.name = "TreeScroll"
	_tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tree_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content.add_child(_tree_scroll)
	var row := HBoxContainer.new()
	row.name = "Trees"
	row.add_theme_constant_override(&"separation", int(TalentLayout.TREE_GAP))
	_tree_scroll.add_child(row)
	_tier_scale = TalentTierScale.new()
	_tier_scale.name = "TierScale"
	_tier_scale.setup(character.database.rules.talent_rules())
	row.add_child(_tier_scale)
	for tree in trees:
		var view := TalentTreeView.new()
		view.name = "Tree_%s" % tree.id
		row.add_child(view)
		view.setup(character, class_id, tree)
		view.learn_requested.connect(_learn)
		view.node_hovered.connect(_on_talent_hovered.bind(view))
		_trees.append(view)
	var legend := _talent_legend()
	_content.add_child(legend)
	# header and legend wrap by width: once the window has its size, size the trees again
	legend.resized.connect(_relayout_trees)
	_tree_room = Vector2.ZERO
	layout_trees()
	layout_trees.call_deferred()
	_reshow_talent_tooltip.call_deferred()


## One caption line under the trees: states (frame + marker), kinds, rules.
func _talent_legend() -> Control:
	var legend := HFlowContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override(&"h_separation", UiTheme.GAP * 3)
	for entry: Array in [["Learned", UiTheme.BRONZE], ["Maxed", UiTheme.BRONZE], ["Available", UiTheme.RESONANCE], ["Locked", UiTheme.TEXT_MUTED]]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override(&"separation", 4)
		var swatch := Control.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var state: String = entry[0]
		var color: Color = entry[1]
		swatch.draw.connect(func() -> void:
			var rect := Rect2(Vector2.ZERO, swatch.size)
			swatch.draw_rect(rect, Color(UiTheme.BRONZE_DARK, 0.9) if state == "Maxed" else (Color(UiTheme.BRONZE_DARK, 0.55) if state == "Learned" else UiTheme.PANEL_INSET))
			swatch.draw_rect(rect.grow(-1.0), color, false, 1.5)
			if state == "Locked":
				TalentTreeView.draw_lock(swatch, rect.get_center() + Vector2(0, 1), color)
			elif state == "Available":
				swatch.draw_line(rect.get_center() - Vector2(4, 0), rect.get_center() + Vector2(4, 0), color, 2.0)
				swatch.draw_line(rect.get_center() - Vector2(0, 4), rect.get_center() + Vector2(0, 4), color, 2.0)
			elif state == "Maxed":
				swatch.draw_rect(rect.grow(-4.0), color, false, 1.0))
		item.add_child(swatch)
		item.add_child(UiTheme.styled(state, &"CaptionLabel"))
		legend.add_child(item)
	legend.add_child(TalentTreeView.kind_legend(TalentNodeDefinition.Kind.PASSIVE, "Passive"))
	legend.add_child(TalentTreeView.kind_legend(TalentNodeDefinition.Kind.ACTIVE, "Skill"))
	legend.add_child(TalentTreeView.kind_legend(TalentNodeDefinition.Kind.TRANSFORMATIVE, "Transformation"))
	var rules := character.database.rules.talent_rules()
	var rules_text := UiTheme.styled("1 point per level from %d  ·  a tier opens with points in its lower tiers  ·  hover a talent for details, click to learn" % rules.first_point_level, &"CaptionLabel")
	rules_text.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	legend.add_child(rules_text)
	return legend


## Sizes the trees from the room the window has left (TalentLayout) - the tree
## row fills it without scrolling whenever the normal or compact layout fits.
func layout_trees() -> void:
	if _tree_scroll == null or not is_instance_valid(_tree_scroll) or not is_inside_tree() or _trees.is_empty():
		return
	var limit := max_window_size() - _chrome_size()
	var others := body.get_combined_minimum_size().y - _tree_scroll.get_combined_minimum_size().y
	var room := Vector2(limit.x - 8.0, limit.y - others - 6.0)
	if room == _tree_room and talent_layout != null:
		return   # nothing changed (called again after every resize)
	_tree_room = room
	talent_layout = TalentLayout.pick(room, _trees.size())
	_tier_scale.apply(talent_layout)
	for view in _trees:
		view.apply(talent_layout)
	var content := talent_layout.content_size(_trees.size())
	var scroll_x := content.x > room.x
	var scroll_y := content.y > room.y
	var bar := 14.0
	_tree_scroll.custom_minimum_size = Vector2(minf(content.x + (bar if scroll_y else 0.0), room.x), minf(content.y + (bar if scroll_x else 0.0), maxf(room.y, 160.0)))
	queue_fit()
	if _keep_scroll != Vector2i(-1, -1):
		_restore_tree_scroll.call_deferred()   # after learning: same view as before (200 %)
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


## After a rebuild (learning a rank) the node whose tooltip was open shows it
## again - the mouse has not moved; leaving the node hides it as usual.
func _reshow_talent_tooltip() -> void:
	if page != "Talents" or not visible or _keep_tooltip == &"":
		return
	for view in _trees:
		if is_instance_valid(view) and view.button_for(_keep_tooltip) != null:
			var node_id := _keep_tooltip
			_keep_tooltip = &""
			_on_talent_hovered(node_id, view)
			return


func _learn(node_id: StringName) -> void:
	_keep_tooltip = node_id   # the mouse is on this node: its tooltip comes back after the rebuild
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

## Armor Mastery: total burden and tier with its penalties, what each armour
## slot holds, and the four tracks (level, XP, coverage, milestones with their
## effective, coverage-scaled bonus). Read-only over ArmorMasteryService.
func _build_armor() -> void:
	var armor_rules := ArmorMasteryService.rules(character)
	var points := ArmorMasteryService.burden(character)
	var tier := ArmorMasteryService.tier(points, armor_rules)
	var head := UiTheme.card(&"CardPanel")
	head.name = "Burden"
	var box := head.get_node("Box") as VBoxContainer
	var title := HBoxContainer.new()
	var heading := UiTheme.styled("Armor Burden", &"SubheadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	var tier_label := UiTheme.styled("%d  ·  %s" % [points, ArmorMasteryService.TIER_NAMES[tier]], &"SubheadingLabel")
	tier_label.name = "Tier"
	tier_label.add_theme_color_override(&"font_color", UiTheme.SUCCESS if tier == 0 else (UiTheme.WARNING if tier < 3 else UiTheme.DANGER))
	title.add_child(tier_label)
	box.add_child(title)
	var move := ArmorMasteryService.move_penalty(character)
	var recovery := ArmorMasteryService.recovery_penalty(character)
	box.add_child(UiTheme.wrapped("No penalty." if move <= 0.0 and recovery <= 0.0 else
		"-%s%% movement  ·  +%s%% attack recovery time" % [_num(move), _num(recovery)], UiTheme.TEXT_SECONDARY, CONTENT_WIDTH - 40))
	if ArmorMasteryService.iron_discipline(character) > 0.0:
		box.add_child(UiTheme.wrapped("Iron Discipline lowers the movement penalty by %s points." % _num(ArmorMasteryService.iron_discipline(character)), UiTheme.TEXT_SECONDARY, CONTENT_WIDTH - 40))
	box.add_child(UiTheme.styled("Light 0-14  ·  Balanced 15-25  ·  Burdened 26-37  ·  Heavy 38+. Dash and parry are never affected.", &"CaptionLabel"))
	var slots := HFlowContainer.new()
	slots.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	var types := ArmorMasteryService.worn_types(character)
	for index in ArmorMasteryRules.SLOTS.size():
		var slot: int = ArmorMasteryRules.SLOTS[index]
		var type_name: String = ArmorMasteryService.TYPE_NAMES.get(types[index], "-")
		slots.add_child(UiTheme.styled("%s: %s (%d)" % [EquipSlot.NAMES[slot], type_name, armor_rules.burden_of(types[index], index)], &"SmallLabel"))
	box.add_child(slots)
	_content.add_child(head)
	var grid := GridContainer.new()
	grid.name = "Tracks"
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	grid.add_theme_constant_override(&"v_separation", UiTheme.GAP)
	var covered := ArmorMasteryService.coverage(character)
	var bonuses := ArmorMasteryService.milestone_bonuses(character)
	for type: int in ArmorMasteryRules.TYPES:
		grid.add_child(_armor_track(type, float(covered[type]), bonuses, armor_rules))
	_content.add_child(grid)


func _armor_track(type: int, coverage: float, bonuses: Array[Dictionary], armor_rules: ArmorMasteryRules) -> Control:
	var card := UiTheme.card(&"InsetPanel")
	card.name = "Track_%s" % CharacterArmorMastery.KEYS[type]
	card.custom_minimum_size = Vector2((CONTENT_WIDTH - UiTheme.GAP) * 0.5, 0)
	var box := card.get_node("Box") as VBoxContainer
	var level := character.armor_mastery.level(type)
	var head := HBoxContainer.new()
	var name_label := UiTheme.styled(ArmorMasteryService.TYPE_NAMES[type], &"SubheadingLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var level_label := UiTheme.styled("Level %d / %d" % [level, armor_rules.max_level], &"SmallLabel")
	level_label.name = "Level"
	head.add_child(level_label)
	box.add_child(head)
	var need := armor_rules.xp_to_next(level)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.BRONZE)
	bar.max_value = maxf(1.0, need)
	bar.value = character.armor_mastery.xp(type) if need > 0 else bar.max_value
	box.add_child(bar)
	box.add_child(UiTheme.styled(("XP %d / %d" % [floori(character.armor_mastery.xp(type)), need] if need > 0 else "Mastered") + "  ·  worn: %d%%" % roundi(coverage * 100.0), &"CaptionLabel"))
	for milestone: Array in ArmorMasteryRules.MILESTONES:
		if int(milestone[0]) != type:
			continue
		var reached := level >= int(milestone[1])
		var text := "Lv %d  %s" % [int(milestone[1]), _milestone_text(milestone[2], float(milestone[3]))]
		if reached:
			var value := 0.0
			for entry: Dictionary in bonuses:
				if int(entry.type) == type and int(entry.level) == int(milestone[1]):
					value = float(entry.value)
			text += ("  ->  now %s points" if milestone[2] == ArmorMasteryRules.IRON_DISCIPLINE else "  ->  now +%s%%") % _num(value)
		var line := UiTheme.styled(text, &"SmallLabel")
		line.add_theme_color_override(&"font_color", UiTheme.SUCCESS if reached and coverage > 0.0 else (UiTheme.TEXT_SECONDARY if reached else UiTheme.TEXT_MUTED))
		box.add_child(line)
	return card


func _milestone_text(stat: StringName, value: float) -> String:
	if stat == ArmorMasteryRules.IRON_DISCIPLINE:
		return "Iron Discipline: up to %s point less burden movement penalty" % _num(value)
	return "+%s%% %s" % [_num(value), Stats.display_name(stat).trim_suffix(" %")]


static func _num(value: float) -> String:
	return str(snappedf(value, 0.1)).trim_suffix(".0")


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


## One fixed frame for all five pages (Book Tabs Stability Fix 1.3): the window
## always takes the whole room the canvas offers (minus the registers), so it
## never resizes or moves when the page changes and the registers stay put.
## Smaller pages sit inside it; taller ones scroll inside the body.
func preferred_body_size() -> Vector2:
	return (max_window_size() - _chrome_size()).max(Vector2.ZERO)


func _relayout_trees() -> void:
	if page == "Talents":
		layout_trees.call_deferred()


func fit() -> void:
	super()
	_place_status.call_deferred()   # the close button is laid out after the fit


## Bottom row, left of the Close button (outside the layout).
func _place_status() -> void:
	if _status == null or not is_inside_tree():
		return
	var close := close_button()
	var padding := get_theme_stylebox(&"panel").get_margin(SIDE_LEFT)
	_status.size = Vector2(maxf(0.0, close.global_position.x - global_position.x - padding * 2.0), close.size.y)
	_status.global_position = Vector2(global_position.x + padding, close.global_position.y)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _restore_tree_scroll() -> void:
	if _tree_scroll == null or not is_instance_valid(_tree_scroll) or _keep_scroll == Vector2i(-1, -1):
		return
	_tree_scroll.scroll_horizontal = _keep_scroll.x
	_tree_scroll.scroll_vertical = _keep_scroll.y
	_keep_scroll = Vector2i(-1, -1)
	if talent_tooltip.visible:
		talent_tooltip._place.call_deferred()
