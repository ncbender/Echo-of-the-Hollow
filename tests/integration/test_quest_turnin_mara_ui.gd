extends TestCase
## NPC Quest Turn-ins 1.1 M3 (docs/NPC_QUEST_TURNINS_1_1_M3.md): guidance for the mixed reward of
## "The Broken Cart" - journal line (pending / received, all three parts), tracker hint naming
## "Mara in Haven" (also on the road), both open rewards side by side, marker and dialogue
## priority, Mara's windows (Flask button, Back, bag full, focus). Edrin's T3 texts unchanged.
## Reading the guidance never changes quest, save or entitlement state.
## Files only under user://test_saves/quest_turnin_mara_ui/.

const QUEST := &"the_broken_cart"
const BINDING := &"the_first_binding"
const CLAIMED := &"quest_reward_claimed.the_broken_cart"
const GOLD := &"gold_coin"
const TIMBER := &"timber"
const STONE := &"stone"
const FILLER := &"iron_sword"
const DIR := "user://test_saves/quest_turnin_mara_ui"
const JOURNAL_PENDING := "Reward available: Return to Mara in Haven.\nReward: 30 Gold, 3 Timber, 2 Stone."
const JOURNAL_CLAIMED := "Reward received: 30 Gold, 3 Timber and 2 Stone."
const TRACKER := "Collect your reward from Mara in Haven."
const EDRIN_PENDING := "Reward available: Return to Edrin Vale (60 Gold)."
const EDRIN_CLAIMED := "Reward received: 60 Gold."
const EDRIN_TRACKER := "Return to Edrin Vale for your reward."
const BAG_FULL := "Not enough inventory space. Make room to claim the full reward."
const TO_ROAD_END := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave"]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	session.saves.reset()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


# --- helpers ------------------------------------------------------------------------------------

func _dialogue(npc_id: StringName, dialogue_id: StringName) -> DialogueDefinition:
	for dialogue in (db.npcs[npc_id] as NpcDefinition).dialogues:
		if dialogue.id == dialogue_id:
			return dialogue
	return null


func _finish_the_cart() -> void:
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	DialogueService.finish(character, _dialogue(&"mara", &"mara_road_end"))
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "Mara's reward pending")


func _to_haven_welcomed() -> void:
	_finish_the_cart()
	StoryService.notify(character, &"enter:home_base")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_welcome"))


