extends TestCase
## NPC Quest Turn-ins 1.1 M1 (docs/NPC_QUEST_TURNINS_1_1_M1.md): mixed rewards (gold +
## stackable materials) through the real QuestRewardService.claim path. The reward data are
## synthetic: "The First Binding" carries test materials for the duration of a test only
## (restored in after_each; the shipped data stay 60 gold at Edrin, no materials). Room for
## all materials is checked before any credit; a failed credit undoes exactly this claim's
## quantities; gold and claimed flag only on full success. Saves are synthetic dictionaries;
## milestone requests go to user://test_saves/quest_turnin_mixed_rewards/ and are dropped.

const QUEST := &"the_first_binding"
const ENTITLED := &"quest_reward_entitled.the_first_binding"
const CLAIMED := &"quest_reward_claimed.the_first_binding"
const GOLD := &"gold_coin"
const TIMBER := &"timber"
const STONE := &"stone"
const FILLER := &"iron_sword"
const PROFILE := "user://test_saves/quest_turnin_mixed_rewards/slot_1.save.json"
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro",
		&"enter:whispering_stone"]
const BINDING := [&"enter:home_base", &"talk:mara_return", &"talk:edrin_threat"]

var db: GameDatabase
var character: Character
var session: SessionState
var quest: StoryQuestDefinition
var _previous_path: String
var _original_gold: int
var _original_items: Array[ItemCost]


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	if session.save_path != PROFILE:
		_previous_path = session.save_path
		session.save_path = PROFILE
	session.saves.reset()
	quest = db.story_quests[QUEST]
	_original_gold = quest.turn_in_gold
	_original_items = quest.turn_in_items.duplicate()
	character = CharacterFactory.create_new(db)
	for item_id: StringName in [TIMBER, STONE]:
		var held := character.inventory.count(item_id)
		if held > 0:
			character.inventory.remove_quantity(item_id, held)


func after_each() -> void:
	quest.turn_in_gold = _original_gold
	quest.turn_in_items = _original_items
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path


# --- helpers ------------------------------------------------------------------------------------

func _cost(item_id: StringName, quantity: int) -> ItemCost:
	var cost := ItemCost.new()
	cost.item_id = item_id
	cost.quantity = quantity
	return cost


## Synthetic reward on the binding quest: `gold` + `items` ({item id: quantity}).
func _reward(gold: int, items: Dictionary) -> void:
	quest.turn_in_gold = gold
	var costs: Array[ItemCost] = []
	for item_id: StringName in items:
		costs.append(_cost(item_id, int(items[item_id])))
	quest.turn_in_items = costs


func _mixed() -> void:
	_reward(30, {TIMBER: 3, STONE: 2})


## The real prologue chain up to "The First Binding" being active (as test_quest_turnin_t1).
func _to_the_binding() -> void:
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	for objective in (db.trials[&"trial_warrior"] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check_eq(PrologueService.choose_starting_class(character, &"warrior"), "", "class chosen")
	StoryService.notify(character, &"waystone:whispering_stone")
	check(StoryService.at_step(character, QUEST, 0), "The First Binding active at step 0")


func _pending_claim() -> void:
	_to_the_binding()
	for event: StringName in BINDING:
		StoryService.notify(character, event)
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "reward pending")
	for item_id: StringName in [TIMBER, STONE]:   # the prologue chain may hand out materials
		var held := character.inventory.count(item_id)
		if held > 0:
			character.inventory.remove_quantity(item_id, held)


## Fills free slots with single items until `leave_free` are left.
func _fill_bag(leave_free: int = 0) -> void:
	while character.inventory.free_slots() > leave_free:
		character.inventory.add_item(FILLER, 1, ItemInstance.ORIGIN_FOUND)


## instance id -> quantity of every instance (the exact bag state).
func _snapshot() -> Dictionary:
	var state := {}
	for item in character.inventory.items():
		state[item.instance_id] = [item.definition_id, item.quantity]
	return state


func _pending_saves() -> int:
	return session.saves._auto_pending.size()


func _reload(source: Character) -> Character:
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())), db, warnings)
	check(loaded != null, "synthetic save loads")
	return loaded


