extends TestCase
## Class Trials 2.0 M4 (docs/CLASS_TRIALS_2_0_M4.md): the class reward of the one
## prologue choice - claim only from a real choice, one Magic item level 5 weapon of
## the chosen class through the regular ItemCreation/AffixRoller pipeline, full bag
## keeps the claim pending, never a second item, save/load and the v14 -> v15
## migration (no claim from an unprovable old class). Saves are synthetic
## dictionaries (Character.to_dict -> from_dict) - no file is written or read.

const R := ItemDefinition.Rarity
const TRIALS := {&"warrior": &"trial_warrior", &"arcanist": &"trial_arcanist", &"shadowrunner": &"trial_shadowrunner"}
const MODELS := {&"warrior": &"steel_greatsword", &"arcanist": &"oak_staff", &"shadowrunner": &"iron_dagger"}

## The panel asks the session for a milestone save after a claim: it is redirected
## here and dropped again (no GameMap is running, so nothing is written).
const PROFILE := "user://test_saves/class_trials_m4/slot_1.save.json"

var db: GameDatabase
var character: Character
var session: SessionState
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	session = SessionState.find(get_tree())
	if session != null and session.save_path != PROFILE:
		_previous_path = session.save_path
		session.save_path = PROFILE


func after_each() -> void:
	if session == null:
		return
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path


func _walk(trial_id: StringName) -> void:
	check_eq(PrologueService.begin_trial(character, trial_id), "", "begin %s" % trial_id)
	for objective in (db.trials[trial_id] as TrialDefinition).objectives:
		PrologueService.record(character, objective.kind, objective.target_id, objective.amount)
	check(not character.classes.in_trial(), "%s ended after its objectives" % trial_id)


func _choose(class_id: StringName) -> void:
	_walk(TRIALS[class_id])
	check_eq(PrologueService.choose_starting_class(character, class_id), "", "%s chosen" % class_id)


func _reload(source: Character) -> Character:
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(JSON.parse_string(JSON.stringify(source.to_dict())), db, warnings)
	check(loaded != null, "synthetic save loads")
	return loaded


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _models_in_bag(target: Character) -> int:
	var total := 0
	for model: StringName in MODELS.values():
		total += target.inventory.count(model)
	return total


## Every affix of a class reward: a regular, known, T5 affix of the model's generation
## pool, no duplicate identity/group/exclusion, no essences.
func _check_reward_item(item: ItemInstance, class_id: StringName) -> void:
	var definition := db.get_item(MODELS[class_id])
	check_eq(item.definition_id, MODELS[class_id], "%s gets %s" % [class_id, MODELS[class_id]])
	check_eq(item.rarity, R.MAGIC, "instance rarity Magic")
	check_eq(item.item_level, 5, "item level 5")
	check(item.affixes.size() >= 1 and item.affixes.size() <= 3, "1-3 regular affixes (%d)" % item.affixes.size())
	check(item.essences.is_empty(), "no essences")
	check_eq(item.origin, ItemInstance.ORIGIN_QUEST, "origin quest reward")
	check_eq(item.base_weapon_damage, WeaponDamage.base_for_level(definition, 5, db), "base damage of the regular model at ilvl 5")
	var seen := {}
	for entry: Dictionary in item.affixes:
		var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
		if not check(affix != null, "known affix %s" % entry.get("affix")):
			continue
		check(affix.id in definition.generation_affixes, "%s in the model's generation pool" % affix.id)
		var tier := affix.tier_of(entry)
		check(tier != null and tier.tier == 5, "%s is T5" % affix.id)
		for key: String in ["id:%s" % affix.id, "group:%s" % affix.group] + (["exclusion:%s" % affix.exclusion_group] if affix.exclusion_group != &"" else []):
			check(not seen.has(key), "no duplicate %s" % key)
			seen[key] = true


# --- 1-3, 10, 14-16: one reward per class --------------------------------------------

