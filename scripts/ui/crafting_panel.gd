class_name CraftingPanel
extends UiWindow
## Resonance Forge 2.0 (Old Smithy): one window, seven sections
##   Craft · Imprint · Affixes · Essences · Sockets · Quality · Evolution
## Left: the forgeable items and the material stock. Right: the section's
## current state of the selected item (with exact before/after values where the
## result is fixed) and the action card: operation, choices, costs (have /
## need), requirements, the REAL outcome chances (the same CraftingPreview the
## service executes) and one confirm button with clear result feedback.
## Pure presentation over CraftingService / BaseBuilder - no crafting rules here;
## holds no item state except the selection. No overlapping sub-windows.

signal recipes_requested(plot: BuildPlot)

const ITEMS_WIDTH := 300
const STATE_WIDTH := 380
const ACTIONS_WIDTH := 420
const SECTIONS := ["Craft", "Imprint", "Affixes", "Essences", "Sockets", "Quality", "Evolution"]
const SECTION_OPS := {
	"Craft": [],
	"Imprint": [CraftingOps.IMPRINT],
	"Affixes": [CraftingOps.AUGMENT, CraftingOps.REFORGE],
	"Essences": [CraftingOps.ESSENCE_INSERT, CraftingOps.ESSENCE_EXTRACT],
	"Sockets": [CraftingOps.SOCKET_OPEN, CraftingOps.SOCKET_INSERT, CraftingOps.SOCKET_REMOVE],
	"Quality": [CraftingOps.QUALITY],
	"Evolution": [CraftingOps.EVOLVE],
}

var character: Character
var plot: BuildPlot
## Decides rolls; tests and playtests may seed it.
var rng := RandomNumberGenerator.new()
## Last executed result (shown below the confirm button).
var last_result: CraftingService.Result
var section: String = "Imprint"

var _item_id: String = ""
var _operation: StringName = &""
var _material_id: StringName = &""
var _focus_tag: StringName = &""
var _affix_index: int = -1
var _essence_id: StringName = &""
var _slot_index: int = -1
var _socketable_id: StringName = &""
var _mutation_id: StringName = &""
var _last_craft: String = ""

var _columns: HFlowContainer
var _items: VBoxContainer
var _stock: GridContainer
var _tabs: UiTabs
var _work: HFlowContainer
var _state: VBoxContainer
var _ops: HFlowContainer
var _params: VBoxContainer
var _costs: VBoxContainer
var _notes: Label
var _outcome_title: Control
var _outcomes: GridContainer
var _confirm: Button
var _result: Label
var _action_card: PanelContainer


