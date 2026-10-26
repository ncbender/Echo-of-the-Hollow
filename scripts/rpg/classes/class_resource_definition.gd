class_name ClassResourceDefinition
extends Resource
## Generic class resource (rage, mana, focus, resolve, soul energy ...).
## The runtime value lives in ClassResourcePool and is not saved (resets per session).
## Gains are driven by the character's dispatched hits (ClassRuntime).

@export var id: StringName
@export var display_name: String
@export var max_value: float = 100.0
@export var start_value: float = 0.0
## Units per second; negative values decay (e.g. rage), positive regenerate (e.g. mana).
@export var regen_per_second: float = 0.0
## Seconds after the last gain before regen/decay applies.
@export var regen_delay: float = 0.0
@export var gain_per_hit_dealt: float = 0.0
@export var gain_per_hit_taken: float = 0.0
@export var color: Color = Color.WHITE

@export_group("Event Gains")
## Extra gain for weapon hits carrying a tag, e.g. {&"finisher": 6, &"weak_point": 12}.
@export var gain_per_tag: Dictionary[StringName, float] = {}
## Gain when one of the character's hits breaks a target's poise.
@export var gain_per_poise_break: float = 0.0
## Gain when one of the character's hits kills a target.
@export var gain_per_kill: float = 0.0

@export_group("Combat Pressure")
## Consecutive weapon hits within `pressure_window` seconds build pressure stacks
## (up to pressure_max_stacks); each stack adds pressure_gain_bonus to resource
## gains. Taking a hit or pausing resets it. 0 stacks = no pressure mechanic.
@export var pressure_max_stacks: int = 0
@export var pressure_window: float = 2.0
@export var pressure_gain_bonus: float = 0.1
