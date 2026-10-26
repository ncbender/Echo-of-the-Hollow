class_name InventoryPanel
extends UiWindow
## Inventory & character window (I): paper doll with all 15 equipment slots of
## the ACTIVE class, character overview and detailed stats, the bag with
## category tabs and sorting, and the selected item's description (same order
## as every tooltip), comparison and actions.
## Only calls public Character / CharacterEquipment methods; holds no item state
## except the selected instance id. Drag & drop between bag and paper doll goes
## through the same equip/unequip calls (an item is never copied).
## Layout: three columns in a flow container - side by side when the canvas is
## wide enough, stacked (vertical scrolling) at high UI scales / small windows.

const BAG_COLUMNS := 8
const DETAILS_WIDTH := 360
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

var character: Character
var category: String = "All"
var sort_mode: String = "Default"
var left_page: String = "Equipment"

var _columns: HFlowContainer
var _left_tabs: UiTabs
var _left: VBoxContainer
var _bag_title: Label
var _middle: VBoxContainer
var _bag_hint: Label
var _bag_tabs: UiTabs
var _sort: OptionButton
var _grid: GridContainer
var _details: VBoxContainer
var _actions: HFlowContainer
var _status: Label
var _selected_id: String = ""


func _ready() -> void:
	set_title("Inventory")
	set_close_text("Close [I / Esc]")
	_columns = HFlowContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override(&"h_separation", UiTheme.GAP * 3)
	body.add_child(_columns)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(DOLL_WIDTH, 0)
	_columns.add_child(left_column)
	_left_tabs = UiTabs.new()
	for page in ["Equipment", "Overview", "Details"]:
		_left_tabs.add_tab(page, page)
	_left_tabs.tab_selected.connect(func(id: String) -> void:
		left_page = id
		rebuild())
	left_column.add_child(_left_tabs)
	_left = VBoxContainer.new()
	left_column.add_child(_left)

	var middle := VBoxContainer.new()
	_middle = middle
	middle.custom_minimum_size = Vector2(BAG_COLUMNS * (ItemCell.SIZE.x + UiTheme.SLOT_GAP), 0)
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
	middle.add_child(header)
	_bag_tabs = UiTabs.new()
	for id in CATEGORIES:
		_bag_tabs.add_tab(id, id)
	_bag_tabs.tab_selected.connect(func(id: String) -> void:
		category = id
		rebuild())
	middle.add_child(_bag_tabs)
	var bag_panel := UiTheme.card(&"InsetPanel")
	bag_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid = GridContainer.new()
	_grid.columns = BAG_COLUMNS
	bag_panel.get_node("Box").add_child(_grid)
	middle.add_child(bag_panel)
	var hint := UiTheme.styled("Drag items onto the equipment slots, or select one and use the actions.", &"CaptionLabel")
	_bag_hint = hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(BAG_COLUMNS * (ItemCell.SIZE.x + UiTheme.SLOT_GAP), 0)
	middle.add_child(hint)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(DETAILS_WIDTH, 0)
	_columns.add_child(right)
	var details_card := UiTheme.card(&"CardPanel")
	_details = details_card.get_node("Box") as VBoxContainer
	_details.add_theme_constant_override(&"separation", 4)
	right.add_child(details_card)
	_actions = HFlowContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override(&"h_separation", UiTheme.GAP)
	right.add_child(_actions)
	_status = UiTheme.wrapped("", UiTheme.WARNING, DETAILS_WIDTH)
	right.add_child(_status)


## All three columns side by side; the flow container stacks them when narrower.
func preferred_body_size() -> Vector2:
	var width := 0.0
	for column: Control in _columns.get_children():
		width += column.get_combined_minimum_size().x
	width += _columns.get_theme_constant(&"h_separation") * maxi(0, _columns.get_child_count() - 1)
	return Vector2(width, body.get_combined_minimum_size().y)


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
	_fit_bag_columns()
	_clear(_left)
	match left_page:
		"Overview":
			_build_overview()
		"Details":
			_build_detailed_stats()
		_:
			_build_paper_doll()
	_rebuild_grid()
	_show_details()


## Fewer bag columns on narrow canvases (high UI scale), so paper doll, bag and
## details stay side by side as long as possible.
func _fit_bag_columns() -> void:
	var available := get_viewport_rect().size.x - 2.0 * UiTheme.SCREEN_MARGIN - _chrome_size().x - 24.0
	var gaps := _columns.get_theme_constant(&"h_separation") * 2.0
	var cell := ItemCell.SIZE.x + UiTheme.SLOT_GAP
	var columns := BAG_COLUMNS
	while columns > 5 and DOLL_WIDTH + DETAILS_WIDTH + gaps + columns * cell + 30.0 > available:
		columns -= 1
	_grid.columns = columns
	_middle.custom_minimum_size.x = columns * cell + 26.0
	_bag_hint.custom_minimum_size.x = columns * cell


# --- paper doll ---------------------------------------------------------------

