class_name ClassChoicePanel
extends UiWindow
## The one-time choice of the first class at the Whispering Stone (exactly
## three paths: Warrior, Arcanist, Shadowrunner). All three stay visible; a path
## can be chosen only once its OWN echo was walked (PrologueService.can_choose,
## Class Trials 2.0 M1), the others show a locked state. Each card also offers
## its trial path (visit: travel to the trial grounds, M2) - never the choice
## itself. The choice needs two
## clicks (choose -> confirm) because it is permanent. After the choice a
## milestone save is written, and success is shown only once that save really
## succeeded - a failed save is reported.

const INTRO := "Three paths linger within the stone. Only a path you have walked can take root within you, and only one of them. The others may yet be learned."

var character: Character
var station: ClassChoiceStation
## Result of the last confirmed choice: "" / "saving" / "saved" / "save_failed".
var save_state: String = ""

var _intro: Label
var _cards: HFlowContainer
var _status: Label
var _pending: StringName
var _save_id: int = -1
var _session: SessionState


func _ready() -> void:
	set_title(tr("UI_CHOOSE_CLASS_TITLE"))
	_intro = UiTheme.wrapped(INTRO, UiTheme.PARCHMENT, 900)
	_intro.add_theme_font_size_override(&"font_size", UiTheme.FONT_SUBHEADING)
	body.add_child(_intro)
	_status = UiTheme.wrapped("", UiTheme.COLOR_DIM, 900)
	body.add_child(_status)
	_cards = HFlowContainer.new()
	body.add_child(_cards)


func open(target_character: Character, target_station: ClassChoiceStation) -> void:
	character = target_character
	station = target_station
	_pending = &""
	_session = SessionState.find(get_tree()) if is_inside_tree() else null
	if _session != null and not _session.saves.save_finished.is_connected(_on_save_finished):
		_session.saves.save_finished.connect(_on_save_finished)
	show()
	rebuild()


func _exit_tree() -> void:
	if _session != null and _session.saves.save_finished.is_connected(_on_save_finished):
		_session.saves.save_finished.disconnect(_on_save_finished)


func _process(_delta: float) -> void:
	if visible and station != null and not station.player_inside and save_state != "saving":
		hide()


func status_text() -> String:
	return _status.text


## Two-step choice: the first call selects, the second confirms (UI and tests).
func choose(class_id: StringName) -> String:
	var error := PrologueService.can_choose(character, class_id)
	if error != "":
		_status.text = error
		return error
	if _pending != class_id:
		_pending = class_id
		_status.text = "Let the path of the %s take root? This cannot be undone; the other two paths stay locked until you learn them later. Click again to confirm." \
			% _class_name(class_id)
		rebuild_cards()
		return "confirm"
	error = PrologueService.choose_starting_class(character, class_id)   # validates, unlocks one, activates it
	_pending = &""
	if error != "":
		_status.text = error
		rebuild_cards()
		return error
	if _session != null:
		save_state = "saving"
		_status.text = "The stone takes hold of your choice..."
		_save_id = _session.request_critical_save("class choice %s" % class_id)
	else:
		save_state = "saved"
		_status.text = _success_text()
	rebuild_cards()
	return ""


func _on_save_finished(id: int, ok: bool, _kind: SaveCoordinator.Kind, message: String) -> void:
	if id != _save_id:
		return
	_save_id = -1
	if ok:
		save_state = "saved"
		_status.text = _success_text()
	else:
		save_state = "save_failed"
		_status.text = "Your path is chosen, but the game could not be saved (%s). It will keep trying; you can also save from the menu (Esc)." % message


func _success_text() -> String:
	return "The path of the %s has taken root within you. Your progress has been saved." % _class_name(character.prologue.chosen_class)


func rebuild() -> void:
	var prologue := character.prologue
	_intro.visible = not prologue.is_completed()
	if save_state == "saving" or save_state == "save_failed":
		pass   # keep the save message visible
	elif prologue.is_completed():
		_status.text = "The path of the %s has taken root within you. The other paths may yet be learned." % _class_name(prologue.chosen_class)
	elif choosable_classes().is_empty():
		_status.text = "Walk an echo first. Each path waits at its own stone."
	else:
		_status.text = ""
	rebuild_cards()


