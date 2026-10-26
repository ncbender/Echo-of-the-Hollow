class_name DialogueLine
extends Resource
## One spoken line. `speaker` is an NPC id, &"player" (shown as "You") or
## empty (narration).

@export var speaker: StringName
@export_multiline var text: String
