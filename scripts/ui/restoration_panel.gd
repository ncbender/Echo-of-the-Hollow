class_name RestorationPanel
extends UiWindow
## Window of a Haven ruin: the stage track (Ruined > Restored > Revitalized),
## what the building is now and what the next step makes of it, the costs of
## that step (have / need, from the same material plan that is consumed) and
## the Restore / Revitalize button - or "Restoration unavailable for now."
## All rules live in RestorationService; the button calls RuinSite.advance()
## with the stage it showed, so a stale or repeated click can never skip a
## stage. After a successful step the window closes (no second click lands on
## the next step's button).

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
	for box: Node in [_list, footer]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	footer.visible = false
	var ruin := site.ruin()
	set_title(ruin.display_name)
	var stage := RestorationService.stage(character, ruin.id)
	var next := RestorationService.next_stage(character, ruin)
	_list.add_child(JournalPanel.StageTrack.make(stage))
	_list.add_child(UiTheme.wrapped(_stage_text(ruin, stage), UiTheme.TEXT_SECONDARY, WIDTH))
	if ruin.profession_id != &"":   # the workshop's bench works in every stage
		var profession: ProfessionDefinition = character.database.professions.get(ruin.profession_id)
		var bench := UiTheme.button("Use the Workbench (%s)" % (profession.display_name if profession else "Profession"), &"", _open_workbench)
		bench.name = "Workbench"
		bench.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_list.add_child(bench)
	if next == &"":
		_list.add_child(UiTheme.label("Fully revitalized." if stage == RestorationService.REVITALIZED else "Restored.", UiTheme.SUCCESS))
		if not ruin.can_revitalize():
			_list.add_child(_note("Revitalized: not available in this version."))
		return
	var error := RestorationService.advance_error(character, ruin, next)
	var verb := "Revitalize" if next == RestorationService.REVITALIZED else "Restore"
	# before -> after
	var compare := HBoxContainer.new()
	compare.name = "Preview"
	compare.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	compare.add_child(_state_card("Now", _now_text(stage), UiTheme.TEXT_SECONDARY))
	var possible := ruin.restorable
	compare.add_child(_state_card("After %s" % ("revitalizing" if verb == "Revitalize" else "restoring") if possible else "Later",
		_after_text(ruin, next) if possible else "This ruin cannot be restored in this version.", UiTheme.SUCCESS if possible else UiTheme.TEXT_MUTED))
	_list.add_child(compare)
	if error == RestorationService.UNAVAILABLE:
		_list.add_child(UiTheme.label(RestorationService.UNAVAILABLE, UiTheme.WARNING))
		if not ruin.can_revitalize():
			_list.add_child(_note("Revitalized: not available in this version."))
		return
	_list.add_child(UiTheme.section("Needed to %s" % verb.to_lower()))
	var plan: Dictionary = RestorationService.material_plan(character, ruin, next)
	var costs := RestorationService.costs_for(ruin, next)
	for index in costs.size():
		_list.add_child(_cost_row(costs[index], plan.plan[index]))
	# the step's button and its reason sit in the fixed footer (never scrolled away)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", UiTheme.GAP)
	var reason := UiTheme.wrapped(error, UiTheme.DANGER, WIDTH - 200)
	reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(reason)
	var button := UiTheme.button(verb, &"PrimaryButton", advance.bind(next))
	button.name = verb
	button.disabled = error != ""
	button.tooltip_text = error
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(button)
	footer.add_child(HSeparator.new())
	footer.add_child(bar)
	footer.visible = true
	_list.add_child(_note("%s is permanent and saved at once. The materials above are consumed." % ("Revitalizing" if verb == "Revitalize" else "Restoring")))
	if not ruin.can_revitalize():
		_list.add_child(_note("Revitalized: not available in this version."))


## One cost with what the plan takes ("have 4 / 6", bag and stash shown when the stash helps).
func _cost_row(cost: ItemCost, entry: Dictionary) -> Control:
	var item := character.database.get_item(cost.item_id)
	var in_bag := character.inventory.count(cost.item_id)
	var in_stash := character.stash.count(cost.item_id) if RestorationService.uses_stash(character) else 0
	var have := in_bag + in_stash
	var enough := int(entry.bag) + int(entry.stash) >= cost.quantity
	var text := "have %d" % have
	if in_stash > 0:
		text += " (bag %d, stash %d)" % [in_bag, in_stash]
	if not enough:
		text += "  (missing %d)" % (cost.quantity - have)
	var row := UiTheme.stat_row("%d x %s" % [cost.quantity, item.display_name if item else String(cost.item_id)], text, UiTheme.SUCCESS if enough else UiTheme.DANGER)
	row.name = "Cost_%s" % cost.item_id
	return row


func _stage_text(ruin: RuinDefinition, stage: StringName) -> String:
	if stage == RestorationService.REVITALIZED and ruin.revitalized_text != "":
		return ruin.revitalized_text
	if stage == RestorationService.RESTORED and ruin.restored_text != "":
		return ruin.restored_text
	return ruin.description


func _now_text(stage: StringName) -> String:
	if stage == RestorationService.RUINED:
		return "Ruined - nothing here works yet." if site.ruin().profession_id == &"" else "Ruined - only the workbench still serves."
	return "Restored."


func _after_text(ruin: RuinDefinition, next: StringName) -> String:
	if next == RestorationService.REVITALIZED:
		return ruin.revitalized_text if ruin.revitalized_text != "" else "Revitalized."
	var building: BuildingDefinition = character.database.buildings.get(ruin.building_id) if ruin.building_id != &"" else null
	if building != null:
		return "%s - %s" % [building.display_name, building.description]
	return ruin.restored_text if ruin.restored_text != "" else "Rebuilt, with no function yet."


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


func _open_workbench() -> void:
	hud.open_professions(site.ruin_id, site)


## Restore button of a ruined building (UI and tests).
func restore() -> String:
	return advance(RestorationService.RESTORED)


## Restore / Revitalize button: advances to `target` (the stage the button
## showed). On success the window closes; a refused step shows its reason.
func advance(target: StringName) -> String:
	var error := site.advance(hud, target)
	if error != "":
		_status.text = error
		rebuild()
	elif visible and not hud.dialogue_panel.visible:
		hide()
	return error
