class_name TalentTreeView
extends Control
## The ONE shown talent tree (Skills & Talents UX 2.0 Phase 2, docs/SKILLS_TALENTS_UX_2_0.md): one row per
## tier, TalentRules.COLUMNS card nodes per row, the capstone alone in the middle of the last row. A node card:
## icon tile on the left (the skill's art for a node that unlocks exactly that skill, else the kind glyph), on
## the right the whole name (wrapped, two lines) and "rank/max state" in words. Lines only for the explicit prerequisites (the six
## direct upgrades) - never for columns or neighbouring tiers. A click (or Enter) only SELECTS a node; learning
## is the detail panel's button (ClassStationPanel). Hover / keyboard focus still ask for the TalentTooltip.
## Works from the tree data alone (node tier / column / prerequisites), for every class.

signal node_selected(node_id: StringName)
## Mouse or keyboard focus entered a node (`node_id`) or left it (&"").
signal node_hovered(node_id: StringName)

var character: Character
var class_id: StringName
var tree: TalentTreeDefinition
var layout: TalentLayout

var _buttons: Dictionary = {}   # node id -> TalentButton
var _columns: Dictionary = {}   # node id -> shown column (float; a lone node sits in the middle)
var _group := ButtonGroup.new()


func setup(target_character: Character, target_class: StringName, target_tree: TalentTreeDefinition) -> void:
	character = target_character
	class_id = target_class
	tree = target_tree
	mouse_filter = Control.MOUSE_FILTER_PASS
	_columns = shown_columns(tree)
	for node in tree.nodes:
		var button := TalentButton.new()
		button.name = String(node.id)
		button.node = node
		button.button_group = _group
		button.pressed.connect(func() -> void: node_selected.emit(node.id))
		button.mouse_entered.connect(func() -> void: node_hovered.emit(node.id))
		button.mouse_exited.connect(func() -> void: node_hovered.emit(&""))
		button.focus_entered.connect(func() -> void: node_hovered.emit(node.id))
		button.focus_exited.connect(func() -> void: node_hovered.emit(&""))
		add_child(button)
		_buttons[node.id] = button
	apply(TalentLayout.new())
	refresh()


## Shown column of every node: the data column, except that a direct upgrade moves under its parent so the
## line runs straight down (it swaps places with the node there); an upgrade two tiers below its parent takes
## the neighbouring column instead, so its line passes between the cards of the tier in between. A lone node
## (the capstone) sits in the middle. Positions only - prerequisites and data stay as they are.
static func shown_columns(target: TalentTreeDefinition) -> Dictionary:
	var result := {}
	var last := TalentRules.COLUMNS - 1
	for node in target.nodes:
		result[node.id] = float(clampi(node.column, 0, last))
	for tier in range(1, TalentRules.TIERS + 1):
		var row := target.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == tier)
		if row.size() == 1:
			result[row[0].id] = last * 0.5
			continue
		for node: TalentNodeDefinition in row:
			for parent_id in node.prerequisites:
				var parent := target.get_node_def(parent_id)
				if parent == null or parent.tier >= node.tier:
					continue
				var want: float = result[parent_id]
				if node.tier - parent.tier > 1:
					want = want - 1.0 if want >= last else want + 1.0
				for other: TalentNodeDefinition in row:
					if other != node and is_equal_approx(result[other.id], want):
						result[other.id] = result[node.id]
				result[node.id] = want
	return result


## Places the node cards for `target` (sizes from the free room).
func apply(target: TalentLayout) -> void:
	layout = target
	custom_minimum_size = Vector2(layout.tree_width(), layout.height())
	size = custom_minimum_size
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		button.apply(layout)
		button.position = Vector2(layout.column_left(_columns[node.id]), layout.row_top(node.tier))
	queue_redraw()


## Top-left corner of a node card in the view.
func card_rect(node_id: StringName) -> Rect2:
	var button: TalentButton = _buttons.get(node_id)
	return Rect2(button.position, button.size) if button != null else Rect2()


