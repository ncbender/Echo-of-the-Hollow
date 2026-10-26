class_name CraftingPanel
extends UiWindow
## Resonance Forge (smithy): choose an item, see its material, affixes, essence
## slots, sockets, quality and evolution, pick an operation, see the exact costs
## and the REAL outcome probabilities (same CraftingPreview the service executes)
## and confirm. Pure presentation over CraftingService; holds no item state except
## the selection. Layout: three flow columns (side by side on wide canvases,
## stacked and scrolling at high UI scales).

signal recipes_requested(plot: BuildPlot)

const ITEMS_WIDTH := 330
const DETAILS_WIDTH := 430
const ACTIONS_WIDTH := 500

var character: Character
var plot: BuildPlot
## Decides rolls; tests and playtests may seed it.
var rng := RandomNumberGenerator.new()
## Last executed result (shown below the confirm button).
var last_result: CraftingService.Result

var _item_id: String = ""
var _operation: StringName = &""
var _material_id: StringName = &""
var _focus_tag: StringName = &""
var _affix_index: int = -1
var _essence_id: StringName = &""
var _slot_index: int = -1
var _socketable_id: StringName = &""
var _mutation_id: StringName = &""

var _columns: HFlowContainer
var _items: VBoxContainer
var _stock: Label
var _details: VBoxContainer
var _ops: HFlowContainer
var _params: VBoxContainer
var _costs: VBoxContainer
var _notes: Label
var _outcomes: GridContainer
var _outcome_title: Label
var _confirm: Button
var _result: Label
var _recipes: Button


func _ready() -> void:
	set_title("Resonance Forge")
	set_close_text("Close [G / Esc]")
	rng.randomize()
	_columns = HFlowContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_columns)

	var left := _column(ITEMS_WIDTH)
	left.add_child(UiTheme.heading("Craftable items"))
	_items = VBoxContainer.new()
	_items.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	left.add_child(_items)
	left.add_child(UiTheme.heading("Materials & currencies"))
	_stock = UiTheme.wrapped("", UiTheme.COLOR_DIM, ITEMS_WIDTH)
	_stock.theme_type_variation = &"SmallLabel"
	left.add_child(_stock)

	var middle := _column(DETAILS_WIDTH)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	middle.add_child(_details)

	var right := _column(ACTIONS_WIDTH)
	right.add_child(UiTheme.heading("Forge action"))
	_ops = HFlowContainer.new()
	right.add_child(_ops)
	_params = VBoxContainer.new()
	right.add_child(_params)
	right.add_child(UiTheme.heading("Cost"))
	_costs = VBoxContainer.new()
	_costs.add_theme_constant_override(&"separation", 2)
	right.add_child(_costs)
	_notes = UiTheme.wrapped("", UiTheme.COLOR_WARN, ACTIONS_WIDTH)
	right.add_child(_notes)
	_outcome_title = UiTheme.heading("Possible results")
	right.add_child(_outcome_title)
	_outcomes = GridContainer.new()
	_outcomes.columns = 3
	_outcomes.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	_outcomes.add_theme_constant_override(&"v_separation", 2)
	right.add_child(_outcomes)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(0, 44)
	_confirm.pressed.connect(confirm)
	right.add_child(_confirm)
	_result = UiTheme.wrapped("", UiTheme.COLOR_ACCENT, ACTIONS_WIDTH)
	right.add_child(_result)
	_recipes = Button.new()
	_recipes.text = "Smithy recipes"
	_recipes.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_recipes.pressed.connect(func() -> void: recipes_requested.emit(plot))
	body.add_child(_recipes)


