class_name QuestRewardPanel
extends UiWindow
## NPC Quest Turn-ins 1.0 T2 (docs/NPC_QUEST_TURNINS_1_0_T2.md): the quest reward window
## of an NPC (service &"quest_rewards", Edrin Vale). Lists the story quests whose reward is
## handed out by this NPC (data: StoryQuestDefinition.turn_in_npc_id) with their state from
## QuestRewardService - never from QuestLog alone. The footer action calls
## QuestRewardService.claim, the only source of success or refusal; the window keeps no
## state of its own and rebuilds from the service on open and after every claim.

const WIDTH := 520

var character: Character
## The NPC that opened the window (closes when the player walks away).
var site: Node2D
## Set by GameHud (the NPC's dialogue from the Talk button).
var hud: GameHud
var last_message: String = ""
var last_ok: bool = true

var _list: VBoxContainer
var _status: Label
var _claim_button: Button


func _ready() -> void:
	set_title(tr("UI_QUEST_REWARDS"))
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.TEXT_SECONDARY, WIDTH)
	_status.name = "Status"
	footer.add_child(_status)
	_claim_button = UiTheme.button(tr("UI_QUEST_REWARD_CLAIM"), &"PrimaryButton", claim)
	_claim_button.name = "ClaimReward"
	footer.add_child(_claim_button)


func open(target_character: Character, target_site: Node2D = null) -> void:
	character = target_character
	site = target_site
	last_message = ""
	show()
	rebuild()


## Keyboard focus on "Claim Reward" when a reward can be taken (it sits in the footer,
## which the base class does not search); otherwise the usual first body button.
func _focus_first() -> void:
	if visible and is_inside_tree() and _claim_button.is_visible_in_tree() and not _claim_button.disabled:
		_claim_button.grab_focus()
		return
	super()


func _process(_delta: float) -> void:
	if visible and site != null and (not is_instance_valid(site) or not site.get(&"player_inside")):
		hide()


func npc_id() -> StringName:
	var npc := site as StoryNpc
	return npc.npc_id if npc != null else &""


## The story quests whose reward this NPC hands out (data order).
func quests() -> Array[StoryQuestDefinition]:
	var result: Array[StoryQuestDefinition] = []
	if character == null:
		return result
	for quest: StoryQuestDefinition in character.database.story_quests.values():
		if quest.turn_in_gold > 0 and quest.turn_in_npc_id == npc_id():
			result.append(quest)
	result.sort_custom(func(a: StoryQuestDefinition, b: StoryQuestDefinition) -> bool: return String(a.id) < String(b.id))
	return result


## The first quest with a pending reward (the footer action), or null.
func pending_quest() -> StoryQuestDefinition:
	for quest in quests():
		if QuestRewardService.state(character, quest.id) == QuestRewardService.PENDING:
			return quest
	return null


func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var shown := 0
	for quest in quests():
		var state := QuestRewardService.state(character, quest.id)
		if state == QuestRewardService.NONE:
			continue   # no reward of this quest exists for the player (yet / any more)
		_list.add_child(_quest_card(quest, state))
		shown += 1
	if shown == 0:
		var empty := UiTheme.wrapped(tr("UI_QUEST_REWARDS_NONE"), UiTheme.TEXT_SECONDARY, WIDTH)
		empty.name = "NoRewards"
		_list.add_child(empty)
	var npc := site as StoryNpc
	var talk := DialogueService.pick(character, npc.definition()) if npc != null else null
	if talk != null and hud != null:   # the NPC's (already heard) talk stays reachable
		var button := UiTheme.button("Talk to %s" % npc.definition().display_name, &"", hud.open_dialogue.bind(talk))
		button.name = "Talk"
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_list.add_child(button)
	var pending := pending_quest()
	var error := QuestRewardService.can_claim(character, pending.id) if pending != null else ""
	footer.visible = pending != null or last_message != ""
	_claim_button.visible = pending != null
	_claim_button.disabled = pending == null or error != ""
	_claim_button.tooltip_text = error
	_status.text = last_message if last_message != "" else error
	var color := UiTheme.TEXT_SECONDARY
	if last_message != "":
		color = UiTheme.SUCCESS if last_ok else UiTheme.DANGER
	elif error != "":
		color = UiTheme.DANGER
	_status.add_theme_color_override(&"font_color", color)


func _quest_card(quest: StoryQuestDefinition, state: StringName) -> Control:
	var card := UiTheme.card(&"CardPanel" if state == QuestRewardService.PENDING else &"InsetPanel")
	card.name = "Reward_%s" % quest.id
	var box := card.get_node("Box") as VBoxContainer
	box.add_child(UiTheme.styled(quest.display_name, &"SubheadingLabel"))
	var reward := UiTheme.stat_row("Reward", tr("UI_QUEST_REWARD_GOLD") % quest.turn_in_gold, UiTheme.PARCHMENT)
	reward.name = "Gold"
	box.add_child(reward)
	if state == QuestRewardService.CLAIMED:
		var received := UiTheme.label(tr("UI_QUEST_REWARD_RECEIVED"), UiTheme.SUCCESS)
		received.name = "Received"
		box.add_child(received)
	return card


## Footer action (UI and tests): claims the pending reward through QuestRewardService.
## Returns "" or the reason; the message comes only from the service's answer.
func claim() -> String:
	var quest := pending_quest()
	if quest == null:   # double click / stale window: nothing to take, the last answer stays shown
		rebuild()
		return tr("UI_QUEST_REWARDS_NONE")
	_claim_button.disabled = true   # no second press while this one runs
	var session := SessionState.find(get_tree()) if is_inside_tree() else null
	var error := QuestRewardService.claim(character, quest.id, session)
	last_ok = error == ""
	last_message = error if error != "" else tr("UI_QUEST_REWARD_SUCCESS") % quest.turn_in_gold
	rebuild()
	return error
