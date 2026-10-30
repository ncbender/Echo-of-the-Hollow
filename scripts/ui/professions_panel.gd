class_name ProfessionsPanel
extends UiWindow
## Professions (P, or a workstation in Haven). Menu UX Polish 1.1 navigation: the areas Crafting | Gathering |
## Salvage are the book registers outside the left edge (the same BookTabs as the class station); the professions
## of the chosen area are tabs in the title row, right of "Professions"; below them the one shared page of the
## chosen profession. Crafting: recipe list (search, bounded scroll) on the left, the chosen recipe's card (output,
## type, level, XP, materials - have / need, the Haven stash included where ProfessionService allows it) on the
## right, and the action zone in the footer (the workshop the recipe needs, the concrete reason Craft is blocked,
## Craft). Gathering lists the resource nodes. Salvage shows only the professions SalvageService supports, with the
## same list | card | footer layout. Read-only over CharacterProfessions; every change goes through
## ProfessionService / SalvageService.

## The workshop's restoration window was asked for (GameHud opens it).
signal restoration_requested(site: RuinSite)

const PAGES := ["Crafting", "Gathering", "Salvage"]
## Kept for older callers: the page width of the former profession cards (no cards any more).
const CARD_WIDTH := 260
## Width of wrapped texts on the page (the body of the main frame).
const DETAIL_WIDTH := 1040
## Recipe / salvage rows: two lines (the whole name, then level and state) - names are never trimmed.
const RECIPE_ROW_HEIGHT := 48
## UI Usability & Haven Crafting 1.0: the recipe list is its own bounded, scrolling column beside the
## recipe card; the window keeps one outer size on every page and profession (the main frame).
const RECIPE_LIST_WIDTH := 380
const RECIPE_LIST_HEIGHT := 300
const RECIPE_CARD_WIDTH := DETAIL_WIDTH - RECIPE_LIST_WIDTH - UiTheme.GAP * 3
const SEARCH_PLACEHOLDER := "Search recipes..."
const NO_RECIPES := "No recipes found."
## Pixels the recipe list moves per mouse-wheel notch.
const WHEEL_STEP := RECIPE_ROW_HEIGHT

var character: Character
## Workstation the window was opened at (&"" = away from any workstation).
var station_id: StringName = &""
## Interactable that opened the window (closes it when the player walks off).
var site: Node2D
var page: String = "Crafting"
var profession_id: StringName = &"blacksmithing"
var recipe_id: StringName = &""
## Bag item selected on the Salvage page ("" = none).
var salvage_id: String = ""
## Set by GameHud: the confirmation dialog for salvaging.
var hud: GameHud
## Result line of the last action ("" = none).
var last_message: String = ""
var last_ok: bool = true
var tooltip: ItemTooltip
## Recipe search of the shown profession (case-insensitive: recipe, output and material names).
var recipe_filter: String = ""

## The areas (book registers, left outer edge) and the professions of the chosen area (title row).
var _pages: BookTabs
var _tabs: UiTabs
var _recipe_list: VBoxContainer
var _recipe_scroll: ScrollContainer
var _recipe_scroll_value: int = 0
var _detail: VBoxContainer
var _connected: Character
var _auto_focusing: bool = false
var _rebuild_queued: bool = false


func _ready() -> void:
	set_title("Professions")
	set_close_text("Close [P / Esc]")
	_pages = BookTabs.new()
	_pages.name = "AreaTabs"
	for id in PAGES:
		_pages.add_tab(id, id)
	_pages.tab_selected.connect(show_page)
	set_side_tabs(_pages)
	main_window = true   # Main Window Layout Lock 1.0 (the recipe list keeps its own bounded scroll area)
	_tabs = UiTabs.new()
	_tabs.name = "ProfessionTabs"
	_tabs.tab_selected.connect(func(id: String) -> void: select_profession(StringName(id)))
	set_title_tabs(_tabs)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL   # the list column reaches down to the action zone
	_detail.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_detail)
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
	if id != page:
		reset_scroll()
		_reset_recipe_view()
	page = id
	_pages.select(id)
	var list := page_professions(id)
	if not list.any(func(p: ProfessionDefinition) -> bool: return p.id == profession_id):
		profession_id = list[0].id if not list.is_empty() else &""
		recipe_id = &""
	_fill_profession_tabs(list)
	rebuild()


