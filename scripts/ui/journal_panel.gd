class_name JournalPanel
extends UiWindow
## Journal (J): Main Story · Side Quests · Haven.
## Main Story: the story quests with their steps (done / current / ahead) and
## counted objectives. Side Quests: the class quests. Haven: every ruin with its
## stage (Ruined -> Restored -> Revitalized), what it needs and whether that is
## possible yet. Read-only over QuestLog / StoryService / RestorationService.

const WIDTH := 760
const PAGES := ["Main Story", "Side Quests", "Haven"]

var character: Character
var page: String = "Main Story"

var _tabs: UiTabs
var _content: VBoxContainer


func _ready() -> void:
	set_title("Journal")
	set_close_text("Close [J / Esc]")
	_tabs = UiTabs.new()
	for id in PAGES:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(show_page)
	body.add_child(_tabs)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(WIDTH, 0)
	_content.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_content)


func open(target_character: Character, start_page: String = "") -> void:
	character = target_character
	show()
	show_page(start_page if start_page != "" else page)


func show_page(id: String) -> void:
	page = id
	_tabs.select(id)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match id:
		"Side Quests":
			_build_side()
		"Haven":
			_build_haven()
		_:
			_build_story()
	queue_fit()


# --- Main Story -------------------------------------------------------------------

func _build_story() -> void:
	var active: Array[StoryQuestDefinition] = []
	var done: Array[StoryQuestDefinition] = []
	for quest: StoryQuestDefinition in character.database.story_quests.values():
		match character.quests.state(quest.id):
			"active":
				active.append(quest)
			"completed":
				done.append(quest)
	if active.is_empty() and done.is_empty():
		_content.add_child(UiTheme.wrapped("Your story has not begun yet.", UiTheme.TEXT_SECONDARY, WIDTH))
		return
	_content.add_child(UiTheme.section("Current"))
	for quest in active:
		_content.add_child(_story_card(quest, true))
	if not done.is_empty():
		_content.add_child(UiTheme.section("Completed"))
		var order: Array[StringName] = _chain_order()
		done.sort_custom(func(a: StoryQuestDefinition, b: StoryQuestDefinition) -> bool: return order.find(a.id) < order.find(b.id))
		for quest in done:
			_content.add_child(_story_card(quest, false))


func _story_card(quest: StoryQuestDefinition, current: bool) -> Control:
	var card := UiTheme.card(&"SelectedCardPanel" if current else &"InsetPanel")
	card.name = "Story_%s" % quest.id
	var box := card.get_node("Box") as VBoxContainer
	box.add_child(UiTheme.styled(quest.chapter.to_upper(), &"CaptionLabel"))
	var title := UiTheme.heading(quest.display_name)
	if not current:
		title.add_theme_color_override(&"font_color", UiTheme.BRONZE_DIM)
	box.add_child(title)
	if not current:
		box.add_child(UiTheme.styled("Completed", &"SmallLabel"))
		var reward := reward_text(character, quest)
		if reward != "":   # NPC Quest Turn-ins T3: pending / received quest reward
			var line := UiTheme.wrapped(reward, UiTheme.SUCCESS if QuestRewardService.state(character, quest.id) == QuestRewardService.PENDING \
					else UiTheme.TEXT_MUTED, WIDTH - 40)
			line.name = "Reward"
			box.add_child(line)
		return card
	box.add_child(UiTheme.wrapped(quest.description, UiTheme.TEXT_SECONDARY, WIDTH - 40))
	var step_index := character.quests.step(quest.id)
	for index in quest.steps.size():
		var step := quest.steps[index]
		if index > step_index:
			break   # later steps stay hidden until they are reached
		var done := index < step_index
		var line := UiTheme.wrapped("%s  %s" % ["[done]" if done else "[now]", step.description], UiTheme.TEXT_MUTED if done else UiTheme.PARCHMENT, WIDTH - 40)
		box.add_child(line)
		if not done:
			for objective_index in step.objectives.size():
				var objective := step.objectives[objective_index]
				if objective.amount > 1:
					box.add_child(UiTheme.styled("      %s  %d / %d" % [objective.description, StoryService.objective_value(character, quest.id, objective_index), objective.amount], &"SmallLabel"))
	return card


## Reward line of a story quest from QuestRewardService (never QuestLog alone):
## pending -> where to collect it, claimed -> received, none -> "".
static func reward_text(target: Character, quest: StoryQuestDefinition) -> String:
	if quest.turn_in_gold <= 0:
		return ""
	match QuestRewardService.state(target, quest.id):
		QuestRewardService.PENDING:
			var npc: NpcDefinition = target.database.npcs.get(quest.turn_in_npc_id)
			return TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_PENDING") % [npc.display_name if npc != null else String(quest.turn_in_npc_id), quest.turn_in_gold]
		QuestRewardService.CLAIMED:
			return TranslationServer.translate("UI_QUEST_REWARD_JOURNAL_CLAIMED") % quest.turn_in_gold
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


# --- Side quests (class quests) --------------------------------------------------------

func _build_side() -> void:
	var shown := 0
	for quest in QuestService.quests_for(character):
		var state := character.quests.state(quest.id)
		if state == "" or not quest.available:
			continue
		shown += 1
		var card := UiTheme.card(&"CardPanel" if state == "active" else &"InsetPanel")
		card.name = "Side_%s" % quest.id
		var box := card.get_node("Box") as VBoxContainer
		var head := HBoxContainer.new()
		var title := UiTheme.styled(quest.display_name, &"SubheadingLabel")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		head.add_child(UiTheme.styled("ACTIVE" if state == "active" else "COMPLETED", &"CaptionLabel"))
		box.add_child(head)
		box.add_child(UiTheme.wrapped(quest.description, UiTheme.TEXT_SECONDARY, WIDTH - 40))
		for index in quest.objectives.size():
			box.add_child(UiTheme.styled("·  " + ObjectiveRules.text(quest.objectives[index], character.quests.progress(quest.id, index)), &"SmallLabel"))
		_content.add_child(card)
	if shown == 0:
		_content.add_child(UiTheme.wrapped("No side quests yet. Class quests are taken at a class station once your first path has taken root.", UiTheme.TEXT_SECONDARY, WIDTH))


# --- Haven -------------------------------------------------------------------------

func _build_haven() -> void:
	_content.add_child(UiTheme.wrapped("Haven's ruins are restored one by one. Each stage stays for good and is saved at once.", UiTheme.TEXT_SECONDARY, WIDTH))
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
	var title := UiTheme.styled(ruin.display_name, &"SubheadingLabel")
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
	box.add_child(UiTheme.styled(status, &"SmallLabel"))
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
