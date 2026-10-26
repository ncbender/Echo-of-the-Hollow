class_name UiConfirmDialog
extends UiWindow
## The one confirmation dialog of the game (overwrite a save, discard an item,
## start a new journey, delete a preset ...). Cancel has keyboard focus, so an
## accidental Enter never confirms something destructive. Esc cancels.

signal resolved(confirmed: bool)

var _message: Label
var _confirm: Button
var _cancel: Button
var _on_confirm: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # also on top of the pause menu
	auto_focus = false
	close_button().visible = false
	_message = UiTheme.wrapped("", UiTheme.TEXT_PRIMARY, 460)
	body.add_child(_message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_cancel = UiTheme.button("Cancel", &"", _resolve.bind(false))
	_cancel.name = "Cancel"
	row.add_child(_cancel)
	_confirm = UiTheme.button("Confirm", &"PrimaryButton", _resolve.bind(true))
	_confirm.name = "Confirm"
	row.add_child(_confirm)
	body.add_child(row)


## Shows the dialog; `on_confirm` runs only when the player confirms.
func ask(title: String, message: String, confirm_text: String, on_confirm: Callable, danger: bool = false) -> void:
	set_title(title)
	_message.text = message
	_confirm.text = confirm_text
	_confirm.theme_type_variation = &"DangerButton" if danger else &"PrimaryButton"
	_on_confirm = on_confirm
	show()
	move_to_front()
	_cancel.grab_focus.call_deferred()


func confirm() -> void:
	_resolve(true)


func cancel() -> void:
	_resolve(false)


func _resolve(confirmed: bool) -> void:
	if not visible:
		return
	var action := _on_confirm
	_on_confirm = Callable()
	hide()
	resolved.emit(confirmed)
	if confirmed and action.is_valid():
		action.call()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
