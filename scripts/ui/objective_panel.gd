class_name ObjectivePanel
extends PanelContainer
## HUD list of the running trial's objectives (and a prologue hint on the
## prologue map), plus active class quests. Pure presentation.

var bridge: PlayerProgressionBridge
## Show the prologue hint even without a running trial (prologue map).
var show_prologue_hint: bool = false

var _title: Label
var _lines: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UiTheme.HUD_COLUMN_WIDTH, 0)
	var box := VBoxContainer.new()
	add_child(box)
	theme_type_variation = &"HudPanel"
	_title = UiTheme.styled("", &"SubheadingLabel")
	_title.add_theme_color_override(&"font_color", UiTheme.BRONZE)
	_title.add_theme_font_override(&"font", UiTheme.display_font())
	_lines = UiTheme.label("", UiTheme.TEXT_PRIMARY)
	_lines.add_theme_constant_override(&"line_spacing", 3)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	box.add_child(_title)
	box.add_child(_lines)
	var keys := UiTheme.styled("[J] Journal    [M] Map", &"CaptionLabel")
	box.add_child(keys)


func _process(_delta: float) -> void:
	if bridge == null or not bridge.is_bound():
		visible = false
		return
	refresh()


func refresh() -> void:
	var character := bridge.character
	var prologue := character.prologue
	var lines: PackedStringArray = []
	var trial: TrialDefinition = character.database.trials.get(prologue.active_trial)
	if trial != null:
		_title.text = trial.display_name
		var class_def := character.database.get_class_def(trial.class_id)
		lines.append(tr("UI_TRIAL_CLASS") % (class_def.display_name if class_def != null else String(trial.class_id)))
		var on_grounds := PrologueService.trial_for_map(character.database, character.world.current_map_id) == trial
		var has_finale := false
		for finale: bool in [false, true]:   # training goals, then (behind the gate) the trial area
			if finale and has_finale and on_grounds:
				lines.append(tr("UI_TRIAL_GATE_OPEN") if PrologueService.training_done(character, trial.id) else tr("UI_TRIAL_GATE_SEALED"))
			for index in trial.objectives.size():
				var objective := trial.objectives[index]
				has_finale = has_finale or objective.finale
				if objective.finale != finale:
					continue
				var value: float = prologue.trial_progress.get(index, 0.0)
				lines.append(("[x] " if value + 0.0001 >= objective.amount else "[ ] ") + ObjectiveRules.text(objective, value))
		lines.append(tr("UI_LEAVE_TRIAL_GROUNDS_HINT") if on_grounds else tr("UI_LEAVE_TRIAL_HINT"))
	elif show_prologue_hint and not prologue.is_completed():
		_title.text = tr("UI_PROLOGUE")
		var done := prologue.completed_trials.size()
		lines.append("Walk a class trial to choose your path (%d/3 walked)." % done)
		lines.append("Then choose your starting class at the Altar of Choice.")
	else:
		_title.text = ""
	var story := StoryService.tracker_lines(character)
	if not story.is_empty():
		if _title.text == "":
			_title.text = "Journey"
		elif not lines.is_empty():
			lines.append("")
		lines.append_array(story)
	var rewards := reward_lines(character)
	if not rewards.is_empty():   # NPC Quest Turn-ins T3: a hint, not a quest objective
		if _title.text == "":
			_title.text = "Journey"
		elif not lines.is_empty():
			lines.append("")
		lines.append_array(rewards)
	for quest_id in character.quests.active_ids():
		var quest: ClassQuestDefinition = character.database.quests.get(quest_id)
		if quest == null:
			continue
		if _title.text == "":
			_title.text = tr("UI_CLASS_QUESTS")
		lines.append(quest.display_name + ":")
		for index in quest.objectives.size():
			lines.append("  " + ObjectiveRules.text(quest.objectives[index], character.quests.progress(quest_id, index)))
	_lines.text = "\n".join(lines)
	visible = _title.text != ""


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