func _column(width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(width, 0)
	_columns.add_child(column)
	return column


## All columns side by side; the flow container stacks them when narrower.
func preferred_body_size() -> Vector2:
	var width := 0.0
	for column: Control in _columns.get_children():
		width += column.get_combined_minimum_size().x
	width += _columns.get_theme_constant(&"h_separation") * maxi(0, _columns.get_child_count() - 1)
	return Vector2(width, body.get_combined_minimum_size().y)


func open(target_character: Character, target_plot: BuildPlot = null) -> void:
	if character != target_character:
		_disconnect()
		character = target_character
		character.inventory.changed.connect(rebuild)
	plot = target_plot
	last_result = null
	if character.inventory.find(_item_id) == null:
		_item_id = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and plot != null and (not is_instance_valid(plot) or not plot.player_inside):
		hide()


# --- selection API (buttons and scripted tests use the same calls) ------------

func select_item(instance_id: String) -> void:
	if instance_id != _item_id:
		_item_id = instance_id
		_reset_params()
		_operation = &""
	rebuild()


func select_operation(operation: StringName) -> void:
	_operation = operation
	_reset_params()
	rebuild()


func choose_material(material_id: StringName) -> void:
	_material_id = material_id
	rebuild()


func choose_focus(tag: StringName) -> void:
	_focus_tag = tag
	rebuild()


func choose_affix(index: int) -> void:
	_affix_index = index
	rebuild()


func choose_essence(essence_id: StringName) -> void:
	_essence_id = essence_id
	rebuild()


func choose_slot(index: int) -> void:
	_slot_index = index
	rebuild()


func choose_socketable(socketable_id: StringName) -> void:
	_socketable_id = socketable_id
	rebuild()


func choose_mutation(mutation_id: StringName) -> void:
	_mutation_id = mutation_id
	rebuild()


func selected_item() -> ItemInstance:
	return character.inventory.find(_item_id) if character != null else null


func current_request() -> CraftingRequest:
	var request := CraftingRequest.make(_operation, selected_item())
	request.material_id = _material_id
	request.focus_tag = _focus_tag
	request.affix_index = _affix_index
	request.essence_id = _essence_id
	request.slot_index = _slot_index
	request.socketable_id = _socketable_id
	request.mutation_id = _mutation_id
	return request


func current_preview() -> CraftingPreview:
	if selected_item() == null or _operation == &"":
		return null
	return CraftingService.preview(character, current_request())


## Executes the previewed request once. The button is disabled until the next
## rebuild, and the request carries the item revision: repeated input is refused.
func confirm() -> CraftingService.Result:
	var preview := current_preview()
	if preview == null or not preview.ok():
		return null
	_confirm.disabled = true
	last_result = CraftingService.execute(character, current_request(), rng)
	if last_result.ok:
		var keep_operation := _operation
		_reset_params()
		_operation = keep_operation
	rebuild()
	return last_result


func _reset_params() -> void:
	_material_id = &""
	_focus_tag = &""
	_affix_index = -1
	_essence_id = &""
	_slot_index = -1
	_socketable_id = &""
	_mutation_id = &""


# --- view ---------------------------------------------------------------------

func rebuild() -> void:
	if character == null or not is_inside_tree() or not visible:
		return
	_rebuild_items()
	_rebuild_stock()
	var item := selected_item()
	var definition := character.database.get_item(item.definition_id) if item != null else null
	_rebuild_details(item, definition)
	_rebuild_actions(item, definition)


func _rebuild_items() -> void:
	_clear(_items)
	var found := false
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition == null or definition.crafting == null:
			continue
		found = true
		var button := ItemSlotButton.new()
		button.custom_minimum_size = Vector2(ITEMS_WIDTH, UiTheme.SLOT_SIZE.y)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = item.instance_id == _item_id
		button.text = "%s%s%s" % ["[E] " if character.equipment.is_equipped(item.instance_id) else "", definition.display_name,
			"  (%s)" % _material_name(item.material_id) if item.is_imprinted() else ""]
		button.add_theme_color_override(&"font_color", definition.rarity_color())
		button.tooltip_text = "\n".join(_summary_lines(item, definition))
		button.pressed.connect(select_item.bind(item.instance_id))
		_items.add_child(button)
	if not found:
		_items.add_child(UiTheme.wrapped("No craftable items. Debug: F4 gives a crafting kit.", UiTheme.COLOR_DIM, ITEMS_WIDTH))


func _rebuild_stock() -> void:
	var lines: PackedStringArray = []
	var seen := {}
	var groups: Array = [character.database.materials.values(), character.database.currencies.values(),
		character.database.essences.values(), character.database.socketables.values()]
	for group: Array in groups:
		for entry: Resource in group:
			var item_id: StringName = entry.get(&"item_id")
			if seen.has(item_id):
				continue
			seen[item_id] = true
			var definition := character.database.get_item(item_id)
			if definition != null:
				lines.append("%s: %d" % [definition.display_name, character.inventory.count(item_id)])
	_stock.text = "\n".join(lines)


func _rebuild_details(item: ItemInstance, definition: ItemDefinition) -> void:
	_clear(_details)
	if item == null:
		_details.add_child(UiTheme.heading("No item selected"))
		_details.add_child(UiTheme.wrapped("Choose a craftable item on the left.", UiTheme.COLOR_DIM, DETAILS_WIDTH))
		return
	var profile := definition.crafting
	var title := UiTheme.heading(definition.display_name)
	title.add_theme_color_override(&"font_color", definition.rarity_color())
	_details.add_child(title)
	_details.add_child(_line("Item level %d  -  Quality %d / %d" % [item.item_level, item.quality, profile.max_quality]))
	for modifier in definition.base_stats:
		_details.add_child(_line("Base: %s%s" % [modifier.describe(), "  (+%d%% quality)" % item.quality if item.quality > 0 else ""], UiTheme.COLOR_DIM))
	for effect in definition.effects:
		_details.add_child(_line("Core (protected): %s" % effect.description, UiTheme.COLOR_PROMPT))
	var material: MaterialDefinition = character.database.materials.get(item.material_id) if item.is_imprinted() else null
	_details.add_child(UiTheme.heading("Main material"))
	if material != null:
		var label := _line("%s - %s" % [material.display_name, _modifiers_text(material.imprint_modifiers)])
		label.add_theme_color_override(&"font_color", material.color)
		_details.add_child(label)
	else:
		_details.add_child(_line("Not imprinted yet." if profile.allows(CraftingOps.IMPRINT) else "-", UiTheme.COLOR_DIM))
	if profile.affix_slots > 0:
		_details.add_child(UiTheme.heading("Affixes %d / %d" % [item.affixes.size(), profile.affix_slots]))
		for index in item.affixes.size():
			var button := Button.new()
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = _affix_text(item.affixes[index])
			button.button_pressed = index == _affix_index and _operation == CraftingOps.REFORGE
			button.tooltip_text = "Select, then Reforge to replace it."
			button.pressed.connect(_pick_affix.bind(index))
			_details.add_child(button)
	if profile.essence_slots > 0:
		_details.add_child(UiTheme.heading("Essence slots"))
		var essences := ItemStats.active_essences(item, definition)
		for index in mini(2, profile.essence_slots):
			var text := "Slot %d: (empty)" % (index + 1)
			if index < essences.size():
				var essence: EssenceDefinition = character.database.essences.get(essences[index])
				text = "Slot %d: %s" % [index + 1, essence.display_name if essence != null else String(essences[index])]
			_details.add_child(_line(text, UiTheme.COLOR_TEXT if index < essences.size() else UiTheme.COLOR_DIM))
		for resonance: EssenceResonanceDefinition in character.database.resonances.values():
			if resonance.matches(essences):
				_details.add_child(_line("Resonance: %s - %s" % [resonance.display_name, resonance.description], UiTheme.COLOR_ACCENT))
	if profile.socket_slots > 0:
		_details.add_child(UiTheme.heading("Sockets %d / %d open" % [item.sockets.size(), profile.socket_slots]))
		for index in item.sockets.size():
			var socketable: SocketableDefinition = character.database.socketables.get(item.sockets[index])
			_details.add_child(_line("Socket %d: %s" % [index + 1, ("%s - %s" % [socketable.display_name, socketable.description]) if socketable != null else "(empty)"]))
	var evolution := ItemStats.evolution_of(definition, character.database)
	if evolution != null:
		_details.add_child(UiTheme.heading("Evolution: %s" % evolution.display_name))
		var current := evolution.get_stage(item.evolution_stage())
		_details.add_child(_line("Stage %d / %d: %s" % [item.evolution_stage(), evolution.max_stage(), current.display_name if current != null else "-"]))
		var next := ItemEvolution.next_stage(item, definition, character.database)
		if next != null:
			_details.add_child(_line("Item XP %d / %d for stage %d (%s)" % [item.evolution_xp(), next.xp_required, next.stage, next.display_name], UiTheme.COLOR_DIM))
			var bar := UiTheme.bar(UiTheme.BAR_HEIGHT)
			bar.max_value = maxi(1, next.xp_required)
			bar.value = mini(item.evolution_xp(), next.xp_required)
			_details.add_child(bar)
		if item.evolution_path() != &"":
			var mutation := evolution.get_stage(evolution.max_stage()).get_mutation(item.evolution_path())
			_details.add_child(_line("Mutation: %s" % (mutation.display_name if mutation != null else String(item.evolution_path())), UiTheme.COLOR_ACCENT))


func _rebuild_actions(item: ItemInstance, definition: ItemDefinition) -> void:
	_clear(_ops)
	_clear(_params)
	_clear(_costs)
	_clear(_outcomes)
	_notes.text = ""
	_result.text = last_result.message if last_result != null and last_result.ok else (last_result.error if last_result != null else "")
	_result.add_theme_color_override(&"font_color", UiTheme.COLOR_ACCENT if last_result == null or last_result.ok else UiTheme.COLOR_ERROR)
	_outcome_title.visible = false
	if item == null:
		_confirm.text = "Choose an item"
		_confirm.disabled = true
		return
	for operation_id in CraftingOps.ALL:
		var operation := character.database.get_operation(operation_id)
		if operation == null or not definition.crafting.allows(operation_id):
			continue
		var button := Button.new()
		button.text = operation.display_name
		button.toggle_mode = true
		button.button_pressed = operation_id == _operation
		button.tooltip_text = operation.description
		button.pressed.connect(select_operation.bind(operation_id))
		_ops.add_child(button)
	if _operation == &"" or not definition.crafting.allows(_operation):
		_confirm.text = "Choose an action"
		_confirm.disabled = true
		return
	_build_params(item, definition)
	var preview := current_preview()
	for cost in preview.costs:
		var cost_def := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		_costs.add_child(_line("%dx %s  (have %d)" % [cost.quantity, cost_def.display_name if cost_def else String(cost.item_id), have],
			UiTheme.COLOR_TEXT if have >= cost.quantity else UiTheme.COLOR_ERROR))
	if preview.costs.is_empty():
		_costs.add_child(_line("Free", UiTheme.COLOR_DIM))
	var notes := preview.notes.duplicate()
	if preview.error != "":
		notes.insert(0, preview.error)
	_notes.text = "\n".join(notes)
	_notes.add_theme_color_override(&"font_color", UiTheme.COLOR_ERROR if preview.error != "" else UiTheme.COLOR_WARN)
	_build_outcomes(preview)
	var operation := character.database.get_operation(_operation)
	_confirm.text = "Confirm: %s" % operation.display_name
	_confirm.disabled = not preview.ok()
	_confirm.tooltip_text = preview.reason()


func _build_params(item: ItemInstance, definition: ItemDefinition) -> void:
	match _operation:
		CraftingOps.IMPRINT:
			_params.add_child(UiTheme.label("Main material (permanent):"))
			var row := HFlowContainer.new()
			for material: MaterialDefinition in _sorted(character.database.materials.values()):
				if not material.allows_slot(definition.slot_kind):
					continue
				row.add_child(_choice("%s (%d)" % [material.display_name, character.inventory.count(material.item_id)],
					material.id == _material_id, choose_material.bind(material.id), material.description))
			_params.add_child(row)
			_focus_row(item, definition)
		CraftingOps.AUGMENT:
			_focus_row(item, definition)
		CraftingOps.REFORGE:
			_params.add_child(UiTheme.wrapped("Select the affix to replace in the middle column. The new roll replaces it immediately.", UiTheme.COLOR_DIM, ACTIONS_WIDTH))
			_focus_row(item, definition)
		CraftingOps.ESSENCE_INSERT:
			var row := HFlowContainer.new()
			for essence: EssenceDefinition in _sorted(character.database.essences.values()):
				row.add_child(_choice("%s (%d)" % [essence.display_name, character.inventory.count(essence.item_id)],
					essence.id == _essence_id, choose_essence.bind(essence.id), essence.description))
			_params.add_child(row)
			_slot_row(mini(2, definition.crafting.essence_slots), "Slot", true)
		CraftingOps.ESSENCE_EXTRACT:
			_slot_row(item.essences.size(), "Extract slot", false)
		CraftingOps.SOCKET_INSERT:
			var row := HFlowContainer.new()
			for socketable: SocketableDefinition in _sorted(character.database.socketables.values()):
				row.add_child(_choice("%s (%d)" % [socketable.display_name, character.inventory.count(socketable.item_id)],
					socketable.id == _socketable_id, choose_socketable.bind(socketable.id), socketable.description))
			_params.add_child(row)
		CraftingOps.SOCKET_REMOVE:
			_slot_row(item.sockets.size(), "Socket", false)
		CraftingOps.EVOLVE:
			var next := ItemEvolution.next_stage(item, definition, character.database)
			if next != null and not next.mutations.is_empty():
				_params.add_child(UiTheme.label("Mutation path (permanent choice):"))
				for mutation in next.mutations:
					_params.add_child(_choice("%s: %s" % [mutation.display_name, mutation.description], mutation.id == _mutation_id,
						choose_mutation.bind(mutation.id), mutation.description, true))


func _focus_row(item: ItemInstance, definition: ItemDefinition) -> void:
	var operation := character.database.get_operation(_operation)
	if operation == null or not operation.allows_focus:
		return
	var material: MaterialDefinition = character.database.materials.get(_material_id if _operation == CraftingOps.IMPRINT else item.material_id)
	var replace := _affix_index if _operation == CraftingOps.REFORGE else -1
	var tags := AffixPool.tags_of(AffixPool.compute(item, definition, material, character.database, &"", 1.0, replace))
	if tags.is_empty():
		return
	_params.add_child(UiTheme.label("Focus catalyst (optional, x%d weight):" % roundi(operation.focus_weight_multiplier)))
	var row := HFlowContainer.new()
	row.add_child(_choice("No focus", _focus_tag == &"", choose_focus.bind(&"")))
	for tag in tags:
		row.add_child(_choice(String(tag), tag == _focus_tag, choose_focus.bind(tag)))
	_params.add_child(row)


func _slot_row(count: int, prefix: String, optional: bool) -> void:
	if count <= 0:
		return
	var row := HFlowContainer.new()
	if optional:
		row.add_child(_choice("First free", _slot_index < 0, choose_slot.bind(-1)))
	for index in count:
		row.add_child(_choice("%s %d" % [prefix, index + 1], index == _slot_index, choose_slot.bind(index)))
	_params.add_child(row)


func _build_outcomes(preview: CraftingPreview) -> void:
	if preview.outcomes.is_empty():
		return
	_outcome_title.visible = true
	_outcome_title.text = "Possible results (exact chances)"
	var by_affix := AffixPool.by_affix(preview.outcomes)
	var affix_ids: Array = by_affix.keys()
	affix_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return by_affix[a] > by_affix[b])
	for header: String in ["Affix", "Chance", "Tiers"]:
		var label := UiTheme.label(header, UiTheme.COLOR_DIM)
		label.theme_type_variation = &"SmallLabel"
		_outcomes.add_child(label)
	for affix_id: StringName in affix_ids:
		var affix: AffixDefinition = character.database.affixes[affix_id]
		_outcomes.add_child(UiTheme.label(affix.display_name))
		_outcomes.add_child(UiTheme.label("%.1f %%" % (by_affix[affix_id] * 100.0), UiTheme.COLOR_ACCENT))
		var tiers: PackedStringArray = []
		for entry in preview.outcomes:
			if entry.affix == affix:
				tiers.append("T%d %s (%.1f%%)" % [(entry.tier as AffixTier).tier, affix.describe_range(entry.tier).get_slice(" ", 0), entry.probability * 100.0])
		var detail := UiTheme.wrapped("%s\n%s" % [Stats.display_name(affix.stat), " · ".join(tiers)], UiTheme.COLOR_DIM, 260)
		detail.theme_type_variation = &"SmallLabel"
		_outcomes.add_child(detail)


