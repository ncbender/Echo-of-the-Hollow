class_name AttackModifier
extends Resource
## Extension point for unique/legendary items, class talents and mastery effects.
## Subclass and override what you need; the base implementation changes nothing.
## Modifiers are applied by CombatComponent before a hit is delivered.


## Whether this modifier applies to `attack` (e.g. only finishers, only one family).
func applies_to(_attack: AttackDefinition) -> bool:
	return true


## Adjust the hit before delivery (damage, poise, tags, knockback...).
func modify_hit(_hit: HitData) -> void:
	pass


## Adjust the hit-sector reach of `attack` (called whenever the reach is queried).
## Must not modify the AttackDefinition itself.
func modify_reach(_attack: AttackDefinition, reach: float) -> float:
	return reach
