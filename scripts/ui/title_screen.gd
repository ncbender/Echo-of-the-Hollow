class_name TitleScreen
extends Control
## Main menu (project main scene): Continue (newest valid save, manual or
## auto), New Game (prologue start; asks first when saves exist), Load Game
## (manual saves and autosaves in a slot window), Options, Quit.
## Uses the shared UiTheme / UiWindow components.

var session: SessionState
var options_panel: OptionsPanel
var load_window: UiWindow
var confirm_dialog: UiConfirmDialog

var _menu: VBoxContainer
var _status: Label
var _latest: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	session = SessionState.find(get_tree())
	get_tree().paused = false
	var background := Backdrop.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	center.add_child(box)
	var title := UiTheme.styled("Echoes of the Hollow", &"DisplayLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var rule := HSeparator.new()
	box.add_child(rule)
	var card := UiTheme.card(&"CardPanel")
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu = card.get_node("Box") as VBoxContainer
	box.add_child(card)
	_status = UiTheme.wrapped("", UiTheme.WARNING, 520)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	options_panel = OptionsPanel.new()
	options_panel.hide()
	add_child(options_panel)
	load_window = UiWindow.new()
	load_window.set_title("Load Game")
	load_window.hide()
	add_child(load_window)
	confirm_dialog = UiConfirmDialog.new()
	confirm_dialog.hide()
	add_child(confirm_dialog)
	_build_menu()


func _build_menu() -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	var latest := SaveSlots.latest(session.save_path) if session != null else {}
	_button("Continue", continue_game, not latest.is_empty(), &"PrimaryButton")
	_latest = UiTheme.styled(SaveSlotList.describe(latest) if not latest.is_empty() else "No saved journey yet.", &"CaptionLabel")
	_latest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_latest)
	_button("New Game", new_game)
	_button("Load Game", open_load, not latest.is_empty())
	_button("Options", func() -> void:
		if session != null:
			options_panel.open(session.settings))
	_button("Quit", func() -> void: get_tree().quit())
	_focus_first.call_deferred()


func _focus_first() -> void:
	for button: Button in _menu.find_children("*", "Button", true, false):
		if not button.disabled:
			button.grab_focus()
			return


func _button(text: String, action: Callable, enabled: bool = true, variation: StringName = &"") -> Button:
	var button := UiTheme.button(text, variation, action)
	button.name = text.replace(" ", "")
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(380, 0)
	_menu.add_child(button)
	return button


func continue_game() -> void:
	var latest := SaveSlots.latest(session.save_path)
	if latest.is_empty():
		return
	_load_path(latest.path)


## A new journey. With saves present it asks first: manual slots are kept, but
## the new journey's autosaves will replace the old autosaves.
func new_game() -> void:
	if SaveSlots.latest(session.save_path).is_empty():
		session.new_game()
		return
	confirm_dialog.ask("Start a new journey?", "Your manual save slots are kept. The three autosaves will be reused by the new journey.",
		"Start New Game", session.new_game)


func open_load() -> void:
	for child in load_window.body.get_children():
		load_window.body.remove_child(child)
		child.queue_free()
	SaveSlotList.build(load_window.body, session.save_path, false, func(path: String, _slot: int, _info: Dictionary) -> void:
		load_window.hide()
		_load_path(path))
	load_window.show()


func _load_path(path: String) -> void:
	var result := session.load_game(path)
	if not result.ok():
		_status.text = "Loading failed: %s" % "; ".join(result.errors)


## Calm dark backdrop with a faint bronze horizon (provisional key art).
class Backdrop:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
		var horizon := size.y * 0.62
		for index in 24:
			var t := float(index) / 24.0
			draw_rect(Rect2(Vector2(0, horizon + t * size.y * 0.38), Vector2(size.x, size.y * 0.38 / 24.0 + 1)),
				Color(UiTheme.PANEL, 0.25 + 0.5 * t))
		draw_line(Vector2(size.x * 0.15, horizon), Vector2(size.x * 0.85, horizon), Color(UiTheme.BRONZE_DARK, 0.6), 1.0)
		for index in 9:   # distant tree line
			var x := size.x * (0.1 + 0.1 * index)
			var h := size.y * (0.05 + 0.03 * ((index * 7) % 4))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 26, horizon), Vector2(x, horizon - h), Vector2(x + 26, horizon)]), Color(UiTheme.PANEL_INSET, 0.9))
