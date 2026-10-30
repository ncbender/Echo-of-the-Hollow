class_name JournalPanel
extends UiWindow
## Journal (J): Main Story · Side Quests · Class Quests · Completed · Haven (UI Window
## Foundation 1.0, docs/UI_WINDOW_FOUNDATION_1_0.md).
## Main Story: the prologue and main quest chain (StoryService.is_main_story) - current quests
## with their steps (done / current; later steps stay hidden) and the earlier chapters.
## Side Quests: active story quests outside the chain (The Lost Hunter ...). Class Quests: the
## class quests in progress. Completed: everything finished, grouped by kind, with reward lines.
## Haven: every ruin with its stage. Read-only over QuestLog / StoryService / QuestService /
## RestorationService.
## Main Window Layout Lock 1.0: the quest pages are a list (left: chapter, title, state, reward line - its own
## scroll area) and the details of the chosen quest (right: description, steps, objectives - its own scroll
## area); Haven is one list of ruins over the whole width. The tabs never scroll away.

## Width of the quest list and of the wrapped texts in the details (design px).
const LIST_WIDTH := 330
const WIDTH := 700
## Menu UX Polish 1.0: inner padding of a quest list entry (compact cards).
const ENTRY_PADDING := 8
const PAGES := ["Main Story", "Side Quests", "Class Quests", "Completed", "Haven"]

var character: Character
var page: String = "Main Story"
## The quest shown in the details (per page; the first listed one when none or gone).
var selected: Dictionary = {}   # page -> quest id
## Main Story: the earlier chapters unfolded (Menu UX Polish 1.1; folded by default, kept while the window lives).
var earlier_open: bool = false

var _tabs: UiTabs
var _list: VBoxContainer
var _list_scroll: ScrollContainer
## Detail pane (named _content: every card builder below adds to it).
var _content: VBoxContainer
var _detail_scroll: ScrollContainer
var _entries: Array = []   # [quest id, detail builder Callable, list button] in list order


func _ready() -> void:
	main_window = true   # Main Window Layout Lock 1.0
	set_title("Journal")
	set_close_text(tr("UI_CLOSE"))   # Menu UX Polish 1.0: no key hint shown (J / Esc still close)
	_tabs = UiTabs.new()
	for id in PAGES:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(show_page)
	body.add_child(_tabs)
	var split := HBoxContainer.new()
	split.name = "Split"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	body.add_child(split)
	_list_scroll = _pane("QuestList")
	_list_scroll.custom_minimum_size.x = LIST_WIDTH
	_list = _list_scroll.get_child(0) as VBoxContainer
	split.add_child(_list_scroll)
	_detail_scroll = _pane("QuestDetail")
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content = _detail_scroll.get_child(0) as VBoxContainer
	split.add_child(_detail_scroll)


func _pane(pane_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = pane_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	scroll.add_child(box)
	return scroll


func open(target_character: Character, start_page: String = "") -> void:
	character = target_character
	show()
	show_page(start_page if start_page != "" else page)


func show_page(id: String) -> void:
	if id != page:
		reset_scroll()   # a new page starts at its top (UI Usability 1.0)
		_list_scroll.scroll_vertical = 0
		_detail_scroll.scroll_vertical = 0
	page = id
	_tabs.select(id)
	for pane: VBoxContainer in [_list, _content]:
		for child in pane.get_children():
			pane.remove_child(child)
			child.queue_free()
	_entries.clear()
	_list_scroll.visible = id != "Haven"
	match id:
		"Side Quests":
			_build_side()
		"Class Quests":
			_build_class()
		"Completed":
			_build_completed()
		"Haven":
			_build_haven()
		_:
			_build_story()
	_show_selected()
	queue_fit()


## Shows the chosen quest of this page in the details (another entry clicked: only the details change).
func select_quest(quest_id: StringName) -> void:
	selected[page] = quest_id
	if page == "Main Story" and character != null and character.quests.state(quest_id) == "completed":
		earlier_open = true   # a chosen earlier chapter is shown in its list
	_detail_scroll.scroll_vertical = 0
	show_page(page)


func _show_selected() -> void:
	if _entries.is_empty():
		return
	var chosen: Array = _entries[0]
	for entry: Array in _entries:
		if entry[0] == selected.get(page, &""):
			chosen = entry
	selected[page] = chosen[0]
	for entry: Array in _entries:
		(entry[2] as Button).set_pressed_no_signal(entry == chosen)   # selected = gold card
	(chosen[1] as Callable).call()   # only the chosen quest's details are built


func _list_section(text: String) -> void:
	_list.add_child(UiTheme.section(text))


## One list entry (Menu UX Polish 1.1: for choosing - title and a compact status; chapter, description and the
## reward lines are the details'): a card button named "Entry_<id>". A pending reward adds "reward waiting".
func _entry(quest_id: StringName, title: String, state: String, details: Callable) -> void:
	var button := Button.new()
	button.name = "Entry_%s" % quest_id
	button.theme_type_variation = &"CardButton"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(LIST_WIDTH - 16, 0)
	button.pressed.connect(select_quest.bind(quest_id))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, ENTRY_PADDING)
	button.add_child(box)
	var head := UiTheme.styled(title, &"MenuTextLabel")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = LIST_WIDTH - 16 - ENTRY_PADDING * 2   # the entry's inner width: wraps as shown
	box.add_child(head)
	var pending := QuestRewardService.state(character, quest_id) == QuestRewardService.PENDING
	var status := UiTheme.styled(state + ("  ·  reward waiting" if pending else ""), &"MenuMetaLabel")
	status.name = "EntryState"
	if pending:
		status.add_theme_color_override(&"font_color", UiTheme.SUCCESS)
	box.add_child(status)
	for label: Control in box.find_children("*", "Label", true, false):
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(button)
	button.custom_minimum_size.y = box.get_combined_minimum_size().y + ENTRY_PADDING * 2   # in the tree: the theme's fonts count
	_entries.append([quest_id, details, button])