func _ready() -> void:
	set_title("Resonance Forge")
	set_close_text("Close [G / Esc]")
	rng.randomize()
	_columns = HFlowContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override(&"h_separation", UiTheme.GAP * 3)
	body.add_child(_columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(ITEMS_WIDTH, 0)
	_columns.add_child(left)
	left.add_child(UiTheme.section("Forgeable items"))
	_items = VBoxContainer.new()
	_items.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	left.add_child(_items)
	left.add_child(UiTheme.section("Materials"))
	_stock = GridContainer.new()
	_stock.columns = 2
	_stock.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	_stock.add_theme_constant_override(&"v_separation", 0)
	left.add_child(_stock)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(STATE_WIDTH + ACTIONS_WIDTH + UiTheme.GAP * 2, 0)
	_columns.add_child(right)
	_tabs = UiTabs.new()
	for id in SECTIONS:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(select_section)
	right.add_child(_tabs)
	_work = HFlowContainer.new()
	_work.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	right.add_child(_work)
	var state_card := UiTheme.card(&"CardPanel")
	state_card.custom_minimum_size = Vector2(STATE_WIDTH, 0)
	_state = state_card.get_node("Box") as VBoxContainer
	_state.add_theme_constant_override(&"separation", 4)
	_work.add_child(state_card)
	var action_card := UiTheme.card(&"InsetPanel")
	_action_card = action_card
	action_card.custom_minimum_size = Vector2(ACTIONS_WIDTH, 0)
	var actions := action_card.get_node("Box") as VBoxContainer
	_work.add_child(action_card)
	_ops = HFlowContainer.new()
	_ops.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	actions.add_child(_ops)
	_params = VBoxContainer.new()
	actions.add_child(_params)
	actions.add_child(UiTheme.section("Cost"))
	_costs = VBoxContainer.new()
	_costs.add_theme_constant_override(&"separation", 2)
	actions.add_child(_costs)
	_notes = UiTheme.wrapped("", UiTheme.WARNING, ACTIONS_WIDTH - 30)
	actions.add_child(_notes)
	_outcome_title = UiTheme.section("Possible results")
	actions.add_child(_outcome_title)
	_outcomes = GridContainer.new()
	_outcomes.columns = 3
	_outcomes.add_theme_constant_override(&"h_separation", UiTheme.GAP * 2)
	_outcomes.add_theme_constant_override(&"v_separation", 2)
	actions.add_child(_outcomes)
	_confirm = UiTheme.button("", &"PrimaryButton", confirm)
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(0, 44)
	actions.add_child(_confirm)
	_result = UiTheme.wrapped("", UiTheme.RESONANCE, ACTIONS_WIDTH - 30)
	_result.name = "Result"
	actions.add_child(_result)


## All columns side by side; the flow containers stack them when narrower.
func preferred_body_size() -> Vector2:
	return Vector2(ITEMS_WIDTH + STATE_WIDTH + ACTIONS_WIDTH + UiTheme.GAP * 8, body.get_combined_minimum_size().y)


func open(target_character: Character, target_plot: BuildPlot = null) -> void:
	if character != target_character:
		_disconnect()
		character = target_character
		character.inventory.changed.connect(rebuild)
	plot = target_plot
	last_result = null
	_last_craft = ""
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
		last_result = null
	rebuild()


func select_section(id: String) -> void:
	section = id
	_reset_params()
	var ops: Array = SECTION_OPS.get(id, [])
	_operation = ops[0] if ops.size() == 1 else &""
	if ops.size() > 1:
		for op: StringName in ops:
			if definition_allows(op):
				_operation = op
				break
	rebuild()


func select_operation(operation: StringName) -> void:
	_operation = operation
	section = section_of(operation)
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


static func section_of(operation: StringName) -> String:
	for id: String in SECTION_OPS:
		if operation in SECTION_OPS[id]:
			return id
	return "Imprint"


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
	if _operation != &"":
		section = section_of(_operation)
	_tabs.select(section)
	_rebuild_items()
	_rebuild_stock()
	var item := selected_item()
	var definition := character.database.get_item(item.definition_id) if item != null else null
	for id in SECTIONS:
		var tab := _tabs.tab_button(id)
		var possible: bool = id == "Craft" or (definition != null and _section_possible(definition, id))
		tab.modulate = Color.WHITE if possible else Color(1, 1, 1, 0.5)
		tab.tooltip_text = "" if possible else "Not possible for this item."
	_clear(_state)
	_clear(_ops)
	_clear(_params)
	_clear(_costs)
	_clear(_outcomes)
	_notes.text = ""
	_outcome_title.visible = false
	_show_result()
	_action_card.visible = section != "Craft"
	if section == "Craft":
		_build_craft()
		return
	if item == null:
		_state.add_child(UiTheme.heading("No item selected"))
		_state.add_child(UiTheme.wrapped("Choose an item on the left. Equipped items can be forged too.", UiTheme.TEXT_SECONDARY, STATE_WIDTH - 30))
		_confirm.text = "Choose an item"
		_confirm.disabled = true
		return
	_item_header(item, definition)
	if not _section_possible(definition, section):
		_state.add_child(UiTheme.wrapped("%s cannot be changed in this section." % definition.display_name, UiTheme.TEXT_SECONDARY, STATE_WIDTH - 30))
		_confirm.text = "Not possible for this item"
		_confirm.disabled = true
		return
	call("_state_%s" % section.to_lower(), item, definition)
	_build_actions(item, definition)


func _section_possible(definition: ItemDefinition, id: String) -> bool:
	if definition.crafting == null:
		return false
	for op: StringName in SECTION_OPS.get(id, []):
		if definition.crafting.allows(op):
			return true
	return false


func definition_allows(operation: StringName) -> bool:
	var item := selected_item()
	var definition := character.database.get_item(item.definition_id) if item != null else null
	return definition != null and definition.crafting != null and definition.crafting.allows(operation)


func _rebuild_items() -> void:
	_clear(_items)
	var found := false
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition == null or definition.crafting == null:
			continue
		found = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		var icon := ItemIcon.new().setup(definition, 1, character.equipment.is_equipped(item.instance_id))
		row.add_child(icon)
		var button := ItemSlotButton.new()
		button.name = "Item_%s" % item.instance_id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, ItemIcon.SIZE.y)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = item.instance_id == _item_id
		button.text = definition.display_name + ("  (equipped)" if character.equipment.is_equipped(item.instance_id) else "")
		button.add_theme_color_override(&"font_color", UiTheme.rarity_color(definition.rarity))
		button.tooltip_text = ItemDescriber.text(character, item)
		button.pressed.connect(select_item.bind(item.instance_id))
		row.add_child(button)
		_items.add_child(row)
	if not found:
		_items.add_child(UiTheme.wrapped("You carry nothing the forge can work on yet.", UiTheme.TEXT_SECONDARY, ITEMS_WIDTH))


