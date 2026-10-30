class_name InventoryPanel
extends UiWindow
## Inventory & character window (I): paper doll with all 15 equipment slots of
## the ACTIVE class, character overview and detailed stats, the bag with
## category tabs and sorting, gold as a wallet counter. Item descriptions and the
## comparison with the worn gear are the hover tooltip (ItemTooltip).
## Interaction (no action buttons): hover shows the ItemTooltip at once (item +
## equipped comparison), right click equips (CharacterEquipment.quick_slot) or
## unequips, drag & drop picks a specific slot (Ring 2, Off Hand). There is no
## way to destroy items here.
## Only calls public Character / CharacterEquipment methods; holds no item state
## except the selected instance id. Drag & drop between bag and paper doll goes
## through the same equip/unequip calls (an item is never copied).
## Layout (Main Window Layout Lock 1.0): one main window frame, two columns - the left page (paper doll /
## overview / details) and the bag - each scrolling on its own; nothing else moves when a page changes.

const BAG_COLUMNS := 9
const DOLL_WIDTH := 420
const CATEGORIES := ["All", "Equipment", "Materials", "Consumables", "Quest"]
const SORTS := ["Default", "Rarity", "Type", "Name"]
## Left and right column of the paper doll; weapons below.
const DOLL_LEFT := [EquipSlot.Slot.HEAD, EquipSlot.Slot.SHOULDERS, EquipSlot.Slot.BACK, EquipSlot.Slot.CHEST,
	EquipSlot.Slot.WRISTS, EquipSlot.Slot.HANDS, EquipSlot.Slot.BELT]
const DOLL_RIGHT := [EquipSlot.Slot.LEGS, EquipSlot.Slot.FEET, EquipSlot.Slot.RING_1, EquipSlot.Slot.RING_2,
	EquipSlot.Slot.NECK, EquipSlot.Slot.TRINKET]
const DOLL_WEAPONS := [EquipSlot.Slot.MAIN_HAND, EquipSlot.Slot.OFF_HAND]
## Overview stats; the Details page lists every stat.
const CORE_STATS: Array[StringName] = [Stats.MAX_HEALTH, Stats.ARMOR, Stats.PHYSICAL_DAMAGE, Stats.CRIT_CHANCE,
	Stats.ATTACK_SPEED, Stats.POISE_DAMAGE]
## Playtest Corrections 1.0: the base values the Details page always shows (every other stat only when in effect).
const BASE_STATS: Array[StringName] = [Stats.MAX_HEALTH, Stats.ARMOR]
## Menu UX Polish 1.1: the Details page's groups, by what each stat does (a view only - values unchanged).
const DETAIL_GROUPS := [
	["Defense", [Stats.MAX_HEALTH, Stats.ARMOR, Stats.DAMAGE_REDUCTION, Stats.PHYSICAL_RESISTANCE, Stats.MAGIC_RESISTANCE,
		Stats.STATUS_RESISTANCE, Stats.POISE, Stats.BLOCK_EFFICIENCY]],
	["Attack", [Stats.PHYSICAL_DAMAGE, Stats.DAMAGE_DEALT, Stats.ATTACK_SPEED, Stats.ATTACK_RECOVERY_SPEED, Stats.CRIT_CHANCE,
		Stats.CRIT_DAMAGE, Stats.POISE_DAMAGE, Stats.FINISHER_POWER, Stats.KNOCKBACK_POWER, Stats.LIFE_ON_HIT]],
	["Elements and status", [Stats.SHOCK_DAMAGE, Stats.BLEED_CHANCE, Stats.BLEED_DAMAGE, Stats.CHILL_CHANCE]],
	["Skills and resource", [Stats.SKILL_DAMAGE, Stats.COOLDOWN_REDUCTION, Stats.SKILL_RECOVERY_SPEED, Stats.MAX_RESOURCE,
		Stats.RESOURCE_GAIN, Stats.RESOURCE_EFFICIENCY]],
	["Movement", [Stats.MOVE_SPEED]],
]

