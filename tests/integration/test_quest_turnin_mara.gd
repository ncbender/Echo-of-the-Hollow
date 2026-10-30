extends TestCase
## NPC Quest Turn-ins 1.1 M2 (docs/NPC_QUEST_TURNINS_1_1_M2.md): "The Broken Cart" earns 30 Gold,
## 3 Timber and 2 Stone, claimed from Mara in Haven through a "Quest Rewards" button in her
## unchanged Hearth Flask window (the T2 QuestRewardPanel, scoped to Mara). The road Mara
## (companion) is no turn-in place and shows no "?". The claim is the M1 all-or-nothing
## QuestRewardService.claim. Files only under user://test_saves/quest_turnin_mara/.

const QUEST := &"the_broken_cart"
const BINDING := &"the_first_binding"
const ENTITLED := &"quest_reward_entitled.the_broken_cart"
const CLAIMED := &"quest_reward_claimed.the_broken_cart"
const GOLD := &"gold_coin"
const TIMBER := &"timber"
const STONE := &"stone"
const FILLER := &"iron_sword"
const DIR := "user://test_saves/quest_turnin_mara"
## Story events until "The Broken Cart" waits for mara_road_end (its last step).
const TO_ROAD_END := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave"]
## From the road's end to "The First Binding" (as test_quest_turnin_t1).
const TO_THE_STONE := [&"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro",
		&"enter:whispering_stone"]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous: Character
var _previous_path: String
var _critical_saves: int = 0


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	_critical_saves = 0


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	if session.saves.save_started.is_connected(_on_save_started):
		session.saves.save_started.disconnect(_on_save_started)
	for path in SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


func _on_save_started(kind: SaveCoordinator.Kind) -> void:
	if kind == SaveCoordinator.Kind.CRITICAL:
		_critical_saves += 1


# --- helpers ------------------------------------------------------------------------------------

func _dialogue(npc_id: StringName, dialogue_id: StringName) -> DialogueDefinition:
	for dialogue in (db.npcs[npc_id] as NpcDefinition).dialogues:
		if dialogue.id == dialogue_id:
			return dialogue
	return null


## The real road chain; the quest completes by reading mara_road_end to the end.
func _finish_the_cart() -> void:
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, 4), "The Broken Cart waits for mara_road_end")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_road_end"))
	check(StoryService.is_completed(character, QUEST), "completed by mara_road_end")


## Up to Haven with Mara's welcome heard (her service window is reachable).
func _to_haven_welcomed() -> void:
	_finish_the_cart()
	StoryService.notify(character, &"enter:home_base")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_welcome"))


