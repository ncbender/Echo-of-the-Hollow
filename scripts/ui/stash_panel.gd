class_name StashPanel
extends UiWindow
## The Haven stash at the Old Storehouse (docs/STASH.md): your bag and the stash
## side by side. The stash shows one of its three category views at a time
## (Equipment Chest, Material Vault, Collection Vault) with its capacity.
## Right click: store (bag) / take (stash). Drag & drop between the two grids.
## "Deposit All Materials" and "Sort". Hover: the immediate ItemTooltip with
## the equipment comparison. Equipped items stay with you; nothing can be
## destroyed here. All rules and transfers: StashService (atomic).
## Usable while the storehouse is still a ruin; restoring it grows the chest.

const BAG_COLUMNS := 7
const STASH_COLUMNS := 9
## Column counts (bag, stash) tried from wide to narrow until both fit side by side.
const COLUMN_STEPS: Array[Vector2i] = [Vector2i(7, 9), Vector2i(6, 8), Vector2i(5, 7), Vector2i(4, 6), Vector2i(4, 5), Vector2i(3, 4)]
const MIN_ROWS := 4
## Smallest visible height of one grid (at least one row of cells).
const MIN_ZONE_HEIGHT := 72.0

var character: Character
var site: RuinSite
var hud: GameHud
var category: StringName = StashService.EQUIPMENT

var _columns: BoxContainer
var _zone_scrolls: Array[ScrollContainer] = []
var _state: Label
var _restore: Button
var _bag_title: Label
var _gold: Label
var _bag_grid: GridContainer
var _tabs: UiTabs
var _capacity: Label
var _stash_grid: GridContainer
var _status: Label
## Immediate hover tooltip (top level, above the window content).
var tooltip: ItemTooltip
## True while the window gives its automatic first focus (no tooltip for that).
var _auto_focusing: bool = false


func _ready() -> void:
	set_title("Haven Stash")
	set_close_text("Close [G / Esc]")
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	_state = UiTheme.styled("", &"SmallLabel")
	_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_state)
	_restore = UiTheme.button("Restore the Storehouse", &"", _open_restoration)
	_restore.name = "RestoreStorehouse"
	head.add_child(_restore)
	body.add_child(head)
	var columns := BoxContainer.new()   # side by side; stacked on narrow canvases (_arrange)
	_columns = columns
	columns.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	body.add_child(columns)

	# left: the bag
	var bag := VBoxContainer.new()
	columns.add_child(bag)
	var bag_head := HBoxContainer.new()
	_bag_title = UiTheme.styled("", &"SubheadingLabel")
	_bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_head.add_child(_bag_title)
	_gold = UiTheme.styled("", &"SubheadingLabel")
	_gold.name = "Gold"
	_gold.add_theme_color_override(&"font_color", UiTheme.WARNING)
	bag_head.add_child(_gold)
	bag.add_child(bag_head)
	_bag_grid = GridContainer.new()
	_bag_grid.name = "BagGrid"
	_bag_grid.columns = BAG_COLUMNS
	bag.add_child(_drop_zone("BagZone", _bag_grid, _drop_on_bag))

	# right: the stash with its three category views
	var stash := VBoxContainer.new()
	columns.add_child(stash)
	_tabs = UiTabs.new()
	for id in StashService.CATEGORIES:
		_tabs.add_tab(String(id), StashService.display_name(id))
	_tabs.tab_selected.connect(func(id: String) -> void: select_category(StringName(id)))
	stash.add_child(_tabs)
	var stash_head := HBoxContainer.new()
	_capacity = UiTheme.styled("", &"SmallLabel")
	_capacity.name = "Capacity"
	_capacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capacity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stash_head.add_child(_capacity)
	var deposit_all := UiTheme.button("Deposit All Materials", &"PrimaryButton", deposit_all_materials)
	deposit_all.name = "DepositAll"
	deposit_all.tooltip_text = "Store every crafting material from your bag in the Material Vault."
	stash_head.add_child(deposit_all)
	var sort := UiTheme.button("Sort", &"", sort_stash)
	sort.name = "Sort"
	sort.tooltip_text = "Sort the stash by category, rarity and name."
	stash_head.add_child(sort)
	stash.add_child(stash_head)
	_stash_grid = GridContainer.new()
	_stash_grid.name = "StashGrid"
	_stash_grid.columns = STASH_COLUMNS
	stash.add_child(_drop_zone("StashZone", _stash_grid, _drop_on_stash))

	var hint := UiTheme.styled("Right-click: store / take  ·  Drag between bag and stash  ·  Equipped items and gold stay with you", &"CaptionLabel")
	hint.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	body.add_child(hint)
	_status = UiTheme.styled("", &"SmallLabel")
	_status.name = "Status"
	body.add_child(_status)
	tooltip = ItemTooltip.new()
	add_child(tooltip)
	visibility_changed.connect(func() -> void: if not visible: tooltip.hide_tooltip())


