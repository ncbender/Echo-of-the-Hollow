class_name RestorationPanel
extends UiWindow
## Window of a ruined building in Haven: what it was, what it needs, and the
## Restore button - or "Restoration unavailable for now." All rules live in
## RestorationService; the button calls RuinSite.restore().

var character: Character
var site: RuinSite
var hud: GameHud

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN)
	body.add_child(_status)


func open(target_character: Character, target_site: RuinSite) -> void:
	character = target_character
	site = target_site
	_status.text = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and site != null and (not is_instance_valid(site) or not site.player_inside):
		hide()


func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ruin := site.ruin()
	set_title(ruin.display_name)
	_list.add_child(UiTheme.wrapped(ruin.description, UiTheme.COLOR_DIM))
	var error := RestorationService.restore_error(character, ruin)
	if error == RestorationService.UNAVAILABLE:
		_list.add_child(UiTheme.label(RestorationService.UNAVAILABLE, UiTheme.COLOR_WARN))
		return
	_list.add_child(UiTheme.label("Needed to restore:"))
	for cost in ruin.costs:
		var item := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		_list.add_child(UiTheme.label("  %s  %d / %d" % [item.display_name if item else String(cost.item_id), have, cost.quantity],
			UiTheme.COLOR_TEXT if have >= cost.quantity else UiTheme.COLOR_ERROR))
	var button := Button.new()
	button.name = "Restore"
	button.text = "Restore"
	button.disabled = error != ""
	button.tooltip_text = error
	button.pressed.connect(restore)
	_list.add_child(button)
	if error != "":
		_list.add_child(UiTheme.wrapped(error, UiTheme.COLOR_ERROR))


## Restore button (UI and tests).
func restore() -> String:
	var error := site.restore(hud)
	if error != "":
		_status.text = error
		rebuild()
	elif visible and not hud.dialogue_panel.visible:
		hide()
	return error
