class_name TalentTooltip
extends PanelContainer
## Immediate tooltip of a talent node (hover or keyboard focus), Talent UI
## Polish 1.2 - replaces the permanent details bar. In this order: name, kind,
## tier, rank, current effect, next rank, requirements (met or missing), lock
## reason, cost, capstone rule. All from the node data and TalentService.
## Top level next to the node: right, else left, else below/above; always on
## screen; never takes mouse input (the node stays clickable, nothing moves).

const WIDTH := 400.0
const GAP := 12.0

var _box: VBoxContainer
var _anchor: Control
var node_id: StringName


func _init() -> void:
	top_level = true
	z_index = 100
	theme_type_variation = &"WindowPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


func show_for(character: Character, class_id: StringName, node: TalentNodeDefinition, anchor: Control) -> void:
	_anchor = anchor
	node_id = node.id
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var tree: TalentTreeDefinition = character.database.talent_trees.get(node.tree_id)
	for line in lines(character, class_id, node):
		_box.add_child(_label(line, tree))
	show()
	reset_size()
	_place()
	_place.call_deferred()   # wrapped lines know their height after one pass


func hide_tooltip() -> void:
	node_id = &""
	_anchor = null
	hide()


## The tooltip content as lines {text, style}: style "title" / "meta" /
## "section" / "line" / "good" / "bad" / "dim" / "hint".
static func lines(character: Character, class_id: StringName, node: TalentNodeDefinition) -> Array[Dictionary]:
	var db := character.database
	var rules := db.rules.talent_rules()
	var tree: TalentTreeDefinition = db.talent_trees.get(node.tree_id)
	var build := character.builds.get_build(class_id)
	var rank := build.rank(node.id)
	var error := TalentService.can_learn(character, class_id, node.id)
	var state := TalentTreeView.state_of(rank, node.max_rank, error)
	var result: Array[Dictionary] = []
	result.append({"text": node.display_name, "style": "title"})
	result.append({"text": "%s  ·  Tier %d  ·  Rank %d / %d  ·  %s" % [_kind_word(node), node.tier, rank, node.max_rank, state], "style": "meta"})
	if rank > 0:
		result.append({"text": "Current (rank %d)" % rank, "style": "section"})
		result.append({"text": node.describe(rank), "style": "line"})
	if rank < node.max_rank:
		result.append({"text": "Next rank (%d)" % (rank + 1) if rank > 0 else "Effect at rank 1", "style": "section"})
		result.append({"text": node.describe(rank + 1), "style": "line"})
	if node.unlocks_skill != &"":
		var skill: SkillDefinition = db.skills.get(node.unlocks_skill)
		if skill != null:
			result.append({"text": "Skill: %s - %s" % [skill.display_name, skill.description], "style": "line"})
	result.append({"text": "Requirements", "style": "section"})
	var needed := rules.tier_requirement(node.tier)
	var spent := TalentService.points_in_tree(build.talents, tree, node.tier) if tree != null else 0
	if needed > 0:
		result.append({"text": "%d points in lower tiers of %s (%d / %d)" % [needed, tree.display_name if tree else "this tree", mini(spent, needed), needed], "style": "good" if spent >= needed else "bad"})
	else:
		result.append({"text": "Tier 1: no points needed", "style": "good"})
	for prerequisite in node.prerequisites:
		var other: TalentNodeDefinition = db.talent_nodes.get(prerequisite)
		result.append({"text": "Requires %s" % (other.display_name if other else String(prerequisite)), "style": "good" if build.rank(prerequisite) > 0 else "bad"})
	if node.required_class_level > 0:
		result.append({"text": "Class level %d" % node.required_class_level, "style": "good" if character.classes.get_level(class_id) >= node.required_class_level else "bad"})
	var free := TalentService.points_available(character, class_id)
	result.append({"text": "Cost: 1 talent point per rank  (%d free)" % free, "style": "dim"})
	if node.is_capstone():
		var max_points := rules.points_at_level(db.get_class_def(class_id).max_level if db.get_class_def(class_id) != null else 0)
		var capstone_note := "Capstone: needs %d points in %s." % [needed, tree.display_name if tree else "its tree"]
		if max_points < needed * 2:
			capstone_note += " Only one capstone fits into a build (at most %d points)." % max_points
		result.append({"text": capstone_note, "style": "dim"})
	if rank >= node.max_rank:
		result.append({"text": "Fully learned.", "style": "hint"})
	elif error == "":
		result.append({"text": "Click to learn a rank.", "style": "hint"})
	else:
		result.append({"text": "Locked: %s" % error, "style": "bad"})
	return result


static func _kind_word(node: TalentNodeDefinition) -> String:
	return ["Passive", "Skill", "Transformation"][node.kind]


func _label(line: Dictionary, tree: TalentTreeDefinition) -> Control:
	if line.style == "section":
		var section := UiTheme.section(line.text)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return section
	var label := UiTheme.wrapped(line.text, UiTheme.TEXT_PRIMARY, WIDTH - 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match line.style:
		"title":
			label.theme_type_variation = &"HeaderLabel"
			label.add_theme_color_override(&"font_color", tree.color.lightened(0.25) if tree != null else UiTheme.PARCHMENT)
		"meta":
			label.theme_type_variation = &"SmallLabel"
			label.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
		"good":
			label.theme_type_variation = &"SmallLabel"
			label.add_theme_color_override(&"font_color", UiTheme.SUCCESS)
		"bad":
			label.theme_type_variation = &"SmallLabel"
			label.add_theme_color_override(&"font_color", UiTheme.WARNING)
		"dim":
			label.theme_type_variation = &"SmallLabel"
			label.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
		"hint":
			label.theme_type_variation = &"SmallLabel"
			label.add_theme_color_override(&"font_color", UiTheme.RESONANCE)
	return label


## Right of the node if it fits, else left, else below / above; clamped.
func _place() -> void:
	if not visible or not is_inside_tree() or _anchor == null or not is_instance_valid(_anchor) or not _anchor.is_inside_tree():
		return
	reset_size()
	var anchor := _anchor.get_global_rect()
	var view := get_viewport_rect().size
	var margin := float(UiTheme.SCREEN_MARGIN) * 0.5
	var want := get_combined_minimum_size()
	size = want
	var x := anchor.end.x + GAP
	if x + want.x > view.x - margin:
		x = anchor.position.x - GAP - want.x
	x = clampf(x, margin, maxf(margin, view.x - margin - want.x))
	var y := clampf(anchor.get_center().y - want.y * 0.3, margin, maxf(margin, view.y - margin - want.y))
	if Rect2(Vector2(x, y), want).intersects(anchor.grow(-2.0)):
		var below := anchor.end.y + GAP
		y = below if below + want.y <= view.y - margin else anchor.position.y - GAP - want.y
		y = clampf(y, margin, maxf(margin, view.y - margin - want.y))
	global_position = Vector2(x, y).floor()