func button_for(node_id: StringName) -> Button:
	return _buttons.get(node_id)


## Marks `node_id` as the chosen node (gold card); &"" clears the choice.
func set_selected(node_id: StringName) -> void:
	for id: StringName in _buttons:
		(_buttons[id] as TalentButton).set_pressed_no_signal(id == node_id)


func refresh() -> void:
	var build := character.builds.get_build(class_id)
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		button.rank = build.rank(node.id)
		button.state = node_state(character, class_id, node)
		button.update_texts()
	queue_redraw()


## "Maxed" / "Learned" / "Available" / "Locked" - the node state in words (from TalentService.can_learn alone).
static func state_of(rank: int, max_rank: int, error: String) -> String:
	if rank >= max_rank:
		return "Maxed"
	if rank > 0:
		return "Learned"
	return "Available" if error == "" else "Locked"


## Menu UX Polish 1.1: the node state, where "no free points" is not "Locked": an unlearned node whose
## requirements are met (TalentService.validate_allocation for its next rank) is OPEN while no point is free -
## learnable as soon as a point comes. Locked = a requirement (tier points, prerequisite, class level) is missing.
const OPEN := "Open"


static func node_state(target: Character, target_class: StringName, node: TalentNodeDefinition) -> String:
	var rank := target.builds.get_build(target_class).rank(node.id)
	var state := state_of(rank, node.max_rank, TalentService.can_learn(target, target_class, node.id))
	if state == "Locked" and requirement_error(target, target_class, node) == "":
		return OPEN
	return state


## The first missing requirement of the node's next rank ("" = all met), free points not counted.
static func requirement_error(target: Character, target_class: StringName, node: TalentNodeDefinition) -> String:
	var build := target.builds.get_build(target_class)
	if build.rank(node.id) >= node.max_rank:
		return ""
	var next := build.talents.duplicate()
	next[node.id] = build.rank(node.id) + 1
	var level := target.classes.get_level(target_class)
	var errors := TalentService.validate_allocation(target.database, target_class, level, next)
	# the service checks the point total last (one entry, only when over the limit): free points do not count here
	var total := 0
	for rank: int in next.values():
		total += maxi(rank, 0)
	if total > target.database.rules.talent_rules().points_at_level(level) and not errors.is_empty():
		errors.remove_at(errors.size() - 1)
	return errors[0] if not errors.is_empty() else ""


## The node's full information as plain text (same content as the tooltip).
func info_text(node_id: StringName) -> String:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	return "\n".join(TalentTooltip.lines(character, class_id, node).map(func(line: Dictionary) -> String: return line.text))


## Pairs of node ids connected by lines: [from, to, explicit prerequisite?] - only explicit prerequisites
## (the flag stays for the callers).
func links() -> Array:
	var result: Array = []
	for node in tree.nodes:
		for prerequisite in node.prerequisites:
			if _buttons.has(prerequisite):
				result.append([prerequisite, node.id, true])
	return result


func _draw() -> void:
	if tree == null or layout == null:
		return
	var build := character.builds.get_build(class_id)
	for link: Array in links():
		var met := build.rank(link[0]) > 0
		var color := UiTheme.BRONZE if met else Color(UiTheme.TEXT_MUTED, 0.8)
		var path := link_path(link[0], link[1])
		draw_polyline(path, color, 2.0)
		# a small arrow head into the upgrade
		var end := path[path.size() - 1]
		draw_colored_polygon(PackedVector2Array([end, end + Vector2(-4, -7), end + Vector2(4, -7)]), color)