## Further until "The First Binding" is completed live: both rewards pending.
func _both_pending() -> void:
	_to_haven_welcomed()
	for event: StringName in [&"restore:old_smithy", &"talk:edrin_intro", &"enter:whispering_stone"]:
		StoryService.notify(character, event)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	for objective in (db.trials[&"trial_warrior"] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "class chosen")
	for event: StringName in [&"waystone:whispering_stone", &"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]:
		StoryService.notify(character, event)
	check_eq(QuestRewardService.state(character, BINDING), QuestRewardService.PENDING, "Edrin's reward pending")


func _hear_all(npc_id: StringName) -> void:
	for dialogue in (db.npcs[npc_id] as NpcDefinition).dialogues:
		character.world.set_flag(dialogue.done_flag())


func _clear_materials() -> void:
	for item_id: StringName in [TIMBER, STONE]:
		var held := character.inventory.count(item_id)
		if held > 0:
			character.inventory.remove_quantity(item_id, held)


func _open_map(map_id: StringName, scene: String) -> void:
	character.world.map_id = map_id
	session.set_character(character)
	get_tree().change_scene_to_file(scene)
	map = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 5:
		await get_tree().process_frame


func _open_haven() -> void:
	await _open_map(&"home_base", "res://scenes/maps/home_base.tscn")


func _mara() -> StoryNpc:
	return map.get_node("Mara") as StoryNpc


func _edrin() -> StoryNpc:
	return map.get_node("Edrin") as StoryNpc


func _stand_at(npc: StoryNpc) -> void:
	map.player.global_position = npc.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame


func _panel() -> QuestRewardPanel:
	return map.hud.quest_reward_panel


func _status() -> String:
	return (_panel().find_child("Status", true, false) as Label).text


func _button(window: Node, button_name: String) -> Button:
	return window.find_child(button_name, true, false) as Button


func _open_maras_rewards() -> bool:
	var mara := _mara()
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	if not check(map.hud.flask_panel.visible, "Mara opens the Hearth Flask"):
		return false
	var button := _button(map.hud.flask_panel, "QuestRewards")
	if not check(button != null, "Quest Rewards button"):
		return false
	button.pressed.emit()
	for i in 3:
		await get_tree().process_frame
	return check(_panel().visible, "Mara's reward window")


func _tracker_text() -> String:
	for panel in map.hud.find_children("*", "ObjectivePanel", true, false):
		var objective := panel as ObjectivePanel
		objective.refresh()
		return objective.full_text()
	return ""


func _journal_texts() -> PackedStringArray:
	var result := PackedStringArray()
	for label in map.hud.journal_panel.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	return result


func _state() -> String:
	var payload := character.to_dict()
	payload.erase("play_time")   # ticks with the map, not guidance
	for map_state: Dictionary in (payload.world.map_states as Dictionary).values():
		map_state.erase("fog")   # explored where the player stands (_stand_at), not guidance (Map & Fog of War 1.0)
	return JSON.stringify(payload)


# --- journal ---------------------------------------------------------------------------------------

func test_journal_lines_follow_the_reward_state() -> void:
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	check_eq(JournalPanel.reward_text(character, quest), "", "active quest: no reward line")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_road_end"))
	check_eq(JournalPanel.reward_text(character, quest), JOURNAL_PENDING, "pending: place and all three parts")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(JournalPanel.reward_text(character, quest), JOURNAL_CLAIMED, "claimed: all three parts")
	check(StoryService.is_completed(character, QUEST), "the quest stays completed")


func test_no_reward_line_without_entitlement() -> void:
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "completed", "step": 5, "progress": {}}   # completed before M2
	payload.world.flags["prologue.cart_done"] = true
	var warnings: PackedStringArray = []
	character = Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "none")
	check_eq(JournalPanel.reward_text(character, db.story_quests[QUEST]), "", "no journal line")
	check(not TRACKER in ObjectivePanel.reward_lines(character), "no tracker hint")
	character.world.set_flag(&"prologue.haven_discovered")
	await _open_haven()
	_hear_all(&"mara")
	check_eq(_mara().marker(), "", "no ?")


func test_material_only_and_gold_only_formats() -> void:
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	var gold := quest.turn_in_gold
	quest.turn_in_gold = 0   # synthetic: materials only
	_finish_the_cart()
	var pending := JournalPanel.reward_text(character, quest)
	check_eq(pending, "Reward available: Return to Mara in Haven.\nReward: 3 Timber, 2 Stone.", "materials only, pending")
	check(not "0 Gold" in pending, "no 0 Gold")
	check_eq(QuestRewardPanel.reward_parts(db, quest), PackedStringArray(["3 Timber", "2 Stone"]), "card rows")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(JournalPanel.reward_text(character, quest), "Reward received: 3 Timber and 2 Stone.", "materials only, received")
	quest.turn_in_gold = gold
	# Edrin's gold-only lines exactly as in T3
	var binding: StoryQuestDefinition = db.story_quests[BINDING]
	check_eq(binding.turn_in_place, "", "Edrin keeps the T3 lines")
	character.quests.entries[BINDING] = {"state": "completed", "step": 3, "progress": {}}
	character.world.set_flag(QuestRewardService.entitled_flag(BINDING))
	check_eq(JournalPanel.reward_text(character, binding), EDRIN_PENDING, "Edrin pending")
	check(EDRIN_TRACKER in ObjectivePanel.reward_lines(character), "Edrin's tracker hint")
	check_eq(QuestRewardService.claim(character, BINDING), "", "Edrin claimed")
	check_eq(JournalPanel.reward_text(character, binding), EDRIN_CLAIMED, "Edrin received")


func test_journal_window_shows_the_line_on_the_completed_card() -> void:
	_to_haven_welcomed()
	await _open_haven()
	map.hud.toggle_journal()
	for i in 3:
		await get_tree().process_frame
	check(map.hud.journal_panel.visible, "journal open")
	# Menu UX Polish 1.1: the list says "reward waiting"; the reward line itself is in the chosen quest's details
	var fold := map.hud.journal_panel.find_child("EarlierChapters", true, false) as Button
	check(fold != null and fold.text.contains("reward waiting"), "the folded earlier chapters say a reward is waiting")
	map.hud.journal_panel.select_quest(QUEST)
	for i in 2:
		await get_tree().process_frame
	check(JOURNAL_PENDING in _journal_texts(), "pending line on the card: %s" % [_journal_texts()])
	map.hud.close_windows()
	QuestRewardService.claim(character, QUEST)
	map.hud.toggle_journal()
	for i in 3:
		await get_tree().process_frame
	map.hud.journal_panel.select_quest(QUEST)
	for i in 2:
		await get_tree().process_frame
	check(JOURNAL_CLAIMED in _journal_texts(), "received line on the card")


