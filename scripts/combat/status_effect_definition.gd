class_name StatusEffectDefinition
extends Resource
## A timed status on a combat target (bleeding, chill, arcane mark, weak point ...).
## Pure data; StatusComponent on the target runs it. Damage over time is dealt as
## HitData (source STATUS) through the target's Hurtbox; slows only change the
## target's own locomotion - never Engine.time_scale, never anyone's dash.

enum StackRule {
	## One stack; a new application renews the duration and keeps the stronger power.
	REFRESH,
	## Adds stacks up to max_stacks; every application renews the duration.
	STACK,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var duration: float = 4.0
@export var max_stacks: int = 1
@export var stack_rule: StackRule = StackRule.REFRESH

@export_group("Damage Over Time")
## Damage per second per stack at power 1.
@export var damage_per_second: float = 0.0
@export var tick_interval: float = 0.5
@export var damage_type: StringName = &"physical"

@export_group("Control")
## Locomotion slow per stack (0.15 = 15 % slower).
@export var slow_per_stack: float = 0.0
## Upper limit of this status's slow (the target may cap it lower, e.g. bosses).
@export var max_slow: float = 0.0

@export_group("Presentation")
@export var color: Color = Color.WHITE


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"":
		errors.append("status without id")
	if duration <= 0.0 or max_stacks < 1:
		errors.append("status %s: duration and max_stacks must be positive" % id)
	if damage_per_second > 0.0 and tick_interval <= 0.0:
		errors.append("status %s: damage over time needs a tick interval" % id)
	if slow_per_stack < 0.0 or max_slow < 0.0 or max_slow > 0.9:
		errors.append("status %s: slow must be within 0..0.9" % id)
	return errors
