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