func test_each_class_gets_its_magic_weapon() -> void:
	for class_id: StringName in MODELS:
		character = CharacterFactory.create_new(db)
		_choose(class_id)
		check_eq(character.prologue.class_reward, PrologueState.ClassReward.PENDING, "%s: claim pending after the choice" % class_id)
		check_eq(_models_in_bag(character), _models_in_bag(CharacterFactory.create_new(db)), "the choice itself adds no item")
		var before := character.inventory.items().size()
		var claimed: Array[ItemInstance] = []
		check_eq(PrologueService.claim_class_reward(character, _rng(7), claimed), "", "%s claims" % class_id)
		check_eq(claimed.size(), 1, "exactly one item")
		check_eq(character.inventory.items().size(), before + 1, "exactly one new bag entry")
		check(character.inventory.has(claimed[0].instance_id), "the item is in the bag")
		_check_reward_item(claimed[0], class_id)
		check_eq(character.prologue.class_reward, PrologueState.ClassReward.CLAIMED, "claimed")


func test_reward_rolls_through_the_regular_pipeline() -> void:
	var rules := db.rules
	check_eq(rules.class_reward_tier_weights, rules.crafting_tier_weights, "the approved early Hollowwood tier table")
	for seed_value in [1, 2, 3, 42, 1234]:
		character = CharacterFactory.create_new(db)
		_choose(&"arcanist")
		var claimed: Array[ItemInstance] = []
		check_eq(PrologueService.claim_class_reward(character, _rng(seed_value), claimed), "", "claims (seed %d)" % seed_value)
		var direct := ItemCreation.generate(db.get_item(&"oak_staff"), R.MAGIC, db, _rng(seed_value), rules.class_reward_tier_weights, 5,
				ItemInstance.ORIGIN_QUEST)
		check_eq(claimed[0].affixes, direct.item.affixes, "same affixes as ItemCreation.generate (seed %d)" % seed_value)


func test_fixed_seeds_cover_all_magic_counts_and_only_t5() -> void:
	var counts := {}
	for seed_value in 60:
		character = CharacterFactory.create_new(db)
		_choose(&"warrior")
		var claimed: Array[ItemInstance] = []
		PrologueService.claim_class_reward(character, _rng(seed_value), claimed)
		if check_eq(claimed.size(), 1, "seed %d claims" % seed_value):
			_check_reward_item(claimed[0], &"warrior")
			counts[claimed[0].affixes.size()] = true
	check(counts.has(1) and counts.has(2) and counts.has(3), "fixed seeds reach 1, 2 and 3 affixes: %s" % [counts.keys()])
	check_eq(ItemCreation.AFFIX_COUNTS[R.MAGIC], {1: 40.0, 2: 40.0, 3: 20.0}, "Magic count weights 40/40/20 unchanged")


# --- 4-7, 18, 19: only the real choice creates the claim ------------------------------

func test_no_claim_without_the_choice() -> void:
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "new character: no claim")
	check(PrologueService.claim_class_reward(character, _rng(1)) != "", "claim refused")
	# preview: visiting the grounds is allowed, starts and chooses nothing
	check_eq(PrologueService.can_visit_grounds(character, &"trial_warrior"), "", "grounds may be visited")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "preview: no claim")
	# a trial: begun, aborted, then completed - no choice
	check_eq(PrologueService.begin_trial(character, &"trial_warrior"), "", "trial begun")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "running trial (temporary class): no claim")
	check(PrologueService.claim_class_reward(character, _rng(1)) != "", "no claim during a trial")
	PrologueService.end_trial(character, false)
	_walk(&"trial_warrior")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "completed trial alone: no claim")
	# debug class change (unlock + activate) is no choice
	character.classes.unlock(&"arcanist")
	character.classes.set_active(&"arcanist")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "debug class change: no claim")
	var bag := character.inventory.items().size()
	check(PrologueService.claim_class_reward(character, _rng(1)) != "", "still nothing to claim")
	check_eq(character.inventory.items().size(), bag, "no item")


