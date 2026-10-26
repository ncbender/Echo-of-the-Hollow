class_name DialoguePanel
extends UiWindow
## Conversation window in the lower part of the screen: one short line at a
## time, the speaker's name in their colour (serif), a line counter. Signs,
## notes and memory fragments use the same window in a "note" look.
## Continue with G, Enter or the button; Esc leaves early (nothing is
## completed then, the conversation can simply be started again). The
## completion callback runs only after the last line. Player input is ignored
## for a moment after each line, so one double press never skips a line.

## Seconds after showing a line in which player input cannot advance it.
const INPUT_GUARD := 0.18

var _speaker: Label
var _counter: Label
var _text: Label
var _next: Button
## [{"name", "text", "color", "note"?}]
var _lines: Array[Dictionary] = []
var _index: int = 0
var _on_done: Callable
var _guard_left: float = 0.0


func _ready() -> void:
	set_close_text("Leave [Esc]")
	auto_focus = false
	var head := HBoxContainer.new()
	_speaker = UiTheme.heading()
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_speaker)
	_counter = UiTheme.styled("", &"CaptionLabel")
	head.add_child(_counter)
	body.add_child(head)
	_text = UiTheme.wrapped("", UiTheme.PARCHMENT, 760)
	_text.add_theme_font_size_override(&"font_size", UiTheme.FONT_SUBHEADING)
	_text.custom_minimum_size.y = 72
	body.add_child(_text)
	_next = UiTheme.button("", &"PrimaryButton", _on_continue_pressed)
	_next.name = "Continue"
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
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


## Player input (key or button): guarded against double presses.
func _on_continue_pressed() -> void:
	if _guard_left > 0.0:
		return
	advance()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var note: bool = line.get("note", false)
	_speaker.text = str(line.get("name", ""))
	_speaker.visible = _speaker.text != ""
	_speaker.add_theme_color_override(&"font_color", UiTheme.BRONZE if note else line.get("color", UiTheme.RESONANCE))
	_text.text = str(line.get("text", ""))
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if note else HORIZONTAL_ALIGNMENT_LEFT
	_counter.text = "%d / %d" % [_index + 1, _lines.size()] if _lines.size() > 1 else ""
	_next.text = "Continue  [G]" if _index < _lines.size() - 1 else ("Close  [G]" if note else "End  [G]")
	_guard_left = INPUT_GUARD
	_next.grab_focus.call_deferred()
	queue_fit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		_on_continue_pressed()
		get_viewport().set_input_as_handled()


## Lower third of the screen instead of the centre: the speakers stay visible.
func fit() -> void:
	super.fit()
	if visible and is_inside_tree():
		position.y = maxf(UiTheme.SCREEN_MARGIN, get_viewport_rect().size.y - size.y - UiTheme.SCREEN_MARGIN * 8)


func _process(delta: float) -> void:
	_guard_left = maxf(0.0, _guard_left - delta)   # game time: also exact in scripted runs