## Further to "The First Binding" completed (Edrin's 60 gold pending as well).
func _binding_completed() -> void:
	_to_haven_welcomed()
	for event: StringName in TO_THE_STONE.slice(2):
		StoryService.notify(character, event)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	for objective in (db.trials[&"trial_warrior"] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "class chosen")
	for event: StringName in [&"waystone:whispering_stone", &"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]:
		StoryService.notify(character, event)
	check_eq(QuestRewardService.state(character, BINDING), QuestRewardService.PENDING, "Edrin's reward pending")


func _clear_materials() -> void:
	for item_id: StringName in [TIMBER, STONE]:
		var held := character.inventory.count(item_id)
		if held > 0:
			character.inventory.remove_quantity(item_id, held)


func _fill_bag(leave_free: int = 0) -> void:
	while character.inventory.free_slots() > leave_free:
		character.inventory.add_item(FILLER, 1, ItemInstance.ORIGIN_FOUND)


func _snapshot() -> Dictionary:
	var state := {}
	for item in character.inventory.items():
		state[item.instance_id] = [item.definition_id, item.quantity]
	return state


func _reload() -> void:
	var warnings: PackedStringArray = []
	character = Character.from_dict(JSON.parse_string(JSON.stringify(character.to_dict())), db, warnings)


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


func _stand_at(npc: StoryNpc) -> void:
	map.player.global_position = npc.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame


func _panel() -> QuestRewardPanel:
	return map.hud.quest_reward_panel


func _button() -> Button:
	return _panel().find_child("ClaimReward", true, false) as Button


func _status() -> String:
	return (_panel().find_child("Status", true, false) as Label).text


func _texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if node == null:
		return result
	for label in node.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	return result


## Interact with Haven Mara (dialogues heard) and follow her "Quest Rewards" button.
func _open_maras_rewards() -> bool:
	var mara := _mara()
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	if not check(map.hud.flask_panel.visible, "Mara opens the Hearth Flask"):
		return false
	var button := map.hud.flask_panel.find_child("QuestRewards", true, false) as Button
	if not check(button != null and button.visible, "Quest Rewards button in the Flask window"):
		return false
	button.pressed.emit()
	await get_tree().process_frame
	return check(_panel().visible and not map.hud.flask_panel.visible, "Quest Rewards opens the reward window")


# --- data and entitlement ------------------------------------------------------------------------

func test_the_broken_cart_carries_the_mixed_reward() -> void:
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check_eq(quest.turn_in_gold, 30, "30 gold")
	check_eq(quest.turn_in_npc_id, &"mara", "at Mara")
	check_eq(QuestRewardService.reward_items(quest), {TIMBER: 3, STONE: 2}, "3 timber, 2 stone")
	check(db.get_item(TIMBER) != null and db.get_item(STONE) != null, "existing materials")
	check(QuestRewardService.validate_quest(db, quest).is_empty(), "valid: %s" % [QuestRewardService.validate_quest(db, quest)])
	check(StoryService.validate_data(db).is_empty(), "story data valid")
	# story contract unchanged
	check_eq(quest.steps.size(), 5, "five steps")
	check_eq(quest.steps[4].objectives[0].event_id, &"talk:mara_road_end", "ends with mara_road_end")
	check_eq(quest.completion_flag, &"prologue.cart_done", "completion flag")
	check_eq(quest.next_quest_ids, [&"shelter_among_the_trees"] as Array[StringName], "successor unchanged")
	check_eq(SaveSystem.VERSION, 15, "save v15")
	check_eq([QuestRewardService.NONE, QuestRewardService.PENDING, QuestRewardService.CLAIMED],
			[&"none", &"pending", &"claimed"], "no new reward states")


func test_live_completion_registers_the_claim_and_keeps_the_story() -> void:
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	var gold := character.inventory.count(GOLD)
	var timber := character.inventory.count(TIMBER)
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "nothing before the end")
	# a visit is not a completion: picking / opening the dialogue changes nothing
	check(DialogueService.pick(character, db.npcs[&"mara"]) == _dialogue(&"mara", &"mara_road_end"), "Mara offers mara_road_end")
	check(not character.world.flags.has(ENTITLED), "no entitlement from a dialogue pick")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_road_end"))
	check(StoryService.is_completed(character, QUEST), "completed as before")
	check(character.world.has_flag(&"prologue.cart_done"), "cart_done as before")
	check(StoryService.is_active(character, &"shelter_among_the_trees"), "successor started as before")
	check(character.world.has_flag(ENTITLED), "entitlement registered")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "pending")
	check_eq(character.inventory.count(GOLD), gold, "no gold on completion")
	check_eq(character.inventory.count(TIMBER), timber, "no timber on completion")
	DialogueService.finish(character, _dialogue(&"mara", &"mara_road_end"))   # replay
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still one pending claim")
	check_eq(character.inventory.count(GOLD), gold, "no gold from the replay")