func _story_entry(quest: StoryQuestDefinition, current: bool) -> void:
	_entry(quest.id, quest.display_name, "In progress" if current else "Completed", func() -> void: _content.add_child(_story_card(quest, current)))


func _class_entry(quest: ClassQuestDefinition, active: bool) -> void:
	_entry(quest.id, quest.display_name, "In progress" if active else "Completed", func() -> void: _content.add_child(_class_card(quest, active)))


# --- Main Story -------------------------------------------------------------------

## Story quests of one kind (main or side) in one state, main ones in chain order.
func _story_quests(main: bool, state: String) -> Array[StoryQuestDefinition]:
	var main_ids := StoryService.main_story_ids(character.database)
	var result: Array[StoryQuestDefinition] = []
	for quest: StoryQuestDefinition in character.database.story_quests.values():
		if main_ids.has(quest.id) == main and character.quests.state(quest.id) == state:
			result.append(quest)
	var order: Array[StringName] = _chain_order()
	result.sort_custom(func(a: StoryQuestDefinition, b: StoryQuestDefinition) -> bool:
		return order.find(a.id) < order.find(b.id) if main else a.display_name < b.display_name)
	return result


func _build_story() -> void:
	var active := _story_quests(true, "active")
	var done := _story_quests(true, "completed")
	if active.is_empty() and done.is_empty():
		_empty("Your story has not begun yet.")
		return
	_list_section("Current")
	for quest in active:
		_story_entry(quest, true)
	if active.is_empty():
		_empty("The story waits for your next step.")
	if done.is_empty():
		return
	# Menu UX Polish 1.1: earlier chapters folded by default (open when nothing is current); one toggle shows them
	var open := earlier_open or active.is_empty()
	var waiting := done.any(func(quest: StoryQuestDefinition) -> bool: return QuestRewardService.state(character, quest.id) == QuestRewardService.PENDING)
	var toggle := UiTheme.button("%s  %s (%d)%s" % ["-" if open else "+", tr("UI_JOURNAL_EARLIER"), done.size(), "\n     reward waiting" if waiting else ""], &"", func() -> void:
		earlier_open = not open
		show_page(page))
	toggle.name = "EarlierChapters"
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.x = LIST_WIDTH - 16
	# Playtest Corrections 1.0: the reward hint on its own line, in the list's text size - the list never widens
	toggle.add_theme_font_size_override(&"font_size", UiTheme.FONT_MENU_TEXT)
	toggle.tooltip_text = "Completed chapters of the main story (also on the Completed page)."
	_list.add_child(toggle)
	if open:
		for quest in done:
			_story_entry(quest, false)


func _empty(text: String) -> void:
	var line := UiTheme.menu_text(text, UiTheme.TEXT_SECONDARY, WIDTH)
	line.name = "Empty"
	_content.add_child(line)   # in the details: the list stays a list