# --- tracker --------------------------------------------------------------------------------------

func test_tracker_names_mara_in_haven_from_the_road_on() -> void:
	_finish_the_cart()
	check_eq(ObjectivePanel.reward_lines(character), PackedStringArray([TRACKER]), "one hint, naming Haven")
	await _open_map(&"old_road", "res://scenes/maps/old_road.tscn")
	check(TRACKER in _tracker_text(), "hint shown on the road: %s" % _tracker_text())
	var mara := map.get_node("Mara") as StoryNpc
	check(mara.marker() != "?", "the road Mara shows no ?")
	check(not mara.offers_service, "and offers no claim")
	check(StoryService.is_completed(character, QUEST) and not StoryService.is_active(character, QUEST), "never reactivated")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed (service)")
	check(not TRACKER in _tracker_text(), "hint gone at once")
	check(ObjectivePanel.reward_lines(character).is_empty(), "no reward lines")


func test_both_open_rewards_stay_findable_after_the_story_lines() -> void:
	_both_pending()
	var lines := ObjectivePanel.reward_lines(character)
	check_eq(lines.size(), 2, "two hints")
	check(TRACKER in lines and EDRIN_TRACKER in lines, "Mara and Edrin: %s" % [lines])
	await _open_haven()
	var text := _tracker_text()
	var story := StoryService.tracker_entries(character, true).map(func(e: Dictionary) -> String: return e.title)   # Combat HUD UX 2.0: title + goal
	check(not story.is_empty(), "a story hint is running")
	check(text.find(story[0]) >= 0 and text.find(story[0]) < text.find(TRACKER) and text.find(story[0]) < text.find(EDRIN_TRACKER),
			"story lines stay first: %s" % text)
	QuestRewardService.claim(character, BINDING)
	check(TRACKER in _tracker_text() and not EDRIN_TRACKER in _tracker_text(), "Edrin's claim removes only his hint")


func test_trial_lines_keep_priority() -> void:
	_finish_the_cart()
	StoryService.notify(character, &"enter:home_base")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_welcome"))
	for event: StringName in [&"restore:old_smithy", &"talk:edrin_intro", &"enter:whispering_stone"]:
		StoryService.notify(character, event)
	await _open_haven()
	# a running trial session (synthetic: entering a map ends a real one, as in quest_turnin_t2)
	character.prologue.stage = PrologueState.Stage.IN_PROGRESS
	character.prologue.active_trial = &"trial_warrior"
	character.classes.begin_trial(&"warrior", 1)
	var text := _tracker_text()
	var trial: TrialDefinition = db.trials[&"trial_warrior"]
	var panel := map.hud.find_children("*", "ObjectivePanel", true, false)[0] as ObjectivePanel
	check(panel.full_text().begins_with(trial.display_name), "the trial comes first, under its name (Combat HUD UX 2.0: the header stays Journey)")
	check(text.find(TRACKER) > text.find(tr("UI_TRIAL_CLASS") % db.get_class_def(trial.class_id).display_name), "reward hint after the trial lines")
	check_eq(QuestRewardService.claim(character, QUEST), "Finish or leave the current trial first.", "claim locked in the trial")
	character.classes.end_trial()
	character.prologue.active_trial = &""


# --- marker and dialogue priority ---------------------------------------------------------------

func test_haven_markers_and_priority() -> void:
	_finish_the_cart()
	StoryService.notify(character, &"enter:home_base")
	await _open_haven()
	var mara := _mara()
	check_eq(mara.marker(), "!", "unheard mara_welcome first")
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible, "the dialogue opens, not the flask")
	map.hud.close_windows()
	DialogueService.finish(character, _dialogue(&"mara", &"mara_welcome"))
	check_eq(mara.marker(), "?", "pending: ?")
	check_eq(_edrin().marker(), "", "Edrin: nothing yet")
	QuestRewardService.claim(character, QUEST)
	check_eq(mara.marker(), "", "claimed: no ?")


