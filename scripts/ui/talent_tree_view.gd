class_name TalentTreeView
extends Control
## One talent tree as a vertical node graph: tier 1 at the top to tier 7 at the
## bottom, the point gate of each tier in the gutter, nodes as square icons
## (glyph by kind, rank badge, state colour) with their name below. Lines show
## the way down the tree (same column / single-node tiers) and, stronger, the
## explicit prerequisites. Hover: tooltip with effect, rank, requirements and
## lock reason. Click: learn one rank - through TalentService only (the panel).

signal learn_requested(node_id: StringName)
## Hovered or focused node (the panel shows it in its details bar).
signal node_hovered(node_id: StringName)

const NODE := 46.0
const COLUMN_WIDTH := 132.0
const COLUMN_GAP := 12.0
const GUTTER := 44.0
const HEADER := 56.0
const ROW := 74.0
const COLUMNS := 2

var character: Character
var class_id: StringName
var tree: TalentTreeDefinition

var _buttons: Dictionary = {}   # node id -> TalentButton
var _names: Dictionary = {}     # node id -> Label
var _header: Label
var _points: Label
var _gates: Array[Label] = []


func setup(target_character: Character, target_class: StringName, target_tree: TalentTreeDefinition) -> void:
	character = target_character
	class_id = target_class
	tree = target_tree
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(GUTTER + COLUMNS * COLUMN_WIDTH + (COLUMNS - 1) * COLUMN_GAP, HEADER + 7 * ROW)
	_header = UiTheme.heading(tree.display_name)
	_header.add_theme_color_override(&"font_color", tree.color.lightened(0.2))
	add_child(_header)
	_points = UiTheme.styled("", &"CaptionLabel")
	_points.position = Vector2(0, 30)
	add_child(_points)
	var rules := character.database.rules.talent_rules()
	for tier in range(1, 8):
		var gate := UiTheme.styled("T%d\n%d" % [tier, rules.tier_requirement(tier)], &"CaptionLabel")
		gate.tooltip_text = "Tier %d: needs %d points in the lower tiers of %s." % [tier, rules.tier_requirement(tier), tree.display_name]
		gate.mouse_filter = Control.MOUSE_FILTER_PASS
		gate.position = Vector2(0, _row_y(tier) + 2)
		add_child(gate)
		_gates.append(gate)
	for node in tree.nodes:
		var button := TalentButton.new()
		button.name = String(node.id)
		button.node = node
		button.custom_minimum_size = Vector2.ONE * NODE
		button.size = Vector2.ONE * NODE
		button.position = node_center(node) - Vector2.ONE * NODE * 0.5
		button.pressed.connect(func() -> void: learn_requested.emit(node.id))
		button.mouse_entered.connect(func() -> void: node_hovered.emit(node.id))
		button.focus_entered.connect(func() -> void: node_hovered.emit(node.id))
		add_child(button)
		_buttons[node.id] = button
		var label := UiTheme.styled(node.display_name, &"CaptionLabel")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		label.size = Vector2(COLUMN_WIDTH, 18)
		label.position = node_center(node) + Vector2(-COLUMN_WIDTH * 0.5, NODE * 0.5 + 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_names[node.id] = label
	refresh()


func _row_y(tier: int) -> float:
	return HEADER + (tier - 1) * ROW


## Centre of a node: its column, or the middle when it is alone in its tier.
func node_center(node: TalentNodeDefinition) -> Vector2:
	var left := GUTTER + COLUMN_WIDTH * 0.5
	var right := left + COLUMN_WIDTH + COLUMN_GAP
	var x := left if clampi(node.column, 0, COLUMNS - 1) == 0 else right
	if _tier_size(node.tier) == 1:
		x = (left + right) * 0.5
	return Vector2(x, _row_y(node.tier) + NODE * 0.5)


func _tier_size(tier: int) -> int:
	return tree.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == tier).size()


func button_for(node_id: StringName) -> Button:
	return _buttons.get(node_id)


func refresh() -> void:
	var build := character.builds.get_build(class_id)
	var invested := TalentService.points_in_tree(build.talents, tree)
	_points.text = "%d points invested" % invested
	var rules := character.database.rules.talent_rules()
	for tier in range(1, 8):
		_gates[tier - 1].add_theme_color_override(&"font_color", UiTheme.BRONZE if invested >= rules.tier_requirement(tier) else UiTheme.TEXT_MUTED)
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		var rank := build.rank(node.id)
		var error := TalentService.can_learn(character, class_id, node.id)
		button.rank = rank
		button.state = state_of(rank, node.max_rank, error)
		button.tooltip_text = tooltip_for(node, rank, error)
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