var character: Character
var category: String = "All"
var sort_mode: String = "Default"
var left_page: String = "Equipment"

var _columns: HBoxContainer
var _left_tabs: UiTabs
var _left_column: VBoxContainer
var _doll_width: float = 0.0
var _left: VBoxContainer
var _bag_title: Label
var _middle: VBoxContainer
var _bag_tabs: UiTabs
var _sort: OptionButton
var _grid: GridContainer
var _status: Label
var _gold: Label
var _selected_id: String = ""
## Immediate hover tooltip (top level, above the window content).
var tooltip: ItemTooltip


func _ready() -> void:
	set_title("Inventory")
	set_close_text("Close [I / Esc]")
	main_window = true   # Main Window Layout Lock 1.0
	_columns = HBoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	body.add_child(_columns)

	var left_column := VBoxContainer.new()
	_left_column = left_column
	left_column.custom_minimum_size = Vector2(DOLL_WIDTH, 0)
	_columns.add_child(left_column)
	_left_tabs = UiTabs.new()
	for page in ["Equipment", "Overview", "Details"]:
		_left_tabs.add_tab(page, page)
	_left_tabs.tab_selected.connect(func(id: String) -> void:
		left_page = id
		reset_scroll()
		rebuild())
	left_column.add_child(_left_tabs)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(_pane("LeftScroll", func(box: VBoxContainer) -> void: _left = box))

	var middle := VBoxContainer.new()
	_middle = middle
	middle.custom_minimum_size = Vector2(BAG_COLUMNS * (ItemCell.SIZE.x + UiTheme.SLOT_GAP) + 26.0, 0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_child(middle)
	var header := HFlowContainer.new()
	_bag_title = UiTheme.styled("", &"SubheadingLabel")
	_bag_title.custom_minimum_size.x = 150
	header.add_child(_bag_title)
	header.add_child(UiTheme.styled("Sort", &"SmallLabel"))
	_sort = OptionButton.new()
	_sort.name = "Sort"
	for mode in SORTS:
		_sort.add_item(mode)
	_sort.item_selected.connect(func(index: int) -> void:
		sort_mode = SORTS[index]
		rebuild())
	header.add_child(_sort)
	_gold = UiTheme.styled("", &"SubheadingLabel")
	_gold.name = "Gold"
	_gold.add_theme_color_override(&"font_color", UiTheme.WARNING)
	_gold.tooltip_text = "Gold - your currency. It takes no bag slot."
	_gold.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(_gold)
	middle.add_child(header)
	_bag_tabs = UiTabs.new()
	for id in CATEGORIES:
		_bag_tabs.add_tab(id, id)
	_bag_tabs.tab_selected.connect(func(id: String) -> void:
		category = id
		reset_scroll()
		rebuild())
	middle.add_child(_bag_tabs)
	var bag_panel := UiTheme.card(&"InsetPanel")
	bag_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid = GridContainer.new()
	_grid.columns = BAG_COLUMNS
	bag_panel.get_node("Box").add_child(_grid)
	middle.add_child(_pane("BagScroll", func(box: VBoxContainer) -> void: box.add_child(bag_panel)))
	# Menu UX Polish 1.0: no visible usage hint - hover shows the ItemTooltip, the controls are unchanged.
	_status = UiTheme.wrapped("", UiTheme.WARNING, BAG_COLUMNS * (ItemCell.SIZE.x + UiTheme.SLOT_GAP))
	_status.name = "Status"
	middle.add_child(_status)
	tooltip = ItemTooltip.new()
	add_child(tooltip)
	visibility_changed.connect(func() -> void: if not visible: tooltip.hide_tooltip())


## A vertical scroll area that fills the rest of its column (its own scrollbar; the window never scrolls).
func _pane(pane_name: String, fill: Callable) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = pane_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	fill.call(box)
	return scroll


func open(target_character: Character) -> void:
	if character != target_character:
		_disconnect()
		character = target_character
		character.inventory.changed.connect(rebuild)
		character.stats_changed.connect(rebuild)
	_status.text = ""
	show()
	rebuild()


func rebuild() -> void:
	if character == null or not is_inside_tree() or not visible:
		return
	if not character.inventory.has(_selected_id):
		_selected_id = ""
	_left_tabs.select(left_page)
	_bag_tabs.select(category)
	_sort.select(SORTS.find(sort_mode))
	_bag_title.text = "Bag  %d / %d" % [character.inventory.used_slots(), character.inventory.capacity]
	_gold.text = "Gold  %s" % gold_text(gold())
	tooltip.hide_tooltip()   # cells are rebuilt; the next hover shows it again
	_hold_left_width()
	_clear(_left)
	match left_page:
		"Overview":
			_build_overview()
		"Details":
			_build_detailed_stats()
		_:
			_build_paper_doll()
	_rebuild_grid()


## The left column is as wide as the widest page (the paper doll), measured once: Equipment,
## Overview and Details then share one width and the window never changes size between them.
func _hold_left_width() -> void:
	if _doll_width <= 0.0:
		_clear(_left)
		_build_paper_doll()
		_doll_width = _left.get_combined_minimum_size().x
	_left_column.custom_minimum_size.x = maxf(DOLL_WIDTH, _doll_width)


# --- paper doll ---------------------------------------------------------------

func _build_paper_doll() -> void:
	var class_def := character.classes.get_active_definition()
	var doll := HBoxContainer.new()
	doll.add_theme_constant_override(&"separation", UiTheme.GAP)
	doll.add_child(_slot_column(DOLL_LEFT, true))
	var figure := PaperDollFigure.new()
	figure.title = class_def.display_name if class_def != null else ""
	figure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll.add_child(figure)
	doll.add_child(_slot_column(DOLL_RIGHT, false))
	_left.add_child(doll)
	var weapons := HBoxContainer.new()
	weapons.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons.add_theme_constant_override(&"separation", UiTheme.GAP * 4)
	for slot: int in DOLL_WEAPONS:
		weapons.add_child(_slot_entry(slot, slot == EquipSlot.Slot.MAIN_HAND))
	_left.add_child(weapons)


func _slot_column(slots: Array, caption_left: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", UiTheme.SLOT_GAP)
	for slot: int in slots:
		column.add_child(_slot_entry(slot, caption_left))
	return column


## One paper-doll slot: cell plus slot name (and the off-hand state).
func _slot_entry(slot: int, caption_left: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Slot_%s" % EquipSlot.key_of(slot)
	row.add_theme_constant_override(&"separation", 6)
	var item := character.equipment.get_item(slot)
	var cell := ItemCell.new().setup(character, item, slot)
	cell.name = "Cell"
	cell.button_pressed = item != null and item.instance_id == _selected_id
	cell.pressed.connect(_select.bind(item.instance_id if item != null else ""))
	cell.drop_handler = _drop_on_slot
	_wire(cell)
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 0)
	info.custom_minimum_size = Vector2(96, 0)
	var name_label := UiTheme.styled(EquipSlot.display_name(slot), &"CaptionLabel")
	var state := UiTheme.styled(_slot_state(slot, item), &"SmallLabel")
	state.clip_text = true
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.custom_minimum_size = Vector2(96, 0)
	info.add_child(name_label)
	info.add_child(state)
	if caption_left:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(info)
		row.add_child(cell)
	else:
		row.add_child(cell)
		row.add_child(info)
	return row


func _slot_state(slot: int, item: ItemInstance) -> String:
	if item != null:
		var definition := character.database.get_item(item.definition_id)
		if slot == EquipSlot.Slot.OFF_HAND and definition.slot_kind == ItemDefinition.SlotKind.ONE_HAND_WEAPON:
			return "Dual wield"
		return ""   # Menu UX Polish 1.0: the item's name lives only in its hover tooltip
	if slot == EquipSlot.Slot.OFF_HAND and _main_hand_is_two_handed():
		return "Two-hander"
	return ""   # an empty slot shows its frame and its name, nothing else


func _main_hand_is_two_handed() -> bool:
	var item := character.equipment.get_item(EquipSlot.Slot.MAIN_HAND)
	return item != null and character.database.get_item(item.definition_id).slot_kind == ItemDefinition.SlotKind.TWO_HAND_WEAPON


# --- character overview / details ------------------------------------------------

func _build_overview() -> void:
	var classes := character.classes
	var class_def := classes.get_active_definition()
	var class_id := classes.active_class_id
	_left.add_child(UiTheme.heading(class_def.display_name if class_def else "-"))
	_left.add_child(UiTheme.styled("Level %d  ·  %d / %d XP%s" % [classes.get_level(class_id), classes.get_xp(class_id),
		classes.xp_to_next(class_id), "  ·  Class trial (temporary)" if classes.in_trial() else ""], &"SmallLabel"))
	_left.add_child(UiTheme.section("Core"))
	var stats := character.get_stats()
	for stat in CORE_STATS:
		_left.add_child(UiTheme.stat_row(Stats.display_name(stat), _format(stats.get(stat, 0.0))))
	var map := get_tree().current_scene as GameMap if is_inside_tree() else null
	var guard := map.player.defense.profile() if map != null and map.player != null and map.player.defense != null else null
	if guard != null:
		_left.add_child(UiTheme.section("Defense (Shift)"))
		_left.add_child(UiTheme.stat_row(guard.display_name, "blocks %d%% damage" % roundi(guard.block_reduction * 100.0)))
	var bonuses := character.active_set_bonuses()
	if not bonuses.is_empty():
		_left.add_child(UiTheme.section("Set bonuses"))
		for bonus in bonuses:
			_left.add_child(UiTheme.wrapped(bonus.description, UiTheme.rarity_color(ItemDefinition.Rarity.SET), DOLL_WIDTH))
	var family_id := character.equipment.main_hand_family()
	if family_id != &"":
		var family: WeaponFamily = character.database.weapons.get(family_id)
		_left.add_child(UiTheme.section("Weapon mastery"))
		_left.add_child(UiTheme.stat_row(family.display_name if family != null else String(family_id), "Level %d" % character.mastery.get_level(family_id)))


## Menu UX Polish 1.1: every stat of Stats.ALL in its group (DETAIL_GROUPS; a stat no group names lands in
## "Other", so nothing is ever left out). Playtest Corrections 1.0: always only what is in effect - a bonus that is 0
## (as shown, to 0.1) is hidden, positive and negative ones stay, the base values (BASE_STATS: Max Health, Armor)
## always stay; a group without a shown value is left out whole (heading and rule). The earlier "Only active
## bonuses" switch kept Physical Damage %, Attack Speed %, Crit Chance % and Poise Damage % at 0 because it spared
## all of CORE_STATS (the Overview list), not only the base values. Rebuilt on every stats_changed (equipment,
## class switch, talents, buffs - the Character's own signal).
func _build_detailed_stats() -> void:
	var stats := character.get_stats()
	var grouped := {}
	for stat in Stats.ALL:
		grouped[stat] = false
	for group: Array in DETAIL_GROUPS:
		_add_stat_group(group[0], group[1].filter(func(stat: StringName) -> bool: return grouped.has(stat)), stats, grouped)
	var rest: Array = Stats.ALL.filter(func(stat: StringName) -> bool: return not grouped[stat])
	_add_stat_group("Other", rest, stats, grouped)


## Details shows `stat`: a base value always, any other only when it is not 0 as displayed.
static func shows_stat(stat: StringName, value: float) -> bool:
	return stat in BASE_STATS or not is_zero_approx(snappedf(value, 0.1))


func _add_stat_group(title: String, members: Array, stats: Dictionary, grouped: Dictionary) -> void:
	var rows: Array[Control] = []
	for stat: StringName in members:
		grouped[stat] = true
		var value: float = stats.get(stat, 0.0)
		if not shows_stat(stat, value):
			continue
		var row := UiTheme.stat_row(Stats.display_name(stat), _format(value), UiTheme.WARNING if value < 0.0 else UiTheme.TEXT_PRIMARY)
		row.name = "Stat_%s" % stat
		rows.append(row)
	if rows.is_empty():
		return
	_left.add_child(UiTheme.section(title))
	for row in rows:
		_left.add_child(row)


# --- bag ------------------------------------------------------------------------

func _rebuild_grid() -> void:
	_clear(_grid)
	var items := visible_items()
	for item in items:
		var cell := ItemCell.new().setup(character, item)
		cell.name = "Item_%s" % item.instance_id
		cell.button_pressed = item.instance_id == _selected_id
		cell.pressed.connect(_select.bind(item.instance_id))
		cell.drop_handler = _drop_on_bag
		_wire(cell)
		_grid.add_child(cell)
	if category == "All":
		for index in maxi(0, character.inventory.capacity - character.inventory.used_slots()):
			var empty := ItemCell.new().setup(character, null)
			empty.disabled = true
			empty.drop_handler = _drop_on_bag
			_grid.add_child(empty)
	elif items.is_empty():
		var none := UiTheme.styled("Nothing here.", &"SmallLabel")
		_grid.add_child(none)


## Items of the current category tab in the current sort order (presentation only).
func visible_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition == null or definition.is_currency:
			continue   # gold is shown as the wallet counter, not as a bag item
		if character.inventory.in_equipment(item.instance_id):
			continue   # sits in its equipment slot (paper doll), not in the bag
		if category == "All" or ItemDescriber.category_tab(definition) == category:
			result.append(item)
	var db := character.database
	match sort_mode:
		"Rarity":
			result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
				return a.effective_rarity(db.get_item(a.definition_id)) > b.effective_rarity(db.get_item(b.definition_id)))
		"Type":
			result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
				return ItemDescriber.type_name(db.get_item(a.definition_id)) < ItemDescriber.type_name(db.get_item(b.definition_id)))
		"Name":
			result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
				return db.get_item(a.definition_id).display_name < db.get_item(b.definition_id).display_name)
	return result