## The professions an area offers: Crafting and Gathering by kind; Salvage only those SalvageService can break
## items down for (its own rule - no list of exceptions here).
func page_professions(id: String) -> Array[ProfessionDefinition]:
	var kind := ProfessionDefinition.Kind.GATHERING if id == "Gathering" else ProfessionDefinition.Kind.CRAFTING
	var result: Array[ProfessionDefinition] = []
	for profession in ProfessionService.professions(character.database, kind):
		if id != "Salvage" or profession.id in SalvageService.SALVAGE_PROFESSIONS:
			result.append(profession)
	return result


## The title-row tabs: the professions of the shown area, full names (level and rank in the tooltip).
func _fill_profession_tabs(list: Array[ProfessionDefinition]) -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for profession in list:
		var level := character.professions.level(profession.id)
		_tabs.add_tab(String(profession.id), profession.display_name,
			"%s  ·  %s, level %d" % [profession.display_name, ProfessionService.rank_name(level), level])
	_tabs.select(String(profession_id))


func select_profession(id: StringName) -> void:
	if id != profession_id:
		recipe_id = &""
		last_message = ""
		reset_scroll()
		_reset_recipe_view()   # the search belongs to one profession
	profession_id = id
	_tabs.select(String(id))
	rebuild()


func select_recipe(id: StringName) -> void:
	recipe_id = id
	rebuild()


## The title-row tab of a profession (null when the shown area does not offer it).
func profession_tab(id: StringName) -> Button:
	return _tabs.tab_button(String(id))


func rebuild() -> void:
	if character == null or not visible:
		return
	tooltip.hide_tooltip()
	var focused := get_viewport().gui_get_focus_owner()
	var keep_focus := String(focused.name) if focused != null and is_ancestor_of(focused) else ""
	if _recipe_scroll != null and is_instance_valid(_recipe_scroll):
		_recipe_scroll_value = _recipe_scroll.scroll_vertical   # a rebuild (select, craft) keeps the list where it was
	_recipe_scroll = null
	_recipe_list = null
	_clear(_detail)
	_clear(footer)
	footer.visible = false
	var definition: ProfessionDefinition = character.database.professions.get(profession_id)
	if definition != null:
		_build_header(definition)
		if definition.is_crafting() and page == "Salvage":
			_build_salvage(definition)
		elif definition.is_crafting():
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


# --- detail -------------------------------------------------------------------------

## Head of the page: the profession, rank and level, XP (bar and numbers) and its short description.
func _build_header(profession: ProfessionDefinition) -> void:
	var level := character.professions.level(profession.id)
	var need := character.professions.xp_to_next(profession.id)
	var head := HBoxContainer.new()
	head.name = "ProfessionHead"
	head.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	var title := UiTheme.heading(profession.display_name)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.tooltip_text = profession.description   # the data text names the workshop too: shown on hover, not again on the page
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(title)
	var rank := UiTheme.styled("%s  ·  Level %d / %d  ·  %s" % [ProfessionService.rank_name(level), level, profession.max_level,
		"XP %d / %d" % [character.professions.xp(profession.id), need] if need > 0 else "Mastered"], &"MenuMetaLabel")
	rank.name = "Rank"
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rank)
	_detail.add_child(head)
	var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, profession.color)
	bar.name = "XpBar"
	bar.max_value = maxi(1, need)
	bar.value = character.professions.xp(profession.id) if need > 0 else 1
	_detail.add_child(bar)


func _build_recipes(profession: ProfessionDefinition) -> void:
	var db := character.database
	if station_id == profession.station_id:
		_add_workshop_stage(profession.station_id)
	var recipes := ProfessionService.recipes_of(db, profession.id)
	if recipe_id == &"" or not db.profession_recipes.has(recipe_id) or (db.profession_recipes[recipe_id] as ProfessionRecipeDefinition).profession_id != profession.id:
		recipe_id = recipes[0].id if not recipes.is_empty() else &""
		for recipe in recipes:
			if character.professions.knows(recipe.id) and recipe.craftable:
				recipe_id = recipe.id
				break
	# the search and the bounded recipe list | the selected recipe's card (same place for every profession)
	var bench := _bench()
	var column := bench.get_node("ListColumn") as VBoxContainer
	var search := LineEdit.new()
	search.name = "RecipeSearch"
	search.placeholder_text = SEARCH_PLACEHOLDER
	search.clear_button_enabled = true
	search.text = recipe_filter
	search.text_changed.connect(_on_recipe_search)
	column.add_child(search)
	_add_list(column, "Recipes")
	_fill_recipe_list(profession)
	var selected: ProfessionRecipeDefinition = db.profession_recipes.get(recipe_id)
	if selected != null:
		bench.add_child(_recipe_card(selected))
		_craft_bar(selected)


