class_name TrialObjective
extends Resource
## One goal of a class trial or class quest, counted from combat events
## (ObjectiveTracker). Data-driven: no class-specific code.

enum Kind {
	## The class resource reaches `amount` (rage, mana, focus).
	RESOURCE_AT_LEAST,
	## Accepted hits of skill `target_id` (&"" = any skill).
	SKILL_HITS,
	## Skill casts of `target_id` (&"" = any).
	SKILL_CASTS,
	## Applications of status `target_id` (marks, weak points ...).
	STATUS_APPLIED,
	## Stacks of status `target_id` consumed (detonations, executions, ruptures).
	STATUS_CONSUMED,
	## Enemies killed (training targets never count).
	KILLS,
	## Poise breaks of enemy variant `target_id` (EnemyConfig.id; &"" = any).
	POISE_BREAKS,
}

@export var kind: Kind = Kind.KILLS
@export var target_id: StringName
@export var amount: float = 1.0
@export var description: String


func is_counter() -> bool:
	return kind != Kind.RESOURCE_AT_LEAST