func select_category(id: String) -> void:
	category = id
	rebuild()


func select_item(instance_id: String) -> void:
	_select(instance_id)


func _select(instance_id: String) -> void:
	_selected_id = instance_id
	_status.text = ""
	rebuild()


# --- actions ------------------------------------------------------------------------

## Cell callbacks: immediate tooltip on hover/focus, quick equip on right click.
func _wire(cell: ItemCell) -> void:
	cell.hovered.connect(_on_cell_hovered)
	cell.right_click_handler = _on_right_click


func _on_cell_hovered(cell: ItemCell) -> void:
	if cell == null or not is_instance_valid(cell) or not cell.is_inside_tree():
		tooltip.hide_tooltip()
		return
	tooltip.show_for(character, cell.item(), cell)


## Right click: an equipped item (paper doll) is unequipped back into the bag -
## refused with a message while the bag has no free slot (it stays equipped).
## Other equippable items go to CharacterEquipment.quick_slot (a swap reuses the slot).
func _on_right_click(cell: ItemCell) -> void:
	var item := cell.item()
	if item == null:
		return
	var definition := character.database.get_item(item.definition_id)
	var slot := cell.equip_slot if cell.equip_slot >= 0 else character.equipment.active_loadout().slot_of(item.instance_id)
	_selected_id = item.instance_id
	if slot >= 0:
		_report(character.equipment.unequip(slot), "Unequipped %s." % definition.display_name)
		return
	if definition.potion_effect != null:   # special potions go on the potion slot (key 2)
		_report(ConsumableService.assign_potion(character, definition.id), "%s is on the potion slot [2]." % definition.display_name)
		return
	if not definition.is_equippable():
		_report("%s cannot be equipped." % definition.display_name, "")
		return
	var target := character.equipment.quick_slot(item)
	if target < 0:
		_report(character.equipment.can_equip(item.instance_id, EquipSlot.allowed_slots(definition)[0]), "")
		return
	_equip(item, target)