## The line of a prerequisite: straight down between neighbouring tiers; over a tier in between it bends
## into the row gap, runs down the column gap (between the cards, never behind one) and bends back.
func link_path(from_id: StringName, to_id: StringName) -> PackedVector2Array:
	var from_rect := card_rect(from_id)
	var to_rect := card_rect(to_id)
	var start := Vector2(from_rect.get_center().x, from_rect.end.y)
	var end := Vector2(to_rect.get_center().x, to_rect.position.y)
	if is_equal_approx(start.x, end.x) or to_rect.position.y - from_rect.end.y <= layout.row_gap + 1.0:
		return PackedVector2Array([start, end])
	var gap_x := maxf(from_rect.position.x, to_rect.position.x) - TalentLayout.COLUMN_GAP * 0.5
	if start.x < end.x:
		gap_x = minf(from_rect.end.x, to_rect.end.x) + TalentLayout.COLUMN_GAP * 0.5
	var high := start.y + layout.row_gap * 0.5
	var low := end.y - layout.row_gap * 0.5
	return PackedVector2Array([start, Vector2(start.x, high), Vector2(gap_x, high), Vector2(gap_x, low), Vector2(end.x, low), end])


## Kind glyph (also used by the legend): passive diamond, skill circle,
## transformation star.
static func draw_glyph(canvas: CanvasItem, kind: TalentNodeDefinition.Kind, center: Vector2, r: float, color: Color) -> void:
	match kind:
		TalentNodeDefinition.Kind.ACTIVE:
			canvas.draw_circle(center, r, color)
		TalentNodeDefinition.Kind.TRANSFORMATIVE:
			var points := PackedVector2Array()
			for i in 10:
				points.append(center + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0) * (r * 1.2 if i % 2 == 0 else r * 0.5))
			canvas.draw_colored_polygon(points, color)
		_:
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), color)


## Small padlock (Locked marker; also in the legend).
static func draw_lock(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_arc(at + Vector2(0, -2), 3.0, PI, TAU, 8, color, 1.5)
	canvas.draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 6)), color)


