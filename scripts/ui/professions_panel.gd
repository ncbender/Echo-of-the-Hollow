class_name ProfessionsPanel
extends UiWindow
## Professions (P, or a workstation in Haven): book registers Crafting /
## Gathering on the left edge; compact profession cards (level, rank, XP bar)
## next to the detail page of the selected profession. Crafting professions
## list every recipe - known ones selectable, locked ones with the reason
## (level, pattern, quest, not in the game yet) - and the selected recipe with
## its output (item tooltip on hover), workshop, materials (have / need, the
## Haven stash included where ProfessionService allows it), XP and Craft.
## Gathering professions list their resource nodes. Read-only over
## CharacterProfessions; every change goes through ProfessionService.

## The workshop's restoration window was asked for (GameHud opens it).
signal restoration_requested(site: RuinSite)

const PAGES := ["Crafting", "Gathering"]
const CARD_WIDTH := 260
const DETAIL_WIDTH := 600
const RECIPE_ROW_HEIGHT := 40

var character: Character
## Workstation the window was opened at (&"" = away from any workstation).
var station_id: StringName = &""
## Interactable that opened the window (closes it when the player walks off).
var site: Node2D
var page: String = "Crafting"
var profession_id: StringName = &"blacksmithing"
var recipe_id: StringName = &""
## Result line of the last action ("" = none).
var last_message: String = ""
var last_ok: bool = true
var tooltip: ItemTooltip

var _tabs: BookTabs
var _cards: VBoxContainer
var _detail: VBoxContainer
var _connected: Character
var _auto_focusing: bool = false
var _rebuild_queued: bool = false


func _ready() -> void:
	set_title("Professions")
	set_close_text("Close [P / Esc]")
	_tabs = BookTabs.new()
	_tabs.name = "BookTabs"
	for id in PAGES:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(show_page)
	set_side_tabs(_tabs)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	body.add_child(columns)
	_cards = VBoxContainer.new()
	_cards.name = "Cards"
	_cards.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_cards.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	columns.add_child(_cards)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_detail.add_theme_constant_override(&"separation", UiTheme.GAP)
	columns.add_child(_detail)
	tooltip = ItemTooltip.new()
	add_child(tooltip)
	visibility_changed.connect(_on_visibility)


## Opens at `target_station` (a workstation; its profession is shown) or, with
## &"", from anywhere (looking only - crafting needs the workstation).
func open(target_character: Character, target_station: StringName = &"", target_site: Node2D = null) -> void:
	_connect(target_character)
	station_id = target_station
	site = target_site
	last_message = ""
	var at_profession := _station_profession(target_station)
	if at_profession != null:
		profession_id = at_profession.id
		page = "Crafting"
		recipe_id = &""
	show()
	show_page(page)


func _process(_delta: float) -> void:
	if visible and site != null and (not is_instance_valid(site) or not site.get(&"player_inside")):
		hide()


func show_page(id: String) -> void:
	page = id
	_tabs.select(id)
	var kind := ProfessionDefinition.Kind.GATHERING if id == "Gathering" else ProfessionDefinition.Kind.CRAFTING
	var list := ProfessionService.professions(character.database, kind)
	var current: ProfessionDefinition = character.database.professions.get(profession_id)
	if current == null or current.kind != kind:
		profession_id = list[0].id if not list.is_empty() else &""
		recipe_id = &""
	rebuild()


func select_profession(id: StringName) -> void:
	if id != profession_id:
		recipe_id = &""
		last_message = ""
	profession_id = id
	rebuild()


func select_recipe(id: StringName) -> void:
	recipe_id = id
	rebuild()


func rebuild() -> void:
	if character == null or not visible:
		return
	tooltip.hide_tooltip()
	var focused := get_viewport().gui_get_focus_owner()
	var keep_focus := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	_clear(_cards)
	_clear(_detail)
	_clear(footer)
	footer.visible = false
	var kind := ProfessionDefinition.Kind.GATHERING if page == "Gathering" else ProfessionDefinition.Kind.CRAFTING
	for profession in ProfessionService.professions(character.database, kind):
		_cards.add_child(_profession_card(profession))
	var definition: ProfessionDefinition = character.database.professions.get(profession_id)
	if definition != null:
		_build_header(definition)
		if definition.is_crafting():
			_build_recipes(definition)
		else:
			_build_gathering(definition)
	if keep_focus != "":
		_restore_focus.call_deferred(keep_focus)   # by name: the node may be rebuilt again meanwhile
	queue_fit()


