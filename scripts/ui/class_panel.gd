class_name ClassPanel
extends UiWindow
## Class selection window opened at a ClassStation. Activation goes through
## Character.switch_class(), which refuses when the player left the station.

var character: Character
var station: ClassStation

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_title("Class Station  -  choose your active class")
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.COLOR_DIM)
	body.add_child(_status)


func open(target_character: Character, target_station: ClassStation) -> void:
	character = target_character
	station = target_station
	_status.text = "Weapon mastery and inventory are shared by all classes."
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and station != null and not station.player_inside:
		hide()


func rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	var definitions: Array = character.database.classes.values()
	definitions.sort_custom(func(a: ClassDefinition, b: ClassDefinition) -> bool: return a.display_name < b.display_name)
	for definition: ClassDefinition in definitions:
		_list.add_child(_row(definition))


func _row(definition: ClassDefinition) -> Control:
	var classes := character.classes
	var row := HBoxContainer.new()
	var unlocked := classes.is_unlocked(definition.id)
	var active := classes.active_class_id == definition.id
	var info := "%s   Lv %d  (%d/%d XP)" % [definition.display_name, classes.get_level(definition.id),
		classes.get_xp(definition.id), classes.xp_to_next(definition.id)] if unlocked \
		else "%s   [locked: %s]" % [definition.display_name, definition.unlock_condition]
	var label := UiTheme.label(info, UiTheme.COLOR_ACCENT if active else UiTheme.COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	if not unlocked:
		button.text = "Unlock (debug)"
		button.pressed.connect(func() -> void:
			classes.unlock(definition.id)
			rebuild())
	elif active:
		button.text = "Active"
		button.disabled = true
	else:
		button.text = "Activate"
		button.pressed.connect(func() -> void:
			var error := character.switch_class(definition.id, station != null and station.player_inside)
			_status.text = error if error != "" else "Now playing as %s." % definition.display_name
			rebuild())
	row.add_child(button)
	return row