func open(target_character: Character, target_site: RuinSite) -> void:
	if character != target_character:
		_disconnect()
		character = target_character
		character.inventory.changed.connect(rebuild)
		character.stash.changed.connect(rebuild)
	site = target_site
	_status.text = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and site != null and (not is_instance_valid(site) or not site.player_inside):
		hide()


func select_category(id: StringName) -> void:
	category = id
	rebuild()


func rebuild() -> void:
	if character == null or not is_inside_tree() or not visible:
		return
	tooltip.hide_tooltip()   # cells are rebuilt; the next hover shows it again
	var upgraded := StashService.is_upgraded(character)
	var ruin := site.ruin() if site != null and is_instance_valid(site) else null
	var ruin_name := ruin.display_name if ruin != null else "The Old Storehouse"
	_state.text = "%s  ·  %s" % [ruin_name, "Restored - a larger chest and vault" if upgraded else "Ruined - a basic chest; restoring it adds room"]
	_restore.visible = not upgraded and ruin != null and ruin.restorable and site != null
	_bag_title.text = "Your Bag  %d / %d" % [character.inventory.used_slots(), character.inventory.capacity]
	_gold.text = "Gold  %s" % InventoryPanel.gold_text(_gold_amount())
	_tabs.select(String(category))
	var limit := StashService.capacity(character, category)
	var used := StashService.used(character, category)
	_capacity.text = "%s  %d / %d" % [StashService.display_name(category), used, limit] if limit >= 0 \
		else "%s  ·  %d stacks  ·  no slot limit" % [StashService.display_name(category), used]
	_capacity.add_theme_color_override(&"font_color", UiTheme.WARNING if limit >= 0 and used >= limit else UiTheme.TEXT_SECONDARY)
	var stash_free := maxi(0, limit - used) if limit >= 0 else _stash_grid.columns
	_fill(_bag_grid, _bag_items(), null, _bag_grid.columns, character.inventory.free_slots())
	_fill(_stash_grid, StashService.items(character, category), character.stash, _stash_grid.columns, stash_free)
	if _arrange():   # after filling: the decision needs the real grid sizes
		_fill(_bag_grid, _bag_items(), null, _bag_grid.columns, character.inventory.free_slots())
		_fill(_stash_grid, StashService.items(character, category), character.stash, _stash_grid.columns, stash_free)


func _gold_amount() -> int:
	var total := 0
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition != null and definition.is_currency:
			total += item.quantity
	return total


## Bag items as shown (gold is the counter above).
func _bag_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition != null and not definition.is_currency:
			result.append(item)
	return result


## Cells for `items` plus empty cells (free room, at least MIN_ROWS rows) as drop targets.
func _fill(grid: GridContainer, items: Array[ItemInstance], container: Inventory, columns: int, free: int) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var from_stash := container != null
	for item in items:
		var cell := ItemCell.new()
		cell.container = container
		cell.setup(character, item)
		cell.name = ("Stash_%s" if from_stash else "Bag_%s") % item.instance_id
		cell.toggle_mode = false
		cell.drop_handler = _drop_on_stash if from_stash else _drop_on_bag
		cell.right_click_handler = _take if from_stash else _store
		cell.hovered.connect(_on_cell_hovered)
		grid.add_child(cell)
	# fill the last row, and at least MIN_ROWS rows - never more empty cells than free room
	var to_row_end := (columns - items.size() % columns) % columns
	var empties := clampi(maxi(columns * MIN_ROWS - items.size(), to_row_end), 0, free)
	for i in empties:
		var empty := ItemCell.new().setup(character, null)
		empty.disabled = true
		empty.drop_handler = _drop_on_stash if from_stash else _drop_on_bag
		grid.add_child(empty)


func _focus_first() -> void:
	_auto_focusing = true
	super()
	_auto_focusing = false


func _on_cell_hovered(cell: ItemCell) -> void:
	if _auto_focusing:
		return
	if cell == null or not is_instance_valid(cell) or not cell.is_inside_tree() or cell.item() == null:
		tooltip.hide_tooltip()
		return
	tooltip.show_for(character, cell.item(), cell)


# --- actions --------------------------------------------------------------------

func _store(cell: ItemCell) -> void:
	store(cell.instance_id)


func _take(cell: ItemCell) -> void:
	take(cell.instance_id)