# --- Mara's windows ---------------------------------------------------------------------------------

func test_flask_rewards_back_talk_and_focus() -> void:
	_to_haven_welcomed()
	await _open_haven()
	_hear_all(&"mara")
	if not await _open_maras_rewards():
		return
	var focused := get_viewport().gui_get_focus_owner()
	check(focused != null and focused.name == &"ClaimReward", "focus on Claim Reward (got %s)" % [focused.name if focused != null else "none"])
	check(_button(_panel(), "Talk") != null, "Talk to Mara Veyne reachable")
	var back := _button(_panel(), "Back")
	check(back != null and back.text == "Back", "Back to the Hearth Flask")
	back.pressed.emit()
	await get_tree().process_frame
	check(map.hud.flask_panel.visible and not _panel().visible, "Back opens the Hearth Flask again")
	check(map.hud.flask_panel.find_child("Path_capacity", true, false) != null, "flask upgrades still there")
	check(_button(map.hud.flask_panel, "Talk") != null, "Talk in the flask window")


func test_edrins_window_has_no_back_and_pays_60() -> void:
	_both_pending()
	await _open_haven()
	_hear_all(&"edrin")
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	for i in 3:
		await get_tree().process_frame
	check(_panel().visible and _panel().npc_id() == &"edrin", "Edrin's window")
	check(_button(_panel(), "Back") == null, "no Back: the reward window is his service")
	var gold := character.inventory.count(GOLD)
	check_eq(_panel().claim(), "", "claimed")
	check_eq(character.inventory.count(GOLD), gold + 60, "60 gold")
	check_eq(_status(), "Received 60 Gold.", "T2 success text")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "Mara's untouched")


func test_bag_full_keeps_pending_and_room_unlocks_the_claim() -> void:
	_to_haven_welcomed()
	_clear_materials()
	await _open_haven()
	_hear_all(&"mara")
	while character.inventory.free_slots() > 1:
		character.inventory.add_item(FILLER, 1, ItemInstance.ORIGIN_FOUND)
	var gold := character.inventory.count(GOLD)
	if not await _open_maras_rewards():
		return
	var claim := _button(_panel(), "ClaimReward")
	check(claim.disabled, "disabled while the bag is full")
	check_eq(_status(), BAG_FULL, "bag-full text")
	check_eq(claim.tooltip_text, BAG_FULL, "bag-full tooltip")
	check_eq(_panel().claim(), QuestRewardService.BAG_FULL, "refused")
	check_eq(character.inventory.count(GOLD), gold, "no gold")
	check_eq(character.inventory.count(TIMBER) + character.inventory.count(STONE), 0, "no materials")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "pending")
	check_eq(_mara().marker(), "?", "still ?")
	for item in character.inventory.items():
		if item.definition_id == FILLER and character.inventory.takes_slot(item):   # a bag sword, never the worn one
			character.inventory.remove_instance(item.instance_id)
			break
	check(not claim.disabled or not _button(_panel(), "ClaimReward").disabled, "room: Claim Reward enabled")
	check_eq(_panel().claim(), "", "regular claim")
	check_eq(_status(), "Received 30 Gold, 3 Timber and 2 Stone.", "success text")
	check_eq(character.inventory.count(GOLD), gold + 30, "30 gold once")


# --- read-only guidance ---------------------------------------------------------------------------

func test_guidance_changes_no_state() -> void:
	_both_pending()
	var before := _state()
	JournalPanel.reward_text(character, db.story_quests[QUEST])
	ObjectivePanel.reward_lines(character)
	QuestRewardPanel.reward_summary(db, db.story_quests[QUEST])
	await _open_haven()
	_hear_all(&"mara")
	_hear_all(&"edrin")
	before = _state()   # map arrival may set its own flags; the guidance must not
	_mara().marker()
	_edrin().marker()
	_tracker_text()
	map.hud.toggle_journal()
	for i in 3:
		await get_tree().process_frame
	map.hud.close_windows()
	check(await _open_maras_rewards(), "window opened")
	map.hud.close_windows()
	check_eq(_state(), before, "journal, tracker, markers and windows change nothing")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still pending")
	check(not character.world.flags.has(CLAIMED), "no claimed flag")
	check_eq(SaveSystem.VERSION, 15, "save v15")