func _rebuild_stock() -> void:
	_clear(_stock)
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
			if definition == null:
				continue
			var count := character.inventory.count(item_id)
			var name_label := UiTheme.styled(definition.display_name, &"SmallLabel")
			var count_label := UiTheme.styled(str(count), &"SmallLabel")
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if count == 0:
				name_label.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
				count_label.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
			_stock.add_child(name_label)
			_stock.add_child(count_label)


func _item_header(item: ItemInstance, definition: ItemDefinition) -> void:
	var row := HBoxContainer.new()
	row.add_child(ItemIcon.new().setup(definition, 1, character.equipment.is_equipped(item.instance_id)))
	var names := VBoxContainer.new()
	names.add_theme_constant_override(&"separation", 0)
	var title := UiTheme.heading(definition.display_name)
	title.add_theme_color_override(&"font_color", UiTheme.rarity_color(definition.rarity))
	names.add_child(title)
	names.add_child(UiTheme.styled("%s  ·  Item Level %d  ·  Quality %d / %d" % [UiTheme.rarity_name(definition.rarity),
		item.item_level, item.quality, definition.crafting.max_quality], &"SmallLabel"))
	row.add_child(names)
	_state.add_child(row)


# --- section states (current values, before -> after where the result is fixed) ---

func _state_imprint(item: ItemInstance, definition: ItemDefinition) -> void:
	_state.add_child(UiTheme.section("Main material"))
	if item.is_imprinted():
		var material: MaterialDefinition = character.database.materials.get(item.material_id)
		_state.add_child(_line("%s (permanent): %s" % [material.display_name, _modifiers_text(material.imprint_modifiers)], material.color.lightened(0.2)))
		return
	_state.add_child(_line("Not imprinted yet. The main material is chosen once and never changes.", UiTheme.TEXT_SECONDARY))
	var material: MaterialDefinition = character.database.materials.get(_material_id)
	if material != null:
		_state.add_child(UiTheme.section("After imprinting"))
		_state.add_child(_line("%s: %s" % [material.display_name, _modifiers_text(material.imprint_modifiers)], UiTheme.SUCCESS))
		_state.add_child(_line("+ one affix rolled from the pool on the right (not guaranteed).", UiTheme.TEXT_SECONDARY))


