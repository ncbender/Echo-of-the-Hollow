class_name WaystonePanel
extends UiWindow
## Fast travel at an awake waystone: all four waystones of the Hollowwood.
## Awake ones have a free Travel button, the others say "Undiscovered"; the
## current one says "You are here". Never while enemies are near
## (WaystoneService.travel_error) - the window says so before you click.

const WIDTH := 520

var character: Character
var waystone: Waystone

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_title("Waystones")
	set_close_text("Close [G / Esc]")
	body.add_child(UiTheme.styled("Travel between awake waystones is free.", &"SmallLabel"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.WARNING, WIDTH)
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
	var danger := waystone != null and waystone.enemies_near()
	if danger:
		_status.text = "You cannot travel while enemies are near."
	for target in WaystoneService.all(character.database):
		var awake := target.available and WaystoneService.is_active(character, target.id)
		var here := waystone != null and target.id == waystone.waystone_id
		var card := UiTheme.card(&"SelectedCardPanel" if here else (&"CardPanel" if awake else &"InsetPanel"))
		var row := HBoxContainer.new()
		row.name = "Waystone_%s" % target.id
		var names := VBoxContainer.new()
		names.add_theme_constant_override(&"separation", 0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := UiTheme.styled(target.display_name, &"SubheadingLabel")
		if not awake:
			title.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
		names.add_child(title)
		var map_def: MapDefinition = character.database.maps.get(target.map_id)
		names.add_child(UiTheme.styled(map_def.display_name if awake and map_def != null else "Somewhere in the Hollowwood", &"CaptionLabel"))
		row.add_child(names)
		if here:
			row.add_child(UiTheme.label("You are here", UiTheme.RESONANCE))
		elif awake:
			var button := UiTheme.button("Travel", &"PrimaryButton", travel.bind(target.id))
			button.name = "Travel"
			button.disabled = danger
			button.tooltip_text = "You cannot travel while enemies are near." if danger else ""
			row.add_child(button)
		else:
			row.add_child(UiTheme.label("Undiscovered", UiTheme.TEXT_MUTED))
		(card.get_node("Box") as VBoxContainer).add_child(row)
		card.custom_minimum_size = Vector2(WIDTH, 0)
		_list.add_child(card)


## Travel button (UI and tests). Returns "" when the journey started.
func travel(target_id: StringName) -> String:
	var error := start_travel(get_tree(), character, waystone, target_id)
	if error != "":
		_status.text = error
		return error
	hide()
	return ""


## Map UX 2.0: the one way a journey starts (this window and the map's place details): from the waystone the
## player stands at, under WaystoneService.travel_error (awake, not here, no enemies near, no trial). "" = started.
static func start_travel(tree: SceneTree, target_character: Character, from: Waystone, target_id: StringName) -> String:
	var from_id := from.waystone_id if from != null else &""
	var error := WaystoneService.travel_error(target_character, from_id, target_id, from != null and from.enemies_near())
	if error != "":
		return error
	var target: WaystoneDefinition = target_character.database.waystones[target_id]
	var session := SessionState.find(tree)
	if session != null:
		session.travel(target.map_id, target.spawn_id)
	return ""
