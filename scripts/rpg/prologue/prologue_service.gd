class_name PrologueService
extends RefCounted
## Prologue rules (docs/CLASS_QUESTS.md):
##  * the player starts as Basic Adventurer and may try Warrior, Arcanist and
##    Shadowrunner in temporary trials - a trial never unlocks the class, never
##    grants talent points, skills or items, and leaves no trace when it ends
##  * after completing all three trials the player chooses EXACTLY ONE of them;
##    that class is unlocked permanently and activated, the others stay locked
##    (later class quests unlock them), and the choice can never run again


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
	if completed and not trial_id in prologue.completed_trials:
		prologue.completed_trials.append(trial_id)
	character.classes.end_trial()
	character.builds.end_trial_build()
	character.equipment.end_trial()
	prologue.trial_finished.emit(trial_id, completed)
	prologue.changed.emit()


static func objectives_done(character: Character, trial: TrialDefinition) -> bool:
	for index in trial.objectives.size():
		if float(character.prologue.trial_progress.get(index, 0.0)) + 0.0001 < trial.objectives[index].amount:
			return false
	return true


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
	for other in prologue_classes(character.database):
		var trial := trial_for_class(character.database, other)
		if trial != null and not prologue.has_completed_trial(trial.id):
			return "Complete all three class trials first."
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
	prologue.changed.emit()
	return ""