func test_invalid_class_is_refused() -> void:
	_walk(&"trial_warrior")
	check(PrologueService.choose_starting_class(character, &"guardian") != "", "guardian is no prologue choice")
	check(PrologueService.choose_starting_class(character, &"arcanist") != "", "a class without its own trial")
	check(PrologueService.choose_starting_class(character, &"nonsense") != "", "unknown class")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.NONE, "refused choices create no claim")
	# a pending claim on an invalid class id (damaged data) is refused and kept, never guessed
	for bad: StringName in [&"", &"guardian", &"nonsense"]:
		var broken := CharacterFactory.create_new(db)
		broken.prologue.stage = PrologueState.Stage.COMPLETED
		broken.prologue.chosen_class = bad
		broken.prologue.class_reward = PrologueState.ClassReward.PENDING
		var bag := broken.inventory.items().size()
		check(PrologueService.claim_class_reward(broken, _rng(1)) != "", "chosen_class '%s' refused" % bad)
		check_eq(broken.inventory.items().size(), bag, "no item for '%s'" % bad)
		check_eq(broken.prologue.class_reward, PrologueState.ClassReward.PENDING, "claim kept for '%s'" % bad)


func test_model_comes_from_the_choice_not_the_active_class() -> void:
	_choose(&"shadowrunner")
	check(character.classes.is_unlocked(&"shadowrunner") and character.classes.active_class_id == &"shadowrunner", "M1: chosen class unlocked and active")
	check(not character.classes.is_unlocked(&"warrior") and not character.classes.is_unlocked(&"arcanist"), "M1: the others stay locked")
	character.classes.unlock(&"warrior")   # e.g. a later class quest / debug switch
	character.classes.set_active(&"warrior")
	var claimed: Array[ItemInstance] = []
	check_eq(PrologueService.claim_class_reward(character, _rng(3), claimed), "", "claims")
	check_eq(claimed[0].definition_id, &"iron_dagger", "model from prologue.chosen_class, not the active class")
	check_eq(character.classes.active_class_id, &"warrior", "claiming changes no class")


# --- 8, 9, 11: full bag and repeats --------------------------------------------------

func test_full_bag_keeps_the_claim() -> void:
	_choose(&"warrior")
	while not character.inventory.is_full():
		check(not character.inventory.add_item(&"iron_axe").is_empty(), "filler added")
	var bag := character.inventory.items()
	var error := PrologueService.claim_class_reward(character, _rng(5))
	check(error.contains("full"), "clear message: %s" % error)
	check_eq(character.inventory.items(), bag, "bag untouched (nothing dropped, nothing created)")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.PENDING, "claim stays pending")
	check(character.prologue.is_completed() and character.prologue.chosen_class == &"warrior", "the choice stays")
	var reloaded := _reload(character)
	check_eq(reloaded.prologue.class_reward, PrologueState.ClassReward.PENDING, "pending survives save/load with a full bag")
	character.inventory.remove_instance(bag[bag.size() - 1].instance_id)   # make room
	var claimed: Array[ItemInstance] = []
	check_eq(PrologueService.claim_class_reward(character, _rng(5), claimed), "", "claim after making room")
	check_eq(character.inventory.count(&"steel_greatsword"), bag.filter(func(i: ItemInstance) -> bool: return i.definition_id == &"steel_greatsword").size() + 1,
			"one greatsword more")
	check(character.inventory.is_full(), "the freed slot holds the reward")


