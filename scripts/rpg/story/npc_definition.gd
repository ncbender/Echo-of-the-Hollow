class_name NpcDefinition
extends Resource
## A named character of the world (Mara Veyne, Edrin Vale). Where it stands is
## decided per map by StoryNpc nodes and their conditions; what it says by its
## dialogues (first matching one wins) and idle lines.

@export var id: StringName
@export var display_name: String
@export var color: Color = Color(0.8, 0.7, 0.5)
@export var dialogues: Array[DialogueDefinition] = []
## Said as a short speech bubble when no dialogue is available.
@export var idle_lines: PackedStringArray = []