func test_historical_completion_and_resettle_give_no_claim() -> void:
	for event: StringName in TO_ROAD_END:
		StoryService.notify(character, event)
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "completed", "step": 5, "progress": {}}   # completed before M2
	payload.world.flags["prologue.cart_done"] = true
	var warnings: PackedStringArray = []
	var old := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(old, QUEST), "historically completed")
	check_eq(QuestRewardService.state(old, QUEST), QuestRewardService.NONE, "no entitlement")
	check_eq(QuestRewardService.claim(old, QUEST), "There is no reward waiting for you.", "no claim")
	check(not QuestRewardPanel.has_rewards_for(old, &"mara"), "no Quest Rewards button for an old save")
	# resettle: the last step met but never settled live -> completes on load, no claim
	payload.quests[String(QUEST)] = {"state": "active", "step": 4, "progress": {"0": 1.0}}
	payload.world.flags.erase("prologue.cart_done")
	var resettled := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(resettled, QUEST), "resettle completes the quest")
	check(not resettled.world.flags.has(ENTITLED), "no entitlement from resettle")
	check(StoryService.resettle(resettled).is_empty(), "a second resettle moves nothing")
	check_eq(QuestRewardService.state(resettled, QUEST), QuestRewardService.NONE, "no claim")


# --- road Mara vs. Haven Mara --------------------------------------------------------------------

func test_road_mara_is_no_turn_in_place() -> void:
	_finish_the_cart()   # pending, still on the road (Mara follows)
	await _open_map(&"old_road", "res://scenes/maps/old_road.tscn")
	var mara := map.get_node("Mara") as StoryNpc
	check(mara is CompanionNpc and mara.visible, "the road Mara is the companion")
	check(not mara.offers_service, "no service on the road")
	check(not mara.has_pending_reward(), "no reachable reward on the road")
	check(mara.marker() != "?", "no reward ? on the road")
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	check(not _panel().visible and not map.hud.flask_panel.visible, "no reward or flask window on the road")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still pending")


func test_haven_mara_story_first_then_question_mark_until_the_claim() -> void:
	_finish_the_cart()
	StoryService.notify(character, &"enter:home_base")
	await _open_haven()
	var mara := _mara()
	check_eq(mara.marker(), "!", "unheard mara_welcome: ! first")
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible and not map.hud.flask_panel.visible, "mara_welcome is not skipped")
	map.hud.close_windows()
	DialogueService.finish(character, _dialogue(&"mara", &"mara_welcome"))
	check_eq(mara.marker(), "?", "pending and reachable: ?")
	check(mara.has_pending_reward(), "reward reachable from the Flask window")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(mara.marker(), "", "claimed: no marker")


func test_flask_window_keeps_its_service_and_reaches_the_rewards() -> void:
	_to_haven_welcomed()
	await _open_haven()
	var mara := _mara()
	for dialogue in mara.definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	check_eq((db.npcs[&"mara"] as NpcDefinition).service, &"hearth_flask", "Mara keeps the Hearth Flask")
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	var flask := map.hud.flask_panel
	check(flask.visible and not _panel().visible, "G opens the Hearth Flask as before")
	check(flask.find_child("Path_capacity", true, false) != null and flask.find_child("Path_potency", true, false) != null, "upgrade paths shown")
	check(flask.find_child("Talk", true, false) != null, "Talk to Mara stays reachable")
	var rewards := flask.find_child("QuestRewards", true, false) as Button
	check(rewards != null and rewards.text == "Quest Rewards", "Quest Rewards button")
	check(await _open_maras_rewards(), "reward window reached")
	check_eq(_panel().npc_id(), &"mara", "scoped to Mara")
	check(_panel().find_child("Talk", true, false) != null, "Talk to Mara in the reward window too")


func test_flask_without_a_reward_has_no_button() -> void:
	character.world.set_flag(&"prologue.haven_discovered")   # no live completion: no entitlement
	await _open_haven()
	var mara := _mara()
	for dialogue in mara.definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.flask_panel.visible, "flask opens")
	check(map.hud.flask_panel.find_child("QuestRewards", true, false) == null, "no Quest Rewards button")
	check_eq(mara.marker(), "", "no marker")