## Legend entry: glyph of a node kind plus its word.
static func kind_legend(kind: TalentNodeDefinition.Kind, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(16, 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.draw.connect(func() -> void: draw_glyph(glyph, kind, glyph.size * 0.5, 6.0, UiTheme.TEXT_PRIMARY))
	row.add_child(glyph)
	row.add_child(UiTheme.styled(text, &"CaptionLabel"))
	return row


## State colour of the rank line and the tile frame.
static func state_color(state: String) -> Color:
	match state:
		"Maxed", "Learned":
			return UiTheme.BRONZE
		"Available":
			return UiTheme.SUCCESS
		OPEN:
			return UiTheme.TEXT_SECONDARY
	return UiTheme.TEXT_MUTED


## One talent node as a card (CardButton: selected = gold card art, keyboard focus = the theme's resonance
## outline): icon tile, whole name, "rank/max state". No Godot tooltip - the panel shows the TalentTooltip.
class TalentButton:
	extends Button

	var node: TalentNodeDefinition
	var rank: int = 0
	var state: String = "Locked"
	var tile: Control
	var art: TextureRect
	var name_label: Label
	var rank_label: Label

	func _init() -> void:
		theme_type_variation = &"CardButton"
		toggle_mode = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clip_contents = true
		tile = Control.new()
		tile.name = "Tile"
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.draw.connect(_draw_tile)
		add_child(tile)
		name_label = UiTheme.styled("", &"CaptionLabel")
		name_label.name = "TalentName"
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # whole words, never "Relentle..."
		add_child(name_label)
		rank_label = UiTheme.styled("", &"CaptionLabel")
		rank_label.name = "Rank"
		add_child(rank_label)

	func _ready() -> void:
		if node != null and node.kind == TalentNodeDefinition.Kind.ACTIVE and node.unlocks_skill != &"":
			art = UiTheme.skill_icon(node.unlocks_skill)   # only a node that unlocks exactly this skill
			if art != null:
				tile.add_child(art)
		name_label.text = node.display_name if node != null else ""
		update_texts()

	func apply(target: TalentLayout) -> void:
		custom_minimum_size = target.card_size()
		size = custom_minimum_size
		var pad := TalentLayout.CARD_PADDING
		tile.size = Vector2.ONE * TalentLayout.TILE
		tile.position = Vector2(pad, floorf((size.y - TalentLayout.TILE) * 0.5))
		if art != null:
			art.position = (tile.size - UiTheme.SKILL_ICON_SIZE) * 0.5   # 1:1, crisp
			art.size = UiTheme.SKILL_ICON_SIZE
		var text_x := tile.position.x + TalentLayout.TILE + pad
		var text_width := size.x - text_x - pad + 2.0
		var block := TalentLayout.NAME_LINES * TalentLayout.NAME_LINE + TalentLayout.RANK_HEIGHT
		var top := floorf((size.y - block) * 0.5)
		name_label.position = Vector2(text_x, top)
		name_label.size = Vector2(text_width, TalentLayout.NAME_LINES * TalentLayout.NAME_LINE)
		rank_label.position = Vector2(text_x, top + TalentLayout.NAME_LINES * TalentLayout.NAME_LINE)
		rank_label.size = Vector2(text_width, TalentLayout.RANK_HEIGHT)

	func update_texts() -> void:
		if node == null:
			return
		# Menu UX Polish 1.1: Locked is said once - padlock on the tile, the card muted; the rank line stays "0/5".
		# Open (requirements met, no free point) has no word either: no padlock, no "+".
		rank_label.text = "%d/%d" % [rank, node.max_rank] if state == "Locked" or state == TalentTreeView.OPEN else "%d/%d %s" % [rank, node.max_rank, state]
		rank_label.add_theme_color_override(&"font_color", TalentTreeView.state_color(state))
		name_label.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY if state == "Locked" else UiTheme.TEXT_PRIMARY)
		if art != null:
			art.modulate = Color(0.5, 0.5, 0.5) if state == "Locked" else Color.WHITE
		tile.queue_redraw()

	## Tile: fill and frame by state (Locked dark + padlock, Available + mark, Learned bronze, Maxed double frame),
	## the capstone gets an inner frame; the skill art or the kind glyph in the middle.
	func _draw_tile() -> void:
		var rect := Rect2(Vector2.ZERO, tile.size)
		var color := TalentTreeView.state_color(state)
		var fill := UiTheme.PANEL_INSET
		var glyph := UiTheme.TEXT_MUTED
		match state:
			"Maxed":
				fill = Color(UiTheme.BRONZE_DARK, 0.95)
				glyph = UiTheme.PARCHMENT
			"Learned":
				fill = Color(UiTheme.BRONZE_DARK, 0.55)
				glyph = UiTheme.PARCHMENT
			"Available", TalentTreeView.OPEN:
				glyph = UiTheme.TEXT_PRIMARY
		tile.draw_rect(rect, fill)
		tile.draw_rect(rect.grow(-1.0), color if state != "Locked" else UiTheme.BRONZE_DARK, false, 2.0 if state != "Locked" else 1.0)
		if state == "Maxed" or node.is_capstone():
			tile.draw_rect(rect.grow(-4.0), Color(color, 0.7), false, 1.0)
		if art == null:
			TalentTreeView.draw_glyph(tile, node.kind, rect.get_center(), tile.size.x * 0.2, glyph)
		var corner := Vector2(tile.size.x - 7, 7)
		match state:
			"Maxed":
				tile.draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -4), corner + Vector2(4, 0), corner + Vector2(0, 4), corner + Vector2(-4, 0)]), UiTheme.BRONZE)
			"Available":
				tile.draw_line(corner + Vector2(-4, 0), corner + Vector2(4, 0), UiTheme.SUCCESS, 2.0)
				tile.draw_line(corner + Vector2(0, -4), corner + Vector2(0, 4), UiTheme.SUCCESS, 2.0)
			"Locked":
				TalentTreeView.draw_lock(tile, corner + Vector2(0, 1), Color(UiTheme.TEXT_MUTED, 0.9))
