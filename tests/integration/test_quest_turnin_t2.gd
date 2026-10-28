extends TestCase
## NPC Quest Turn-ins 1.0 T2 (docs/NPC_QUEST_TURNINS_1_0_T2.md): Edrin Vale's quest reward
## service in Haven. Unheard story dialogues (edrin_threat) keep priority, heard ones stay
## reachable through "Talk"; the window shows none/pending/claimed from QuestRewardService
## and claims only through QuestRewardService.claim (60 gold once, one milestone save).
## Mara's Hearth Flask service is unchanged. Files only under user://test_saves/quest_turnin_t2/.

const QUEST := &"the_first_binding"
const ENTITLED := &"quest_reward_entitled.the_first_binding"
const CLAIMED := &"quest_reward_claimed.the_first_binding"
const GOLD := &"gold_coin"
const DIR := "user://test_saves/quest_turnin_t2"
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro",
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


## The real prologue chain until The First Binding waits for Edrin (step 2).
func _to_edrins_talk() -> void:
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	for objective in (db.trials[&"trial_warrior"] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "class chosen")
	StoryService.notify(character, &"waystone:whispering_stone")
	StoryService.notify(character, &"enter:home_base")
	StoryService.notify(character, &"talk:mara_return")
	check(StoryService.at_step(character, QUEST, 2), "The First Binding waits for Edrin")


func _open_haven() -> void:
	character.world.map_id = &"home_base"
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	map = null
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	for i in 5:   # arrival milestones first
		await get_tree().process_frame


func _edrin() -> StoryNpc:
	return map.get_node("Edrin") as StoryNpc


func _stand_at(npc: StoryNpc) -> void:
	map.player.global_position = npc.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame


func _dialogue(npc_id: StringName, dialogue_id: StringName) -> DialogueDefinition:
	for dialogue in (db.npcs[npc_id] as NpcDefinition).dialogues:
		if dialogue.id == dialogue_id:
			return dialogue
	return null


func _panel() -> QuestRewardPanel:
	return map.hud.quest_reward_panel


func _button() -> Button:
	return _panel().find_child("ClaimReward", true, false) as Button


# --- registration --------------------------------------------------------------------------------

func test_only_edrin_has_the_reward_service() -> void:
	check_eq((db.npcs[&"edrin"] as NpcDefinition).service, &"quest_rewards", "Edrin's service")
	check_eq((db.npcs[&"mara"] as NpcDefinition).service, &"hearth_flask", "Mara keeps the Hearth Flask")
	for npc: NpcDefinition in db.npcs.values():
		if npc.id != &"edrin":
			check(npc.service != &"quest_rewards", "%s has no reward service" % npc.id)
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check(quest.turn_in_gold == 60 and quest.turn_in_npc_id == &"edrin" and quest.steps.size() == 3, "quest data unchanged")
	check_eq(quest.next_quest_ids, [&"the_first_signs"] as Array[StringName], "successor unchanged")


# --- the turn-in -----------------------------------------------------------------------------------

func test_edrin_talk_first_then_one_claim_of_60_gold() -> void:
	_to_edrins_talk()
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible and not _panel().visible, "the unheard edrin_threat comes first")
	check(not character.world.has_flag(&"dialogue.edrin_threat"), "not marked heard by the service")
	map.hud.close_windows()
	DialogueService.finish(character, _dialogue(&"edrin", &"edrin_threat"))   # read to the end
	check(StoryService.is_completed(character, QUEST), "edrin_threat completes the quest as before")
	check(StoryService.is_active(character, &"the_first_signs"), "successor started")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "reward pending")
	await get_tree().process_frame
	edrin.interact(map.hud)   # talk to Edrin again
	await get_tree().process_frame
	var panel := _panel()
	check(panel.visible and not map.hud.dialogue_panel.visible, "now Edrin opens Quest Rewards")
	check_eq(panel._title.text, "Quest Rewards", "title")
	var card := panel.find_child("Reward_the_first_binding", true, false)
	check(card != null, "The First Binding listed")
	var gold_row := panel.find_child("Gold", true, false)
	check(gold_row != null and _texts(gold_row).has("60 Gold"), "shows 60 Gold: %s" % [_texts(gold_row) if gold_row != null else []])
	var button := _button()
	if not check(button != null and button.visible and not button.disabled, "Claim Reward offered"):
		return
	check_eq(button.text, "Claim Reward", "button text")
	var gold := character.inventory.count(GOLD)
	session.saves.save_started.connect(_on_save_started)
	button.pressed.emit()
	button.pressed.emit()   # double click
	for i in 3:
		await get_tree().process_frame
	check_eq(character.inventory.count(GOLD), gold + 60, "exactly 60 gold")
	check(character.world.has_flag(CLAIMED), "claimed through the service")
	check_eq(_critical_saves, 1, "one milestone save")
	check_eq((panel.find_child("Status", true, false) as Label).text, "Received 60 Gold.", "success from the service")
	check(not _button().visible, "no claim action any more")
	check(panel.find_child("Received", true, false) != null, "Reward received shown")
	check_eq(panel.claim(), tr("UI_QUEST_REWARDS_NONE"), "another press pays nothing")
	edrin.interact(map.hud)
	await get_tree().process_frame
	check_eq(character.inventory.count(GOLD), gold + 60, "still 60 gold")
	check(_panel().find_child("Received", true, false) != null, "reopened: Reward received")


