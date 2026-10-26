class_name PotionEffectDefinition
extends Resource
## The timed buff of a special potion (Consumables 1.0). Data only: the stat
## modifiers run through Character runtime modifiers (StatResolver), the
## duration through ConsumableService. Only one potion buff is active at a
## time; a new one replaces it.

## Stable id (also the buff's runtime modifier source).
@export var id: StringName
## Short effect text for tooltips and the effect bar ("+8% damage dealt").
@export var summary: String
## Seconds the buff lasts.
@export var duration: float = 60.0
@export var modifiers: Array[StatModifier] = []
## Icon colour of the potion and its buff.
@export var color: Color = Color(0.8, 0.5, 0.3)
