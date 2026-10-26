class_name TalentTreeView
extends Control
## One talent tree drawn as a 7-tier grid: tier rows with their point gate,
## node buttons (rank, state colour, tooltip with effect and requirements) and
## lines for prerequisites. Learning goes through TalentService only.

signal learn_requested(node_id: StringName)

const CELL := Vector2(196, 48)
const GAP := Vector2(14, 14)
const GUTTER := 64.0
const HEADER := 58.0
const COLUMNS := 2

var character: Character
var class_id: StringName
var tree: TalentTreeDefinition

var _buttons: Dictionary = {}   # node id -> Button
var _header: Label
var _points: Label


func setup(target_character: Character, target_class: StringName, target_tree: TalentTreeDefinition) -> void:
	character = target_character
	class_id = target_class
	tree = target_tree
	custom_minimum_size = Vector2(GUTTER + COLUMNS * CELL.x + (COLUMNS - 1) * GAP.x, HEADER + 7 * (CELL.y + GAP.y))
	_header = UiTheme.heading(tree.display_name)
	_header.add_theme_color_override(&"font_color", tree.color.lightened(0.2))
	_header.position = Vector2(0, 0)
	add_child(_header)
	_points = UiTheme.label("", UiTheme.COLOR_DIM)
	_points.theme_type_variation = &"SmallLabel"
	_points.position = Vector2(0, 30)
	add_child(_points)
	var rules := character.database.rules.talent_rules()
	for tier in range(1, 8):
		var gate := UiTheme.label("T%d\n%d pts" % [tier, rules.tier_requirement(tier)], UiTheme.COLOR_DIM)
		gate.theme_type_variation = &"SmallLabel"
		gate.position = Vector2(0, _row_y(tier) + 4)
		add_child(gate)
	for node in tree.nodes:
		var button := TalentButton.new()
		button.name = String(node.id)
		button.custom_minimum_size = CELL
		button.size = CELL
		button.clip_text = true
		button.position = Vector2(GUTTER + clampi(node.column, 0, COLUMNS - 1) * (CELL.x + GAP.x), _row_y(node.tier))
		button.pressed.connect(func() -> void: learn_requested.emit(node.id))
		add_child(button)
		_buttons[node.id] = button
	refresh()


func _row_y(tier: int) -> float:
	return HEADER + (tier - 1) * (CELL.y + GAP.y)


func button_for(node_id: StringName) -> Button:
	return _buttons.get(node_id)


func refresh() -> void:
	var build := character.builds.get_build(class_id)
	_points.text = "%d points invested" % TalentService.points_in_tree(build.talents, tree)
	for node in tree.nodes:
		var button: TalentButton = _buttons[node.id]
		var rank := build.rank(node.id)
		var error := TalentService.can_learn(character, class_id, node.id)
		var marker: String = {TalentNodeDefinition.Kind.ACTIVE: " [A]", TalentNodeDefinition.Kind.TRANSFORMATIVE: " [T]"}.get(node.kind, "")
		button.text = "%s%s\n%d / %d" % [node.display_name, marker, rank, node.max_rank]
		var color := UiTheme.COLOR_TEXT
		if rank >= node.max_rank:
			color = tree.color.lightened(0.35)
		elif rank > 0:
			color = UiTheme.COLOR_ACCENT
		elif error != "":
			color = UiTheme.COLOR_DIM
		button.add_theme_color_override(&"font_color", color)
		button.add_theme_color_override(&"font_hover_color", color.lightened(0.2))
		button.modulate = Color.WHITE if rank > 0 or error == "" else Color(1, 1, 1, 0.6)
		button.tooltip_text = _tooltip(node, rank, error)
	queue_redraw()


func _tooltip(node: TalentNodeDefinition, rank: int, error: String) -> String:
	var rules := character.database.rules.talent_rules()
	var lines: PackedStringArray = ["%s (%s, tier %d)" % [node.display_name, node.kind_name(), node.tier], node.describe(rank)]
	lines.append("Rank %d / %d" % [rank, node.max_rank])
	if node.tier > 1:
		lines.append("Requires %d points in lower tiers of %s." % [rules.tier_requirement(node.tier), tree.display_name])
	for prerequisite in node.prerequisites:
		var other: TalentNodeDefinition = character.database.talent_nodes.get(prerequisite)
		lines.append("Requires: %s" % (other.display_name if other else String(prerequisite)))
	if node.unlocks_skill != &"":
		var skill: SkillDefinition = character.database.skills.get(node.unlocks_skill)
		if skill != null:
			lines.append("Skill: %s - %s" % [skill.display_name, skill.description])
	if rank < node.max_rank:
		lines.append("Click to learn." if error == "" else "Cannot learn: %s" % error)
	return "\n".join(lines)


func _draw() -> void:
	if tree == null:
		return
	for tier in range(1, 8):
		var y := _row_y(tier) - GAP.y * 0.5
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UiTheme.COLOR_BORDER, 0.5), 1.0)
	var build := character.builds.get_build(class_id)
	for node in tree.nodes:
		var to: Button = _buttons.get(node.id)
		for prerequisite in node.prerequisites:
			var from: Button = _buttons.get(prerequisite)
			if from == null or to == null:
				continue
			var active := build.rank(prerequisite) > 0
			draw_line(from.position + Vector2(CELL.x * 0.5, CELL.y), to.position + Vector2(CELL.x * 0.5, 0),
					UiTheme.COLOR_ACCENT if active else Color(UiTheme.COLOR_DIM, 0.6), 2.0)


class TalentButton:
	extends Button

	func _make_custom_tooltip(for_text: String) -> Object:
		return UiTheme.tooltip(for_text)
