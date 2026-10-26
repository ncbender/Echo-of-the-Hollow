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
	_title = UiTheme.label("", UiTheme.COLOR_ACCENT)
	_lines = UiTheme.label("", UiTheme.COLOR_TEXT)
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
	box.add_child(_title)
	box.add_child(_lines)


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
		for index in trial.objectives.size():
			var objective := trial.objectives[index]
			var value: float = prologue.trial_progress.get(index, 0.0)
			lines.append(("[x] " if value + 0.0001 >= objective.amount else "[ ] ") + ObjectiveRules.text(objective, value))
		lines.append(tr("UI_LEAVE_TRIAL_HINT"))
	elif show_prologue_hint and not prologue.is_completed():
		_title.text = tr("UI_PROLOGUE")
		var done := prologue.completed_trials.size()
		lines.append("Try the three class trials (%d/3 done)." % done)
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