func _restore_focus(node_name: String) -> void:
	if not visible or not is_inside_tree():
		return
	var again := find_child(node_name, true, false) as Control
	if again != null and again.is_inside_tree() and again.is_visible_in_tree() and again.focus_mode != Control.FOCUS_NONE:
		again.grab_focus()


# --- cards --------------------------------------------------------------------------

func _profession_card(profession: ProfessionDefinition) -> Control:
	var button := Button.new()
	button.name = "Prof_%s" % profession.id
	button.toggle_mode = true
	button.button_pressed = profession.id == profession_id
	button.theme_type_variation = &"InventorySlot"
	button.custom_minimum_size = Vector2(CARD_WIDTH, 58)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(select_profession.bind(profession.id))
	var level := character.professions.level(profession.id)
	button.tooltip_text = profession.description
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -10
	box.offset_top = 5
	box.offset_bottom = -6
	box.add_theme_constant_override(&"separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch := ColorRect.new()
	swatch.color = profession.color
	swatch.custom_minimum_size = Vector2(4, 0)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(swatch)
	var title := UiTheme.label(profession.display_name, UiTheme.PARCHMENT if profession.id == profession_id else UiTheme.TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var level_label := UiTheme.styled("Lv %d" % level, &"SmallLabel")
	level_label.name = "Level"
	head.add_child(level_label)
	box.add_child(head)
	var rank := UiTheme.styled(ProfessionService.rank_name(level), &"CaptionLabel")
	box.add_child(rank)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, profession.color)
	bar.max_value = maxi(1, character.professions.xp_to_next(profession.id))
	bar.value = character.professions.xp(profession.id)
	box.add_child(bar)
	button.add_child(box)
	return button


# --- detail -------------------------------------------------------------------------

func _build_header(profession: ProfessionDefinition) -> void:
	var level := character.professions.level(profession.id)
	var head := HBoxContainer.new()
	var title := UiTheme.heading(profession.display_name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.styled("%s  ·  Level %d / %d" % [ProfessionService.rank_name(level), level, profession.max_level], &"SubheadingLabel"))
	_detail.add_child(head)
	var need := character.professions.xp_to_next(profession.id)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT, profession.color)
	bar.name = "XpBar"
	bar.max_value = maxi(1, need)
	bar.value = character.professions.xp(profession.id) if need > 0 else 1
	_detail.add_child(bar)
	_detail.add_child(UiTheme.styled("XP %d / %d" % [character.professions.xp(profession.id), need] if need > 0 else "Mastered", &"SmallLabel"))
	_detail.add_child(UiTheme.wrapped(profession.description, UiTheme.TEXT_SECONDARY, DETAIL_WIDTH))


func _build_recipes(profession: ProfessionDefinition) -> void:
	var db := character.database
	var workshop := ProfessionService.station_name(db, profession.station_id)
	var here := station_id == profession.station_id
	var where := "Workshop: %s (Haven)" % workshop
	if here:
		where += "  ·  you are here"
		if ProfessionService.uses_stash(character, station_id):
			where += "  ·  stash materials in reach"
	_detail.add_child(UiTheme.styled(where, &"SmallLabel"))
	if here:
		_add_workshop_stage(profession.station_id)
	_detail.add_child(UiTheme.section("Recipes"))
	var recipes := ProfessionService.recipes_of(db, profession.id)
	if recipe_id == &"" or not db.profession_recipes.has(recipe_id) or (db.profession_recipes[recipe_id] as ProfessionRecipeDefinition).profession_id != profession.id:
		recipe_id = recipes[0].id if not recipes.is_empty() else &""
		for recipe in recipes:
			if character.professions.knows(recipe.id) and recipe.craftable:
				recipe_id = recipe.id
				break
	var list := VBoxContainer.new()
	list.name = "Recipes"
	list.add_theme_constant_override(&"separation", 2)
	for recipe in recipes:
		list.add_child(_recipe_row(recipe))
	_detail.add_child(list)
	var selected: ProfessionRecipeDefinition = db.profession_recipes.get(recipe_id)
	if selected != null:
		_detail.add_child(_recipe_card(selected))


## Stage of the workshop the window was opened at and, while a next step exists,
## the button to the restoration window (an Artisan Quarter workshop opens its
## bench first; restoring is offered here). Never blocks crafting.
func _add_workshop_stage(workshop_id: StringName) -> void:
	var ruin: RuinDefinition = character.database.ruins.get(workshop_id)
	var ruin_site := site as RuinSite
	if ruin == null or ruin_site == null or not ruin_site.is_workshop():
		return
	var row := HBoxContainer.new()
	row.name = "WorkshopStage"
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	var stage := RestorationService.stage(character, ruin.id)
	var track := JournalPanel.StageTrack.make(stage)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(track)
	var next := RestorationService.next_stage(character, ruin)
	if next != &"":
		var verb := "Revitalize" if next == RestorationService.REVITALIZED else "Restore"
		var button := UiTheme.button("%s the workshop" % verb, &"", func() -> void: restoration_requested.emit(ruin_site))
		button.name = "RestoreWorkshop"
		button.tooltip_text = RestorationService.advance_error(character, ruin, next)
		row.add_child(button)
	_detail.add_child(row)