func _texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	return result


func test_no_entitlement_no_payout() -> void:
	_to_edrins_talk()
	# historically completed (before T1): no entitlement
	character.quests.entries[QUEST] = {"state": "completed", "step": 3, "progress": {}}
	character.world.set_flag(&"dialogue.edrin_threat")
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	var panel := _panel()
	check(panel.visible, "service window opens")
	check(panel.find_child("NoRewards", true, false) != null, "No rewards available.")
	check(panel.find_child("Reward_the_first_binding", true, false) == null, "no quest card from QuestLog.completed")
	check(not _button().visible, "no claim action")
	var gold := character.inventory.count(GOLD)
	check(panel.claim() != "", "claim refused")
	check_eq(character.inventory.count(GOLD), gold, "no gold")
	check(not character.world.flags.has(CLAIMED), "no flag set by the UI")


func test_save_load_rebuilds_pending_and_claimed() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	var warnings: PackedStringArray = []
	character = Character.from_dict(JSON.parse_string(JSON.stringify(character.to_dict())), db, warnings)
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_button() != null and _button().visible and not _button().disabled, "pending after load")
	check_eq(_panel().claim(), "", "claimed")
	character = Character.from_dict(JSON.parse_string(JSON.stringify(character.to_dict())), db, warnings)
	await _open_haven()
	edrin = _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_panel().find_child("Received", true, false) != null and not _button().visible, "claimed after load")


func test_stale_window_never_pays_twice() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_button().visible, "window shows pending")
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed elsewhere while the window is open")
	_panel().claim()   # the stale button
	check_eq(character.inventory.count(GOLD), gold + 60, "only one payout")


func test_trial_lock_stays_in_force() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	await _open_haven()
	character.classes.begin_trial(&"warrior", 1)   # synthetic running trial (map entry would end a real one)
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	var button := _button()
	check(button.visible and button.disabled, "claim disabled in a trial")
	check_eq(button.tooltip_text, "Finish or leave the current trial first.", "reason shown")
	var gold := character.inventory.count(GOLD)
	check_eq(_panel().claim(), "Finish or leave the current trial first.", "refused")
	check_eq(character.inventory.count(GOLD), gold, "no gold")
	check(not character.world.flags.has(CLAIMED), "no flag")
	character.classes.end_trial()


# --- dialogues, Mara, window life ------------------------------------------------------------------

func test_edrins_dialogues_stay_reachable() -> void:
	for event: StringName in TO_THE_STONE.slice(0, 12):   # Shelter Among the Trees, step 3: Edrin's intro
		StoryService.notify(character, event)
	check(StoryService.at_step(character, &"shelter_among_the_trees", 3), "intro step")
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible and not _panel().visible, "unheard edrin_intro first")
	map.hud.close_windows()
	DialogueService.finish(character, _dialogue(&"edrin", &"edrin_intro"))
	check(StoryService.is_active(character, &"the_whispering_stone"), "story moves on (no soft-lock)")
	check(character.world.has_flag(&"prologue.haven_settled"), "north gate opens as before")
	# the repeatable shrine hint: unheard first, heard -> service with Talk
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible, "shrine hint told first")
	map.hud.close_windows()
	DialogueService.finish(character, _dialogue(&"edrin", &"edrin_shrine_hint"))
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_panel().visible, "heard hint: service window")
	var talk := _panel().find_child("Talk", true, false) as Button
	check(talk != null, "the hint stays reachable (Talk)")
	check(_panel().find_child("NoRewards", true, false) != null, "no reward yet")
	if talk != null:
		talk.pressed.emit()
		await get_tree().process_frame
		check(map.hud.dialogue_panel.visible and not _panel().visible, "Talk opens the dialogue")


func test_mara_flask_service_unchanged() -> void:
	character.world.set_flag(&"prologue.haven_discovered")
	await _open_haven()
	var mara := map.get_node("Mara") as StoryNpc
	for dialogue in mara.definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	await _stand_at(mara)
	mara.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.flask_panel.visible and not _panel().visible, "Mara opens the Hearth Flask")


func test_window_closes_when_walking_away_and_leaves_nothing_open() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	await _open_haven()
	var edrin := _edrin()
	await _stand_at(edrin)
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(_panel().visible, "open")
	map.player.global_position = edrin.global_position + Vector2(0, 200)
	for i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame
	check(not _panel().visible, "closes when the player walks away")
	check(not map.hud.is_window_open(), "no window left open")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "nothing claimed by leaving")
