class_name TalentTreeView
extends Control
## One talent tree as a vertical node graph (Talent UI Polish 1.2): tree name
## and invested points on top, tier 1 to tier 7 downwards in rows of equal
## height (the same rows in every tree, so tiers line up across the columns;
## the tier labels are the shared TalentTierScale). Sizes come from a
## TalentLayout: "normal" nodes with their short name below, or "compact" icon
## nodes when the room is small. Nodes: kind glyph, state frame and marker,
## rank badge. Lines: the way down the tree (thin) and explicit prerequisites
## (thick). Everything else is in the TalentTooltip (hover / keyboard focus).
## A click learns one rank - through TalentService only (the panel).
## Works from the tree data alone (node tier/column/prerequisites), for every class.

signal learn_requested(node_id: StringName)
## Mouse or keyboard focus entered a node (`node_id`) or left it (&"").
signal node_hovered(node_id: StringName)

var character: Character
var class_id: StringName
var tree: TalentTreeDefinition
var layout: TalentLayout

var _buttons: Dictionary = {}   # node id -> TalentButton
var _names: Dictionary = {}     # node id -> Label
var _header: Label
var _points: Label


func setup(target_character: Character, target_class: StringName, target_tree: TalentTreeDefinition) -> void:
	character = target_character
	class_id = target_class
	tree = target_tree
	mouse_filter = Control.MOUSE_FILTER_PASS
	_header = UiTheme.styled(tree.display_name, &"HeaderLabel")
	_header.name = "TreeName"
	_header.add_theme_color_override(&"font_color", tree.color.lightened(0.2))
	add_child(_header)
	_points = UiTheme.styled("", &"CaptionLabel")
	_points.name = "Invested"
	add_child(_points)
	for node in tree.nodes:
		var button := TalentButton.new()
		button.name = String(node.id)
		button.node = node
		button.pressed.connect(func() -> void: learn_requested.emit(node.id))
		button.mouse_entered.connect(func() -> void: node_hovered.emit(node.id))
		button.mouse_exited.connect(func() -> void: node_hovered.emit(&""))
		button.focus_entered.connect(func() -> void: node_hovered.emit(node.id))
		button.focus_exited.connect(func() -> void: node_hovered.emit(&""))
		add_child(button)
		_buttons[node.id] = button
		var label := UiTheme.styled(node.display_name, &"CaptionLabel")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_names[node.id] = label
	apply(TalentLayout.new())
	refresh()


## Places header, nodes and names for `target` (sizes from the free room).
func apply(target: TalentLayout) -> void:
	layout = target
	custom_minimum_size = Vector2(layout.tree_width, layout.height())
	size = custom_minimum_size
	_header.position = Vector2(0, 0)
	_header.size = Vector2(layout.tree_width, 26)
	_points.position = Vector2(0, 24)
	_points.size = Vector2(layout.tree_width, 16)
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		button.custom_minimum_size = Vector2.ONE * layout.node_size
		button.size = button.custom_minimum_size
		button.position = node_center(node) - Vector2.ONE * layout.node_size * 0.5
		var label: Label = _names[node.id]
		label.visible = not layout.compact
		label.size = Vector2(layout.name_width(), TalentLayout.NAME_HEIGHT)
		label.position = node_center(node) + Vector2(-layout.name_width() * 0.5, layout.node_size * 0.5 + 2)
	queue_redraw()


## Centre of a node: its column, or the middle when it is alone in its tier.
func node_center(node: TalentNodeDefinition) -> Vector2:
	var x := layout.tree_width * (0.27 if clampi(node.column, 0, 1) == 0 else 0.73)
	if _tier_size(node.tier) == 1:
		x = layout.tree_width * 0.5
	return Vector2(x, layout.node_center_y(node.tier))


func _tier_size(tier: int) -> int:
	return tree.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == tier).size()


func button_for(node_id: StringName) -> Button:
	return _buttons.get(node_id)


func refresh() -> void:
	var build := character.builds.get_build(class_id)
	_points.text = "%d points invested" % TalentService.points_in_tree(build.talents, tree)
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		var rank := build.rank(node.id)
		button.rank = rank
		button.state = state_of(rank, node.max_rank, TalentService.can_learn(character, class_id, node.id))
		button.queue_redraw()
		(_names[node.id] as Label).add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED if button.state == "Locked" else UiTheme.TEXT_PRIMARY)
	queue_redraw()


## "Maxed" / "Learned" / "Available" / "Locked" - the node state in words.
static func state_of(rank: int, max_rank: int, error: String) -> String:
	if rank >= max_rank:
		return "Maxed"
	if rank > 0:
		return "Learned"
	return "Available" if error == "" else "Locked"


## The node's full information as plain text (same content as the tooltip).
func info_text(node_id: StringName) -> String:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	return "\n".join(TalentTooltip.lines(character, class_id, node).map(func(line: Dictionary) -> String: return line.text))


