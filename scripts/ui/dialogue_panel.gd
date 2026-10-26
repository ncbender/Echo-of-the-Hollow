class_name DialoguePanel
extends UiWindow
## Conversation window in the lower part of the screen: one line at a time,
## speaker name in the speaker's colour. Continue with G, Enter or the button;
## Esc leaves early (nothing is completed then, the conversation can simply be
## started again). The completion callback runs only after the last line.

var _speaker: Label
var _text: Label
var _next: Button
## [{"name", "text", "color"}]
var _lines: Array[Dictionary] = []
var _index: int = 0
var _on_done: Callable


func _ready() -> void:
	set_close_text("Leave [Esc]")
	_speaker = UiTheme.heading()
	body.add_child(_speaker)
	_text = UiTheme.wrapped("", UiTheme.COLOR_TEXT, 760)
	_text.custom_minimum_size.y = 72
	body.add_child(_text)
	_next = Button.new()
	_next.name = "Continue"
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.pressed.connect(advance)
	body.add_child(_next)


## Plays an NPC dialogue; DialogueService.finish() runs after the last line.
func open_dialogue(character: Character, dialogue: DialogueDefinition, on_done: Callable = Callable()) -> void:
	var lines: Array[Dictionary] = []
	for line in dialogue.lines:
		lines.append({"name": DialogueService.speaker_name(character.database, line.speaker), "text": line.text,
			"color": DialogueService.speaker_color(character.database, line.speaker)})
	open_lines(lines, func() -> void:
		DialogueService.finish(character, dialogue)
		if on_done.is_valid():
			on_done.call())


## Plays raw lines (notes, signs, scripted scenes).
func open_lines(lines: Array[Dictionary], on_done: Callable = Callable()) -> void:
	_lines = lines
	_index = 0
	_on_done = on_done
	show()
	_show_line()


func current_text() -> String:
	return _text.text if visible else ""


func advance() -> void:
	if not visible:
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	var done := _on_done
	_on_done = Callable()
	hide()
	if done.is_valid():
		done.call()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_speaker.text = str(line.get("name", ""))
	_speaker.visible = _speaker.text != ""
	_speaker.add_theme_color_override(&"font_color", line.get("color", UiTheme.COLOR_ACCENT))
	_text.text = str(line.get("text", ""))
	_next.text = "Continue [G]" if _index < _lines.size() - 1 else "End [G]"
	queue_fit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		advance()
		get_viewport().set_input_as_handled()


## Lower third of the screen instead of the centre: the speakers stay visible.
func fit() -> void:
	super.fit()
	if visible and is_inside_tree():
		position.y = maxf(UiTheme.SCREEN_MARGIN, get_viewport_rect().size.y - size.y - UiTheme.SCREEN_MARGIN * 8)