## Checks that a refused/failed claim left everything as before.
func _check_unchanged(before: Dictionary, saves: int, label: String) -> void:
	check_eq(_snapshot(), before, "%s: bag unchanged (stacks and quantities)" % label)
	check(not character.world.flags.has(CLAIMED), "%s: no claimed flag" % label)
	check_eq(_pending_saves(), saves, "%s: no save requested" % label)
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "%s: claim still pending" % label)


## Fills the bag the moment the first material lands (a credit failing mid-claim).
func _fill_after_first_credit() -> void:
	var fired := [false]
	var inventory := character.inventory
	var fill := func() -> void:
		if fired[0]:
			return
		fired[0] = true
		while inventory.free_slots() > 0:
			inventory.add_item(FILLER, 1, ItemInstance.ORIGIN_FOUND)
	inventory.changed.connect(fill, CONNECT_ONE_SHOT)


# --- Edrin and gold-only ------------------------------------------------------------------------

func test_edrin_reward_is_still_exactly_60_gold_and_no_materials() -> void:
	check_eq(quest.turn_in_gold, 60, "60 gold in the data")
	check(quest.turn_in_items.is_empty(), "no materials in the data")
	check_eq(quest.turn_in_npc_id, &"edrin", "at Edrin")
	_pending_claim()
	var gold := character.inventory.count(GOLD)
	var slots := character.inventory.used_slots()
	var others := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(GOLD), gold + 60, "exactly 60 gold")
	check_eq(character.inventory.used_slots(), slots, "no bag slot used")
	for instance_id: String in others:
		var item := character.inventory.find(instance_id)
		if item != null and item.definition_id != GOLD:
			check_eq(item.quantity, int(others[instance_id][1]), "non-gold item %s unchanged" % instance_id)
	var gold_ids := 0
	for instance_id: String in _snapshot():
		if not others.has(instance_id):
			gold_ids += 1
			check_eq(character.inventory.find(instance_id).definition_id, GOLD, "only gold is new")
	check(gold_ids <= 1, "at most one new (gold) instance")
	check_eq(_pending_saves(), 1, "one milestone save")


func test_gold_only_reward_needs_no_bag_slot() -> void:
	_reward(25, {})
	_pending_claim()
	_fill_bag()
	check_eq(QuestRewardService.can_claim(character, QUEST), "", "full bag does not block gold")
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(GOLD), gold + 25, "25 gold")
	check(character.world.has_flag(CLAIMED), "claimed")


# --- successful mixed claim -----------------------------------------------------------------------

func test_mixed_claim_pays_every_material_and_the_gold_once() -> void:
	_mixed()
	_to_the_binding()
	var gold := character.inventory.count(GOLD)
	for event: StringName in BINDING:
		StoryService.notify(character, event)
	# completion alone pays nothing
	check(character.world.has_flag(ENTITLED), "entitlement registered")
	check_eq(character.inventory.count(GOLD), gold, "no gold on completion")
	for item_id: StringName in [TIMBER, STONE]:
		var held := character.inventory.count(item_id)
		if held > 0:
			character.inventory.remove_quantity(item_id, held)
	check_eq(character.inventory.count(TIMBER) + character.inventory.count(STONE), 0, "no materials on completion")
	var saves := _pending_saves()
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(TIMBER), 3, "3 timber")
	check_eq(character.inventory.count(STONE), 2, "2 stone")
	check_eq(character.inventory.count(GOLD), gold + 30, "30 gold")
	check_eq(character.world.get_flag(CLAIMED), true, "claimed flag")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.CLAIMED, "claimed state")
	check_eq(_pending_saves(), saves + 1, "one milestone save")
	check(session.saves._critical_pending, "as a critical (milestone) save")
	# repeated claim pays nothing
	var after := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), "You were already rewarded.", "second claim refused")
	check_eq(_snapshot(), after, "nothing paid again")
	check_eq(_pending_saves(), saves + 1, "no second save")


func test_partial_timber_stack_is_topped_up_without_a_new_slot() -> void:
	_mixed()
	_pending_claim()
	character.inventory.add_item(TIMBER, 40)
	character.inventory.add_item(STONE, 10)
	_fill_bag()
	check_eq(QuestRewardService.slots_needed(character, QuestRewardService.reward_items(quest)), 0, "stacks hold the reward")
	check_eq(QuestRewardService.can_claim(character, QUEST), "", "full bag, but the stacks have room")
	var stacks := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(TIMBER), 43, "timber stack topped up")
	check_eq(character.inventory.count(STONE), 12, "stone stack topped up")
	for instance_id: String in _snapshot():
		if not stacks.has(instance_id):
			check_eq(character.inventory.find(instance_id).definition_id, GOLD, "no new material instance")
	check(character.world.has_flag(CLAIMED), "claimed")


