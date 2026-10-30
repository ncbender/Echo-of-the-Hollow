class_name BuildPanel
extends UiWindow
## Building window of a BuildPlot / restored ruin (Old Smithy: its recipes).
## Header with the building's description and effect, then one card per recipe:
## output icon and name, what it makes, every cost with "have / need", and the
## Craft button (or the reason it is disabled). Calls BaseBuilder only.
## UI Usability & Haven Crafting 1.0: recipes of a Haven ruin (the Old Smithy's forge) read bag + Haven
## stash through the one material plan ("have / need  (bag x, stash y)"); building costs stay bag-only.

const CARD_WIDTH := 620

var character: Character
var plot: BuildPlot

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.WARNING, CARD_WIDTH)
	_status.name = "Status"
	body.add_child(_status)


func open(target_character: Character, target_plot: BuildPlot) -> void:
	character = target_character
	plot = target_plot
	_status.text = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and plot != null and (not is_instance_valid(plot) or not plot.player_inside):
		hide()


func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)   # rebuilt rows reuse their names
		child.queue_free()
	var plot_def := plot.definition()
	var building := plot.built_building()
	if building == null:
		set_title("%s  -  choose a building" % (plot_def.display_name if plot_def else "Plot"))
		_list.add_child(UiTheme.section("BUILDINGS"))
		var ids: Array = character.database.buildings.keys()
		ids.sort()
		for building_id: StringName in ids:
			var candidate: BuildingDefinition = character.database.buildings[building_id]
			if plot_def != null and plot_def.allows(candidate):
				_list.add_child(_build_card(plot_def, candidate))
	else:
		set_title(building.display_name)
		_list.add_child(UiTheme.wrapped(building.description, UiTheme.TEXT_SECONDARY, CARD_WIDTH))
		if building.inventory_capacity_bonus > 0:
			_list.add_child(UiTheme.stat_row("Storage", "+%d bag slots (now %d)" % [building.inventory_capacity_bonus, character.inventory.capacity]))
		if not building.recipes.is_empty():
			_list.add_child(UiTheme.section("RECIPES"))
		for recipe in building.recipes:
			_list.add_child(_recipe_card(recipe))


func _recipe_card(recipe: RecipeDefinition) -> Control:
	var with_stash := uses_stash()
	var error := BaseBuilder.craft_error(character, recipe, with_stash)
	var output := character.database.get_item(recipe.output_item_id)
	var card := UiTheme.card(&"CardPanel")
	card.name = "Recipe_%s" % recipe.id
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP + 4)
	var icon := ItemIcon.new().setup(output, recipe.output_quantity)
	icon.custom_minimum_size = Vector2(48, 48)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiTheme.styled(recipe.display_name, &"SubheadingLabel")
	names.add_child(title)
	if output != null:
		var makes := UiTheme.styled("Makes %s%s  ·  %s" % [output.display_name, " x%d" % recipe.output_quantity if recipe.output_quantity > 1 else "",
			UiTheme.rarity_name(output.rarity)], &"CaptionLabel")
		makes.add_theme_color_override(&"font_color", UiTheme.rarity_color(output.rarity))
		names.add_child(makes)
	head.add_child(names)
	var button := UiTheme.button("Craft", &"PrimaryButton", func() -> void:
		var result := BaseBuilder.craft(character, recipe, uses_stash())
		_say(result, "Crafted %s." % recipe.display_name))
	button.name = "Craft_%s" % recipe.id
	button.disabled = error != ""
	button.tooltip_text = error
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(button)
	box.add_child(head)
	if output != null and output.description != "":
		box.add_child(_small(output.description, UiTheme.TEXT_SECONDARY))
	_add_costs(box, recipe.inputs, with_stash)
	if error != "":
		box.add_child(_small(error, UiTheme.WARNING))
	return card


## True when this building stands in a Haven ruin: its recipes may use the Haven stash.
func uses_stash() -> bool:
	var ruin_site := plot as RuinSite
	return ruin_site != null and is_instance_valid(ruin_site) and ProfessionService.uses_stash(character, ruin_site.ruin_id)


func _build_card(plot_def: BuildingPlotDefinition, building: BuildingDefinition) -> Control:
	var error := BaseBuilder.build_error(character, plot_def, building)
	var card := UiTheme.card(&"CardPanel")
	card.name = "Building_%s" % building.id
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var title := UiTheme.styled(building.display_name, &"SubheadingLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var button := UiTheme.button("Build", &"PrimaryButton", func() -> void:
		var result := BaseBuilder.build(character, plot_def, building)
		plot.refresh()
		_say(result, "%s built." % building.display_name))
	button.name = "Build_%s" % building.id
	button.disabled = error != ""
	button.tooltip_text = error
	head.add_child(button)
	box.add_child(head)
	if building.description != "":
		box.add_child(_small(building.description, UiTheme.TEXT_SECONDARY))
	_add_costs(box, building.costs)
	if error != "":
		box.add_child(_small(error, UiTheme.WARNING))
	return card


## One row per cost: item name, "have / need" in green (enough) or red; with the stash in reach
## the total counts both and the split is shown when the stash holds some.
func _add_costs(box: VBoxContainer, costs: Array[ItemCost], with_stash := false) -> void:
	if costs.is_empty():
		return
	box.add_child(UiTheme.section("COST"))
	for cost in costs:
		var definition := character.database.get_item(cost.item_id)
		var in_bag := character.inventory.count(cost.item_id)
		var have := in_bag + (character.stash.count(cost.item_id) if with_stash else 0)
		var text := "%d / %d" % [have, cost.quantity]
		if have != in_bag:
			text += "  (bag %d, stash %d)" % [in_bag, have - in_bag]
		box.add_child(UiTheme.stat_row(definition.display_name if definition != null else String(cost.item_id),
			text, UiTheme.SUCCESS if have >= cost.quantity else UiTheme.DANGER))


func _say(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.add_theme_color_override(&"font_color", UiTheme.DANGER if error != "" else UiTheme.SUCCESS)
	rebuild()


func _small(text: String, color: Color) -> Label:
	var label := UiTheme.wrapped(text, color, CARD_WIDTH - 32)
	label.theme_type_variation = &"SmallLabel"
	return label
