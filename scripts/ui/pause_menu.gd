class_name PauseMenu
extends UiWindow
## Esc (no other window open): pauses the game. Resume, Save Game (five manual
## slots), Load Game (manual slots and the three autosaves, clearly apart),
## Options and Quit to Title. Saving goes through the SaveCoordinator (one write
## at a time; overwriting a slot asks first); loading unpauses and loads through
## SessionState. Quitting to the title asks first (progress since the last save
## is lost).

signal options_requested

var session: SessionState
var page: String = "main"

var _content: VBoxContainer
var _status: Label
var _confirm: UiConfirmDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_title("Paused")
	set_close_text("Resume [Esc]")
	_status = UiTheme.wrapped("", UiTheme.WARNING, 680)
	body.add_child(_status)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", UiTheme.GAP)
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
		get_tree().paused = visible or (_confirm != null and _confirm.visible)


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
			_build_main()
	queue_fit()
	_focus_first.call_deferred()


func _build_main() -> void:
	var where := ""
	if session != null and session.character != null:
		var world := session.character.world
		var map_def: MapDefinition = session.database.maps.get(world.here())
		where = map_def.display_name if map_def != null else ""
	if where != "":
		_content.add_child(UiTheme.styled(where, &"SmallLabel"))
	for entry: Array in [["Resume", &"PrimaryButton", hide], ["Save Game", &"", show_page.bind("save")],
			["Load Game", &"", show_page.bind("load")], ["Options", &"", func() -> void: options_requested.emit()],
			["Quit to Title", &"DangerButton", ask_quit]]:
		var button := UiTheme.button(entry[0], entry[1], entry[2])
		button.name = String(entry[0]).replace(" ", "")
		button.custom_minimum_size = Vector2(340, 0)
		_content.add_child(button)


func _build_slots(saving: bool) -> void:
	var character := session.character
	if saving and character != null and character.classes.in_trial():
		_say("You are inside a class trial: the save keeps your progress from before the trial.")
	SaveSlotList.build(_content, session.save_path, saving, _on_slot_action.bind(saving))
	var back := UiTheme.button("Back", &"", show_page.bind("main"))
	back.name = "Back"
	_content.add_child(back)


func _on_slot_action(path: String, slot: int, info: Dictionary, saving: bool) -> void:
	if not saving:
		load_path(path)
		return
	if info.exists:
		_dialog().ask("Overwrite Slot %d?" % slot, "The journey saved in Slot %d (%s) will be replaced by your current progress." % [slot,
			SaveSlotList.describe(info) if info.valid else "damaged"], "Overwrite", _save_to.bind(slot), true)
	else:
		_save_to(slot)


func _save_to(slot: int) -> void:
	session.saves.request_manual(slot)
	_say("Saving...")


## "Haven  ·  Warrior Lv 12  ·  1:05:12 played  ·  2026-10-26 14:03".
static func describe(info: Dictionary) -> String:
	return SaveSlotList.describe(info)


func load_path(path: String) -> void:
	hide()
	var result := session.load_game(path)
	if not result.ok():
		show()
		show_page("load")
		_say("Loading failed: %s" % "; ".join(result.errors))


func ask_quit() -> void:
	_dialog().ask("Quit to the title screen?", "Progress since your last save is lost. Important milestones are saved automatically.", "Quit to Title", quit_to_title, true)


func quit_to_title() -> void:
	hide()
	session.go_to_title()


func _dialog() -> UiConfirmDialog:
	if _confirm == null:
		var hud := get_parent()
		while hud != null and not hud is GameHud:
			hud = hud.get_parent()
		_confirm = (hud as GameHud).confirm_dialog if hud != null else null
		if _confirm == null:
			_confirm = UiConfirmDialog.new()
			get_parent().add_child(_confirm)
	return _confirm


func _on_saved(_id: int, ok: bool, kind: SaveCoordinator.Kind, message: String) -> void:
	if not visible or kind != SaveCoordinator.Kind.MANUAL:
		return
	show_page(page)
	_say("Game saved." if ok else message)


func _say(text: String) -> void:
	_status.text = text
	_status.visible = text != ""