func test_repeated_claims_and_choice_events_add_nothing() -> void:
	_choose(&"arcanist")
	check_eq(PrologueService.claim_class_reward(character, _rng(9)), "", "first claim")
	var bag := character.inventory.items().size()
	var staffs := character.inventory.count(&"oak_staff")
	for i in 3:
		check(PrologueService.claim_class_reward(character, _rng(9 + i)) != "", "repeat %d refused" % i)
	StoryService.notify(character, &"class_chosen")   # repeated choice event
	check(PrologueService.choose_starting_class(character, &"arcanist") != "", "the choice never runs twice")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.CLAIMED, "still claimed")
	check_eq(character.inventory.items().size(), bag, "no further item")
	check_eq(character.inventory.count(&"oak_staff"), staffs, "no second staff")


# --- 12, 13: save/load -----------------------------------------------------------------

func test_save_load_pending_and_claimed() -> void:
	_choose(&"shadowrunner")
	var pending := _reload(character)
	check_eq(pending.prologue.class_reward, PrologueState.ClassReward.PENDING, "pending stays pending")
	check_eq(pending.prologue.to_dict().class_reward, "pending", "written as pending")
	var claimed: Array[ItemInstance] = []
	check_eq(PrologueService.claim_class_reward(pending, _rng(11), claimed), "", "claim after load")
	var after := _reload(pending)
	check_eq(after.prologue.class_reward, PrologueState.ClassReward.CLAIMED, "claimed stays claimed")
	var loaded := after.inventory.find(claimed[0].instance_id)
	check(loaded != null, "the reward is in the loaded bag")
	if loaded != null:
		check_eq(loaded.to_dict(), claimed[0].to_dict(), "rarity, level and affixes saved unchanged")
	var bag := after.inventory.items().size()
	check(PrologueService.claim_class_reward(after, _rng(11)) != "", "no claim again after load")
	check_eq(after.inventory.items().size(), bag, "no second item after load")


func test_unknown_saved_state_is_no_claim() -> void:
	var data := character.to_dict()
	data.prologue["class_reward"] = "granted"
	data.prologue["stage"] = "completed"
	data.prologue["chosen_class"] = "warrior"
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(data, db, warnings)
	check_eq(loaded.prologue.class_reward, PrologueState.ClassReward.NONE, "unknown state -> none")
	check(Array(warnings).any(func(w: String) -> bool: return w.contains("class reward")), "warned")


# --- 20: old saves ---------------------------------------------------------------------

func _v14(prologue: Variant, counter: Variant = null) -> Dictionary:
	var flags := {}
	if counter != null:
		flags["count.class_chosen"] = counter
	var data := {"world": {"flags": flags}}
	if prologue != null:
		data["prologue"] = prologue
	return data


func test_migration_v14_to_v15() -> void:
	var errors: PackedStringArray = []
	var chosen := {"stage": "completed", "completed_trials": ["trial_warrior"], "chosen_class": "warrior"}
	var cases := [
		[_v14({"stage": "not_started", "completed_trials": [], "chosen_class": ""}), "none", "no choice"],
		[_v14(chosen.duplicate(true), 1), "pending", "proven choice (story counter) -> pending"],
		[_v14(chosen.duplicate(true)), "none", "class without proof (v3->v4 / v4 era) -> none"],
		[_v14(chosen.duplicate(true), 0), "none", "counter 0 -> none"],
		[_v14(chosen.duplicate(true), "1"), "none", "malformed counter -> none"],
		[_v14({"stage": "completed", "completed_trials": [], "chosen_class": "guardian"}, 1), "none", "not a prologue class -> none"],
		[_v14({"stage": "completed", "completed_trials": [], "chosen_class": ""}, 1), "none", "missing class -> none"],
		[_v14({"stage": "in_progress", "completed_trials": [], "chosen_class": "warrior"}, 1), "none", "unfinished prologue -> none"],
	]
	for entry: Array in cases:
		var data: Dictionary = SaveMigrations.migrate(entry[0], 14, errors)
		check_eq(str(data.prologue.class_reward), entry[1], entry[2])
	var kept: Dictionary = SaveMigrations.migrate(_v14({"stage": "completed", "completed_trials": [], "chosen_class": "warrior", "class_reward": "claimed"}, 1), 14, errors)
	check_eq(kept.prologue.class_reward, "claimed", "an existing state is never overwritten")
	var without: Dictionary = SaveMigrations.migrate(_v14(null, 1), 14, errors)
	check(not without.has("prologue"), "no prologue: nothing invented")
	check(errors.is_empty(), "migrates: %s" % [errors])
	check_eq(SaveSystem.VERSION, 15, "save version 15")


