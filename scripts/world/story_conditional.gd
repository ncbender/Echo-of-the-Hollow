class_name StoryConditional
extends Node2D
## Enables its children only while `condition` holds (or does not hold, with
## `invert`): debris that blocks a road until the story allows passage, props
## of a ruin stage ... Disabled children are hidden AND removed from physics.

@export var condition: StoryCondition
@export var invert: bool = false

var character: Character


func _ready() -> void:
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()
		character.world.flag_changed.connect(_on_flag_changed)
		character.quests.changed.connect(refresh_story)
	refresh_story()


func _exit_tree() -> void:
	if character != null:
		if character.world.flag_changed.is_connected(_on_flag_changed):
			character.world.flag_changed.disconnect(_on_flag_changed)
		if character.quests.changed.is_connected(refresh_story):
			character.quests.changed.disconnect(refresh_story)


func is_active() -> bool:
	return StoryCondition.check(condition, character) != invert


func refresh_story() -> void:
	var active := is_active()
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	refresh_story.call_deferred()   # physics state may not change inside a callback
