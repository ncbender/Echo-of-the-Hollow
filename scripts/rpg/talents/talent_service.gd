class_name TalentService
extends RefCounted
## Central talent rules (docs/TALENT_SYSTEM.md). Stateless; every check of
## learning, allocations, presets and respecs goes through validate_allocation(),
## so there is exactly one place that knows the rules:
##  * points: one per class level from TalentRules.first_point_level
##  * tiers: a node of tier t needs tier_points[t-1] points invested in LOWER
##    tiers of the same tree (trees can be mixed freely)
##  * ranks, class level, prerequisites (no cycles, checked on data load)


static func rules(character: Character) -> TalentRules:
	return character.database.rules.talent_rules()


static func points_total(character: Character, class_id: StringName) -> int:
	return rules(character).points_at_level(character.classes.get_level(class_id))


static func points_available(character: Character, class_id: StringName) -> int:
	return points_total(character, class_id) - character.builds.get_build(class_id).spent()


## Points invested in `tree` (optionally only in tiers below `below_tier`).
static func points_in_tree(talents: Dictionary, tree: TalentTreeDefinition, below_tier: int = 99) -> int:
	var total := 0
	for node in tree.nodes:
		if node.tier < below_tier:
			total += talents.get(node.id, 0)
	return total


static func trees_of(db: GameDatabase, class_id: StringName) -> Array[TalentTreeDefinition]:
	var result: Array[TalentTreeDefinition] = []
	var definition := db.get_class_def(class_id)
	if definition == null:
		return result
	for tree_id in definition.talent_tree_ids:
		var tree: TalentTreeDefinition = db.talent_trees.get(tree_id)
		if tree != null:
			result.append(tree)
	return result