func test_stack_overflow_needs_one_new_slot() -> void:
	_mixed()
	_pending_claim()
	character.inventory.add_item(TIMBER, 49)   # one unit of room left in the stack
	check_eq(QuestRewardService.slots_needed(character, {TIMBER: 3}), 1, "2 overflow -> one new slot")
	check_eq(QuestRewardService.slots_needed(character, {TIMBER: 1}), 0, "1 fits in the stack")
	check_eq(QuestRewardService.slots_needed(character, {TIMBER: 3, STONE: 2}), 2, "plus one stone slot")
	check_eq(QuestRewardService.slots_needed(character, {TIMBER: 102}), 3, "101 overflow -> three stacks of 50")


# --- room check before any credit ---------------------------------------------------------------

func test_two_materials_need_two_new_slots() -> void:
	_mixed()
	_pending_claim()
	_fill_bag(2)
	check_eq(QuestRewardService.slots_needed(character, QuestRewardService.reward_items(quest)), 2, "two new slots")
	check_eq(QuestRewardService.can_claim(character, QUEST), "", "two free slots are enough")
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.free_slots(), 0, "both slots used")
	check_eq(character.inventory.count(TIMBER), 3, "timber")
	check_eq(character.inventory.count(STONE), 2, "stone")


func test_one_free_slot_is_not_enough_for_two_materials() -> void:
	_mixed()
	_pending_claim()
	_fill_bag(1)
	check_eq(character.inventory.room_for(TIMBER), 50, "timber alone would fit")
	check_eq(character.inventory.room_for(STONE), 50, "stone alone would fit")
	var before := _snapshot()
	var saves := _pending_saves()
	check_eq(QuestRewardService.can_claim(character, QUEST), QuestRewardService.BAG_FULL, "refused by the total check")
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.BAG_FULL, "claim refused")
	_check_unchanged(before, saves, "one slot")


func test_full_bag_gives_no_partial_reward() -> void:
	_mixed()
	_pending_claim()
	_fill_bag()
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.BAG_FULL, "full bag refused")
	_check_unchanged(before, 0, "full bag")
	# making room is enough to claim later
	var removed := 0
	for item in character.inventory.items():
		if item.definition_id == FILLER and removed < 2:
			character.inventory.remove_instance(item.instance_id)
			removed += 1
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claim after making room")


func test_refusal_keeps_existing_material_stacks_unchanged() -> void:
	_mixed()
	_pending_claim()
	character.inventory.add_item(TIMBER, 50)   # full timber stack: timber needs a new slot
	character.inventory.add_item(STONE, 49)    # one stone fits, the second needs a new slot
	_fill_bag(1)
	check_eq(QuestRewardService.slots_needed(character, QuestRewardService.reward_items(quest)), 2, "two slots needed")
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.BAG_FULL, "refused")
	_check_unchanged(before, 0, "existing stacks")
	check_eq(character.inventory.count(TIMBER), 50, "timber as before")
	check_eq(character.inventory.count(STONE), 49, "stone as before (no unit topped up)")


# --- rollback ------------------------------------------------------------------------------------

func test_first_material_failure_pays_nothing() -> void:
	_mixed()
	_pending_claim()
	var before := _snapshot()
	# the transaction with a first entry add_item refuses (unknown item): nothing to undo
	check_eq(QuestRewardService.pay(character, 30, {&"no_such_item": 3, STONE: 2}), QuestRewardService.HANDOVER_FAILED, "failed")
	check_eq(_snapshot(), before, "no stone, no gold")
	# through claim: a first material the bag cannot take is refused before any credit
	_fill_bag()
	var full := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.BAG_FULL, "claim refused")
	_check_unchanged(full, 0, "first material")


