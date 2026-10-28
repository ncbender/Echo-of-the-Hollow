class_name PrologueService
extends RefCounted
## Prologue rules (docs/CLASS_QUESTS.md):
##  * the player starts as Basic Adventurer and may try Warrior, Arcanist and
##    Shadowrunner in temporary trials - a trial never unlocks the class, never
##    grants talent points, skills or items, and leaves no trace when it ends
##  * Class Trials 2.0 (docs/CLASS_TRIALS_2_0_M1.md): one completed trial is
##    enough; the player chooses EXACTLY ONE class whose OWN trial was completed
##    (further trials stay optional until then). That class is unlocked
##    permanently and activated, the others stay locked (later class quests
##    unlock them), and the choice can never run again
##  * Class Trials 2.0 M3 (docs/CLASS_TRIALS_2_0_M3.md): trials run on their own
##    grounds (TrialDefinition.map_id, TrialGrounds); training goals open the
##    trial gate, finale goals (mini-boss variant) complete the trial. A trial
##    never costs Hearth Flask charges and blocks every reward (rewards_blocked)


static func trial_for_class(db: GameDatabase, class_id: StringName) -> TrialDefinition:
	for trial: TrialDefinition in db.trials.values():
		if trial.class_id == class_id:
			return trial
	return null


static func prologue_classes(db: GameDatabase) -> Array[StringName]:
	return db.rules.prologue_class_ids


static func can_begin_trial(character: Character, trial_id: StringName) -> String:
	var prologue := character.prologue
	var trial: TrialDefinition = character.database.trials.get(trial_id)
	if trial == null or not trial.class_id in prologue_classes(character.database):
		return "Unknown trial."
	if prologue.is_completed():
		return "The prologue is already complete."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	return ""


## "" if the trial grounds of `trial_id` may be visited from the Heart of the
## Stone now (Class Trials 2.0 M2). Same gate as starting a trial; visiting
## alone starts no trial, chooses no class and completes nothing.
static func can_visit_grounds(character: Character, trial_id: StringName) -> String:
	var error := can_begin_trial(character, trial_id)
	if error != "":
		return error
	var trial: TrialDefinition = character.database.trials[trial_id]
	if trial.map_id == &"" or not character.database.maps.has(trial.map_id):
		return "This echo has no grounds yet."
	return ""


## Starts a temporary trial: the trial class is played at the trial level with
## the trial's build and a reference copy of the current loadout.
static func begin_trial(character: Character, trial_id: StringName) -> String:
	var error := can_begin_trial(character, trial_id)
	if error != "":
		return error
	var trial: TrialDefinition = character.database.trials[trial_id]
	var prologue := character.prologue
	prologue.stage = PrologueState.Stage.IN_PROGRESS
	prologue.active_trial = trial_id
	prologue.trial_progress.clear()
	prologue.trial_flask_charges = character.consumables.charges   # restored when the trial ends (M3)
	character.equipment.begin_trial(trial.class_id, character.classes.active_class_id)
	character.builds.begin_trial_build(trial.make_build(character.database.rules.talent_rules().skill_slots))
	character.classes.begin_trial(trial.class_id, trial.trial_level)
	prologue.changed.emit()
	return ""


## Ends the running trial; `completed` records it as done. Everything temporary
## (class, level, build, loadout copy, resource, cooldowns) is discarded.
static func end_trial(character: Character, completed: bool) -> void:
	var prologue := character.prologue
	var trial_id := prologue.active_trial
	if trial_id == &"":
		return
	prologue.active_trial = &""
	prologue.trial_progress.clear()
	if prologue.trial_flask_charges >= 0:   # the trial never costs (nor gains) Hearth Flask charges
		character.consumables.charges = mini(prologue.trial_flask_charges, ConsumableService.max_charges(character))
		prologue.trial_flask_charges = -1
		character.consumables.changed.emit()
	var first_completion := completed and not trial_id in prologue.completed_trials
	if first_completion:
		prologue.completed_trials.append(trial_id)
	character.classes.end_trial()
	character.builds.end_trial_build()
	character.equipment.end_trial()
	prologue.trial_finished.emit(trial_id, completed)
	prologue.changed.emit()
	if first_completion:
		StoryService.notify(character, &"trial_complete")   # after the trial state is gone: safe to save


static func objectives_done(character: Character, trial: TrialDefinition) -> bool:
	for index in trial.objectives.size():
		if float(character.prologue.trial_progress.get(index, 0.0)) + 0.0001 < trial.objectives[index].amount:
			return false
	return true


## Class Trials 2.0 M3: every training (non-finale) goal of the RUNNING trial
## `trial_id` is met - the trial gate opens. False without that running trial.
static func training_done(character: Character, trial_id: StringName) -> bool:
	if character.prologue.active_trial != trial_id or trial_id == &"":
		return false
	var trial: TrialDefinition = character.database.trials.get(trial_id)
	if trial == null:
		return false
	for index in trial.objectives.size():
		var objective := trial.objectives[index]
		if not objective.finale and float(character.prologue.trial_progress.get(index, 0.0)) + 0.0001 < objective.amount:
			return false
	return true


