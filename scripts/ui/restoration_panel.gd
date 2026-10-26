class_name RestorationPanel
extends UiWindow
## Window of a ruined building in Haven: the stage track (Ruined > Restored >
## Revitalized), what the ruin is now and what it provides once restored, the
## costs (have / need) and the Restore button - or "Restoration unavailable for
## now." Revitalizing is never shown as usable (not in this version). All rules
## live in RestorationService; the button calls RuinSite.restore().

const WIDTH := 560

var character: Character
var site: RuinSite
var hud: GameHud

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.WARNING, WIDTH)
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
	var stage := RestorationService.stage(character, ruin.id)
	_list.add_child(JournalPanel.StageTrack.make(stage))
	_list.add_child(UiTheme.wrapped(ruin.description, UiTheme.TEXT_SECONDARY, WIDTH))
	var error := RestorationService.restore_error(character, ruin)
	# before -> after
	var compare := HBoxContainer.new()
	compare.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	compare.add_child(_state_card("Now", "Ruined - nothing here works yet." if stage == RestorationService.RUINED else "Restored.", UiTheme.TEXT_SECONDARY))
	var building: BuildingDefinition = character.database.buildings.get(ruin.building_id) if ruin.building_id != &"" else null
	var after := "Rebuilt, with no function yet." if building == null else "%s - %s" % [building.display_name, building.description]
	compare.add_child(_state_card("After restoring" if ruin.restorable else "Later", after if ruin.restorable else "This ruin cannot be restored in this version.", UiTheme.SUCCESS if ruin.restorable else UiTheme.TEXT_MUTED))
	_list.add_child(compare)
	if error == RestorationService.UNAVAILABLE:
		_list.add_child(UiTheme.label(RestorationService.UNAVAILABLE, UiTheme.WARNING))
		_list.add_child(_note("Revitalized: not available in this version."))
		return
	_list.add_child(UiTheme.section("Needed to restore"))
	for cost in ruin.costs:
		var item := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		var enough := have >= cost.quantity
		_list.add_child(UiTheme.stat_row("%d x %s" % [cost.quantity, item.display_name if item else String(cost.item_id)],
			"have %d%s" % [have, "" if enough else "  (missing)"], UiTheme.SUCCESS if enough else UiTheme.DANGER))
	var button := UiTheme.button("Restore", &"PrimaryButton", restore)
	button.name = "Restore"
	button.disabled = error != ""
	button.tooltip_text = error
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_list.add_child(button)
	if error != "":
		_list.add_child(UiTheme.wrapped(error, UiTheme.DANGER, WIDTH))
	_list.add_child(_note("Restoring is permanent and saved at once. Revitalized: not available in this version."))


func _state_card(title: String, text: String, color: Color) -> Control:
	var card := UiTheme.card(&"InsetPanel")
	card.custom_minimum_size = Vector2((WIDTH - UiTheme.GAP * 2) * 0.5, 0)
	var box := card.get_node("Box") as VBoxContainer
	box.add_child(UiTheme.styled(title.to_upper(), &"CaptionLabel"))
	box.add_child(UiTheme.wrapped(text, color, (WIDTH - UiTheme.GAP * 2) * 0.5 - 30))
	return card


func _note(text: String) -> Label:
	var label := UiTheme.wrapped(text, UiTheme.TEXT_MUTED, WIDTH)
	label.theme_type_variation = &"SmallLabel"
	return label


## Restore button (UI and tests).
func restore() -> String:
	var error := site.restore(hud)
	if error != "":
		_status.text = error
		rebuild()
	elif visible and not hud.dialogue_panel.visible:
		hide()
	return error