# --- the claim in Mara's window ------------------------------------------------------------------

func test_maras_card_and_one_full_claim() -> void:
	_to_haven_welcomed()
	_clear_materials()
	await _open_haven()
	for dialogue in _mara().definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	if not await _open_maras_rewards():
		return
	var panel := _panel()
	var card := panel.find_child("Reward_the_broken_cart", true, false)
	check(card != null, "The Broken Cart listed")
	check(_texts(card).has("The Broken Cart"), "title")
	check(_texts(panel.find_child("Gold", true, false)).has("30 Gold"), "30 Gold")
	check(_texts(panel.find_child("Item_timber", true, false)).has("3 Timber"), "3 Timber")
	check(_texts(panel.find_child("Item_stone", true, false)).has("2 Stone"), "2 Stone")
	check(panel.find_child("Reward_the_first_binding", true, false) == null, "no Edrin card at Mara")
	var button := _button()
	check(button != null and button.visible and not button.disabled and button.text == "Claim Reward", "Claim Reward offered")
	var gold := character.inventory.count(GOLD)
	session.saves.save_started.connect(_on_save_started)
	button.pressed.emit()
	button.pressed.emit()   # double click
	for i in 3:
		await get_tree().process_frame
	check_eq(character.inventory.count(GOLD), gold + 30, "30 gold")
	check_eq(character.inventory.count(TIMBER), 3, "3 timber")
	check_eq(character.inventory.count(STONE), 2, "2 stone")
	check(character.world.has_flag(CLAIMED), "claimed through the service")
	check_eq(_critical_saves, 1, "one milestone save")
	check_eq(_status(), "Received 30 Gold, 3 Timber and 2 Stone.", "success text")
	check(not _button().visible, "no claim action any more")
	check(panel.find_child("Received", true, false) != null, "Reward received.")
	check_eq(panel.claim(), tr("UI_QUEST_REWARDS_NONE"), "another press pays nothing")
	check_eq(QuestRewardService.claim(character, QUEST), "You were already rewarded.", "service refuses again")
	check_eq(character.inventory.count(GOLD), gold + 30, "still 30 gold")
	check_eq(character.inventory.count(TIMBER), 3, "still 3 timber")
	check(QuestRewardPanel.has_rewards_for(character, &"mara"), "the button stays for the received card")


func test_full_bag_pays_nothing_then_claims_after_making_room() -> void:
	_to_haven_welcomed()
	_clear_materials()
	await _open_haven()
	for dialogue in _mara().definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	_fill_bag(1)   # timber and stone need two new slots
	var before := _snapshot()
	if not await _open_maras_rewards():
		return
	var button := _button()
	check(button.visible and button.disabled, "claim disabled: no room")
	check_eq(_status(), "Not enough inventory space. Make room to claim the full reward.", "bag-full text")
	check_eq(_panel().claim(), QuestRewardService.BAG_FULL, "refused with the service's BAG_FULL")
	check_eq(_status(), "Not enough inventory space. Make room to claim the full reward.", "bag-full text after a press")
	check_eq(_snapshot(), before, "no partial reward, stacks unchanged")
	check(not character.world.flags.has(CLAIMED), "no claimed flag")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still pending")
	check_eq(_mara().marker(), "?", "still ?")
	# make room while the window is open: the button unlocks
	for item in character.inventory.items():
		if item.definition_id == FILLER and character.inventory.takes_slot(item):   # never the worn starting gear
			character.inventory.remove_instance(item.instance_id)
			break
	check(not _button().disabled, "room made: Claim Reward enabled again")
	var gold := character.inventory.count(GOLD)
	check_eq(_panel().claim(), "", "claimed")
	check_eq(character.inventory.count(GOLD), gold + 30, "one payout of 30 gold")
	check_eq(character.inventory.count(TIMBER), 3, "timber")
	check_eq(character.inventory.count(STONE), 2, "stone")


