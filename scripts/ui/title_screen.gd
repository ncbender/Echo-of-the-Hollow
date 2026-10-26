class_name TitleScreen
extends Control
## Main menu (project main scene): Continue (newest valid save, manual or
## auto), New Game (prologue start), Load Game (all slots), Options, Quit.
## Uses the shared UiTheme and UiWindow layout rules.

var session: SessionState

var _menu: VBoxContainer
var _status: Label
var _load: VBoxContainer
var _confirm_new: bool = false
var options_panel: OptionsPanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	session = SessionState.find(get_tree())
	get_tree().paused = false
	var background := ColorRect.new()
	background.color = Color(0.05, 0.045, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	center.add_child(box)
	var title := UiTheme.heading("Echoes of the Hollow")
	title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE * 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_menu = VBoxContainer.new()
	box.add_child(_menu)
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN, 520)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	_load = VBoxContainer.new()
	_load.visible = false
	box.add_child(_load)
	options_panel = OptionsPanel.new()
	options_panel.hide()
	add_child(options_panel)
	_build_menu()


func _build_menu() -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	var latest := SaveSlots.latest(session.save_path) if session != null else {}
	_button("Continue", continue_game, not latest.is_empty(),
			"Newest save: %s" % PauseMenu.describe(latest) if not latest.is_empty() else "No save yet.")
	_button("New Game", new_game)
	_button("Load Game", _toggle_load, not latest.is_empty())
	_button("Options", func() -> void:
		if session != null:
			options_panel.open(session.settings))
	_button("Quit", func() -> void: get_tree().quit())


func _button(text: String, action: Callable, enabled: bool = true, tooltip: String = "") -> Button:
	var button := Button.new()
	button.name = text.replace(" ", "")
	button.text = text
	button.disabled = not enabled
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(360, 0)
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


func continue_game() -> void:
	var latest := SaveSlots.latest(session.save_path)
	if latest.is_empty():
		return
	_load_path(latest.path)


## Two clicks: existing manual saves stay, but autosaves of the new journey will
## replace the old autosaves.
func new_game() -> void:
	if not SaveSlots.latest(session.save_path).is_empty() and not _confirm_new:
		_confirm_new = true
		_status.text = "Start a new journey? Your manual save slots are kept; the three autosaves will be reused by the new game. Click New Game again to confirm."
		return
	_confirm_new = false
	session.new_game()


func _toggle_load() -> void:
	_load.visible = not _load.visible
	for child in _load.get_children():
		_load.remove_child(child)
		child.queue_free()
	if not _load.visible:
		return
	var paths: Array[String] = []
	for slot in range(1, SaveSlots.MANUAL_SLOTS + 1):
		paths.append(SaveSlots.manual_path(session.save_path, slot))
	for slot in range(1, SaveSlots.AUTO_SLOTS + 1):
		paths.append(SaveSlots.auto_path(session.save_path, slot))
	for index in paths.size():
		var info := SaveSystem.read_info(paths[index])
		if not info.exists:
			continue
		var label := ("Slot %d" % (index + 1)) if index < SaveSlots.MANUAL_SLOTS else ("Autosave %d" % (index - SaveSlots.MANUAL_SLOTS + 1))
		var row := HBoxContainer.new()
		row.add_child(UiTheme.label("%s  -  %s" % [label, PauseMenu.describe(info) if info.valid else "damaged"],
				UiTheme.COLOR_TEXT if info.valid else UiTheme.COLOR_ERROR))
		var button := Button.new()
		button.text = "Load"
		button.disabled = not info.valid
		button.pressed.connect(_load_path.bind(paths[index]))
		row.add_child(button)
		_load.add_child(row)


func _load_path(path: String) -> void:
	var result := session.load_game(path)
	if not result.ok():
		_status.text = "Loading failed: %s" % "; ".join(result.errors)
