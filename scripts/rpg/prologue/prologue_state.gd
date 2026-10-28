class_name PrologueState
extends RefCounted
## Prologue progress of a character (saved under "prologue"): which class trials
## were completed and the one permanent class choice. A running trial and its
## objective progress are TEMPORARY: never saved (loading always returns to the
## state before the trial).
## Class Trials 2.0 M4 (docs/CLASS_TRIALS_2_0_M4.md): the one class reward of the
## choice - NONE (no claim), PENDING (earned, not taken yet) or CLAIMED. Only
## PrologueService sets it; nothing else ever creates a claim.

enum Stage { NOT_STARTED, IN_PROGRESS, COMPLETED }
enum ClassReward { NONE, PENDING, CLAIMED }
const CLASS_REWARD_NAMES := ["none", "pending", "claimed"]

signal changed
## A trial ended (completed = all objectives met; false = left or aborted).
signal trial_finished(trial_id: StringName, completed: bool)

var stage: Stage = Stage.NOT_STARTED
var completed_trials: Array[StringName] = []
## The class chosen at the end of the prologue (&"" until then).
var chosen_class: StringName
## Class Trials 2.0 M4: state of the class reward (saved, v15).
var class_reward: ClassReward = ClassReward.NONE
## Running trial (transient).
var active_trial: StringName
## Objective index -> amount of the running trial (transient).
var trial_progress: Dictionary = {}
## Hearth Flask charges when the running trial began (transient): restored when
## it ends and written instead of the live value while it runs.
var trial_flask_charges: int = -1


func is_completed() -> bool:
	return stage == Stage.COMPLETED


func has_completed_trial(trial_id: StringName) -> bool:
	return trial_id in completed_trials


func to_dict() -> Dictionary:
	return {
		"stage": ["not_started", "in_progress", "completed"][stage],
		"completed_trials": completed_trials.map(func(id: StringName) -> String: return String(id)),
		"chosen_class": String(chosen_class),
		"class_reward": CLASS_REWARD_NAMES[class_reward],
	}


func from_dict(data: Dictionary, warnings: PackedStringArray) -> void:
	var names := ["not_started", "in_progress", "completed"]
	var stage_name := str(data.get("stage", "not_started"))
	if not stage_name in names:
		warnings.append("unknown prologue stage %s; treated as not started" % stage_name)
		stage_name = "not_started"
	stage = names.find(stage_name) as Stage
	completed_trials = ClassBuild._names(data.get("completed_trials", []))
	chosen_class = StringName(str(data.get("chosen_class", "")))
	var reward_name := str(data.get("class_reward", "none"))
	if not reward_name in CLASS_REWARD_NAMES:
		warnings.append("unknown class reward state %s; treated as none" % reward_name)   # a claim is never guessed
		reward_name = "none"
	class_reward = CLASS_REWARD_NAMES.find(reward_name) as ClassReward
	active_trial = &""
	trial_progress.clear()
	trial_flask_charges = -1
