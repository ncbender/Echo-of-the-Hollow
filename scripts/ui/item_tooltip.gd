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


func _card(target: ItemInstance, header: String) -> PanelContainer:
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
	ItemDescriber.build(box, character, target, UiTheme.TOOLTIP_MAX_WIDTH - 24)
	for node in panel.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Moves the second half of a card's lines (from the section heading nearest to
## the middle) into a second column - same order, read left then right.
func _split_columns(card: PanelContainer) -> void:
	var box := card.get_child(0) as VBoxContainer
	if box == null or box.get_child_count() < 4:
		return
	var total := box.get_combined_minimum_size().y
	var split := -1
	var running := 0.0
	var best := INF
	for index in box.get_child_count():
		var child := box.get_child(index) as Control
		if child is HBoxContainer and index > 2 and absf(running - total * 0.5) < best:   # a section heading
			best = absf(running - total * 0.5)
			split = index
		running += child.get_combined_minimum_size().y + box.get_theme_constant(&"separation")
	if split < 0:
		return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 18)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var second := VBoxContainer.new()
	second.add_theme_constant_override(&"separation", 3)
	second.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in box.get_children().slice(split):
		box.remove_child(child)
		second.add_child(child)
	card.remove_child(box)
	columns.add_child(box)
	columns.add_child(second)
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
