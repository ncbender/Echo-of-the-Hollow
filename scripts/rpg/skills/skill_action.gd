class_name SkillAction
extends Resource
## One step of an active skill (strike, projectile, zone, movement, buff).
## Skills are an ordered list of actions; modifications can append or replace
## actions. Actions are shared, stateless data; all runtime state lives in the
## SkillCast passed to execute().


func execute(_cast: SkillCast) -> void:
	pass


## Short rules text for tooltips.
func describe(_params: SkillParams) -> String:
	return ""


## Movement actions return true: the skill's following actions run when the
## movement arrived (SkillCast.arrive), so hits land where the caster is.
func defers_following() -> bool:
	return false


## Checked before a cast spends anything: "" or the reason it cannot run now
## (e.g. a gap closer without a reachable target).
func cast_error(_runtime: ClassRuntime, _params: SkillParams) -> String:
	return ""
