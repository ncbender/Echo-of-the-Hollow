class_name ClassResourceDefinition
extends Resource
## Generic class resource (rage, mana, focus, resolve, soul energy ...).
## The runtime value lives in ClassResourcePool and is not saved (resets per session).

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