## The shared two-column bench of Crafting and Salvage: list column (fixed width) | card (the rest).
func _bench() -> HBoxContainer:
	var bench := HBoxContainer.new()
	bench.name = "RecipeBench"
	bench.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(bench)
	var column := VBoxContainer.new()
	column.name = "ListColumn"
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(RECIPE_LIST_WIDTH, 0)
	column.add_theme_constant_override(&"separation", UiTheme.GAP)
	bench.add_child(column)
	return bench


## The bounded, scrolling list in `column` (its rows go into _recipe_list).
func _add_list(column: VBoxContainer, list_name: String) -> void:
	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.name = "RecipeScroll"
	_recipe_scroll.custom_minimum_size = Vector2(RECIPE_LIST_WIDTH, RECIPE_LIST_HEIGHT)
	_recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL   # at least RECIPE_LIST_HEIGHT, else the room the page leaves
	_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_recipe_scroll.gui_input.connect(_on_recipe_list_input)
	column.add_child(_recipe_scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.name = list_name
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override(&"separation", 2)
	_recipe_scroll.add_child(_recipe_list)


## Recipes of `profession` that match the search, as rows in the bounded list ("No recipes found."
## when none). Only the list is refilled, so typing keeps the focus in the search field. The search
## only narrows what the list shows anyway - nothing hidden is revealed.
func _fill_recipe_list(profession: ProfessionDefinition) -> void:
	if _recipe_list == null:
		return
	_clear(_recipe_list)
	var shown := 0
	for recipe in ProfessionService.recipes_of(character.database, profession.id):
		if not recipe_matches(recipe, recipe_filter):
			continue
		_recipe_list.add_child(_recipe_row(recipe))
		shown += 1
	if shown == 0:
		var none := UiTheme.styled(NO_RECIPES, &"SmallLabel")
		none.name = "NoRecipes"
		_recipe_list.add_child(none)
	_restore_recipe_scroll.call_deferred(_recipe_scroll_value)


## True when `recipe` matches `filter` (case-insensitive): its name, its output or one of its materials.
func recipe_matches(recipe: ProfessionRecipeDefinition, filter: String) -> bool:
	var needle := filter.strip_edges().to_lower()
	if needle == "":
		return true
	var names: PackedStringArray = [recipe.display_name]
	var output := character.database.get_item(recipe.output_item_id)
	if output != null:
		names.append(output.display_name)
	for cost in recipe.inputs:
		var item := character.database.get_item(cost.item_id)
		if item != null:
			names.append(item.display_name)
	for entry in names:
		if entry.to_lower().contains(needle):
			return true
	return false


func _on_recipe_search(text: String) -> void:
	recipe_filter = text
	_recipe_scroll_value = 0
	var definition: ProfessionDefinition = character.database.professions.get(profession_id) if character != null else null
	if definition != null:
		_fill_recipe_list(definition)


## The mouse wheel over the recipe list moves only the list (handled here, so it never also
## scrolls the window body behind it); elsewhere the wheel is untouched.
func _on_recipe_list_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or _recipe_scroll == null:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var direction := -1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		_recipe_scroll.scroll_vertical += direction * WHEEL_STEP * maxi(1, roundi(button.factor))
		_recipe_scroll.accept_event()


func _restore_recipe_scroll(value: int) -> void:
	if _recipe_scroll == null or not is_instance_valid(_recipe_scroll):
		return
	_recipe_scroll.scroll_vertical = value
	var selected := _recipe_list.find_child("Recipe_%s" % recipe_id, false, false) as Control if _recipe_list != null else null
	if selected != null and value == 0:
		_recipe_scroll.ensure_control_visible(selected)   # a fresh list shows the selection


func _reset_recipe_view() -> void:
	recipe_filter = ""
	_recipe_scroll_value = 0


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
	var place := UiTheme.styled(ProfessionService.station_name(character.database, workshop_id), &"MenuMetaLabel")
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(place)
	var stage := RestorationService.stage(character, ruin.id)
	var track := JournalPanel.StageTrack.make(stage)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var next := RestorationService.next_stage(character, ruin)
	if next != &"":
		var verb := "Revitalize" if next == RestorationService.REVITALIZED else "Restore"
		var button := UiTheme.button("%s the workshop" % verb, &"", func() -> void: restoration_requested.emit(ruin_site))
		button.name = "RestoreWorkshop"
		button.tooltip_text = RestorationService.advance_error(character, ruin, next)
		row.add_child(button)
	_detail.add_child(row)


## A list row with two lines: the whole name, then "Lv n" and - when locked - its short state.
func _recipe_row(recipe: ProfessionRecipeDefinition) -> Control:
	var locked := locked_reason(recipe)
	var button := _list_button("Recipe_%s" % recipe.id, recipe.id == recipe_id)
	button.pressed.connect(select_recipe.bind(recipe.id))
	var meta := "Lv %d" % recipe.required_level
	if locked != "":
		meta += "  ·  %s" % locked_tag(recipe)
	_row_content(button, ItemIcon.new().setup(character.database.get_item(recipe.output_item_id), recipe.output_quantity), recipe.display_name,
		UiTheme.TEXT_PRIMARY if locked == "" else UiTheme.TEXT_SECONDARY, meta, UiTheme.TEXT_SECONDARY if locked == "" else UiTheme.WARNING, locked != "")
	# the full name, plus why it is locked
	button.tooltip_text = recipe.display_name if locked == "" else "%s\n%s" % [recipe.display_name, locked]
	return button


func _list_button(button_name: String, pressed: bool) -> Button:
	var button := Button.new()
	button.name = button_name
	button.toggle_mode = true
	button.button_pressed = pressed
	button.theme_type_variation = &"InventorySlot"
	button.custom_minimum_size = Vector2(0, RECIPE_ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Icon, then the name over a meta line. A blocked entry keeps a readable name; only its icon is dimmed.
func _row_content(button: Button, icon: ItemIcon, title: String, title_color: Color, meta: String, meta_color: Color, dimmed: bool) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate.a = 0.55 if dimmed else 1.0
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiTheme.label(title, title_color)
	name_label.name = "RowName"
	name_label.theme_type_variation = &"MenuTextLabel"
	name_label.clip_text = true   # only a name longer than the whole row is trimmed (none in the data)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	var meta_label := UiTheme.styled(meta, &"CaptionLabel")
	meta_label.name = "RowMeta"
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.add_theme_color_override(&"font_color", meta_color)
	texts.add_child(meta_label)
	row.add_child(texts)
	button.add_child(row)


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
	if not character.professions.knows(recipe.id) and recipe.unlock_source != ProfessionRecipeDefinition.UnlockSource.AUTOMATIC:
		return "Not learned"
	return "Level too low"   # automatic recipes come with the level


func _unlock_text(recipe: ProfessionRecipeDefinition) -> String:
	var source := ProfessionRecipeDefinition.source_name(recipe.unlock_source)
	match recipe.unlock_source:
		ProfessionRecipeDefinition.UnlockSource.AUTOMATIC:
			return "Learned automatically at level %d." % recipe.required_level
		ProfessionRecipeDefinition.UnlockSource.RECIPE_ITEM:
			var item := character.database.get_item(recipe.unlock_reference)
			return "Learn it from %s." % (item.display_name if item != null else "a recipe item")
	return "Source: %s." % source


## The chosen recipe: output (item tooltip on hover / focus), its facts and the materials - have / need. The
## workshop and the reason a craft is blocked are the footer's (one place, never repeated here).
func _recipe_card(recipe: ProfessionRecipeDefinition) -> Control:
	var db := character.database
	var card := UiTheme.card(&"CardPanel")
	card.name = "RecipeCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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
	var title := UiTheme.styled(recipe.display_name, &"MenuTitleLabel")
	title.name = "RecipeTitle"
	titles.add_child(title)
	var item := db.get_item(recipe.output_item_id)
	titles.add_child(UiTheme.styled("Makes %d x %s" % [recipe.output_quantity, item.display_name if item else String(recipe.output_item_id)], &"MenuMetaLabel"))
	head.add_child(titles)
	box.add_child(head)
	if recipe.is_processing:   # secondary facts live here, never in the list row
		box.add_child(_compact(UiTheme.stat_row("Type", "Processing (materials for other recipes)")))
	box.add_child(_compact(UiTheme.stat_row("Required level", str(recipe.required_level),
		UiTheme.SUCCESS if character.professions.level(recipe.profession_id) >= recipe.required_level else UiTheme.DANGER)))
	var xp := ProfessionService.craft_xp(character, recipe)
	var first := not character.professions.crafted_before(recipe.id)
	box.add_child(_compact(UiTheme.stat_row("Experience", ("%d XP  (first craft bonus)" if first else "%d XP") % xp, UiTheme.RESONANCE if xp > 0 else UiTheme.TEXT_MUTED)))
	box.add_child(UiTheme.section("Materials"))
	var station := ProfessionService.station_of(db, recipe)
	for cost in recipe.inputs:
		box.add_child(_material_row(cost, station if station == station_id else &""))
	var teach := _teaching_item(recipe)
	if teach != null:
		var learn := UiTheme.button("Learn from %s" % db.get_item(teach.definition_id).display_name, &"", learn_from_bag.bind(teach.instance_id))
		learn.name = "Learn"
		learn.size_flags_horizontal = Control.SIZE_SHRINK_END
		box.add_child(learn)
	return card


## The action zone in the window footer (never scrolled away, same place for every profession): the workshop the
## recipe needs - once, with whether you are there -, the concrete reason Craft is blocked, and Craft.
func _craft_bar(recipe: ProfessionRecipeDefinition) -> void:
	var db := character.database
	var station := ProfessionService.station_of(db, recipe)
	var here := station == station_id
	var locked := locked_reason(recipe)
	var error := ProfessionService.craft_error(character, recipe.id, station_id)
	var where := "Workshop: %s  ·  %s" % [ProfessionService.station_name(db, station), "you are here" if here else "go there to craft"]
	if here and ProfessionService.uses_stash(character, station_id):
		where += "  ·  stash in reach"
	# a lock says how to unlock it; at the workshop the service's reason (materials, bag); elsewhere the workshop
	# line above already is the reason
	var reason := locked if locked != "" else (error if here else "")
	var craft_button := UiTheme.button("Craft", &"PrimaryButton", craft_selected)
	craft_button.name = "Craft"
	craft_button.disabled = error != ""
	craft_button.tooltip_text = error
	_action_zone("CraftBar", where, here or locked != "", reason, craft_button)


## Footer row: requirement line and the blocking reason on the left, the action on the right; the result of the
## last action below. `met`: the requirement line is fulfilled (else it is the warning itself).
func _action_zone(zone_name: String, requirement: String, met: bool, reason: String, action: Button) -> void:
	var bottom := HBoxContainer.new()
	bottom.name = zone_name
	bottom.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	var need := UiTheme.styled(requirement, &"MenuMetaLabel")
	need.name = "Requirement"
	need.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY if met else UiTheme.WARNING)
	texts.add_child(need)
	var hint := UiTheme.wrapped(reason, UiTheme.WARNING, DETAIL_WIDTH - 220)
	hint.name = "CraftHint" if zone_name == "CraftBar" else "SalvageHint"
	hint.theme_type_variation = &"MenuMetaLabel"
	hint.visible = reason != ""
	texts.add_child(hint)
	bottom.add_child(texts)
	action.custom_minimum_size = Vector2(160, 40)
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(action)
	footer.add_child(HSeparator.new())
	footer.add_child(bottom)
	var result := UiTheme.wrapped(last_message, UiTheme.SUCCESS if last_ok else UiTheme.DANGER, DETAIL_WIDTH)
	result.theme_type_variation = &"MenuTextLabel"
	result.name = "Result"
	result.visible = last_message != ""
	footer.add_child(result)
	footer.visible = true


func _material_row(cost: ItemCost, at_station: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "Material_%s" % cost.item_id
	row.add_theme_constant_override(&"separation", UiTheme.GAP)
	row.add_child(_item_chip(cost.item_id, 1, 32))
	var item := character.database.get_item(cost.item_id)
	var name_label := UiTheme.label(item.display_name if item else String(cost.item_id), UiTheme.TEXT_PRIMARY)
	name_label.theme_type_variation = &"MenuTextLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var in_bag := character.inventory.count(cost.item_id)
	var have := ProfessionService.available(character, cost.item_id, at_station)
	var text := "%d / %d" % [have, cost.quantity]
	if have != in_bag:
		text += "  (bag %d, stash %d)" % [in_bag, have - in_bag]
	var amount := UiTheme.label(text, UiTheme.SUCCESS if have >= cost.quantity else UiTheme.DANGER)
	amount.theme_type_variation = &"MenuTextLabel"
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
	var definition := character.database.get_item(item_id)
	var preview := ItemCreation.create(definition, quantity, character.database, 0, "preview") if definition != null \
		else ItemInstance.create(item_id, quantity, "preview")
	tooltip.show_for(character, preview, anchor)   # same creation contract as the crafted item


## Gathering: the resource nodes of the profession - name, yield and XP, the level they need. The yield is said
## once in words (the icon carries no count).
func _build_gathering(profession: ProfessionDefinition) -> void:
	_detail.add_child(UiTheme.styled("Gather in the world: walk up to a resource and press G.", &"MenuMetaLabel"))
	_detail.add_child(UiTheme.section("Resources"))
	var nodes: Array = character.database.resource_nodes.values().filter(func(n: ResourceNodeDefinition) -> bool: return n.profession_id == profession.id)
	nodes.sort_custom(func(a: ResourceNodeDefinition, b: ResourceNodeDefinition) -> bool:
		return a.display_name < b.display_name if a.required_level == b.required_level else a.required_level < b.required_level)
	if nodes.is_empty():
		_detail.add_child(UiTheme.menu_text("No resources of this kind are known yet.", UiTheme.TEXT_MUTED, DETAIL_WIDTH, &"MenuMetaLabel"))
	var level := character.professions.level(profession.id)
	for node: ResourceNodeDefinition in nodes:
		var card := UiTheme.card(&"InsetPanel")
		card.name = "Node_%s" % node.id
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", UiTheme.GAP)
		row.add_child(_item_chip(node.yield_item_id, 1, 40))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override(&"separation", 0)
		texts.add_child(UiTheme.styled(node.display_name, &"MenuTextLabel"))
		var item := character.database.get_item(node.yield_item_id)
		var xp := roundi(node.gather_xp * ProfessionService.xp_share(level, node.required_level))
		var yield_label := UiTheme.styled("%d x %s  ·  %d XP" % [node.yield_quantity, item.display_name if item else String(node.yield_item_id), xp], &"MenuMetaLabel")
		yield_label.name = "Yield"
		texts.add_child(yield_label)
		row.add_child(texts)
		var ok := level >= node.required_level
		var req := UiTheme.label("Lv %d" % node.required_level, UiTheme.SUCCESS if ok else UiTheme.DANGER)
		req.theme_type_variation = &"MenuTextLabel"
		req.tooltip_text = "Needs %s level %d (you have %d)." % [profession.display_name, node.required_level, level]
		req.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(req)
		(card.get_node("Box") as VBoxContainer).add_child(row)
		_detail.add_child(card)


# --- salvage ----------------------------------------------------------------------

## Salvage page (same bench as Crafting): the bag items this profession's workshop can break down - each with
## what it returns or why it is protected - on the left; the selected item with its exact return and its marks
## (Favourite / Lock) on the right; the Salvage action in the footer (asks for confirmation; the destruction
## cannot be undone). The general rules sit in the "?" help.
func _build_salvage(profession: ProfessionDefinition) -> void:
	var db := character.database
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP)
	var section := UiTheme.section("Items in your bag")
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(section)
	head.add_child(HelpButton.make("Salvaging breaks an item down into part of the raw materials of its recipe.\nAffixes, quality, essences, sockets and other upgrades are lost.\nEquipped, preset, favourite and locked items are protected.\nSalvage at the workshop of the item's recipe; no profession XP.", "SalvageHelp"))
	_detail.add_child(head)
	var candidates: Array[ItemInstance] = []
	for item in character.inventory.items():
		if SalvageService.station_for(db, item.definition_id) == profession.station_id:
			candidates.append(item)
	var bench := _bench()
	var column := bench.get_node("ListColumn") as VBoxContainer
	if candidates.is_empty():
		var none := UiTheme.menu_text("Nothing in your bag can be salvaged at %s." % ProfessionService.station_name(db, profession.station_id),
			UiTheme.TEXT_SECONDARY, RECIPE_LIST_WIDTH, &"MenuMetaLabel")
		none.name = "NoSalvage"
		column.add_child(none)
		salvage_id = ""
		return
	if candidates.all(func(i: ItemInstance) -> bool: return i.instance_id != salvage_id):
		salvage_id = candidates[0].instance_id
	_add_list(column, "SalvageItems")
	for item in candidates:
		_recipe_list.add_child(_salvage_row(item))
	var selected := character.inventory.find(salvage_id)
	if selected != null:
		bench.add_child(_salvage_card(selected))
		_salvage_bar(profession, selected)


func _salvage_row(item: ItemInstance) -> Control:
	var definition := character.database.get_item(item.definition_id)
	var button := _list_button("Salvage_%s" % item.instance_id, item.instance_id == salvage_id)
	button.pressed.connect(select_salvage.bind(item.instance_id))
	var block := ItemProtection.destroy_block(character, item.instance_id)
	var icon := ItemIcon.new().setup(definition, item.quantity)
	icon.favorite = item.favorite
	icon.locked = item.locked
	_row_content(button, icon, definition.display_name, UiTheme.rarity_color(definition.rarity) if block == "" else UiTheme.TEXT_SECONDARY,
		_short_block(item, block) if block != "" else _yield_text(SalvageService.outputs(character, item)),
		UiTheme.WARNING if block != "" else UiTheme.TEXT_SECONDARY, block != "")
	button.tooltip_text = block
	return button


func _short_block(item: ItemInstance, block: String) -> String:
	if item.locked:
		return "Locked"
	if item.favorite:
		return "Favourite"
	if character.equipment.is_referenced(item.instance_id):
		return "Equipped"
	if PresetService.references_item(character, item.instance_id):
		return "In a preset"
	return "Protected" if block != "" else ""


func _yield_text(gained: Array[Dictionary]) -> String:
	var parts: PackedStringArray = []
	for entry: Dictionary in gained:
		var definition := character.database.get_item(entry.item_id)
		parts.append("%d x %s" % [entry.quantity, definition.display_name if definition else String(entry.item_id)])
	return ", ".join(parts) if not parts.is_empty() else "nothing"


func _salvage_card(item: ItemInstance) -> Control:
	var definition := character.database.get_item(item.definition_id)
	var card := UiTheme.card(&"CardPanel")
	card.name = "SalvageCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := card.get_node("Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", 6)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP)
	var chip := Button.new()
	chip.name = "SalvageItem"
	chip.theme_type_variation = &"InventorySlot"
	chip.custom_minimum_size = Vector2(48, 48)
	var icon := ItemIcon.new().setup(definition, item.quantity)
	icon.favorite = item.favorite
	icon.locked = item.locked
	icon.custom_minimum_size = Vector2.ZERO
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	chip.add_child(icon)
	chip.mouse_entered.connect(_show_instance.bind(chip, item.instance_id))
	chip.focus_entered.connect(_show_instance.bind(chip, item.instance_id))
	chip.mouse_exited.connect(tooltip.hide_tooltip)
	chip.focus_exited.connect(tooltip.hide_tooltip)
	head.add_child(chip)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UiTheme.styled(definition.display_name, &"MenuTitleLabel"))
	titles.add_child(UiTheme.styled("%s  ·  Origin: %s" % [UiTheme.rarity_name(definition.rarity), ItemProtection.origin_name(item.origin)], &"MenuMetaLabel"))
	head.add_child(titles)
	box.add_child(head)
	box.add_child(UiTheme.section("You receive"))
	var gained := SalvageService.outputs(character, item)
	for entry: Dictionary in gained:
		var material := character.database.get_item(entry.item_id)
		var row := _compact(UiTheme.stat_row(material.display_name if material else String(entry.item_id), "%d" % entry.quantity, UiTheme.SUCCESS))
		row.name = "Gain_%s" % entry.item_id
		box.add_child(row)
	if gained.is_empty():
		box.add_child(UiTheme.styled("Nothing could be recovered.", &"MenuMetaLabel"))
	if SalvageService.has_investments(item):
		box.add_child(UiTheme.menu_text("Its upgrades (affixes, quality, essences, sockets) are lost.", UiTheme.WARNING, RECIPE_CARD_WIDTH - 30))
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override(&"separation", UiTheme.GAP)
	var favorite := UiTheme.button("Unfavourite" if item.favorite else "Favourite", &"", _toggle_mark.bind(item.instance_id, &"favorite"))
	favorite.name = "MarkFavorite"
	marks.add_child(favorite)
	var lock := UiTheme.button("Unlock" if item.locked else "Lock", &"", _toggle_mark.bind(item.instance_id, &"locked"))
	lock.name = "MarkLocked"
	marks.add_child(lock)
	box.add_child(marks)
	return card