func _story_card(quest: StoryQuestDefinition, current: bool) -> Control:
	var card := UiTheme.card(&"SelectedCardPanel" if current else &"InsetPanel")
	card.name = "Story_%s" % quest.id
	var box := card.get_node("Box") as VBoxContainer
	box.add_child(UiTheme.styled(quest.chapter.to_upper(), &"CaptionLabel"))
	var title := UiTheme.styled(quest.display_name, &"MenuHeadingLabel")
	if not current:
		title.add_theme_color_override(&"font_color", UiTheme.BRONZE_DIM)
	box.add_child(title)
	if not current:
		box.add_child(UiTheme.styled("Completed", &"MenuMetaLabel"))
		box.add_child(UiTheme.menu_text(quest.description, UiTheme.TEXT_MUTED, WIDTH - 40))
		var reward := reward_text(character, quest)
		if reward != "":   # NPC Quest Turn-ins T3: pending / received quest reward
			var line := UiTheme.wrapped(reward, UiTheme.SUCCESS if QuestRewardService.state(character, quest.id) == QuestRewardService.PENDING \
					else UiTheme.TEXT_MUTED, WIDTH - 40)
			line.name = "Reward"
			line.theme_type_variation = &"MenuTextLabel"
			box.add_child(line)
		return card
	box.add_child(UiTheme.menu_text(quest.description, UiTheme.TEXT_SECONDARY, WIDTH - 40))
	var step_index := character.quests.step(quest.id)
	for index in quest.steps.size():
		var step := quest.steps[index]
		if index > step_index:
			break   # later steps stay hidden until they are reached
		var done := index < step_index
		var line := UiTheme.menu_text("%s  %s" % ["[done]" if done else "[now]", step.description], UiTheme.TEXT_MUTED if done else UiTheme.PARCHMENT, WIDTH - 40)
		box.add_child(line)
		if not done:
			for objective_index in step.objectives.size():
				var objective := step.objectives[objective_index]
				if objective.amount > 1:
					box.add_child(UiTheme.styled("      %s  %d / %d" % [objective.description, StoryService.objective_value(character, quest.id, objective_index), objective.amount], &"MenuMetaLabel"))
	return card


## Reward line of a story quest from QuestRewardService (never QuestLog alone):
## pending -> where to collect it, claimed -> received, none -> "". 1.1 M3: the reward parts
## come from QuestRewardPanel (gold only if > 0, then materials); a quest with a
## turn_in_place names it and lists the parts on a second line.
static func reward_text(target: Character, quest: StoryQuestDefinition) -> String:
	if not QuestRewardService.has_reward(quest):
		return ""
	match QuestRewardService.state(target, quest.id):
		QuestRewardService.PENDING:
			if quest.turn_in_place != "":
				return "%s\n%s" % [TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_PENDING_AT") % quest.turn_in_place,
						TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_PARTS") % ", ".join(QuestRewardPanel.reward_parts(target.database, quest))]
			var npc: NpcDefinition = target.database.npcs.get(quest.turn_in_npc_id)
			return TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_PENDING") % [npc.display_name if npc != null else String(quest.turn_in_npc_id),
					QuestRewardPanel.reward_summary(target.database, quest)]
		QuestRewardService.CLAIMED:
			return TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_CLAIMED") % QuestRewardPanel.reward_summary(target.database, quest)
	return ""


## Quest ids in story order (first quest, then the chain of next quests).
func _chain_order() -> Array[StringName]:
	var order: Array[StringName] = []
	var quest_id := StoryService.FIRST_QUEST
	while quest_id != &"" and not quest_id in order:
		order.append(quest_id)
		var quest: StoryQuestDefinition = character.database.story_quests.get(quest_id)
		quest_id = quest.next_quest_ids[0] if quest != null and not quest.next_quest_ids.is_empty() else &""
	return order


# --- Side quests, class quests, completed ---------------------------------------------

func _build_side() -> void:
	var active := _story_quests(false, "active")
	for quest in active:
		_story_entry(quest, true)
	if active.is_empty():
		_empty("No side quests in progress. People in Haven and out in the woods may need your help.")
	_completed_hint(_story_quests(false, "completed").size())


func _build_class() -> void:
	var shown := 0
	var done := 0
	for quest in QuestService.quests_for(character):
		var state := character.quests.state(quest.id)
		if not quest.available:
			continue
		if state == "completed":
			done += 1
		elif state == "active":
			shown += 1
			_class_entry(quest, true)
	if shown == 0:
		_empty("No class quests in progress. Class quests are taken at a class station once your first path has taken root.")
	_completed_hint(done)