func test_second_material_failure_rolls_the_first_back() -> void:
	_mixed()
	_pending_claim()
	character.inventory.add_item(TIMBER, 30)   # timber goes into this stack
	var before := _snapshot()
	var gold := character.inventory.count(GOLD)
	_fill_after_first_credit()   # the bag fills up after timber: stone fails
	var error := QuestRewardService.claim(character, QUEST, session)
	check_eq(error, QuestRewardService.HANDOVER_FAILED, "second credit failed")
	check_eq(character.inventory.count(TIMBER), 30, "timber rolled back")
	check_eq(character.inventory.count(STONE), 0, "no stone")
	check_eq(character.inventory.count(GOLD), gold, "no gold")
	for instance_id: String in before:
		var item := character.inventory.find(instance_id)
		check(item != null and item.quantity == int(before[instance_id][1]), "%s unchanged" % instance_id)
	check(not character.world.flags.has(CLAIMED), "no claimed flag")
	check_eq(_pending_saves(), 0, "no save")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.PENDING, "still pending")


func test_gold_failure_rolls_the_materials_back() -> void:
	_reward(Inventory.CURRENCY_ROOM + 1, {TIMBER: 3, STONE: 2})   # more gold than add_item takes
	_pending_claim()
	character.inventory.add_item(TIMBER, 48)   # 2 into the stack, 1 into a new one
	var before := _snapshot()
	var saves := _pending_saves()
	check_eq(QuestRewardService.can_claim(character, QUEST), "", "room check passes (gold needs no slot)")
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.HANDOVER_FAILED, "gold credit failed")
	_check_unchanged(before, saves, "gold failure")
	check_eq(character.inventory.count(TIMBER), 48, "timber back to 48")
	check_eq(character.inventory.count(STONE), 0, "stone removed")


func test_rollback_only_takes_back_this_claims_quantities() -> void:
	_reward(30, {TIMBER: 25, STONE: 2})
	_pending_claim()
	character.inventory.add_item(TIMBER, 80)   # stacks of 50 and 30
	character.inventory.add_item(STONE, 50)   # full stack: stone needs a new slot
	var before := _snapshot()
	_fill_after_first_credit()   # timber: 30 -> 50 and a new stack of 5; then stone fails
	check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.HANDOVER_FAILED, "failed")
	var after := _snapshot()
	for instance_id: String in before:
		check_eq(after.get(instance_id), before[instance_id], "%s keeps its quantity (same instance)" % instance_id)
	check_eq(character.inventory.count(TIMBER), 80, "80 timber, not 0 and not 105")
	check_eq(character.inventory.count(STONE), 50, "50 stone")
	var new_timber := 0
	for instance_id: String in after:
		if not before.has(instance_id) and after[instance_id][0] == TIMBER:
			new_timber += 1
	check_eq(new_timber, 0, "the new timber stack of this claim is gone")
	check(not character.world.flags.has(CLAIMED), "no claimed flag")


# --- invalid data --------------------------------------------------------------------------------

func test_invalid_material_data_never_pays_partially() -> void:
	var invalid := [
		[{TIMBER: 3, &"no_such_item": 2}, "unknown item"],
		[{TIMBER: 3, STONE: 0}, "zero quantity"],
		[{TIMBER: 3, STONE: -2}, "negative quantity"],
		[{TIMBER: 3, GOLD: 5}, "currency as material"],
		[{TIMBER: 3, FILLER: 1}, "single item as material"],
	]
	for case: Array in invalid:
		_reward(30, case[0])
		character = CharacterFactory.create_new(db)
		_pending_claim()
		var before := _snapshot()
		check_eq(QuestRewardService.claim(character, QUEST, session), QuestRewardService.HANDOVER_FAILED, "%s refused" % case[1])
		_check_unchanged(before, 0, case[1])
		check(not QuestRewardService.validate_quest(db, quest).is_empty(), "%s reported by validation" % case[1])
	_mixed()
	check(QuestRewardService.validate_quest(db, quest).is_empty(), "valid mixed data: %s" % [QuestRewardService.validate_quest(db, quest)])


func test_shipped_data_have_no_material_rewards_yet() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	for other: StoryQuestDefinition in db.story_quests.values():
		check(other.turn_in_items.is_empty(), "%s has no material reward (M1)" % other.id)
		if other.id != QUEST:
			check(not QuestRewardService.has_reward(other), "%s has no reward" % other.id)
	check(not QuestRewardService.has_reward(db.story_quests[&"the_broken_cart"]), "the_broken_cart not active yet")


# --- entitlement, trial, story contract ---------------------------------------------------------