func gold() -> int:
	var total := 0
	for item in character.inventory.items():
		var definition := character.database.get_item(item.definition_id)
		if definition != null and definition.is_currency:
			total += item.quantity
	return total


## 12345 -> "12,345".
static func gold_text(amount: int) -> String:
	var digits := str(absi(amount))
	var groups: PackedStringArray = []
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.insert(0, digits)
	return ("-" if amount < 0 else "") + ",".join(groups)


func _equip(item: ItemInstance, slot: int) -> void:
	var error := character.equipment.equip(item.instance_id, slot)
	var displaced: PackedStringArray = []
	for instance_id in character.equipment.last_displaced:
		var other := character.inventory.find(instance_id)
		if other != null:
			displaced.append(character.database.get_item(other.definition_id).display_name)
	var text := "Equipped %s (%s)." % [character.database.get_item(item.definition_id).display_name, EquipSlot.display_name(character.equipment.active_loadout().slot_of(item.instance_id))]
	if not displaced.is_empty():
		text += " Moved back to the bag: %s." % ", ".join(displaced)
	_report(error, text)


func _drop_on_slot(cell: ItemCell, data: Dictionary) -> void:
	var instance_id := str(data.instance_id)
	if int(data.get("from_slot", -1)) == cell.equip_slot:
		return
	var item := character.inventory.find(instance_id)
	if item != null:
		_selected_id = instance_id
		_equip(item, cell.equip_slot)


