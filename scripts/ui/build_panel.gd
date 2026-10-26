class_name BuildPanel
extends UiWindow
## Build / building menu of a BuildPlot. Calls BaseBuilder only.

var character: Character
var plot: BuildPlot

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	body.add_child(_list)
	_status = UiTheme.wrapped("", UiTheme.COLOR_WARN)
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
		child.queue_free()
	var plot_def := plot.definition()
	var building := plot.built_building()
	if building == null:
		set_title("%s  -  choose a building" % (plot_def.display_name if plot_def else "Plot"))
		var ids: Array = character.database.buildings.keys()
		ids.sort()
		for building_id: StringName in ids:
			var candidate: BuildingDefinition = character.database.buildings[building_id]
			if plot_def != null and plot_def.allows(candidate):
				_add_build_row(plot_def, candidate)
	else:
		set_title(building.display_name)
		_list.add_child(_wrapped(building.description, UiTheme.COLOR_DIM))
		if building.inventory_capacity_bonus > 0:
			_list.add_child(UiTheme.label("Active: +%d inventory slots (now %d)" % [
				building.inventory_capacity_bonus, character.inventory.capacity]))
		for recipe in building.recipes:
			_add_recipe_row(recipe)


func _add_build_row(plot_def: BuildingPlotDefinition, building: BuildingDefinition) -> void:
	var row := HBoxContainer.new()
	var error := BaseBuilder.build_error(character, plot_def, building)
	var label := _wrapped("%s  -  %s" % [building.display_name, _costs_text(building.costs)],
		UiTheme.COLOR_TEXT if error == "" else UiTheme.COLOR_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = "Build"
	button.disabled = error != ""
	button.tooltip_text = error
	button.pressed.connect(func() -> void:
		var result := BaseBuilder.build(character, plot_def, building)
		_status.text = result if result != "" else "%s built." % building.display_name
		plot.refresh()
		rebuild())
	row.add_child(button)
	_list.add_child(row)
	if error != "":
		_list.add_child(_wrapped("   " + error, UiTheme.COLOR_ERROR))


func _add_recipe_row(recipe: RecipeDefinition) -> void:
	var row := HBoxContainer.new()
	var error := BaseBuilder.craft_error(character, recipe)
	var label := _wrapped("%s  -  %s" % [recipe.display_name, _costs_text(recipe.inputs)],
		UiTheme.COLOR_TEXT if error == "" else UiTheme.COLOR_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = "Craft"
	button.disabled = error != ""
	button.tooltip_text = error
	button.pressed.connect(func() -> void:
		var result := BaseBuilder.craft(character, recipe)
		_status.text = result if result != "" else "Crafted %s." % recipe.display_name
		rebuild())
	row.add_child(button)
	_list.add_child(row)


func _costs_text(costs: Array[ItemCost]) -> String:
	var parts: PackedStringArray = []
	for cost in costs:
		var definition := character.database.get_item(cost.item_id)
		parts.append("%s %d/%d" % [definition.display_name if definition else String(cost.item_id),
			character.inventory.count(cost.item_id), cost.quantity])
	return ", ".join(parts)


func _wrapped(text: String, color: Color) -> Label:
	var label := UiTheme.label(text, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(UiTheme.TEXT_WIDTH - 120, 0)
	return label