func _pick_affix(index: int) -> void:
	_operation = CraftingOps.REFORGE if definition_allows(CraftingOps.REFORGE) else _operation
	choose_affix(index)


func definition_allows(operation: StringName) -> bool:
	var item := selected_item()
	var definition := character.database.get_item(item.definition_id) if item != null else null
	return definition != null and definition.crafting != null and definition.crafting.allows(operation)


# --- helpers --------------------------------------------------------------------

func _choice(text: String, pressed: bool, callback: Callable, tooltip: String = "", wide: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = pressed
	button.tooltip_text = tooltip
	if wide:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(ACTIONS_WIDTH, 0)
	button.pressed.connect(callback)
	return button


func _line(text: String, color: Color = UiTheme.COLOR_TEXT) -> Label:
	return UiTheme.wrapped(text, color, DETAILS_WIDTH)


func _summary_lines(item: ItemInstance, definition: ItemDefinition) -> PackedStringArray:
	var lines: PackedStringArray = [definition.display_name, "Item level %d, quality %d" % [item.item_level, item.quality]]
	if item.is_imprinted():
		lines.append("Material: %s" % _material_name(item.material_id))
	for affix in item.affixes:
		lines.append(_affix_text(affix))
	return lines


func _affix_text(entry: Dictionary) -> String:
	var affix: AffixDefinition = character.database.affixes.get(StringName(str(entry.get("affix", ""))))
	var value := float(entry.get("flat", 0.0)) + float(entry.get("percent", 0.0))
	var stat := Stats.display_name(StringName(str(entry.get("stat", ""))))
	var number := str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	if affix == null:
		return "+%s %s (fixed)" % [number, stat]
	return "%s T%d: +%s %s" % [affix.display_name, int(entry.get("tier", 0)), number, stat]


func _material_name(material_id: StringName) -> String:
	var material: MaterialDefinition = character.database.materials.get(material_id)
	return material.display_name if material != null else String(material_id)


func _modifiers_text(modifiers: Array[StatModifier]) -> String:
	var parts: PackedStringArray = []
	for modifier in modifiers:
		parts.append(modifier.describe())
	return ", ".join(parts)


func _sorted(definitions: Array) -> Array:
	var result := definitions.duplicate()
	result.sort_custom(func(a: Resource, b: Resource) -> bool: return String(a.get(&"id")) < String(b.get(&"id")))
	return result


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _disconnect() -> void:
	if character != null and character.inventory.changed.is_connected(rebuild):
		character.inventory.changed.disconnect(rebuild)


func _exit_tree() -> void:
	_disconnect()