func _recipe_row(recipe: ProfessionRecipeDefinition) -> Control:
	var button := Button.new()
	button.name = "Recipe_%s" % recipe.id
	button.toggle_mode = true
	button.button_pressed = recipe.id == recipe_id
	button.theme_type_variation = &"InventorySlot"
	button.custom_minimum_size = Vector2(DETAIL_WIDTH, RECIPE_ROW_HEIGHT)
	button.pressed.connect(select_recipe.bind(recipe.id))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	var locked := locked_reason(recipe)
	var icon := ItemIcon.new().setup(character.database.get_item(recipe.output_item_id), recipe.output_quantity)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate.a = 1.0 if locked == "" else 0.45
	row.add_child(icon)
	var name_label := UiTheme.label(recipe.display_name, UiTheme.TEXT_PRIMARY if locked == "" else UiTheme.TEXT_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var tag := "Processing" if recipe.is_processing else ""
	if locked != "":
		tag = locked_tag(recipe)
	if tag != "":
		var tag_label := UiTheme.styled(tag, &"CaptionLabel")
		if locked != "":
			tag_label.add_theme_color_override(&"font_color", UiTheme.WARNING)
		row.add_child(tag_label)
	row.add_child(UiTheme.styled("Lv %d" % recipe.required_level, &"SmallLabel"))
	button.add_child(row)
	button.tooltip_text = locked
	return button


## Why `recipe` cannot be crafted in general ("" = it can, given the place and
## the materials): not in the game yet, not learned, level too low.
func locked_reason(recipe: ProfessionRecipeDefinition) -> String:
	if not recipe.craftable:
		return recipe.unavailable_reason if recipe.unavailable_reason != "" else "This recipe cannot be crafted yet."
	if not character.professions.knows(recipe.id):
		return "Not learned. %s" % _unlock_text(recipe)
	if character.professions.level(recipe.profession_id) < recipe.required_level:
		return "Requires level %d." % recipe.required_level
	return ""


## Short tag of a locked recipe row.
func locked_tag(recipe: ProfessionRecipeDefinition) -> String:
	if not recipe.craftable:
		return "Not yet available"
	if not character.professions.knows(recipe.id):
		return "Not learned"
	return "Level %d" % recipe.required_level


func _unlock_text(recipe: ProfessionRecipeDefinition) -> String:
	var source := ProfessionRecipeDefinition.source_name(recipe.unlock_source)
	match recipe.unlock_source:
		ProfessionRecipeDefinition.UnlockSource.AUTOMATIC:
			return "Learned automatically at level %d." % recipe.required_level
		ProfessionRecipeDefinition.UnlockSource.RECIPE_ITEM:
			var item := character.database.get_item(recipe.unlock_reference)
			return "Learn it from %s." % (item.display_name if item != null else "a recipe item")
	return "Source: %s." % source


func _recipe_card(recipe: ProfessionRecipeDefinition) -> Control:
	var db := character.database
	var card := UiTheme.card(&"CardPanel")
	card.name = "RecipeCard"
	var box := card.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP)
	var output := _item_chip(recipe.output_item_id, recipe.output_quantity)
	output.name = "Output"
	head.add_child(output)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override(&"separation", 0)
	titles.add_child(UiTheme.styled(recipe.display_name, &"SubheadingLabel"))
	var item := db.get_item(recipe.output_item_id)
	titles.add_child(UiTheme.styled("Makes %d x %s" % [recipe.output_quantity, item.display_name if item else String(recipe.output_item_id)], &"SmallLabel"))
	head.add_child(titles)
	box.add_child(head)
	var station := ProfessionService.station_of(db, recipe)
	box.add_child(UiTheme.stat_row("Workstation", ProfessionService.station_name(db, station), UiTheme.SUCCESS if station == station_id else UiTheme.TEXT_PRIMARY))
	box.add_child(UiTheme.stat_row("Required level", str(recipe.required_level),
		UiTheme.SUCCESS if character.professions.level(recipe.profession_id) >= recipe.required_level else UiTheme.DANGER))
	var xp := ProfessionService.craft_xp(character, recipe)
	var first := not character.professions.crafted_before(recipe.id)
	box.add_child(UiTheme.stat_row("Experience", ("%d XP  (first craft bonus)" if first else "%d XP") % xp, UiTheme.RESONANCE if xp > 0 else UiTheme.TEXT_MUTED))
	box.add_child(UiTheme.section("Materials"))
	var at_station := station == station_id
	for cost in recipe.inputs:
		box.add_child(_material_row(cost, station if at_station else &""))
	var locked := locked_reason(recipe)
	if locked != "":
		box.add_child(UiTheme.wrapped(locked, UiTheme.WARNING, DETAIL_WIDTH - 30))
	var teach := _teaching_item(recipe)
	if teach != null:
		var learn := UiTheme.button("Learn from %s" % db.get_item(teach.definition_id).display_name, &"", learn_from_bag.bind(teach.instance_id))
		learn.name = "Learn"
		learn.size_flags_horizontal = Control.SIZE_SHRINK_END
		box.add_child(learn)
	var error := ProfessionService.craft_error(character, recipe.id, station_id)
	var craft_button := UiTheme.button("Craft", &"PrimaryButton", craft_selected)
	craft_button.name = "Craft"
	craft_button.disabled = error != ""
	craft_button.tooltip_text = error
	craft_button.custom_minimum_size = Vector2(160, 40)
	craft_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	# Craft and its feedback sit in the window footer: the recipe list and card
	# may scroll (150 % UI), the primary action stays visible.
	var bottom := HBoxContainer.new()
	bottom.name = "CraftBar"
	bottom.add_theme_constant_override(&"separation", UiTheme.GAP)
	var hint := UiTheme.wrapped(error if error != "" and locked == "" else "", UiTheme.TEXT_MUTED, DETAIL_WIDTH - 220)
	hint.name = "CraftHint"
	hint.theme_type_variation = &"SmallLabel"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(UiTheme.styled(recipe.display_name, &"SubheadingLabel"))
	bottom.add_child(hint)
	bottom.add_child(craft_button)
	footer.add_child(HSeparator.new())
	footer.add_child(bottom)
	var result := UiTheme.wrapped(last_message, UiTheme.SUCCESS if last_ok else UiTheme.DANGER, CARD_WIDTH + DETAIL_WIDTH)
	result.name = "Result"
	result.visible = last_message != ""
	footer.add_child(result)
	footer.visible = true
	return card