func test_partial_stacks_are_topped_up_and_a_failed_claim_keeps_them() -> void:
	_to_haven_welcomed()
	_clear_materials()
	character.inventory.add_item(TIMBER, 48)   # 2 fit, 1 needs a new slot
	character.inventory.add_item(STONE, 50)    # full: stone needs a new slot
	_fill_bag(1)
	check_eq(QuestRewardService.slots_needed(character, QuestRewardService.reward_items(db.story_quests[QUEST])), 2, "two slots")
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST), QuestRewardService.BAG_FULL, "refused")
	check_eq(_snapshot(), before, "existing stacks unchanged")
	for item in character.inventory.items():
		if item.definition_id == FILLER and character.inventory.takes_slot(item):   # never the worn starting gear
			character.inventory.remove_instance(item.instance_id)
			break
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(character.inventory.count(TIMBER), 51, "48 + 3 timber")
	check_eq(character.inventory.count(STONE), 52, "50 + 2 stone")
	for instance_id: String in before:
		var item := character.inventory.find(instance_id)
		if item != null and item.definition_id == TIMBER:
			check_eq(item.quantity, 50, "the partial timber stack was topped up")


func test_trial_blocks_maras_claim() -> void:
	_to_haven_welcomed()
	character.prologue.stage = PrologueState.Stage.IN_PROGRESS
	character.classes.begin_trial(&"warrior", 1)
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST), "Finish or leave the current trial first.", "refused")
	check_eq(_snapshot(), before, "nothing paid")
	check(not character.world.flags.has(CLAIMED), "no flag")
	character.classes.end_trial()
	character.prologue.stage = PrologueState.Stage.COMPLETED
	check_eq(QuestRewardService.claim(character, QUEST), "", "claim outside the trial")


func test_pending_and_claimed_survive_save_and_load() -> void:
	_to_haven_welcomed()
	_clear_materials()
	_reload()
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "pending after load")
	await _open_haven()
	check_eq(_mara().marker(), "?", "? after load")
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	var payload := character.to_dict()
	check_eq((payload.world.flags as Dictionary).get(String(CLAIMED)), true, "claimed flag in the snapshot")
	_reload()
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.CLAIMED, "claimed after load")
	check_eq(character.inventory.count(GOLD), gold + 30, "gold kept")
	check_eq(character.inventory.count(TIMBER), 3, "timber kept")
	check_eq(character.inventory.count(STONE), 2, "stone kept")
	check_eq(QuestRewardService.claim(character, QUEST), "You were already rewarded.", "no claim after load")
	await _open_haven()
	check_eq(_mara().marker(), "", "no ? after load")


# --- NPC context: Mara and Edrin --------------------------------------------------------------------

func test_mara_and_edrin_never_claim_each_others_reward() -> void:
	_binding_completed()
	await _open_haven()
	for npc_id: StringName in [&"mara", &"edrin"]:
		for dialogue in (db.npcs[npc_id] as NpcDefinition).dialogues:
			character.world.set_flag(dialogue.done_flag())
	check_eq(_mara().marker(), "?", "Mara: ?")
	check_eq((map.get_node("Edrin") as StoryNpc).marker(), "?", "Edrin: ?")
	check(await _open_maras_rewards(), "Mara's window")
	# Side Quests 1.0: The Lost Hunter and Embers of Shelter are Mara's too - never Edrin's First Binding
	check_eq(_panel().quests().map(func(q: StoryQuestDefinition) -> StringName: return q.id), [&"embers_of_shelter", QUEST, &"the_lost_hunter"],
		"Mara lists her own quests only")
	var gold := character.inventory.count(GOLD)
	check_eq(_panel().claim(), "", "Mara's claim")
	check_eq(character.inventory.count(GOLD), gold + 30, "30 gold, not 60")
	check_eq(QuestRewardService.state(character, BINDING), QuestRewardService.PENDING, "Edrin's reward untouched")
	check_eq(_panel().claim(), tr("UI_QUEST_REWARDS_NONE"), "Mara's window cannot take Edrin's reward")
	check_eq(QuestRewardService.state(character, BINDING), QuestRewardService.PENDING, "still pending at Edrin")
	# Edrin's window: only The First Binding, 60 gold as before
	var edrin := map.get_node("Edrin") as StoryNpc
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_panel().visible and _panel().npc_id() == &"edrin", "Edrin's window")
	check(_panel().find_child("Reward_the_broken_cart", true, false) == null, "no Broken Cart card at Edrin")
	check(_texts(_panel().find_child("Gold", true, false)).has("60 Gold"), "Edrin's card: 60 Gold")
	gold = character.inventory.count(GOLD)
	var timber := character.inventory.count(TIMBER)
	check_eq(_panel().claim(), "", "Edrin's claim")
	check_eq(_status(), "Received 60 Gold.", "Edrin's success text unchanged")
	check_eq(character.inventory.count(GOLD), gold + 60, "exactly 60 gold")
	check_eq(character.inventory.count(TIMBER), timber, "no materials from Edrin")
	check_eq(_mara().marker(), "", "Mara: claimed")
	check_eq(edrin.marker(), "", "Edrin: claimed")