## Salvage's action zone (same place as Craft): the workshop, the concrete reason, Salvage.
func _salvage_bar(profession: ProfessionDefinition, item: ItemInstance) -> void:
	var here := station_id == profession.station_id
	var error := SalvageService.salvage_error(character, item.instance_id, station_id)
	var action := UiTheme.button("Salvage", &"DangerButton", request_salvage)
	action.name = "Salvage"
	action.disabled = error != ""
	action.tooltip_text = error
	# at the workshop the service's reason; elsewhere the workshop line is the reason, plus a protection if any
	var reason := error if here else ItemProtection.destroy_block(character, item.instance_id)
	_action_zone("SalvageBar", "Workshop: %s  ·  %s" % [ProfessionService.station_name(character.database, profession.station_id),
		"you are here" if here else "go there to salvage"], here, reason, action)


func _show_instance(anchor: Control, instance_id: String) -> void:
	var item := character.inventory.find(instance_id)
	if _auto_focusing or item == null or not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	tooltip.show_for(character, item, anchor)


func select_salvage(instance_id: String) -> void:
	salvage_id = instance_id
	rebuild()


func _toggle_mark(instance_id: String, field: StringName) -> void:
	var item := character.inventory.find(instance_id)
	if item == null:
		return
	var error := ItemProtection.set_locked(character, instance_id, not item.locked) if field == &"locked" \
		else ItemProtection.set_favorite(character, instance_id, not item.favorite)
	last_ok = error == ""
	last_message = error
	rebuild()