func _material_row(cost: ItemCost, at_station: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "Material_%s" % cost.item_id
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	row.add_child(_item_chip(cost.item_id, 1, 32))
	var item := character.database.get_item(cost.item_id)
	var name_label := UiTheme.label(item.display_name if item else String(cost.item_id), UiTheme.TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var in_bag := character.inventory.count(cost.item_id)
	var have := ProfessionService.available(character, cost.item_id, at_station)
	var text := "%d / %d" % [have, cost.quantity]
	if have != in_bag:
		text += "  (bag %d, stash %d)" % [in_bag, have - in_bag]
	var amount := UiTheme.label(text, UiTheme.SUCCESS if have >= cost.quantity else UiTheme.DANGER)
	amount.name = "Have"
	row.add_child(amount)
	return row


## Item icon with the item tooltip on hover / focus (a preview instance: the
## base item, nothing rolled).
func _item_chip(item_id: StringName, quantity: int, edge: float = 48.0) -> Control:
	var chip := Button.new()
	chip.theme_type_variation = &"InventorySlot"
	chip.custom_minimum_size = Vector2(edge, edge)
	chip.focus_mode = Control.FOCUS_ALL
	var icon := ItemIcon.new().setup(character.database.get_item(item_id), quantity)
	icon.custom_minimum_size = Vector2.ZERO   # sized by the chip
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	chip.mouse_entered.connect(_show_item.bind(chip, item_id, quantity))
	chip.focus_entered.connect(_show_item.bind(chip, item_id, quantity))
	chip.mouse_exited.connect(tooltip.hide_tooltip)
	chip.focus_exited.connect(tooltip.hide_tooltip)
	return chip


func _show_item(anchor: Control, item_id: StringName, quantity: int) -> void:
	if _auto_focusing or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	tooltip.show_for(character, ItemInstance.create(item_id, quantity, "preview"), anchor)


func _build_gathering(profession: ProfessionDefinition) -> void:
	_detail.add_child(UiTheme.styled("Gather in the world: walk up to a resource and press G.", &"SmallLabel"))
	_detail.add_child(UiTheme.section("Resources"))
	var nodes: Array = character.database.resource_nodes.values().filter(func(n: ResourceNodeDefinition) -> bool: return n.profession_id == profession.id)
	nodes.sort_custom(func(a: ResourceNodeDefinition, b: ResourceNodeDefinition) -> bool:
		return a.display_name < b.display_name if a.required_level == b.required_level else a.required_level < b.required_level)
	if nodes.is_empty():
		_detail.add_child(UiTheme.label("No resources of this kind are known yet.", UiTheme.TEXT_MUTED))
	var level := character.professions.level(profession.id)
	for node: ResourceNodeDefinition in nodes:
		var card := UiTheme.card(&"InsetPanel")
		card.name = "Node_%s" % node.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", UiTheme.GAP)
		row.add_child(_item_chip(node.yield_item_id, node.yield_quantity, 40))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override(&"separation", 0)
		texts.add_child(UiTheme.label(node.display_name, UiTheme.TEXT_PRIMARY))
		var item := character.database.get_item(node.yield_item_id)
		var xp := roundi(node.gather_xp * ProfessionService.xp_share(level, node.required_level))
		texts.add_child(UiTheme.styled("%d x %s  ·  %d XP" % [node.yield_quantity, item.display_name if item else String(node.yield_item_id), xp], &"SmallLabel"))
		row.add_child(texts)
		var ok := level >= node.required_level
		var req := UiTheme.label("Lv %d" % node.required_level, UiTheme.SUCCESS if ok else UiTheme.DANGER)
		row.add_child(req)
		(card.get_node("Box") as VBoxContainer).add_child(row)
		_detail.add_child(card)


# --- actions -----------------------------------------------------------------------

## Crafts the selected recipe once at the current workstation (UI and tests).
func craft_selected() -> Dictionary:
	var result := ProfessionService.craft(character, recipe_id, station_id)
	last_ok = result.error == ""
	if last_ok:
		var recipe: ProfessionRecipeDefinition = character.database.profession_recipes[recipe_id]
		var item := character.database.get_item(recipe.output_item_id)
		last_message = "Crafted %d x %s  ·  +%d XP%s" % [recipe.output_quantity, item.display_name, result.xp, "  (first craft)" if result.first else ""]
		if int(result.levels) > 0:
			var profession: ProfessionDefinition = character.database.professions[recipe.profession_id]
			last_message += "  ·  %s level %d!" % [profession.display_name, character.professions.level(profession.id)]
	else:
		last_message = result.error
	rebuild()
	return result


## Learns a recipe from a recipe item in the bag (UI and tests).
func learn_from_bag(instance_id: String) -> String:
	var item := character.inventory.find(instance_id)
	var definition := character.database.get_item(item.definition_id) if item != null else null
	var error := ProfessionService.learn_from_item(character, instance_id)
	last_ok = error == ""
	last_message = error if error != "" else "Learned %s." % (character.database.profession_recipes[definition.teaches_recipe_id] as ProfessionRecipeDefinition).display_name
	rebuild()
	return error


func _teaching_item(recipe: ProfessionRecipeDefinition) -> ItemInstance:
	if character.professions.knows(recipe.id):
		return null
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition != null and definition.teaches_recipe_id == recipe.id:
			return item
	return null


# --- plumbing ----------------------------------------------------------------------

func _station_profession(target_station: StringName) -> ProfessionDefinition:
	if target_station == &"":
		return null
	for profession: ProfessionDefinition in character.database.professions.values():
		if profession.station_id == target_station:
			return profession
	return null


func _connect(target: Character) -> void:
	if _connected == target:
		character = target
		return
	_disconnect()
	character = target
	_connected = target
	character.professions.changed.connect(_on_changed)
	character.inventory.changed.connect(_on_changed)
	character.stash.changed.connect(_on_changed)


func _disconnect() -> void:
	if _connected == null:
		return
	if _connected.professions.changed.is_connected(_on_changed):
		_connected.professions.changed.disconnect(_on_changed)
	if _connected.inventory.changed.is_connected(_on_changed):
		_connected.inventory.changed.disconnect(_on_changed)
	if _connected.stash.changed.is_connected(_on_changed):
		_connected.stash.changed.disconnect(_on_changed)
	_connected = null


func _on_changed(_arg: Variant = null) -> void:
	if visible and not _rebuild_queued:
		_rebuild_queued = true   # several changes of one action: one rebuild
		_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_rebuild_queued = false
	rebuild()


func _on_visibility() -> void:
	if not visible:
		tooltip.hide_tooltip()


func _exit_tree() -> void:
	_disconnect()


func _focus_first() -> void:
	_auto_focusing = true
	super()
	_auto_focusing = false


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
