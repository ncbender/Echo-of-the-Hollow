class_name StoryTrigger
extends Area2D
## Walking into this area reports `event_id` to the StoryService (while
## `condition` holds) and/or shows a contextual tutorial `hint` once per
## character ("hint.<hint_id>").

@export var event_id: StringName
@export var condition: StoryCondition
@export_multiline var hint: String
## Remembers that the hint was shown (empty: the node name).
@export var hint_id: StringName

var _session: SessionState


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	monitoring = true
	monitorable = false
	_session = SessionState.find(get_tree())
	body_entered.connect(_on_body_entered)


func hint_flag() -> StringName:
	return StringName("hint.%s" % (hint_id if hint_id != &"" else StringName(name.to_snake_case())))


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or _session == null:
		return
	var character := _session.get_character()
	if not StoryCondition.check(condition, character):
		return
	if hint != "" and not character.world.has_flag(hint_flag()):
		character.world.set_flag(hint_flag())
		var map := get_tree().current_scene as GameMap
		if map != null:
			map.hud.show_hint(hint)
	if event_id != &"":
		StoryService.notify(character, event_id)