func _state_affixes(item: ItemInstance, definition: ItemDefinition) -> void:
	var profile := definition.crafting
	_state.add_child(UiTheme.section("Affixes  %d / %d" % [item.affixes.size(), profile.affix_slots]))
	for index in item.affixes.size():
		var button := Button.new()
		button.name = "Affix%d" % index
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = ItemDescriber.affix_text(character.database, item.affixes[index])
		button.button_pressed = index == _affix_index and _operation == CraftingOps.REFORGE
		button.tooltip_text = "Select to reforge this affix."
		button.pressed.connect(_pick_affix.bind(index))
		_state.add_child(button)
	for index in range(item.affixes.size(), profile.affix_slots):
		_state.add_child(_line("Open affix slot (Augment)", UiTheme.TEXT_MUTED))
	if _operation == CraftingOps.REFORGE and _affix_index >= 0 and _affix_index < item.affixes.size():
		_state.add_child(UiTheme.section("Reforge replaces"))
		_state.add_child(_line(ItemDescriber.affix_text(character.database, item.affixes[_affix_index]), UiTheme.DANGER))
		_state.add_child(_line("with a new roll from the pool on the right. The old affix is lost.", UiTheme.TEXT_SECONDARY))


func _state_essences(item: ItemInstance, definition: ItemDefinition) -> void:
	var active := ItemStats.active_essences(item, definition)
	_state.add_child(UiTheme.section("Monster essences  %d / %d" % [active.size(), mini(2, definition.crafting.essence_slots)]))
	for index in mini(2, definition.crafting.essence_slots):
		var text := "Slot %d: empty" % (index + 1)
		if index < active.size():
			var essence: EssenceDefinition = character.database.essences.get(active[index])
			text = "Slot %d: %s - %s" % [index + 1, essence.display_name, essence.description] if essence != null else text
		_state.add_child(_line(text, UiTheme.TEXT_PRIMARY if index < active.size() else UiTheme.TEXT_MUTED))
	for resonance: EssenceResonanceDefinition in character.database.resonances.values():
		if resonance.matches(active):
			_state.add_child(_line("Resonance: %s - %s" % [resonance.display_name, resonance.description], UiTheme.RESONANCE))
	var chosen: EssenceDefinition = character.database.essences.get(_essence_id)
	if _operation == CraftingOps.ESSENCE_INSERT and chosen != null:
		_state.add_child(UiTheme.section("After"))
		var target := _slot_index if _slot_index >= 0 else active.size()
		_state.add_child(_line("Slot %d: %s" % [target + 1, chosen.display_name], UiTheme.SUCCESS))


func _state_sockets(item: ItemInstance, definition: ItemDefinition) -> void:
	var limit := definition.crafting.socket_slots
	_state.add_child(UiTheme.section("Sockets  %d / %d open" % [item.sockets.size(), limit]))
	for index in limit:
		var text := "Socket %d: closed" % (index + 1)
		var color := UiTheme.TEXT_MUTED
		if index < item.sockets.size():
			var socketable: SocketableDefinition = character.database.socketables.get(item.sockets[index])
			text = "Socket %d: %s" % [index + 1, ("%s - %s" % [socketable.display_name, socketable.description]) if socketable != null else "empty"]
			color = UiTheme.TEXT_PRIMARY
		_state.add_child(_line(text, color))
	if _operation == CraftingOps.SOCKET_OPEN and item.sockets.size() < limit:
		_state.add_child(UiTheme.section("After"))
		_state.add_child(_line("Sockets %d -> %d open" % [item.sockets.size(), item.sockets.size() + 1], UiTheme.SUCCESS))


