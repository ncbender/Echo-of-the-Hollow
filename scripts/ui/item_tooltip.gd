class_name ItemTooltip
extends HBoxContainer
## Immediate item tooltip ("WoW style") for the inventory: the hovered item in
## full (ItemDescriber, same section order everywhere) and, next to it, the
## currently equipped item(s) of the slots it would use, headed "EQUIPPED".
## Placed beside the hovered cell - right of it, or left when there is no room -
## and always kept inside the visible canvas. Never takes mouse input.
## Lives as a top-level child of its window, so containers and scroll clipping
## do not touch it.

const GAP := 10.0
## Equipped items compared at most (two rings, main + off hand).
const MAX_COMPARE := 2
## Text width of the compact three-column card (small canvases).
const COMPACT_WIDTH := 270.0

var character: Character
var item: ItemInstance
var _anchor: Rect2
var _anchor_control: Control


func _init() -> void:
	top_level = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	visible = false


## Shows `target` next to `anchor` (the hovered cell).
func show_for(target_character: Character, target: ItemInstance, anchor: Control) -> void:
	character = target_character
	item = target
	_anchor_control = anchor
	_anchor = anchor.get_global_rect()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if item == null:
		hide()
		return
	add_child(_card(item, ""))
	for equipped in compared_items():
		add_child(_card(equipped, "EQUIPPED  ·  %s" % EquipSlot.display_name(character.equipment.active_loadout().slot_of(equipped.instance_id))))
	show()
	reset_size()
	_place()
	_place.call_deferred()   # wrapped labels know their height after one layout pass


func hide_tooltip() -> void:
	item = null
	hide()


## Equipped items of the active class in the slots `item` could use (not itself).
func compared_items() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var definition := character.database.get_item(item.definition_id)
	if definition == null or not definition.is_equippable() or character.equipment.is_equipped(item.instance_id):
		return result
	for slot: int in EquipSlot.allowed_slots(definition):
		var equipped := character.equipment.get_item(slot)
		if equipped != null and equipped.instance_id != item.instance_id and not equipped in result and result.size() < MAX_COMPARE:
			result.append(equipped)
	return result


func _card(target: ItemInstance, header: String, compact: bool = false, width: float = UiTheme.TOOLTIP_MAX_WIDTH - 24) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	panel.add_child(box)
	if header != "":
		var caption := UiTheme.styled(header, &"CaptionLabel")
		caption.add_theme_color_override(&"font_color", UiTheme.RESONANCE)
		box.add_child(caption)
	ItemDescriber.build(box, character, target, width, true, compact)
	for node in panel.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Moves a card's lines into `count` columns of similar height - same order,
## read left to right; a section heading always stays with its first line.
func _split_columns(card: PanelContainer, count: int = 2) -> void:
	var box := card.get_child(0) as VBoxContainer
	if box == null or box.get_child_count() < count * 2:
		return
	var separation := float(box.get_theme_constant(&"separation"))
	var total := box.get_combined_minimum_size().y
	var starts: Array[int] = []
	var running := 0.0
	for index in box.get_child_count():
		var target := total * (starts.size() + 1) / count
		if starts.size() < count - 1 and index > 2 and running >= target:
			var start := index - 1 if box.get_child(index - 1) is HBoxContainer else index   # keep headings with their line
			if starts.is_empty() or start > starts[starts.size() - 1]:
				starts.append(start)
		running += (box.get_child(index) as Control).get_combined_minimum_size().y + separation
	if starts.is_empty():
		return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 18)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var children := box.get_children()
	card.remove_child(box)
	columns.add_child(box)
	for part in starts.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override(&"separation", 3)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var end := starts[part + 1] if part + 1 < starts.size() else children.size()
		for child: Node in children.slice(starts[part], end):
			box.remove_child(child)
			column.add_child(child)
		columns.add_child(column)
	card.add_child(columns)




## Beside the cell: right if it fits, else left if it fits, else the wider side;
## if it would still cover the cell, below or above it instead. Always clamped
## to the canvas. The cell rect is read now (windows may still be settling).
func _place() -> void:
	if not visible or not is_inside_tree():
		return
	if _anchor_control != null and is_instance_valid(_anchor_control) and _anchor_control.is_inside_tree():
		_anchor = _anchor_control.get_global_rect()
	reset_size()
	var view := get_viewport_rect().size
	var margin := float(UiTheme.SCREEN_MARGIN) * 0.5
	var want := get_combined_minimum_size()
	# small canvas (high UI scale): drop comparison cards rather than cover the
	# cell; a card taller than the canvas is laid out in two columns
	while (want.x > view.x - margin * 2.0 or want.y > view.y - margin * 2.0) and get_child_count() > 1:
		var last := get_child(get_child_count() - 1)
		remove_child(last)
		last.queue_free()
		reset_size()
		want = get_combined_minimum_size()
	if want.y > view.y - margin * 2.0 and get_child_count() == 1:
		_split_columns(get_child(0) as PanelContainer)
		reset_size()
		want = get_combined_minimum_size()
	if want.y > view.y - margin * 2.0 and get_child_count() == 1:
		# still too tall (200 %): leave out the dimmed lines; the details card has all
		var full := get_child(0)
		remove_child(full)
		full.queue_free()
		add_child(_card(item, "Click the item for all details", true, COMPACT_WIDTH))
		_split_columns(get_child(0) as PanelContainer, 3)
		reset_size()
		want = get_combined_minimum_size()
	size = want
	var room_right := view.x - margin - (_anchor.end.x + GAP)
	var room_left := _anchor.position.x - GAP - margin
	var x := _anchor.end.x + GAP
	if want.x > room_right:
		x = _anchor.position.x - GAP - want.x if want.x <= room_left or room_left > room_right else x
	x = clampf(x, margin, maxf(margin, view.x - margin - want.x))
	var y := clampf(_anchor.position.y, margin, maxf(margin, view.y - margin - want.y))
	var rect := Rect2(Vector2(x, y), want)
	if rect.intersects(_anchor.grow(-2.0)):
		# no room beside it: below the cell, or above it
		var below := _anchor.end.y + GAP
		y = below if below + want.y <= view.y - margin else _anchor.position.y - GAP - want.y
		y = clampf(y, margin, maxf(margin, view.y - margin - want.y))
	global_position = Vector2(x, y).floor()
