class_name TalentTreeDefinition
extends Resource
## One of the three talent trees of a class. Nodes of all three trees can be
## mixed freely; tier gates only count points invested in THIS tree.

@export var id: StringName
@export var class_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
@export var nodes: Array[TalentNodeDefinition] = []


func get_node_def(node_id: StringName) -> TalentNodeDefinition:
	for node in nodes:
		if node != null and node.id == node_id:
			return node
	return null


func capstones() -> Array[TalentNodeDefinition]:
	var result: Array[TalentNodeDefinition] = []
	for node in nodes:
		if node != null and node.is_capstone():
			result.append(node)
	return result


## Data checks of this tree alone (see TalentService.validate_trees for the
## cross-tree checks: prerequisites, cycles, skills).
func validate(rules: TalentRules) -> PackedStringArray:
	var errors: PackedStringArray = []
	if id == &"" or class_id == &"":
		errors.append("talent tree without id or class")
	var seen := {}
	var capacity := {}   # tier -> total max ranks
	if rules.tier_points.size() != TalentRules.TIERS:
		errors.append("talent rules: %d tier gates, %d tiers expected" % [rules.tier_points.size(), TalentRules.TIERS])
	for node in nodes:
		if node == null or node.id == &"":
			errors.append("%s: node without id" % id)
			continue
		if seen.has(node.id):
			errors.append("%s: duplicate node %s" % [id, node.id])
		seen[node.id] = true
		if node.tree_id != id or node.class_id != class_id:
			errors.append("%s: node %s belongs to %s/%s" % [id, node.id, node.class_id, node.tree_id])
		if node.max_rank < 1 or node.tier < 1 or node.tier > rules.tier_points.size():
			errors.append("%s: node %s has an invalid rank or tier" % [id, node.id])
		if node.kind == TalentNodeDefinition.Kind.ACTIVE and node.unlocks_skill == &"":
			errors.append("%s: active node %s unlocks no skill" % [id, node.id])
		if node.column < 0 or node.column >= TalentRules.COLUMNS:
			errors.append("%s: node %s has column %d (0..%d)" % [id, node.id, node.column, TalentRules.COLUMNS - 1])
		if node.is_capstone() and node.max_rank != 1:
			errors.append("%s: capstone %s must have exactly one rank" % [id, node.id])
		capacity[node.tier] = capacity.get(node.tier, 0) + node.max_rank
	if capstones().size() != 1:
		errors.append("%s: needs exactly one tier %d capstone" % [id, TalentRules.TIERS])
	# Reachability: the ranks of tiers below t must be able to pay tier t's gate.
	var below := 0
	for tier in range(1, rules.tier_points.size() + 1):
		if capacity.get(tier, 0) > 0 and below < rules.tier_points[tier - 1]:
			errors.append("%s: tier %d unreachable (%d ranks below, %d needed)" % [id, tier, below, rules.tier_points[tier - 1]])
		below += capacity.get(tier, 0)
	return errors