func _state_quality(item: ItemInstance, definition: ItemDefinition) -> void:
	var profile := definition.crafting
	_state.add_child(UiTheme.section("Quality  %d / %d" % [item.quality, profile.max_quality]))
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT, UiTheme.BRONZE)
	bar.max_value = maxi(1, profile.max_quality)
	bar.value = item.quality
	_state.add_child(bar)
	if item.quality >= profile.max_quality:
		_state.add_child(_line("Maximum quality reached.", UiTheme.TEXT_SECONDARY))
		return
	_state.add_child(UiTheme.section("Base stats now -> after +1 quality"))
	var now := 1.0 + item.quality * ItemStats.QUALITY_PERCENT_PER_POINT / 100.0
	var after := 1.0 + (item.quality + 1) * ItemStats.QUALITY_PERCENT_PER_POINT / 100.0
	for modifier in definition.base_stats:
		if modifier == null or not (profile.quality_stats.is_empty() or modifier.stat in profile.quality_stats):
			continue
		var value := modifier.flat if modifier.flat != 0.0 else modifier.percent
		var unit := "" if modifier.flat != 0.0 else "%"
		_state.add_child(_line("%s:  %+.2f%s  ->  %+.2f%s" % [Stats.display_name(modifier.stat), value * now, unit, value * after, unit], UiTheme.SUCCESS))
	_state.add_child(_line("Affixes, essences and special effects stay unchanged.", UiTheme.TEXT_MUTED))


func _state_evolution(item: ItemInstance, definition: ItemDefinition) -> void:
	var evolution := ItemStats.evolution_of(definition, character.database)
	if evolution == null:
		_state.add_child(_line("This item cannot evolve.", UiTheme.TEXT_SECONDARY))
		return
	var current := evolution.get_stage(item.evolution_stage())
	_state.add_child(UiTheme.section("%s  ·  stage %d / %d" % [evolution.display_name, item.evolution_stage(), evolution.max_stage()]))
	_state.add_child(_line(current.display_name if current != null else "-", UiTheme.TEXT_PRIMARY))
	var next := ItemEvolution.next_stage(item, definition, character.database)
	if next == null:
		_state.add_child(_line("Fully evolved.", UiTheme.TEXT_SECONDARY))
	else:
		_state.add_child(_line("Item XP %d / %d for stage %d (%s). Item XP comes from real fights." % [item.evolution_xp(), next.xp_required, next.stage, next.display_name], UiTheme.TEXT_SECONDARY))
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT, UiTheme.RESONANCE)
		bar.max_value = maxi(1, next.xp_required)
		bar.value = mini(item.evolution_xp(), next.xp_required)
		_state.add_child(bar)
	if item.evolution_path() != &"":
		var mutation := evolution.get_stage(evolution.max_stage()).get_mutation(item.evolution_path())
		_state.add_child(_line("Mutation: %s" % (mutation.display_name if mutation != null else String(item.evolution_path())), UiTheme.RESONANCE))


# --- action card ------------------------------------------------------------------

func _build_actions(item: ItemInstance, definition: ItemDefinition) -> void:
	var ops: Array = SECTION_OPS.get(section, [])
	if ops.size() > 1:
		for operation_id: StringName in ops:
			var operation := character.database.get_operation(operation_id)
			if operation == null or not definition.crafting.allows(operation_id):
				continue
			var button := UiTheme.button(operation.display_name, &"TabButton", select_operation.bind(operation_id))
			button.name = "Op_%s" % operation_id
			button.toggle_mode = true
			button.button_pressed = operation_id == _operation
			button.tooltip_text = operation.description
			_ops.add_child(button)
	if _operation == &"" or not definition.crafting.allows(_operation):
		_confirm.text = "Choose an action"
		_confirm.disabled = true
		return
	var operation := character.database.get_operation(_operation)
	_params.add_child(UiTheme.wrapped(operation.description, UiTheme.TEXT_SECONDARY, ACTIONS_WIDTH - 30))
	_build_params(item, definition)
	var preview := current_preview()
	for cost in preview.costs:
		var cost_def := character.database.get_item(cost.item_id)
		var have := character.inventory.count(cost.item_id)
		var enough := have >= cost.quantity
		_costs.add_child(UiTheme.stat_row("%dx %s" % [cost.quantity, cost_def.display_name if cost_def else String(cost.item_id)],
			"have %d%s" % [have, "" if enough else "  (missing)"], UiTheme.SUCCESS if enough else UiTheme.DANGER))
	if preview.costs.is_empty():
		_costs.add_child(_small("No material cost."))
	var notes := preview.notes.duplicate()
	if preview.error != "":
		notes.insert(0, preview.error)
	_notes.text = "\n".join(notes)
	_notes.add_theme_color_override(&"font_color", UiTheme.DANGER if preview.error != "" else UiTheme.WARNING)
	_build_outcomes(preview)
	_confirm.text = "%s" % operation.display_name
	_confirm.disabled = not preview.ok()
	_confirm.tooltip_text = preview.reason()


