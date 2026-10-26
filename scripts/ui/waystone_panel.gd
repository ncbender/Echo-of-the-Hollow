class_name WaystonePanel
extends UiWindow
## Fast travel at an awake waystone: every waystone of the Hollowwood, awake
## ones with a Travel button (free), the others undiscovered. Never while
## enemies are near (WaystoneService.travel_error).

var character: Character
var waystone: Waystone

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_title("Waystones")
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN)
	body.add_child(_status)


func open(target_character: Character, target_waystone: Waystone) -> void:
	character = target_character
	waystone = target_waystone
	_status.text = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and waystone != null and (not is_instance_valid(waystone) or not waystone.player_inside):
		hide()


func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for target in WaystoneService.all(character.database):
		var row := HBoxContainer.new()
		row.name = "Waystone_%s" % target.id
		var awake := target.available and WaystoneService.is_active(character, target.id)
		var here := waystone != null and target.id == waystone.waystone_id
		var label := UiTheme.label(target.display_name if awake else "%s  -  undiscovered" % target.display_name,
			UiTheme.COLOR_TEXT if awake else UiTheme.COLOR_DIM)
		label.custom_minimum_size = Vector2(360, 0)
		row.add_child(label)
		if here:
			row.add_child(UiTheme.label("You are here", UiTheme.COLOR_ACCENT))
		elif awake:
			var button := Button.new()
			button.name = "Travel"
			button.text = "Travel"
			button.pressed.connect(travel.bind(target.id))
			row.add_child(button)
		_list.add_child(row)


## Travel button (UI and tests). Returns "" when the journey started.
func travel(target_id: StringName) -> String:
	var from_id := waystone.waystone_id if waystone != null else &""
	var error := WaystoneService.travel_error(character, from_id, target_id, waystone != null and waystone.enemies_near())
	if error != "":
		_status.text = error
		return error
	var target: WaystoneDefinition = character.database.waystones[target_id]
	var session := SessionState.find(get_tree())
	hide()
	if session != null:
		session.travel(target.map_id, target.spawn_id)
	return ""
