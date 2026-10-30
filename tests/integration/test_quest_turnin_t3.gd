extends TestCase
## NPC Quest Turn-ins 1.0 T3 (docs/NPC_QUEST_TURNINS_1_0_T3.md): guidance for Edrin's quest
## reward - "?" over Edrin while it is pending ("!" story talk first), the journal line on
## the completed quest card and the tracker hint, all read from QuestRewardService and live
## after entitlement, claim, save/load and map changes. Files only under
## user://test_saves/quest_turnin_t3/.

const QUEST := &"the_first_binding"
const ENTITLED := &"quest_reward_entitled.the_first_binding"
const CLAIMED := &"quest_reward_claimed.the_first_binding"
const GOLD := &"gold_coin"
const DIR := "user://test_saves/quest_turnin_t3"
const PENDING_JOURNAL := "Reward available: Return to Edrin Vale (60 Gold)."
const CLAIMED_JOURNAL := "Reward received: 60 Gold."
const TRACKER := "Return to Edrin Vale for your reward."
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


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
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
	# 1.1 M2: the chain also earns Mara's reward (The Broken Cart); taken here, so only Edrin's remains
	check_eq(QuestRewardService.claim(character, &"the_broken_cart"), "", "Mara's reward taken")
	check(StoryService.at_step(character, QUEST, 2), "The First Binding waits for Edrin")


func _threat() -> DialogueDefinition:
	for dialogue in (db.npcs[&"edrin"] as NpcDefinition).dialogues:
		if dialogue.id == &"edrin_threat":
			return dialogue
	return null


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
	for i in 3:
		await get_tree().process_frame


func _edrin() -> StoryNpc:
	return map.get_node("Edrin") as StoryNpc


func _tracker() -> String:
	return "\n".join(ObjectivePanel.reward_lines(character))


func _journal_reward() -> String:
	return JournalPanel.reward_text(character, db.story_quests[QUEST])


func _reload() -> void:
	var warnings: PackedStringArray = []
	character = Character.from_dict(JSON.parse_string(JSON.stringify(character.to_dict())), db, warnings)


# --- marker ---------------------------------------------------------------------------------------

func test_story_mark_first_then_question_mark_until_the_claim() -> void:
	_to_edrins_talk()
	await _open_haven()
	var edrin := _edrin()
	check_eq(edrin.marker(), "!", "the story talk shows ! first")
	DialogueService.finish(character, _threat())
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "entitlement arose")
	check_eq(edrin.marker(), "?", "pending reward: ? in the same stay")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(edrin.marker(), "", "claimed: no marker")
	var mara := map.get_node("Mara") as StoryNpc
	check(mara.marker() != "?", "Mara shows no reward ? (hers was taken)")


func test_marker_after_save_load_and_map_change() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	_reload()
	await _open_haven()
	check_eq(_edrin().marker(), "?", "pending after save/load")
	await _open_haven()   # enter the map again
	check_eq(_edrin().marker(), "?", "pending after a map change")
	QuestRewardService.claim(character, QUEST)
	_reload()
	await _open_haven()
	check_eq(_edrin().marker(), "", "claimed after save/load: no marker")


func test_historical_completion_shows_no_reward_guidance() -> void:
	_to_edrins_talk()
	character.quests.entries[QUEST] = {"state": "completed", "step": 3, "progress": {}}
	character.world.set_flag(&"dialogue.edrin_threat")
	await _open_haven()
	check_eq(_edrin().marker(), "", "no ? without entitlement")
	check_eq(_journal_reward(), "", "no journal reward line")
	check_eq(_tracker(), "", "no tracker hint")


# --- journal and tracker --------------------------------------------------------------------------

func test_journal_and_tracker_follow_the_reward_state() -> void:
	_to_edrins_talk()
	check_eq(_journal_reward(), "", "none: no journal line")
	check_eq(_tracker(), "", "none: no tracker hint")
	StoryService.notify(character, &"talk:edrin_threat")
	check_eq(_journal_reward(), PENDING_JOURNAL, "journal pending")
	check_eq(_tracker(), TRACKER, "tracker pending")
	await _open_haven()
	map.hud.toggle_journal()
	await get_tree().process_frame
	map.hud.journal_panel.select_quest(&"the_first_binding")   # Menu UX Polish 1.1: reward lines are in the details
	await get_tree().process_frame
	var card := map.hud.journal_panel.find_child("QuestDetail", true, false).find_child("Story_the_first_binding", true, false)
	if check(card != null, "completed quest card shown"):
		var line := card.find_child("Reward", true, false) as Label
		check(line != null and line.text == PENDING_JOURNAL, "journal card shows the pending line")
		check(_texts(card).has("Completed"), "the quest still reads Completed")
	map.hud.close_windows()
	await get_tree().process_frame
	map.hud.objectives.refresh()
	check("\n".join(_texts(map.hud.objectives)).contains(TRACKER), "tracker shows the hint")
	check(StoryService.is_completed(character, QUEST) and not character.quests.active_ids().has(QUEST), "no reactivated quest")
	check(not "\n".join(StoryService.tracker_lines(character)).contains(TRACKER), "not a quest objective line")
	check(StoryService.is_active(character, &"the_first_signs"), "successor unchanged")
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed")
	check_eq(_journal_reward(), CLAIMED_JOURNAL, "journal claimed")
	check_eq(_tracker(), "", "tracker hint gone")
	map.hud.objectives.refresh()
	check(not "\n".join(_texts(map.hud.objectives)).contains(TRACKER), "tracker line gone")


func _texts(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		result.append((label as Label).text)
	return result


# --- unchanged behaviour --------------------------------------------------------------------------

func test_window_pays_once_and_trial_lock_holds() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	await _open_haven()
	var edrin := _edrin()
	map.player.global_position = edrin.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame
	character.classes.begin_trial(&"warrior", 1)
	edrin.interact(map.hud)
	await get_tree().process_frame
	var gold := character.inventory.count(GOLD)
	check(map.hud.quest_reward_panel.claim() != "", "trial: refused")
	check_eq(edrin.marker(), "?", "still pending in a trial")
	character.classes.end_trial()
	map.hud.quest_reward_panel.rebuild()
	check_eq(map.hud.quest_reward_panel.claim(), "", "claimed")
	map.hud.quest_reward_panel.claim()
	check_eq(character.inventory.count(GOLD), gold + 60, "one payout of 60")
	edrin.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.quest_reward_panel.visible, "Edrin still reachable after the claim")
	check_eq(edrin.marker(), "", "no marker")


func test_contract_unchanged() -> void:
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	check(quest.turn_in_gold == 60 and quest.turn_in_npc_id == &"edrin", "60 gold at Edrin")
	check_eq(quest.next_quest_ids, [&"the_first_signs"] as Array[StringName], "successor unchanged")
	check_eq(QuestRewardService.entitled_flag(QUEST), ENTITLED, "entitled flag unchanged")
	check_eq(QuestRewardService.claimed_flag(QUEST), CLAIMED, "claimed flag unchanged")
	check_eq(SaveSystem.VERSION, 15, "save v15")


func test_pending_window_focuses_claim_reward() -> void:
	_to_edrins_talk()
	StoryService.notify(character, &"talk:edrin_threat")
	await _open_haven()
	var edrin := _edrin()
	map.player.global_position = edrin.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame
	edrin.interact(map.hud)
	for i in 3:
		await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner()
	check(focused != null and focused.name == &"ClaimReward", "keyboard focus on Claim Reward (got %s)" % [focused.name if focused != null else "none"])