func _build_params(item: ItemInstance, definition: ItemDefinition) -> void:
	match _operation:
		CraftingOps.IMPRINT:
			_params.add_child(UiTheme.section("Main material (permanent)"))
			var row := HFlowContainer.new()
			row.add_theme_constant_override(&"h_separation", UiTheme.GAP)
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
			if _affix_index < 0:
				_params.add_child(_small("Select the affix to replace in the left card."))
			_focus_row(item, definition)
		CraftingOps.ESSENCE_INSERT:
			_params.add_child(UiTheme.section("Essence"))
			var row := HFlowContainer.new()
			row.add_theme_constant_override(&"h_separation", UiTheme.GAP)
			for essence: EssenceDefinition in _sorted(character.database.essences.values()):
				row.add_child(_choice("%s (%d)" % [essence.display_name, character.inventory.count(essence.item_id)],
					essence.id == _essence_id, choose_essence.bind(essence.id), essence.description))
			_params.add_child(row)
			_slot_row(mini(2, definition.crafting.essence_slots), "Slot", true)
		CraftingOps.ESSENCE_EXTRACT:
			_slot_row(item.essences.size(), "Extract slot", false)
		CraftingOps.SOCKET_INSERT:
			_params.add_child(UiTheme.section("Gem or rune"))
			var row := HFlowContainer.new()
			row.add_theme_constant_override(&"h_separation", UiTheme.GAP)
			for socketable: SocketableDefinition in _sorted(character.database.socketables.values()):
				row.add_child(_choice("%s (%d)" % [socketable.display_name, character.inventory.count(socketable.item_id)],
					socketable.id == _socketable_id, choose_socketable.bind(socketable.id), socketable.description))
			_params.add_child(row)
		CraftingOps.SOCKET_REMOVE:
			_slot_row(item.sockets.size(), "Socket", false)
		CraftingOps.EVOLVE:
			var next := ItemEvolution.next_stage(item, definition, character.database)
			if next != null and not next.mutations.is_empty():
				_params.add_child(UiTheme.section("Mutation path (permanent)"))
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
	_params.add_child(UiTheme.section("Focus catalyst (optional, x%d weight)" % roundi(operation.focus_weight_multiplier)))
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	row.add_child(_choice("No focus", _focus_tag == &"", choose_focus.bind(&"")))
	for tag in tags:
		row.add_child(_choice(String(tag).capitalize(), tag == _focus_tag, choose_focus.bind(tag)))
	_params.add_child(row)


func _slot_row(count: int, prefix: String, optional: bool) -> void:
	if count <= 0:
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	if optional:
		row.add_child(_choice("First free", _slot_index < 0, choose_slot.bind(-1)))
	for index in count:
		row.add_child(_choice("%s %d" % [prefix, index + 1], index == _slot_index, choose_slot.bind(index)))
	_params.add_child(row)