func _drop_on_bag(_cell: ItemCell, data: Dictionary) -> void:
	var from_slot := int(data.get("from_slot", -1))
	if from_slot >= 0:
		_report(character.equipment.unequip(from_slot), "Unequipped.")


func _report(error: String, success_text: String) -> void:
	_status.text = error if error != "" else success_text
	_status.add_theme_color_override(&"font_color", UiTheme.DANGER if error != "" else UiTheme.SUCCESS)
	rebuild()


func _format(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _disconnect() -> void:
	if character == null:
		return
	if character.inventory.changed.is_connected(rebuild):
		character.inventory.changed.disconnect(rebuild)
	if character.stats_changed.is_connected(rebuild):
		character.stats_changed.disconnect(rebuild)


func _exit_tree() -> void:
	_disconnect()


## Provisional character silhouette between the slot columns (no art yet).
class PaperDollFigure:
	extends Control

	var title: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(110, 360)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var line := Color(UiTheme.BRONZE_DARK, 0.9)
		var fill := Color(UiTheme.PANEL_ELEVATED, 0.7)
		draw_circle(c + Vector2(0, -120), 18, fill)
		draw_arc(c + Vector2(0, -120), 18, 0, TAU, 24, line, 2.0)
		var torso := PackedVector2Array([c + Vector2(-30, -96), c + Vector2(30, -96), c + Vector2(24, 10), c + Vector2(-24, 10)])
		draw_colored_polygon(torso, fill)
		draw_polyline(torso + PackedVector2Array([torso[0]]), line, 2.0)
		for side in [-1.0, 1.0]:
			draw_line(c + Vector2(30 * side, -92), c + Vector2(44 * side, -10), line, 6.0)
			draw_line(c + Vector2(12 * side, 12), c + Vector2(16 * side, 120), line, 8.0)
		if title != "":
			var width := UiTheme.body_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL).x
			draw_string(UiTheme.body_font(), Vector2(c.x - width * 0.5, size.y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.BRONZE)
