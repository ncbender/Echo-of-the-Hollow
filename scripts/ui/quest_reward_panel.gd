class_name QuestRewardPanel
extends UiWindow
## NPC Quest Turn-ins 1.0 T2 (docs/NPC_QUEST_TURNINS_1_0_T2.md): the quest reward window
## of an NPC (service &"quest_rewards", Edrin Vale). Lists the story quests whose reward is
## handed out by this NPC (data: StoryQuestDefinition.turn_in_npc_id) with their state from
## QuestRewardService - never from QuestLog alone. The footer action calls
## QuestRewardService.claim, the only source of success or refusal; the window keeps no
## state of its own and rebuilds from the service on open and after every claim.
## 1.1 M2 (docs/NPC_QUEST_TURNINS_1_1_M2.md): mixed rewards (gold + materials) as one line per
## part; opened directly (Edrin, service &"quest_rewards") or from Mara's Hearth Flask window.
## Always scoped to the NPC of `site`: it never lists or claims another NPC's reward.

const WIDTH := 520
## The NPC services whose window reaches this one (the "?" marker needs a way to claim):
## the window itself, and the Hearth Flask window's "Quest Rewards" button.
const REWARD_SERVICES: Array[StringName] = [&"quest_rewards", &"hearth_flask"]

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
	if character != null and character.inventory.changed.is_connected(_on_inventory_changed):
		character.inventory.changed.disconnect(_on_inventory_changed)
	character = target_character
	site = target_site
	last_message = ""
	character.inventory.changed.connect(_on_inventory_changed)   # room made elsewhere: the claim unlocks
	show()
	rebuild()


func _exit_tree() -> void:
	if character != null and character.inventory.changed.is_connected(_on_inventory_changed):
		character.inventory.changed.disconnect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	if visible:
		if not last_ok:
			last_message = ""   # an old refusal (full bag) gives way to the current state
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
	return quests_for(character, npc_id())


## The story quests with a reward (QuestRewardService.has_reward) handed out by `npc`, by id.
static func quests_for(target: Character, npc: StringName) -> Array[StoryQuestDefinition]:
	var result: Array[StoryQuestDefinition] = []
	if target == null or npc == &"":
		return result
	for quest: StoryQuestDefinition in target.database.story_quests.values():
		if QuestRewardService.has_reward(quest) and quest.turn_in_npc_id == npc:
			result.append(quest)
	result.sort_custom(func(a: StoryQuestDefinition, b: StoryQuestDefinition) -> bool: return String(a.id) < String(b.id))
	return result


## True while `npc` has a pending or claimed reward to show (Mara's "Quest Rewards" button).
static func has_rewards_for(target: Character, npc: StringName) -> bool:
	for quest in quests_for(target, npc):
		if QuestRewardService.state(target, quest.id) != QuestRewardService.NONE:
			return true
	return false


## The reward as display parts: "30 Gold", "3 Timber", "2 Stone" (gold first, data order).
static func reward_parts(db: GameDatabase, quest: StoryQuestDefinition) -> PackedStringArray:
	var parts: PackedStringArray = []
	if quest.turn_in_gold > 0:
		parts.append(TranslationServer.translate("UI_QUEST_REWARD_GOLD") % quest.turn_in_gold)
	var items := QuestRewardService.reward_items(quest)
	for item_id: StringName in items:
		var definition := db.get_item(item_id)
		parts.append(TranslationServer.translate("UI_QUEST_REWARD_ITEM") % [int(items[item_id]),
				definition.display_name if definition != null else String(item_id)])
	return parts


## "30 Gold, 3 Timber and 2 Stone" (one part alone: "60 Gold").
static func reward_summary(db: GameDatabase, quest: StoryQuestDefinition) -> String:
	var parts := reward_parts(db, quest)
	if parts.size() <= 1:
		return "".join(parts)
	return TranslationServer.translate("UI_QUEST_REWARD_AND") % [", ".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1]]


## The player-facing text of a QuestRewardService answer (BAG_FULL has its own UI line).
static func reason_text(error: String) -> String:
	return TranslationServer.translate("UI_QUEST_REWARD_BAG_FULL") if error == QuestRewardService.BAG_FULL else error


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
	var service := npc.definition().service if npc != null and npc.definition() != null else &""
	if hud != null and service != &"" and service != &"quest_rewards":   # 1.1 M3: back to Mara's Hearth Flask
		var back := UiTheme.button(tr("UI_QUEST_REWARD_BACK"), &"", hud.open_npc_service.bind(service, site))
		back.name = "Back"
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_list.add_child(back)
	var pending := pending_quest()
	var error := reason_text(QuestRewardService.can_claim(character, pending.id)) if pending != null else ""
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
	var parts := reward_parts(character.database, quest)
	var items := QuestRewardService.reward_items(quest).keys()
	var offset := 1 if quest.turn_in_gold > 0 else 0
	for index in parts.size():
		var reward := UiTheme.stat_row("Reward" if index == 0 else "", parts[index], UiTheme.PARCHMENT)
		reward.name = "Gold" if index < offset else "Item_%s" % items[index - offset]
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
	last_message = reason_text(error) if error != "" else tr("UI_QUEST_REWARD_SUCCESS") % reward_summary(character.database, quest)
	rebuild()
	return error