## Pairs of node ids connected by lines: [from, to, explicit prerequisite?].
func links() -> Array:
	var result: Array = []
	for node in tree.nodes:
		for prerequisite in node.prerequisites:
			if _buttons.has(prerequisite):
				result.append([prerequisite, node.id, true])
	for node in tree.nodes:
		if node.tier >= 7:
			continue
		for lower in tree.nodes:
			if lower.tier != node.tier + 1:
				continue
			var same_column := clampi(node.column, 0, 1) == clampi(lower.column, 0, 1)
			if not (same_column or _tier_size(node.tier) == 1 or _tier_size(lower.tier) == 1):
				continue
			if result.any(func(link: Array) -> bool: return link[0] == node.id and link[1] == lower.id):
				continue
			result.append([node.id, lower.id, false])
	return result


func _draw() -> void:
	if tree == null or layout == null:
		return
	# faint tier bands (same rows as the tier scale)
	for tier in range(1, 8):
		if tier % 2 == 0:
			draw_rect(Rect2(0, layout.row_top(tier), size.x, layout.row_height), Color(UiTheme.BRONZE_DARK, 0.12))
	var build := character.builds.get_build(class_id)
	var below := layout.node_size * 0.5 + (0.0 if layout.compact else TalentLayout.NAME_HEIGHT + 2.0)
	for link: Array in links():
		var from_node: TalentNodeDefinition = (_buttons[link[0]] as TalentButton).node
		var to_node: TalentNodeDefinition = (_buttons[link[1]] as TalentButton).node
		var start := node_center(from_node) + Vector2(0, below)
		var end := node_center(to_node) - Vector2(0, layout.node_size * 0.5)
		var walked := build.rank(link[0]) > 0
		var explicit: bool = link[2]
		var color := UiTheme.BRONZE if walked else Color(UiTheme.TEXT_MUTED, 0.45)
		if explicit and not walked:
			color = Color(UiTheme.WARNING, 0.6)
		draw_line(start, end, color, 3.0 if explicit else 1.5, true)


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


## Square talent node: glyph by kind, state frame, state marker (not only by
## colour: Maxed double frame + diamond, Available "+", Locked padlock),
## rank badge. No Godot tooltip - the panel shows the TalentTooltip at once.
class TalentButton:
	extends Button

	var node: TalentNodeDefinition
	var rank: int = 0
	var state: String = "Locked"

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		if node == null:
			return
		var rect := Rect2(Vector2.ZERO, size)
		var border := UiTheme.BRONZE_DARK
		var fill := UiTheme.PANEL_INSET
		var glyph := UiTheme.TEXT_MUTED
		match state:
			"Maxed":
				border = UiTheme.BRONZE
				fill = Color(UiTheme.BRONZE_DARK, 0.95)
				glyph = UiTheme.PARCHMENT
			"Learned":
				border = UiTheme.BRONZE
				fill = Color(UiTheme.BRONZE_DARK, 0.55)
				glyph = UiTheme.PARCHMENT
			"Available":
				border = UiTheme.RESONANCE
				glyph = UiTheme.TEXT_PRIMARY
		if is_hovered() or has_focus():
			fill = fill.lightened(0.12)
		draw_rect(rect, fill)
		draw_rect(rect.grow(-1.0), border, false, 2.0 if state != "Locked" else 1.0)
		if state == "Maxed" or node.is_capstone():
			draw_rect(rect.grow(-5.0), Color(border, 0.7), false, 1.0)
		TalentTreeView.draw_glyph(self, node.kind, rect.get_center() + Vector2(0, -2), size.x * 0.2, glyph)
		# state marker in the top right corner
		var corner := Vector2(size.x - 7, 7)
		match state:
			"Maxed":
				draw_colored_polygon(PackedVector2Array([corner + Vector2(0, -4), corner + Vector2(4, 0), corner + Vector2(0, 4), corner + Vector2(-4, 0)]), UiTheme.BRONZE)
			"Available":
				draw_line(corner + Vector2(-4, 0), corner + Vector2(4, 0), UiTheme.RESONANCE, 2.0)
				draw_line(corner + Vector2(0, -4), corner + Vector2(0, 4), UiTheme.RESONANCE, 2.0)
			"Locked":
				TalentTreeView.draw_lock(self, corner + Vector2(0, 1), Color(UiTheme.TEXT_MUTED, 0.9))
		# rank badge, bottom right, always inside the node
		var font := get_theme_font(&"font")
		var font_size := UiTheme.FONT_CAPTION
		var badge := "%d/%d" % [rank, node.max_rank]
		var text_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var badge_rect := Rect2(Vector2(size.x - text_size.x - 6.0, size.y - font_size - 1.0), Vector2(text_size.x + 5.0, font_size))
		draw_rect(badge_rect, Color(UiTheme.BG, 0.88))
		draw_string(font, badge_rect.position + Vector2(2.5, font_size - 3.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				UiTheme.BRONZE if rank > 0 else UiTheme.TEXT_SECONDARY)
		if has_focus():
			draw_rect(rect.grow(2.0), UiTheme.COLOR_FOCUS, false, 2.0)
