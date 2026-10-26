class_name StoryStep
extends Resource
## One step of a story quest: all objectives must be met to advance.

@export var description: String
@export var objectives: Array[StoryObjective] = []
## World flag set when this step is completed (stable prologue ids).
@export var completion_flag: StringName
