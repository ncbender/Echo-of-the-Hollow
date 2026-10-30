class_name ObjectivePanel
extends PanelContainer
## HUD quest tracker "Journey" under the minimap (UI Layout Lock 1.0; Combat HUD UX 2.0, docs/COMBAT_HUD_UX_2_0.md).
## Collapsed: one slim header row ("JOURNEY", a "!" while a quest reward waits, the expand button) - nothing else.
## Expanded: per entry a short title and under it the concrete current goal - the running trial (its goals, the
## gate and the leave hint), the prologue hint on the prologue map, the main story (quest name + StoryService
## short_goal: the step's objective texts with counters, else its optional hud_goal, else the step text), up to
## MAX_SIDE side quests the same way (the full step text in their tooltip), "+N more in the Journal", the active
## class quests and the pending quest rewards. No narrative summaries, no chapter names, no key hints; goals
## wrap, they are never cut. Height follows the content; above `max_height` the one body scrolls.
## Pure presentation: no quest data, flag or save is touched; the collapsed state is a display preference of
## this session only.

const MAX_SIDE := 3
const WIDTH := UiTheme.HUD_COLUMN_WIDTH
## Compact panel padding (the HudPanel default is 10).
const PADDING_X := 8
const PADDING_Y := 6
const TITLE_SIZE := UiTheme.FONT_MENU_TEXT
const GOAL_SIZE := UiTheme.FONT_MENU_META

## Collapsed tracker (display only, kept across map changes, not saved).
static var collapsed: bool = false

var bridge: PlayerProgressionBridge
## Show the prologue hint even without a running trial (prologue map).
var show_prologue_hint: bool = false
## Largest height (design px) the HUD layout allows; 0 = unlimited.
var max_height: float = 0.0

var _title: Label
var _reward_mark: Label
var _toggle: Button
var _scroll: ScrollContainer
var _content: VBoxContainer
var _rewards: Label
var _signature: String = ""
## The shown entries, in order: {name, title, goal, tooltip, main}.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	theme_type_variation = &"HudPanel"
	var panel := (UiTheme.get_theme().get_stylebox(&"panel", &"HudPanel")).duplicate() as StyleBox
	panel.set_content_margin(SIDE_LEFT, PADDING_X)
	panel.set_content_margin(SIDE_RIGHT, PADDING_X)
	panel.set_content_margin(SIDE_TOP, PADDING_Y)
	panel.set_content_margin(SIDE_BOTTOM, PADDING_Y)
	add_theme_stylebox_override(&"panel", panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 4)
	add_child(box)
	var head := HBoxContainer.new()
	head.name = "Header"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_title = UiTheme.styled("Journey", &"MenuHeadingLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_title)
	_reward_mark = UiTheme.styled("!", &"MenuTextLabel")
	_reward_mark.name = "RewardMark"
	_reward_mark.add_theme_color_override(&"font_color", UiTheme.WARNING)
	_reward_mark.mouse_filter = Control.MOUSE_FILTER_STOP   # its tooltip names the waiting reward
	head.add_child(_reward_mark)
	_toggle = Button.new()
	_toggle.name = "Collapse"
	_toggle.flat = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.custom_minimum_size = Vector2(24, 20)
	_toggle.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	_toggle.add_theme_constant_override(&"h_separation", 0)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		_toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_toggle.pressed.connect(toggle_collapsed)
	head.add_child(_toggle)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_content)
	# open rewards sit below the scrolling body: never scrolled out of sight, never cut
	_rewards = _text(UiTheme.WARNING, GOAL_SIZE)
	_rewards.name = "Rewards"
	box.add_child(_rewards)