## The trial whose grounds are `map_id` (null: not trial grounds).
static func trial_for_map(db: GameDatabase, map_id: StringName) -> TrialDefinition:
	if map_id == &"":
		return null
	for trial: TrialDefinition in db.trials.values():
		if trial.map_id == map_id:
			return trial
	return null


## Class Trials 2.0 M3: no permanent progress from fights inside a trial or on
## trial grounds (drops, class/weapon/armor mastery XP, item evolution XP). The
## one source every reward pipeline asks; regular fights are never affected.
static func rewards_blocked(character: Character) -> bool:
	return character.classes.in_trial() or trial_for_map(character.database, character.world.current_map_id) != null


## Counts a combat event for the running trial (and active class quests). The
## trial completes - and ends - as soon as all its objectives are met.
static func record(character: Character, kind: TrialObjective.Kind, target_id: StringName, amount: float) -> void:
	QuestService.record(character, kind, target_id, amount)
	var prologue := character.prologue
	var trial: TrialDefinition = character.database.trials.get(prologue.active_trial)
	if trial == null:
		return
	var touched := false
	for index in trial.objectives.size():
		var objective := trial.objectives[index]
		if ObjectiveRules.matches(objective, kind, target_id):
			var before: float = prologue.trial_progress.get(index, 0.0)
			prologue.trial_progress[index] = ObjectiveRules.advance(objective, before, amount)
			touched = touched or prologue.trial_progress[index] != before
	if not touched:
		return
	prologue.changed.emit()
	if objectives_done(character, trial):
		end_trial(character, true)


static func can_choose(character: Character, class_id: StringName) -> String:
	var prologue := character.prologue
	if prologue.is_completed():
		return "Your starting class was already chosen."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	if not class_id in prologue_classes(character.database):
		return "This class cannot be chosen in the prologue."
	var trial := trial_for_class(character.database, class_id)
	if trial == null or not prologue.has_completed_trial(trial.id):
		return "Walk the echo of this path first."   # only its OWN trial opens a class
	return ""


## The one permanent prologue choice: unlocks and activates `class_id`.
static func choose_starting_class(character: Character, class_id: StringName) -> String:
	var error := can_choose(character, class_id)
	if error != "":
		return error
	character.classes.unlock(class_id)
	character.classes.set_active(class_id)
	var prologue := character.prologue
	prologue.chosen_class = class_id
	prologue.stage = PrologueState.Stage.COMPLETED
	if prologue.class_reward == PrologueState.ClassReward.NONE:
		prologue.class_reward = PrologueState.ClassReward.PENDING   # the one claim (M4), never a second
	prologue.changed.emit()
	StoryService.notify(character, &"class_chosen")
	return ""


## Class Trials 2.0 M4 (docs/CLASS_TRIALS_2_0_M4.md): the weapon model of the class
## reward - only ever from prologue.chosen_class (never the active class or the
## equipped weapon). Null without a valid choice or reward data.
static func class_reward_item(character: Character) -> ItemDefinition:
	var prologue := character.prologue
	var rules := character.database.rules
	if not prologue.is_completed() or not prologue.chosen_class in prologue_classes(character.database):
		return null
	return character.database.get_item(StringName(str(rules.class_reward_items.get(prologue.chosen_class, ""))))


## "" if the pending class reward can be taken now, else the reason (also for UI).
static func can_claim_class_reward(character: Character) -> String:
	var prologue := character.prologue
	if prologue.class_reward == PrologueState.ClassReward.CLAIMED:
		return "The stone's gift was already taken."
	if prologue.class_reward != PrologueState.ClassReward.PENDING:
		return "The stone holds no gift for you."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	var definition := class_reward_item(character)
	if definition == null:
		return "The stone cannot shape a gift for this path."
	if character.inventory.room_for(definition.id) < 1:
		return "Your bag is full. Make room to receive the stone's gift."
	return ""


## Takes the pending class reward: one new Magic instance of the chosen class's weapon
## model (ItemCreation.generate, regular affix rolls) into the bag, then CLAIMED. All
## checks run before the item is generated; a refusal changes nothing (stays PENDING).
## Bag and claim state change in the same call, so every save sees both or neither.
## Returns "" or the reason; `claimed` receives the new item on success.
static func claim_class_reward(character: Character, rng: RandomNumberGenerator, claimed: Array[ItemInstance] = []) -> String:
	var error := can_claim_class_reward(character)
	if error != "":
		return error
	var rules := character.database.rules
	var result := ItemCreation.generate(class_reward_item(character), rules.class_reward_rarity, character.database, rng,
			rules.class_reward_tier_weights, rules.class_reward_item_level, ItemInstance.ORIGIN_QUEST)
	if not result.ok():
		return "The stone cannot shape a gift for this path."
	error = character.inventory.add_instance(result.item)
	if error != "":
		return "Your bag is full. Make room to receive the stone's gift."
	character.prologue.class_reward = PrologueState.ClassReward.CLAIMED
	character.prologue.changed.emit()
	claimed.append(result.item)
	return ""