func test_trial_blocks_the_mixed_claim() -> void:
	_mixed()
	_pending_claim()
	character.prologue.stage = PrologueState.Stage.IN_PROGRESS
	character.classes.begin_trial(&"warrior", 1)
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), "Finish or leave the current trial first.", "refused")
	_check_unchanged(before, 0, "trial")
	character.classes.end_trial()
	character.prologue.stage = PrologueState.Stage.COMPLETED
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claim outside the trial")
	check_eq(character.inventory.count(TIMBER), 3, "timber after the trial")


func test_story_contract_is_unchanged_with_a_mixed_reward() -> void:
	_mixed()
	_to_the_binding()
	for event: StringName in BINDING:
		StoryService.notify(character, event)
	check(StoryService.is_completed(character, QUEST), "completed as before")
	check(character.world.has_flag(&"prologue.completed"), "completion flag as before")
	check(StoryService.is_active(character, &"the_first_signs"), "successor started as before")
	check_eq(quest.next_quest_ids, [&"the_first_signs"] as Array[StringName], "successor data unchanged")
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check(StoryService.is_active(character, &"the_first_signs"), "claim does not touch the story")


func test_items_only_reward_registers_an_entitlement() -> void:
	_reward(0, {STONE: 2})
	check(QuestRewardService.has_reward(quest), "materials alone are a reward")
	_pending_claim()
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST, session), "", "claimed")
	check_eq(character.inventory.count(STONE), 2, "stone")
	check_eq(character.inventory.count(GOLD), gold, "no gold")


func test_historical_completion_gives_no_mixed_reward() -> void:
	_mixed()
	_to_the_binding()
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "completed", "step": 3, "progress": {}}
	payload.world.flags["prologue.completed"] = true
	var warnings: PackedStringArray = []
	character = Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(character, QUEST), "historically completed")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no entitlement")
	var before := _snapshot()
	check_eq(QuestRewardService.claim(character, QUEST, session), "There is no reward waiting for you.", "no claim")
	check_eq(_snapshot(), before, "nothing paid")


func test_resettle_creates_no_retroactive_claim() -> void:
	_mixed()
	_to_the_binding()
	for event: StringName in BINDING.slice(0, 2):
		StoryService.notify(character, event)
	var payload: Dictionary = character.to_dict()
	payload.quests[String(QUEST)] = {"state": "active", "step": 2, "progress": {"0": 1.0}}
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(payload)), db, warnings)
	check(StoryService.is_completed(loaded, QUEST), "resettle completes the quest")
	check(not loaded.world.flags.has(ENTITLED), "no entitlement from the reconstruction")
	check(StoryService.resettle(loaded).is_empty(), "a second resettle moves nothing")
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.NONE, "no claim")


# --- save / load ---------------------------------------------------------------------------------

func test_pending_mixed_reward_survives_save_and_load() -> void:
	_mixed()
	_pending_claim()
	var loaded := _reload(character)
	check_eq(QuestRewardService.state(loaded, QUEST), QuestRewardService.PENDING, "pending after load")
	check_eq(loaded.inventory.count(TIMBER), 0, "nothing paid by the load")


func test_claimed_mixed_reward_is_one_snapshot_and_survives_load() -> void:
	_mixed()
	_pending_claim()
	character = _reload(character)
	var gold := character.inventory.count(GOLD)
	check_eq(QuestRewardService.claim(character, QUEST), "", "claimed after load")
	var payload := character.to_dict()
	check_eq((payload.world.flags as Dictionary).get(String(CLAIMED)), true, "claimed flag in the snapshot")
	var saved := {}
	for entry: Dictionary in payload.inventory:
		var key := str(entry.get("def", ""))
		saved[key] = int(saved.get(key, 0)) + int(entry.get("qty", 0))
	check_eq(int(saved.get(String(GOLD), 0)), gold + 30, "gold in the same snapshot")
	check_eq(int(saved.get(String(TIMBER), 0)), 3, "timber in the same snapshot")
	check_eq(int(saved.get(String(STONE), 0)), 2, "stone in the same snapshot")
	var again := _reload(character)
	check_eq(QuestRewardService.state(again, QUEST), QuestRewardService.CLAIMED, "claimed after load")
	check_eq(QuestRewardService.claim(again, QUEST), "You were already rewarded.", "no claim after load")
	check_eq(again.inventory.count(TIMBER), 3, "timber kept, not paid twice")