func test_v3_derived_class_gets_no_reward() -> void:
	var old := {"classes": {"active": "warrior", "progress": {"basic_adventurer": {"unlocked": true, "level": 3, "xp": 0},
		"warrior": {"unlocked": true, "level": 5, "xp": 10}}}, "inventory": []}
	var errors: PackedStringArray = []
	var upgraded: Dictionary = SaveMigrations.migrate(old, 3, errors)
	check(errors.is_empty(), "migrates: %s" % [errors])
	check_eq(upgraded.prologue.chosen_class, "warrior", "class derived from the old unlock (v3 -> v4)")
	check_eq(upgraded.prologue.class_reward, "none", "derived class: no retroactive reward")
	var warnings: PackedStringArray = []
	var loaded := Character.from_dict(upgraded, db, warnings)
	check_eq(loaded.prologue.class_reward, PrologueState.ClassReward.NONE, "loaded: no claim")
	check(PrologueService.claim_class_reward(loaded, _rng(1)) != "", "claim refused")


func test_reward_data_is_valid() -> void:
	check(not Array(db.validate()).any(func(e: String) -> bool: return e.contains("class reward")), "no class reward data errors")
	for class_id: StringName in MODELS:
		check_eq(StringName(str(db.rules.class_reward_items.get(class_id, ""))), MODELS[class_id], "%s -> %s" % [class_id, MODELS[class_id]])
	check_eq(db.rules.class_reward_rarity, R.MAGIC, "Magic")
	check_eq(db.rules.class_reward_item_level, 5, "item level 5")


# --- Phase C: the altar's claim action (separate from the choice) -----------------------

func test_altar_claim_action() -> void:
	_walk(&"trial_warrior")
	var panel := ClassChoicePanel.new()
	add_child(panel)
	panel.open(character, null)
	var claim := panel.find_child("ClaimReward", true, false) as Button
	check(not panel.footer.visible, "no claim before the choice: no reward footer")
	check_eq(panel.choose(&"warrior"), "confirm", "first click asks")
	check_eq(panel.choose(&"warrior"), "", "choice confirmed")
	check_eq(_models_in_bag(character), _models_in_bag(CharacterFactory.create_new(db)), "choosing grants no item")
	check(panel.footer.visible and not claim.disabled, "claim action offered after the choice")
	var fillers: Array[ItemInstance] = []
	while not character.inventory.is_full():
		fillers.append_array(character.inventory.add_item(&"iron_axe"))
	panel.rebuild()
	check(claim.disabled and claim.tooltip_text.contains("full"), "full bag: claim disabled with the reason")
	check(panel.claim_reward().contains("full"), "full bag: claim refused")
	check_eq(character.prologue.class_reward, PrologueState.ClassReward.PENDING, "still pending")
	character.inventory.remove_instance(fillers[0].instance_id)
	panel.rebuild()
	check(not claim.disabled, "room again: claim offered")
	var swords := character.inventory.count(&"steel_greatsword")
	check_eq(panel.claim_reward(), "", "claimed at the altar")
	check_eq(character.inventory.count(&"steel_greatsword"), swords + 1, "one greatsword")
	check(claim.disabled and claim.text == tr("UI_CLASS_REWARD_CLAIMED"), "button shows the gift as received")
	check(panel.claim_reward() != "", "second click refused")
	check_eq(character.inventory.count(&"steel_greatsword"), swords + 1, "still one greatsword")
	panel.queue_free()