## Bag -> stash (right click, drop). Shows the item's category afterwards.
func store(instance_id: String) -> void:
	var item := character.inventory.find(instance_id)
	var definition := character.database.get_item(item.definition_id) if item != null else null
	var error := StashService.deposit(character, instance_id)
	if error == "":
		category = StashService.category_of(definition)
	_report(error, "Stored %s in the %s." % [definition.display_name, StashService.display_name(category)] if definition != null else "")


## Stash -> bag (right click, drop).
func take(instance_id: String) -> void:
	var item := character.stash.find(instance_id)
	var definition := character.database.get_item(item.definition_id) if item != null else null
	_report(StashService.withdraw(character, instance_id), "Took %s." % definition.display_name if definition != null else "")


func deposit_all_materials() -> void:
	var result := StashService.deposit_all_materials(character)
	var refused: PackedStringArray = result.refused
	if result.moved > 0:
		category = StashService.MATERIALS
	var text := "Stored %d material stack%s." % [result.moved, "" if result.moved == 1 else "s"] if result.moved > 0 else "No materials to store."
	_report(refused[0] if result.moved == 0 and not refused.is_empty() else "", text + ("  (%s)" % refused[0] if result.moved > 0 and not refused.is_empty() else ""))


func sort_stash() -> void:
	StashService.sort(character)
	_report("", "Stash sorted.")


func _drop_on_stash(_cell: ItemCell, data: Dictionary) -> void:
	if not data.get("from_stash", false) and int(data.get("from_slot", -1)) < 0:
		store(str(data.instance_id))


func _drop_on_bag(_cell: ItemCell, data: Dictionary) -> void:
	if data.get("from_stash", false):
		take(str(data.instance_id))


func _report(error: String, success: String) -> void:
	_status.text = error if error != "" else success
	_status.add_theme_color_override(&"font_color", UiTheme.WARNING if error != "" else UiTheme.SUCCESS)
	rebuild()


func _open_restoration() -> void:
	if hud != null and site != null:
		hud.open_restoration(site)


## Grid wrapper that also accepts drops on its empty space.
func _drop_zone(zone_name: String, grid: GridContainer, handler: Callable) -> Control:
	var zone := DropZone.new()
	zone.name = zone_name
	zone.theme_type_variation = &"InsetPanel"
	zone.drop_handler = handler
	var scroll := ScrollContainer.new()   # each grid scrolls on its own (_fit_zones)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_child(grid)
	zone.add_child(scroll)
	_zone_scrolls.append(scroll)
	return zone


func _disconnect() -> void:
	if character == null:
		return
	if character.inventory.changed.is_connected(rebuild):
		character.inventory.changed.disconnect(rebuild)
	if character.stash.changed.is_connected(rebuild):
		character.stash.changed.disconnect(rebuild)


func _exit_tree() -> void:
	_disconnect()


class DropZone:
	extends PanelContainer

	## Callable(cell: ItemCell, data: Dictionary) -> void (cell = null here).
	var drop_handler: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return drop_handler.is_valid() and data is Dictionary and (data as Dictionary).has("instance_id")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		drop_handler.call(null, data)


## Bag and stash side by side; on narrow canvases (high UI scale) with fewer
## columns, stacked only if even the narrowest grids do not fit. Each grid
## scrolls on its own and both are sized to stay in view together - dragging
## between them never needs the window to scroll.
## Returns true if the column counts changed (the grids are filled again).
func _arrange() -> bool:
	for scroll in _zone_scrolls:
		scroll.custom_minimum_size.y = 0
	var before := Vector2i(_bag_grid.columns, _stash_grid.columns)
	_columns.vertical = false
	var fits := false
	# narrower grids before stacking: side by side keeps both in view for dragging
	for counts: Vector2i in COLUMN_STEPS:
		_bag_grid.columns = counts.x
		_stash_grid.columns = counts.y
		if _columns.get_combined_minimum_size().x + _chrome_size().x <= max_window_size().x:
			fits = true
			break
	if not fits:
		_bag_grid.columns = BAG_COLUMNS
		_stash_grid.columns = STASH_COLUMNS
		_columns.vertical = true
	_fit_zones.call_deferred()
	return before != Vector2i(_bag_grid.columns, _stash_grid.columns)


func _fit_zones() -> void:
	if not visible or not is_inside_tree():
		return
	# the grid scrolls are 0 high here (_arrange), so the body is everything else
	var room := max_window_size().y - _chrome_size().y - body.get_combined_minimum_size().y - 8.0
	var each := room / 2.0 if _columns.vertical else room
	for scroll in _zone_scrolls:
		var grid := scroll.get_child(0) as Control
		scroll.custom_minimum_size.y = minf(grid.get_combined_minimum_size().y, maxf(MIN_ZONE_HEIGHT, each))
	queue_fit()