func _build_paper_doll() -> void:
	var class_def := character.classes.get_active_definition()
	var caption := UiTheme.styled("Equipment of %s  (only the active class's gear is in effect)" % (class_def.display_name if class_def else "-"), &"CaptionLabel")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(DOLL_WIDTH, 0)
	_left.add_child(caption)
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
	var info := VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 0)
	info.custom_minimum_size = Vector2(96, 0)
	var name_label := UiTheme.styled(EquipSlot.display_name(slot), &"CaptionLabel")
	var state := UiTheme.styled(_slot_state(slot, item), &"SmallLabel")
	state.clip_text = true
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.custom_minimum_size = Vector2(96, 0)
	if item != null:
		state.add_theme_color_override(&"font_color", UiTheme.rarity_color(character.database.get_item(item.definition_id).rarity))
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
		return definition.display_name
	if slot == EquipSlot.Slot.OFF_HAND and _main_hand_is_two_handed():
		return "Two-hander"
	return "Empty"


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


func _build_detailed_stats() -> void:
	_left.add_child(UiTheme.styled("Every stat of the active class, resolved from base, class, gear, sets and talents.", &"CaptionLabel"))
	var stats := character.get_stats()
	for stat in Stats.ALL:
		var value: float = stats.get(stat, 0.0)
		_left.add_child(UiTheme.stat_row(Stats.display_name(stat), _format(value), UiTheme.TEXT_PRIMARY if value != 0.0 else UiTheme.TEXT_MUTED))


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
		if definition != null and (category == "All" or ItemDescriber.category_tab(definition) == category):
			result.append(item)
	var db := character.database
	match sort_mode:
		"Rarity":
			result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
				return db.get_item(a.definition_id).rarity > db.get_item(b.definition_id).rarity)
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


# --- details & actions --------------------------------------------------------------

func _show_details() -> void:
	_clear(_details)
	_clear(_actions)
	var item := character.inventory.find(_selected_id)
	if item == null:
		_details.add_child(UiTheme.heading("No item selected"))
		_details.add_child(UiTheme.wrapped("Select an item in the bag or on the paper doll to see its details and compare it with your gear.",
			UiTheme.TEXT_SECONDARY, DETAILS_WIDTH - 30))
		return
	ItemDescriber.build(_details, character, item, DETAILS_WIDTH - 30)
	_add_actions(item, character.database.get_item(item.definition_id))


func _add_actions(item: ItemInstance, definition: ItemDefinition) -> void:
	var equipment := character.equipment
	if definition.is_equippable():
		var current_slot := equipment.active_loadout().slot_of(item.instance_id)
		if current_slot >= 0:
			_add_action("Unequip", &"PrimaryButton", func() -> void: _report(equipment.unequip(current_slot), "Unequipped."))
		else:
			_add_action("Equip", &"PrimaryButton", func() -> void: _equip(item, -1))
		if definition.slot_kind == ItemDefinition.SlotKind.ONE_HAND_WEAPON and current_slot != EquipSlot.Slot.OFF_HAND:
			_add_action("Equip Off-hand", &"", func() -> void: _equip(item, EquipSlot.Slot.OFF_HAND))
		if definition.slot_kind == ItemDefinition.SlotKind.RING:
			for ring: int in [EquipSlot.Slot.RING_1, EquipSlot.Slot.RING_2]:
				if ring != current_slot:
					_add_action("Equip %s" % EquipSlot.display_name(ring), &"", func() -> void: _equip(item, ring))
	_add_action("Discard", &"DangerButton", func() -> void: _ask_discard(item, definition))


func _ask_discard(item: ItemInstance, definition: ItemDefinition) -> void:
	var dialog := _confirm_dialog()
	var action := func() -> void:
		_report("" if character.discard_item(item.instance_id) else "Cannot discard this item.", "Discarded %s." % definition.display_name)
	if dialog == null:
		action.call()
		return
	var amount := " (x%d)" % item.quantity if item.quantity > 1 else ""
	dialog.ask("Discard item?", "%s%s will be destroyed for good. This cannot be undone." % [definition.display_name, amount], "Discard", action, true)


func _confirm_dialog() -> UiConfirmDialog:
	var hud := get_parent()
	while hud != null and not hud is GameHud:
		hud = hud.get_parent()
	return (hud as GameHud).confirm_dialog if hud != null else null


func _equip(item: ItemInstance, slot: int) -> void:
	var error := character.equipment.equip(item.instance_id, slot)
	var displaced: PackedStringArray = []
	for instance_id in character.equipment.last_displaced:
		var other := character.inventory.find(instance_id)
		if other != null:
			displaced.append(character.database.get_item(other.definition_id).display_name)
	var text := "Equipped."
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


func _add_action(text: String, variation: StringName, callback: Callable) -> void:
	var button := UiTheme.button(text, variation, callback)
	button.name = text.replace(" ", "").replace("-", "")
	_actions.add_child(button)


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
			var width := ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL).x
			draw_string(ThemeDB.fallback_font, Vector2(c.x - width * 0.5, size.y - 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.BRONZE)