func _completed_hint(count: int) -> void:
	if count > 0:
		_list.add_child(UiTheme.styled("%d completed - see Completed." % count, &"MenuMetaLabel"))


func _build_completed() -> void:
	var main := _story_quests(true, "completed")
	var side := _story_quests(false, "completed")
	var classes: Array[ClassQuestDefinition] = []
	for quest in QuestService.quests_for(character):
		if quest.available and character.quests.state(quest.id) == "completed":
			classes.append(quest)
	if main.is_empty() and side.is_empty() and classes.is_empty():
		_empty("Nothing completed yet.")
		return
	if not main.is_empty():
		_list_section("Main Story")
		for quest in main:
			_story_entry(quest, false)
	if not side.is_empty():
		_list_section("Side Quests")
		for quest in side:
			_story_entry(quest, false)
	if not classes.is_empty():
		_list_section("Class Quests")
		for quest in classes:
			_class_entry(quest, false)


func _class_card(quest: ClassQuestDefinition, active: bool) -> Control:
	var card := UiTheme.card(&"CardPanel" if active else &"InsetPanel")
	card.name = "Class_%s" % quest.id
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var title := UiTheme.styled(quest.display_name, &"MenuTitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.styled("ACTIVE" if active else "COMPLETED", &"CaptionLabel"))
	box.add_child(head)
	box.add_child(UiTheme.menu_text(quest.description, UiTheme.TEXT_SECONDARY, WIDTH - 40))
	if active:
		for index in quest.objectives.size():
			box.add_child(UiTheme.styled("·  " + ObjectiveRules.text(quest.objectives[index], character.quests.progress(quest.id, index)), &"MenuTextLabel"))
	return card


# --- Haven -------------------------------------------------------------------------

func _build_haven() -> void:
	_content.add_child(UiTheme.menu_text("Each restored stage stays for good.", UiTheme.TEXT_SECONDARY, WIDTH, &"MenuMetaLabel"))
	var ruins: Array = character.database.ruins.values()
	ruins.sort_custom(func(a: RuinDefinition, b: RuinDefinition) -> bool:
		return (1 if a.restorable else 0) > (1 if b.restorable else 0) if a.restorable != b.restorable else a.display_name < b.display_name)
	for ruin: RuinDefinition in ruins:
		_content.add_child(_ruin_card(ruin))


func _ruin_card(ruin: RuinDefinition) -> Control:
	var stage := RestorationService.stage(character, ruin.id)
	var card := UiTheme.card(&"CardPanel" if stage != RestorationService.RUINED else &"InsetPanel")
	card.name = "Ruin_%s" % ruin.id
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var title := UiTheme.styled(ruin.display_name, &"MenuTitleLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(StageTrack.make(stage))
	box.add_child(head)
	var next := RestorationService.next_stage(character, ruin)
	var status := "Revitalized." if stage == RestorationService.REVITALIZED else "Restored."
	if next != &"":
		var error := RestorationService.advance_error(character, ruin, next)
		var verb := "revitalize" if next == RestorationService.REVITALIZED else "restore"
		status = error if error != "" else "Ready to %s - visit the ruin in Haven." % verb
		if stage == RestorationService.RESTORED:
			status = "Restored. " + status
	box.add_child(UiTheme.styled(status, &"MenuMetaLabel"))
	return card


## "Ruined > Restored > Revitalized" with the reached stages marked in words.
class StageTrack:
	static func make(stage: StringName) -> HBoxContainer:
		var row := HBoxContainer.new()
		row.name = "Stages"
		row.add_theme_constant_override(&"separation", 4)
		var reached := [RestorationService.RUINED, RestorationService.RESTORED, RestorationService.REVITALIZED].find(stage)
		var names := ["Ruined", "Restored", "Revitalized"]
		for index in names.size():
			var label := UiTheme.styled(names[index], &"CaptionLabel")
			label.add_theme_color_override(&"font_color", UiTheme.BRONZE if index == reached else (UiTheme.TEXT_SECONDARY if index < reached else UiTheme.TEXT_MUTED))
			if index == reached:
				label.text = "[%s]" % names[index]
			row.add_child(label)
			if index < names.size() - 1:
				row.add_child(UiTheme.styled(">", &"CaptionLabel"))
		return row