## Salvage button: asks for confirmation (the item is destroyed), then salvages
## exactly the item that was shown. Without a HUD (tests) it salvages at once.
func request_salvage() -> void:
	var item := character.inventory.find(salvage_id)
	if item == null:
		return
	var definition := character.database.get_item(item.definition_id)
	var target := salvage_id
	var message := "%s is destroyed for good. You receive: %s." % [definition.display_name, _yield_text(SalvageService.outputs(character, item))]
	if SalvageService.has_investments(item):
		message += " Its upgrades are lost."
	if hud == null:
		salvage_item(target)
		return
	hud.confirm_dialog.ask("Salvage %s?" % definition.display_name, message, "Salvage", salvage_item.bind(target), true)


## Salvages `instance_id` at the current workstation (UI and tests).
func salvage_item(instance_id: String) -> Dictionary:
	var result := SalvageService.salvage(character, instance_id, station_id)
	last_ok = result.error == ""
	last_message = result.error if not last_ok else "Salvaged: %s." % _yield_text(result.outputs)
	if last_ok and salvage_id == instance_id:
		salvage_id = ""
	rebuild()
	return result


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


## Menu UX Polish 1.0: a stat row in the running-text size of the menu pages (UiTheme.stat_row is 18 px).
static func _compact(row: HBoxContainer) -> HBoxContainer:
	for label: Label in row.find_children("*", "Label", false, false):
		label.theme_type_variation = &"MenuTextLabel"
	return row
