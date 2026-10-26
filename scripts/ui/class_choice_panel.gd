class_name ClassChoicePanel
extends UiWindow
## The one-time prologue choice of the starting class (exactly three cards).
## A choice needs two clicks (choose -> confirm) because it is permanent.

var character: Character
var station: ClassChoiceStation

var _cards: HFlowContainer
var _status: Label
var _pending: StringName


func _ready() -> void:
	set_title(tr("UI_CHOOSE_CLASS_TITLE"))
	_status = UiTheme.wrapped("", UiTheme.COLOR_DIM, 900)
	body.add_child(_status)
	_cards = HFlowContainer.new()
	body.add_child(_cards)


func open(target_character: Character, target_station: ClassChoiceStation) -> void:
	character = target_character
	station = target_station
	_pending = &""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and station != null and not station.player_inside:
		hide()


## Two-step choice: the first call selects, the second confirms (UI and tests).
func choose(class_id: StringName) -> String:
	var error := PrologueService.can_choose(character, class_id)
	if error != "":
		_status.text = error
		return error
	if _pending != class_id:
		_pending = class_id
		_status.text = "Choose %s permanently? The other two classes stay locked until their class quests are done. Click again to confirm." \
			% character.database.get_class_def(class_id).display_name
		rebuild_cards()
		return "confirm"
	error = PrologueService.choose_starting_class(character, class_id)
	_status.text = error if error != "" else "You are now a %s." % character.database.get_class_def(class_id).display_name
	_pending = &""
	rebuild_cards()
	return error


func rebuild() -> void:
	var prologue := character.prologue
	if prologue.is_completed():
		_status.text = "Your starting class: %s. Other classes are unlocked by class quests at a class station." \
			% _class_name(prologue.chosen_class)
	else:
		_status.text = "Try all three classes at the trial pedestals, then choose ONE permanent starting class."
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
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiTheme.heading(definition.display_name))
	box.add_child(UiTheme.wrapped(definition.description, UiTheme.COLOR_TEXT, 290))
	var resource := definition.resource.display_name if definition.resource != null else "-"
	box.add_child(UiTheme.wrapped("Resource: %s" % resource, UiTheme.COLOR_DIM, 290))
	var done := trial != null and character.prologue.has_completed_trial(trial.id)
	box.add_child(UiTheme.label("Trial completed" if done else "Trial not completed yet",
			UiTheme.COLOR_ACCENT if done else UiTheme.COLOR_WARN))
	var button := Button.new()
	button.name = "Choose_%s" % class_id
	var chosen := character.prologue.chosen_class == class_id
	if character.prologue.is_completed():
		button.text = "Chosen" if chosen else "Locked (class quest)"
		button.disabled = true
	else:
		button.text = "Confirm %s" % definition.display_name if _pending == class_id else "Choose %s" % definition.display_name
		button.disabled = PrologueService.can_choose(character, class_id) != ""
		button.tooltip_text = PrologueService.can_choose(character, class_id)
	button.pressed.connect(choose.bind(class_id))
	box.add_child(button)
	return panel


func _class_name(class_id: StringName) -> String:
	var definition := character.database.get_class_def(class_id)
	return definition.display_name if definition != null else String(class_id)
