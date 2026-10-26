class_name PauseMenu
extends UiWindow
## Esc (no other window open): pauses the game. Resume, Save Game (five manual
## slots), Load Game (manual slots + the three autosaves), Options and Quit to
## Title. Saving goes through the SaveCoordinator (one write at a time);
## loading unpauses and loads through SessionState.

signal options_requested

var session: SessionState
var page: String = "main"

var _content: VBoxContainer
var _status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_title("Paused")
	set_close_text("Resume [Esc]")
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN, 760)
	body.add_child(_status)
	_content = VBoxContainer.new()
	body.add_child(_content)
	visibility_changed.connect(_on_visibility_changed)


func open(target_session: SessionState) -> void:
	session = target_session
	if not session.saves.save_finished.is_connected(_on_saved):
		session.saves.save_finished.connect(_on_saved)
	show()
	show_page("main")


func _on_visibility_changed() -> void:
	if is_inside_tree():
		get_tree().paused = visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if page == "main":
			hide()
		else:
			show_page("main")
		get_viewport().set_input_as_handled()


func show_page(name: String) -> void:
	page = name
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_status.text = ""
	_status.visible = false
	match name:
		"save":
			set_title("Save Game")
			_build_slots(true)
		"load":
			set_title("Load Game")
			_build_slots(false)
		_:
			set_title("Paused")
			for entry: Array in [["Resume", hide], ["Save Game", show_page.bind("save")], ["Load Game", show_page.bind("load")],
					["Options", func() -> void: options_requested.emit()], ["Quit to Title", quit_to_title]]:
				var button := Button.new()
				button.name = String(entry[0]).replace(" ", "")
				button.text = entry[0]
				button.custom_minimum_size = Vector2(320, 0)
				button.pressed.connect(entry[1])
				_content.add_child(button)
	queue_fit()


func _build_slots(saving: bool) -> void:
	var character := session.character
	if saving and character != null and character.classes.in_trial():
		_say("You are inside a class trial: the save keeps your progress from before the trial.")
	for slot in range(1, SaveSlots.MANUAL_SLOTS + 1):
		_content.add_child(_slot_row("Slot %d" % slot, SaveSlots.manual_path(session.save_path, slot), saving, slot))
	if not saving:
		_content.add_child(UiTheme.heading("Autosaves"))
		for slot in range(1, SaveSlots.AUTO_SLOTS + 1):
			_content.add_child(_slot_row("Autosave %d" % slot, SaveSlots.auto_path(session.save_path, slot), false, -1))
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(show_page.bind("main"))
	_content.add_child(back)


func _slot_row(label: String, path: String, saving: bool, slot: int) -> Control:
	var info := SaveSystem.read_info(path)
	var row := HBoxContainer.new()
	row.name = label.replace(" ", "")
	var text := "%s  -  empty" % label
	var color := UiTheme.COLOR_DIM
	if info.valid:
		text = "%s  -  %s" % [label, describe(info)]
		color = UiTheme.COLOR_TEXT
	elif info.exists:
		text = "%s  -  damaged, cannot be loaded" % label
		color = UiTheme.COLOR_ERROR
	var name_label := UiTheme.label(text, color)
	name_label.custom_minimum_size = Vector2(620, 0)
	row.add_child(name_label)
	var button := Button.new()
	button.name = "Action"
	if saving:
		button.text = "Overwrite" if info.exists else "Save here"
		button.pressed.connect(func() -> void:
			session.saves.request_manual(slot)
			_say("Saving..."))
	else:
		button.text = "Load"
		button.disabled = not info.valid
		button.pressed.connect(load_path.bind(path))
	row.add_child(button)
	return row


## "Haven - Warrior Lv 12 - 1:05:12 played - 2026-10-26 14:03".
static func describe(info: Dictionary) -> String:
	var meta: Dictionary = info.meta
	var seconds := int(meta.get("play_time", 0))
	var played := "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	var when := Time.get_datetime_string_from_unix_time(int(info.saved_at) + _utc_offset(), true)
	var who := "%s Lv %d" % [meta.get("class", "?"), int(meta.get("level", 1))]
	return "%s  -  %s  -  %s played  -  %s" % [meta.get("location", "?"), who, played, when.left(16)]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func load_path(path: String) -> void:
	hide()
	var result := session.load_game(path)
	if not result.ok():
		show()
		show_page("load")
		_say("Loading failed: %s" % "; ".join(result.errors))


func quit_to_title() -> void:
	hide()
	session.go_to_title()


func _on_saved(_id: int, ok: bool, kind: SaveCoordinator.Kind, message: String) -> void:
	if not visible or kind != SaveCoordinator.Kind.MANUAL:
		return
	show_page(page)
	_say("Game saved." if ok else message)


func _say(text: String) -> void:
	_status.text = text
	_status.visible = text != ""