func _text(color: Color, font_size: int) -> Label:
	var label := UiTheme.label("", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_constant_override(&"line_spacing", 1)
	label.custom_minimum_size.x = WIDTH - 2 * PADDING_X
	return label


func _process(_delta: float) -> void:
	if bridge == null or not bridge.is_bound():
		visible = false
		return
	refresh()


func toggle_collapsed() -> void:
	collapsed = not collapsed
	refresh()


func refresh() -> void:
	var character := bridge.character
	var entries := tracker_entries(character, show_prologue_hint)
	var rewards := reward_lines(character)   # NPC Quest Turn-ins T3: a hint, not a quest objective
	var signature := "%s|%s|%s" % [JSON.stringify(entries), "\n".join(rewards), collapsed]
	if signature != _signature:
		_signature = signature
		_entries = entries
		_rebuild(entries, rewards)
	visible = not entries.is_empty() or not rewards.is_empty()
	_fit_height()


func _rebuild(entries: Array[Dictionary], rewards: PackedStringArray) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for entry in entries:
		var block := VBoxContainer.new()
		block.name = entry.name
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_constant_override(&"separation", 0)
		if entry.title != "":
			var title := _text(UiTheme.BRONZE if entry.main else UiTheme.TEXT_SECONDARY, TITLE_SIZE)
			title.name = "Title"
			title.text = entry.title
			block.add_child(title)
		if entry.goal != "":
			var goal := _text(UiTheme.TEXT_PRIMARY, GOAL_SIZE)
			goal.name = "Goal"
			goal.text = entry.goal
			block.add_child(goal)
		if entry.tooltip != "":
			block.tooltip_text = entry.tooltip
			block.mouse_filter = Control.MOUSE_FILTER_STOP   # the tooltip holds the full step text
		_content.add_child(block)
	_rewards.text = "\n".join(rewards)
	_scroll.visible = not collapsed and not entries.is_empty()
	_rewards.visible = not collapsed and not rewards.is_empty()
	_reward_mark.visible = collapsed and not rewards.is_empty()
	_reward_mark.tooltip_text = "\n".join(rewards)
	_toggle.text = "+" if collapsed else "-"
	_toggle.tooltip_text = "Expand the tracker" if collapsed else "Collapse the tracker"


## What the tracker lists, in order: [{name, title, goal, tooltip, main}] - trial, prologue hint, main story,
## side quests (MAX_SIDE, then "+N more in the Journal"), class quests. Only from quest data and progress.
static func tracker_entries(character: Character, prologue_hint: bool = false) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var prologue := character.prologue
	var trial: TrialDefinition = character.database.trials.get(prologue.active_trial)
	if trial != null:
		var lines: PackedStringArray = []
		var class_def := character.database.get_class_def(trial.class_id)
		lines.append(TranslationServer.translate("UI_TRIAL_CLASS") % (class_def.display_name if class_def != null else String(trial.class_id)))
		var on_grounds := PrologueService.trial_for_map(character.database, character.world.current_map_id) == trial
		var has_finale := false
		for finale: bool in [false, true]:   # training goals, then (behind the gate) the trial area
			if finale and has_finale and on_grounds:
				lines.append(TranslationServer.translate("UI_TRIAL_GATE_OPEN") if PrologueService.training_done(character, trial.id) else TranslationServer.translate("UI_TRIAL_GATE_SEALED"))
			for index in trial.objectives.size():
				var objective := trial.objectives[index]
				has_finale = has_finale or objective.finale
				if objective.finale != finale:
					continue
				var value: float = prologue.trial_progress.get(index, 0.0)
				lines.append(("[x] " if value + 0.0001 >= objective.amount else "[ ] ") + ObjectiveRules.text(objective, value))
		lines.append(TranslationServer.translate("UI_LEAVE_TRIAL_GROUNDS_HINT") if on_grounds else TranslationServer.translate("UI_LEAVE_TRIAL_HINT"))
		entries.append(_entry("Trial", trial.display_name, "\n".join(lines), "", true))
	elif prologue_hint and not prologue.is_completed():
		entries.append(_entry("Prologue", TranslationServer.translate("UI_PROLOGUE"), "Walk a class trial to choose your path (%d/3 walked).\nThen choose your starting class at the Altar of Choice." % prologue.completed_trials.size(), "", true))
	var index := 0
	for quest: Dictionary in StoryService.tracker_entries(character, true):
		entries.append(_entry("Main%d" % index, quest.title, quest.goal, "", true))
		index += 1
	var side := StoryService.tracker_entries(character, false)
	for i in mini(side.size(), MAX_SIDE):
		var step := StoryService.current_step(character, side[i].quest_id)
		entries.append(_entry("Side%d" % i, side[i].title, side[i].goal, step.description if step != null and step.description != side[i].goal else "", false))
	if side.size() > MAX_SIDE:
		entries.append(_entry("More", "", "+%d more in the Journal" % (side.size() - MAX_SIDE), "", false))
	index = 0
	for quest_id in character.quests.active_ids():
		var quest: ClassQuestDefinition = character.database.quests.get(quest_id)
		if quest == null:
			continue
		var goals: PackedStringArray = []
		for objective in quest.objectives.size():
			goals.append(ObjectiveRules.text(quest.objectives[objective], character.quests.progress(quest_id, objective)))
		entries.append(_entry("Class%d" % index, quest.display_name, "\n".join(goals), "", false))
		index += 1
	return entries


static func _entry(entry_name: String, title: String, goal: String, tooltip: String, main: bool) -> Dictionary:
	return {"name": entry_name, "title": title, "goal": goal, "tooltip": tooltip, "main": main}


## The body scrolls once the whole tracker would be taller than `max_height`.
func _fit_height() -> void:
	var content := _content.get_combined_minimum_size().y
	if max_height <= 0.0:
		_scroll.custom_minimum_size.y = content
		return
	var chrome := _title.get_combined_minimum_size().y + (_rewards.get_combined_minimum_size().y + 4.0 if _rewards.visible else 0.0) \
		+ 2.0 * PADDING_Y + 4.0
	_scroll.custom_minimum_size.y = clampf(content, 0.0, maxf(40.0, max_height - chrome))


## Everything the tracker shows, in order (tests, debugging): the entries' titles and goals, then the rewards.
## Collapsed: nothing (the header only).
func full_text() -> String:
	var parts: PackedStringArray = []
	if collapsed:
		return ""
	for entry in _entries:
		for part: String in [entry.title, entry.goal]:
			if part != "":
				parts.append(part)
	if _rewards.visible and _rewards.text != "":
		parts.append(_rewards.text)
	return "\n".join(parts)


## NPC Quest Turn-ins T3: one hint line per pending quest reward (QuestRewardService),
## also for completed quests; gone once claimed. Never an objective, never reactivates a quest.
## 1.1 M3: a quest with a turn_in_place names it ("Collect your reward from Mara in Haven."),
## so the hint may stand on the road although only the Haven NPC pays out.
static func reward_lines(character: Character) -> PackedStringArray:
	var lines: PackedStringArray = []
	for quest: StoryQuestDefinition in character.database.story_quests.values():
		if QuestRewardService.has_reward(quest) and QuestRewardService.state(character, quest.id) == QuestRewardService.PENDING:
			if quest.turn_in_place != "":
				lines.append(TranslationServer.translate("UI_QUEST_REWARD_TRACKER_AT") % quest.turn_in_place)
				continue
			var npc: NpcDefinition = character.database.npcs.get(quest.turn_in_npc_id)
			lines.append(TranslationServer.translate("UI_QUEST_REWARD_TRACKER") % (npc.display_name if npc != null else String(quest.turn_in_npc_id)))
	return lines