## Real chances of the rolling operations (the pool CraftingService draws from).
func _build_outcomes(preview: CraftingPreview) -> void:
	if preview.outcomes.is_empty():
		return
	_outcome_title.visible = true
	var by_affix := AffixPool.by_affix(preview.outcomes)
	var affix_ids: Array = by_affix.keys()
	affix_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return by_affix[a] > by_affix[b])
	for header: String in ["Affix", "Chance", "Tiers"]:
		_outcomes.add_child(UiTheme.styled(header, &"CaptionLabel"))
	for affix_id: StringName in affix_ids:
		var affix: AffixDefinition = character.database.affixes[affix_id]
		_outcomes.add_child(UiTheme.label(affix.display_name))
		_outcomes.add_child(UiTheme.label("%.1f %%" % (by_affix[affix_id] * 100.0), UiTheme.RESONANCE))
		var tiers: PackedStringArray = []
		for entry in preview.outcomes:
			if entry.affix == affix:
				tiers.append("T%d %s (%.1f%%)" % [(entry.tier as AffixTier).tier, affix.describe_range(entry.tier).get_slice(" ", 0), entry.probability * 100.0])
		var detail := UiTheme.wrapped("%s\n%s" % [Stats.display_name(affix.stat), " · ".join(tiers)], UiTheme.TEXT_SECONDARY, 200)
		detail.theme_type_variation = &"SmallLabel"
		_outcomes.add_child(detail)
	var note := _small("One of these is rolled - the result is never guaranteed.")
	_outcomes.add_child(note)


func _show_result() -> void:
	if section == "Craft":
		_result.text = _last_craft
		_result.add_theme_color_override(&"font_color", UiTheme.SUCCESS)
		return
	if last_result == null:
		_result.text = ""
		return
	_result.text = ("Done: %s" % last_result.message) if last_result.ok else ("Not possible: %s" % last_result.error)
	_result.add_theme_color_override(&"font_color", UiTheme.SUCCESS if last_result.ok else UiTheme.DANGER)


# --- Craft (the Old Smithy's recipes) -----------------------------------------------

func _build_craft() -> void:
	var building := plot.built_building() if plot != null and is_instance_valid(plot) else null
	_state.add_child(UiTheme.heading("Smithing"))
	if building == null or building.recipes.is_empty():
		_state.add_child(_line("No recipes at this forge.", UiTheme.TEXT_SECONDARY))
		_confirm.text = "No recipe"
		_confirm.disabled = true
		return
	_state.add_child(_line(building.description, UiTheme.TEXT_SECONDARY))
	for recipe in building.recipes:
		_state.add_child(_recipe_row(recipe))
	if _last_craft != "":
		_state.add_child(_line(_last_craft, UiTheme.SUCCESS))


func _recipe_row(recipe: RecipeDefinition) -> Control:
	var card := UiTheme.card(&"InsetPanel")
	var box := card.get_node("Box") as VBoxContainer
	var output := character.database.get_item(recipe.output_item_id)
	box.add_child(UiTheme.label("%s  ->  %d x %s" % [recipe.display_name, recipe.output_quantity, output.display_name if output else String(recipe.output_item_id)], UiTheme.PARCHMENT))
	for input in recipe.inputs:
		var item := character.database.get_item(input.item_id)
		var have := character.inventory.count(input.item_id)
		box.add_child(UiTheme.stat_row("%dx %s" % [input.quantity, item.display_name if item else String(input.item_id)], "have %d" % have,
			UiTheme.SUCCESS if have >= input.quantity else UiTheme.DANGER))
	var error := BaseBuilder.craft_error(character, recipe)
	var button := UiTheme.button("Craft", &"PrimaryButton", func() -> void:
		var result := BaseBuilder.craft(character, recipe)
		_last_craft = result if result != "" else "Crafted %s." % recipe.display_name
		rebuild())
	button.name = "Craft_%s" % recipe.id
	button.disabled = error != ""
	button.tooltip_text = error
	box.add_child(button)
	return card


func _pick_affix(index: int) -> void:
	_operation = CraftingOps.REFORGE if definition_allows(CraftingOps.REFORGE) else _operation
	choose_affix(index)


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
		button.custom_minimum_size = Vector2(ACTIONS_WIDTH - 30, 0)
	button.pressed.connect(callback)
	return button


func _line(text: String, color: Color = UiTheme.TEXT_PRIMARY) -> Label:
	return UiTheme.wrapped(text, color, STATE_WIDTH - 30)


func _small(text: String) -> Label:
	var label := UiTheme.wrapped(text, UiTheme.TEXT_MUTED, ACTIONS_WIDTH - 30)
	label.theme_type_variation = &"SmallLabel"
	return label


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