func rebuild_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for class_id in PrologueService.prologue_classes(character.database):
		_cards.add_child(_card(class_id))


func _card(class_id: StringName) -> Control:
	var definition := character.database.get_class_def(class_id)
	var trial := PrologueService.trial_for_class(character.database, class_id)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SelectedCardPanel" if _pending == class_id or character.prologue.chosen_class == class_id else &"CardPanel"
	panel.custom_minimum_size = Vector2(320, 0)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiTheme.heading(definition.display_name))
	var text := trial.choice_text if trial != null and trial.choice_text != "" else definition.description
	box.add_child(UiTheme.wrapped(text, UiTheme.COLOR_TEXT, 290))
	var resource := definition.resource.display_name if definition.resource != null else "-"
	box.add_child(UiTheme.wrapped("Resource: %s" % resource, UiTheme.COLOR_DIM, 290))
	var done := trial != null and character.prologue.has_completed_trial(trial.id)
	box.add_child(UiTheme.label("Echo walked" if done else "Echo not walked yet",
			UiTheme.COLOR_ACCENT if done else UiTheme.COLOR_WARN))
	var button := Button.new()
	button.name = "Choose_%s" % class_id
	button.theme_type_variation = &"PrimaryButton" if _pending == class_id else &""
	var chosen := character.prologue.chosen_class == class_id
	if character.prologue.is_completed():
		button.text = "Chosen" if chosen else "Locked (learn later)"
		button.disabled = true
	elif not done:
		button.text = "Locked (walk its echo)"
		button.disabled = true
		button.tooltip_text = PrologueService.can_choose(character, class_id)
	else:
		button.text = "Confirm %s" % definition.display_name if _pending == class_id else "Choose %s" % definition.display_name
		button.disabled = PrologueService.can_choose(character, class_id) != ""
		button.tooltip_text = PrologueService.can_choose(character, class_id)
	button.pressed.connect(choose.bind(class_id))
	if not character.prologue.is_completed() and trial != null:
		var visit_button := Button.new()   # trial path: travel only, never the final choice
		visit_button.name = "Visit_%s" % class_id
		visit_button.text = tr("UI_TRIAL_VISIT")
		var visit_error := PrologueService.can_visit_grounds(character, trial.id)
		visit_button.disabled = visit_error != ""
		visit_button.tooltip_text = visit_error if visit_error != "" else tr("UI_TRIAL_VISIT_HINT")
		visit_button.pressed.connect(visit.bind(class_id))
		box.add_child(visit_button)
	box.add_child(button)
	return panel


## Trial path (Class Trials 2.0 M2): travels to the trial grounds of `class_id`.
## Entering is NOT choosing - no trial starts, nothing is chosen or completed;
## the grounds lead back to the Heart of the Stone. Returns "" or the reason.
func visit(class_id: StringName) -> String:
	var trial := PrologueService.trial_for_class(character.database, class_id)
	var error := PrologueService.can_visit_grounds(character, trial.id) if trial != null else "Unknown trial."
	if error == "" and _session == null:
		error = "The stone cannot carry you now."
	if error != "":
		_status.text = error
		return error
	if not _session.travel(trial.map_id, trial.entry_spawn_id):
		return "The stone is already carrying you."   # one transition at a time
	_pending = &""
	hide()
	return ""


## Classes the service lets the player choose right now (UI and tests).
func choosable_classes() -> Array[StringName]:
	var result: Array[StringName] = []
	for class_id in PrologueService.prologue_classes(character.database):
		if PrologueService.can_choose(character, class_id) == "":
			result.append(class_id)
	return result


func _class_name(class_id: StringName) -> String:
	var definition := character.database.get_class_def(class_id)
	return definition.display_name if definition != null else String(class_id)