func test_edrin_claims_only_his_reward_while_maras_is_pending() -> void:
	_binding_completed()
	var gold := character.inventory.count(GOLD)
	await _open_haven()
	for dialogue in (db.npcs[&"edrin"] as NpcDefinition).dialogues:
		character.world.set_flag(dialogue.done_flag())
	var edrin := map.get_node("Edrin") as StoryNpc
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check_eq(_panel().quests().map(func(q: StoryQuestDefinition) -> StringName: return q.id), [BINDING], "Edrin lists only The First Binding")
	check_eq(_panel().claim(), "", "Edrin's claim")
	check_eq(character.inventory.count(GOLD), gold + 60, "60 gold")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "Mara's reward untouched")
	check_eq(_panel().claim(), tr("UI_QUEST_REWARDS_NONE"), "Edrin's window cannot take Mara's reward")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still pending at Mara")


# --- reward detection without gold ----------------------------------------------------------------

func test_material_only_rewards_count_as_rewards_in_the_ui_paths() -> void:
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	var gold := quest.turn_in_gold
	quest.turn_in_gold = 0   # synthetic: materials only
	_to_haven_welcomed()
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "materials alone register a claim")
	check(QuestRewardPanel.quests_for(character, &"mara").has(quest), "panel lists it")
	check(QuestRewardPanel.has_rewards_for(character, &"mara"), "Flask button")
	check_eq(QuestRewardPanel.reward_parts(db, quest), PackedStringArray(["3 Timber", "2 Stone"]), "card rows")
	check_eq(QuestRewardPanel.reward_summary(db, quest), "3 Timber and 2 Stone", "success summary")
	check(JournalPanel.reward_text(character, quest) != "", "journal sees a reward")
	check(not ObjectivePanel.reward_lines(character).is_empty(), "tracker sees a reward")
	await _open_haven()
	check_eq(_mara().marker(), "?", "marker sees a reward")
	quest.turn_in_gold = gold


func test_other_reward_systems_are_untouched() -> void:
	_to_haven_welcomed()
	character.world.set_flag(BossRewardService.defeat_flag(&"whisper_forest_grove_warden"))
	check_eq(BossRewardService.claim(character, &"whisper_forest_grove_warden", load("res://data/loot/grove_warden_rare_reward.tres"),
			RandomNumberGenerator.new()), "", "Warden's Cache claim")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "the cache does not touch Mara's claim")
	check(not character.world.flags.has(CLAIMED), "not claimed by another reward")
	check_eq(QuestRewardService.claim(character, QUEST), "", "Mara's claim")
	check(BossRewardService.is_claimed(character, &"whisper_forest_grove_warden"), "the cache stays claimed")