## All rule violations of a complete allocation (node id -> rank) for a class at
## `level`. Empty = valid. Used for learning, presets and loading.
static func validate_allocation(db: GameDatabase, class_id: StringName, level: int, talents: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var talent_rules := db.rules.talent_rules()
	var total := 0
	for node_id: StringName in talents:
		var rank: int = talents[node_id]
		var node: TalentNodeDefinition = db.talent_nodes.get(node_id)
		if node == null:
			errors.append("Unknown talent %s." % node_id)
			continue
		if node.class_id != class_id:
			errors.append("%s belongs to another class." % node.display_name)
			continue
		if rank < 0 or rank > node.max_rank:
			errors.append("%s: rank %d of %d is not possible." % [node.display_name, rank, node.max_rank])
		if rank <= 0:
			continue
		total += rank
		if node.required_class_level > level:
			errors.append("%s requires class level %d." % [node.display_name, node.required_class_level])
		for prerequisite in node.prerequisites:
			if talents.get(prerequisite, 0) <= 0:
				var other: TalentNodeDefinition = db.talent_nodes.get(prerequisite)
				errors.append("%s requires %s." % [node.display_name, other.display_name if other else String(prerequisite)])
		var tree: TalentTreeDefinition = db.talent_trees.get(node.tree_id)
		var needed := talent_rules.tier_requirement(node.tier)
		if tree != null and points_in_tree(talents, tree, node.tier) < needed:
			errors.append("%s needs %d points in lower tiers of %s." % [node.display_name, needed, tree.display_name])
	var available := talent_rules.points_at_level(level)
	if total > available:
		errors.append("%d talent points spent, only %d available at level %d." % [total, available, level])
	return errors


## "" if one more rank of `node_id` can be learned now, otherwise the reason.
static func can_learn(character: Character, class_id: StringName, node_id: StringName) -> String:
	var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
	if node == null or node.class_id != class_id:
		return "Unknown talent."
	var build := character.builds.get_build(class_id)
	if build.rank(node_id) >= node.max_rank:
		return "Already at maximum rank."
	if points_available(character, class_id) <= 0:
		return "No talent points available."
	var next := build.talents.duplicate()
	next[node_id] = build.rank(node_id) + 1
	var errors := validate_allocation(character.database, class_id, character.classes.get_level(class_id), next)
	return errors[0] if not errors.is_empty() else ""


## Learns one rank. Talent points can be spent anywhere; returns "" or the reason.
static func learn(character: Character, class_id: StringName, node_id: StringName) -> String:
	var error := can_learn(character, class_id, node_id)
	if error != "":
		return error
	var build := character.builds.get_build(class_id)
	build.talents[node_id] = build.rank(node_id) + 1
	SkillBook.auto_fill(character, class_id)
	character.builds.notify(class_id)
	return ""


## 0 for the first respec of a class (if the rules say so), else level-based.
static func respec_cost(character: Character, class_id: StringName) -> int:
	var talent_rules := rules(character)
	if talent_rules.first_respec_free and character.builds.get_build(class_id).respecs == 0:
		return 0
	return talent_rules.respec_cost(character.classes.get_level(class_id))


static func can_respec(character: Character, class_id: StringName, at_station: bool) -> String:
	if character.classes.in_trial():
		return "Not during a class trial."
	if not at_station:
		return "Talents can only be reset at a class station."
	if character.builds.get_build(class_id).talents.is_empty():
		return "No talents to reset."
	var cost := respec_cost(character, class_id)
	var currency := rules(character).respec_currency_item
	if cost > 0 and character.inventory.count(currency) < cost:
		return "Not enough %s (%d needed)." % [_item_name(character, currency), cost]
	return ""


## Full talent reset of one class. Keeps class XP, skill/mod unlocks from other
## sources, mastery and quests; skills and mods that only came from talents
## leave their slots.
static func respec(character: Character, class_id: StringName, at_station: bool) -> String:
	var error := can_respec(character, class_id, at_station)
	if error != "":
		return error
	var cost := respec_cost(character, class_id)
	if cost > 0 and not character.inventory.remove_quantity(rules(character).respec_currency_item, cost):
		return "Payment failed."
	var build := character.builds.get_build(class_id)
	build.talents.clear()
	build.respecs += 1
	SkillBook.sanitize(character, class_id)
	character.builds.notify(class_id)
	return ""


## Repairs a loaded or otherwise untrusted build: unknown nodes, impossible ranks
## and allocations that break the rules (e.g. data changed) are removed - the
## whole allocation is cleared when it cannot be repaired node by node, and the
## respec stays free in that case. Returns warnings.
static func sanitize_build(character: Character, class_id: StringName) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var db := character.database
	var build := character.builds.get_build(class_id)
	for node_id: StringName in build.talents.keys():
		var node: TalentNodeDefinition = db.talent_nodes.get(node_id)
		if node == null or node.class_id != class_id:
			warnings.append("talent %s of %s removed (unknown)" % [node_id, class_id])
			build.talents.erase(node_id)
		elif build.talents[node_id] > node.max_rank:
			warnings.append("talent %s clamped to rank %d" % [node_id, node.max_rank])
			build.talents[node_id] = node.max_rank
	var errors := validate_allocation(db, class_id, character.classes.get_level(class_id), build.talents)
	if not errors.is_empty():
		warnings.append("talents of %s reset: %s" % [class_id, errors[0]])
		build.talents.clear()
	warnings.append_array(SkillBook.sanitize(character, class_id))
	return warnings


## Data checks across trees: prerequisites exist, belong to the class, sit in
## the same or a lower tier, contain no cycles; unlocked skills and mods exist.
static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	var talent_rules := db.rules.talent_rules()
	for tree: TalentTreeDefinition in db.talent_trees.values():
		errors.append_array(tree.validate(talent_rules))
		if db.get_class_def(tree.class_id) == null:
			errors.append("tree %s for unknown class %s" % [tree.id, tree.class_id])
	for node: TalentNodeDefinition in db.talent_nodes.values():
		for prerequisite in node.prerequisites:
			var other: TalentNodeDefinition = db.talent_nodes.get(prerequisite)
			if other == null:
				errors.append("talent %s requires unknown %s" % [node.id, prerequisite])
			elif other.class_id != node.class_id or other.tier > node.tier:
				errors.append("talent %s: prerequisite %s must be same class, same or lower tier" % [node.id, prerequisite])
		if node.unlocks_skill != &"":
			var skill: SkillDefinition = db.skills.get(node.unlocks_skill)
			if skill == null or skill.class_id != node.class_id:
				errors.append("talent %s unlocks unknown skill %s" % [node.id, node.unlocks_skill])
		for mod_id in node.unlocks_mods:
			if not db.skill_mods.has(mod_id):
				errors.append("talent %s unlocks unknown mod %s" % [node.id, mod_id])
		if _has_cycle(db, node.id, {}):
			errors.append("talent %s has circular prerequisites" % node.id)
	for definition: ClassDefinition in db.classes.values():
		for tree_id in definition.talent_tree_ids:
			var tree: TalentTreeDefinition = db.talent_trees.get(tree_id)
			if tree == null or tree.class_id != definition.id:
				errors.append("class %s lists unknown tree %s" % [definition.id, tree_id])
	return errors


static func _has_cycle(db: GameDatabase, node_id: StringName, visiting: Dictionary) -> bool:
	if visiting.has(node_id):
		return true
	var node: TalentNodeDefinition = db.talent_nodes.get(node_id)
	if node == null:
		return false
	visiting[node_id] = true
	for prerequisite in node.prerequisites:
		if _has_cycle(db, prerequisite, visiting):
			return true
	visiting.erase(node_id)
	return false


## Stat modifiers of the class's talents (StatResolver source).
static func stat_modifiers(character: Character, class_id: StringName) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var build := character.builds.get_build(class_id)
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node != null:
			result.append_array(node.modifiers_at(build.talents[node_id]))
	return result


## Combat effects of the class (innate mechanics) and its talents (power = rank)
## for ItemEffectRunner.rebuild.
static func effect_entries(character: Character, class_id: StringName) -> Array:
	var result := []
	var definition := character.database.get_class_def(class_id)
	if definition != null:
		for index in definition.innate_effects.size():
			result.append({"effect": definition.innate_effects[index], "key": "class:%s:%d" % [class_id, index], "power": 1.0})
	var build := character.builds.get_build(class_id)
	for node_id: StringName in build.talents:
		var node: TalentNodeDefinition = character.database.talent_nodes.get(node_id)
		if node == null or build.talents[node_id] <= 0:
			continue
		for index in node.effects.size():
			result.append({"effect": node.effects[index], "key": "talent:%s:%d" % [node_id, index], "power": float(build.talents[node_id])})
	return result


static func _item_name(character: Character, item_id: StringName) -> String:
	var definition := character.database.get_item(item_id)
	return definition.display_name if definition != null else String(item_id)