## Name, kind, tier, state, effect, rank, requirements and why it is locked.
func tooltip_for(node: TalentNodeDefinition, rank: int, error: String) -> String:
	var rules := character.database.rules.talent_rules()
	var state := state_of(rank, node.max_rank, error)
	var lines: PackedStringArray = ["%s (%s, tier %d)  -  %s" % [node.display_name, node.kind_name(), node.tier, state], node.describe(rank)]
	lines.append("Rank %d / %d" % [rank, node.max_rank])
	if node.tier > 1:
		lines.append("Requires %d points in lower tiers of %s." % [rules.tier_requirement(node.tier), tree.display_name])
	for prerequisite in node.prerequisites:
		var other: TalentNodeDefinition = character.database.talent_nodes.get(prerequisite)
		lines.append("Requires: %s" % (other.display_name if other else String(prerequisite)))
	if node.required_class_level > 0:
		lines.append("Requires class level %d." % node.required_class_level)
	if node.unlocks_skill != &"":
		var skill: SkillDefinition = character.database.skills.get(node.unlocks_skill)
		if skill != null:
			lines.append("Skill: %s - %s" % [skill.display_name, skill.description])
	if rank < node.max_rank:
		lines.append("Click to learn." if error == "" else "Cannot learn: %s" % error)
	return "\n".join(lines)


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
			var same_column := clampi(node.column, 0, COLUMNS - 1) == clampi(lower.column, 0, COLUMNS - 1)
			if not (same_column or _tier_size(node.tier) == 1 or _tier_size(lower.tier) == 1):
				continue
			if result.any(func(link: Array) -> bool: return link[0] == node.id and link[1] == lower.id):
				continue
			result.append([node.id, lower.id, false])
	return result


func _draw() -> void:
	if tree == null:
		return
	for tier in range(2, 8):
		var y := _row_y(tier) - (ROW - NODE - 18.0) * 0.5
		draw_line(Vector2(GUTTER, y), Vector2(size.x, y), Color(UiTheme.BRONZE_DARK, 0.35), 1.0)
	var build := character.builds.get_build(class_id)
	for link: Array in links():
		var from_node: TalentNodeDefinition = (_buttons[link[0]] as TalentButton).node
		var to_node: TalentNodeDefinition = (_buttons[link[1]] as TalentButton).node
		var start := node_center(from_node) + Vector2(0, NODE * 0.5 + 18.0)
		var end := node_center(to_node) - Vector2(0, NODE * 0.5)
		if absf(start.x - end.x) < 1.0 and to_node.tier - from_node.tier == 1:
			start.y = node_center(from_node).y + NODE * 0.5 + 18.0
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


## Legend entry: glyph of a node kind plus its word.
static func kind_legend(kind: TalentNodeDefinition.Kind, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(16, 16)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.draw.connect(func() -> void: draw_glyph(glyph, kind, glyph.size * 0.5, 6.0, UiTheme.TEXT_PRIMARY))
	row.add_child(glyph)
	row.add_child(UiTheme.styled(text, &"SmallLabel"))
	return row


## Square talent node: glyph by kind, state colours, rank badge.
class TalentButton:
	extends Button

	var node: TalentNodeDefinition
	var rank: int = 0
	var state: String = "Locked"

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _make_custom_tooltip(for_text: String) -> Object:
		return UiTheme.tooltip(for_text)

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
				fill = Color(UiTheme.BRONZE_DARK, 0.9)
				glyph = UiTheme.PARCHMENT
			"Learned":
				border = UiTheme.BRONZE
				fill = Color(UiTheme.BRONZE_DARK, 0.55)
				glyph = UiTheme.PARCHMENT
			"Available":
				border = UiTheme.RESONANCE
				glyph = UiTheme.TEXT_PRIMARY
		if is_hovered() or has_focus():
			fill = fill.lightened(0.1)
		draw_rect(rect, fill)
		draw_rect(rect.grow(-1.0), border, false, 2.0 if state != "Locked" else 1.0)
		if node.is_capstone():
			draw_rect(rect.grow(-5.0), Color(border, 0.6), false, 1.0)
		var center := rect.get_center()
		TalentTreeView.draw_glyph(self, node.kind, center, size.x * 0.22, glyph)
		var font := get_theme_font(&"font")
		var badge := "%d/%d" % [rank, node.max_rank]
		var font_size := UiTheme.FONT_CAPTION
		var text_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var badge_rect := Rect2(Vector2(size.x - text_size.x - 4.0, size.y - font_size + 2.0), Vector2(text_size.x + 4.0, font_size - 2.0))
		draw_rect(badge_rect, Color(UiTheme.BG, 0.85))
		draw_string(font, badge_rect.position + Vector2(2.0, font_size - 6.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				UiTheme.BRONZE if rank > 0 else UiTheme.TEXT_SECONDARY)
		if has_focus():
			draw_rect(rect.grow(2.0), UiTheme.COLOR_FOCUS, false, 2.0)
