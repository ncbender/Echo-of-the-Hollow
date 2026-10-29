class_name StoryStep
extends Resource
## One step of a story quest: all objectives must be met to advance.

@export var description: String
@export var objectives: Array[StoryObjective] = []
## Combat HUD UX 2.0: optional short goal for the HUD tracker when no objective has a description (a step
## without objectives); empty = the step description. Display text only - no rule reads it.
@export var hud_goal: String = ""
## World flag set when this step is completed (stable prologue ids).
@export var completion_flag: StringName
