extends TestCase
## Gathering Rework 1.1 (docs/GATHERING.md): step counts per node, fixed
## material / XP budgets with a guaranteed completion bonus, a plan fixed once
## per node cycle, persistent partial state over save/load, atomic steps and no
## duplication by interruption, reload or repeated use. Only user://test_saves/.

const PATH := "user://test_saves/gathering_steps/slot_1.save.json"
const MAP := &"test_map"
## Node -> [profession, steps, step seconds] (prototype values of the design).
const NODES := {
	&"oak_tree": [&"woodcutting", 3, 0.75], &"old_oak": [&"woodcutting", 4, 0.75],
	&"forest_rock": [&"mining", 3, 0.85], &"iron_vein": [&"mining", 4, 0.85],
	&"rich_iron_vein": [&"mining", 5, 0.85], &"ancient_deposit": [&"mining", 5, 0.85],
	&"wild_flax": [&"herbalism", 2, 0.65], &"duskleaf_patch": [&"herbalism", 1, 0.65],
	&"duskleaf_cluster": [&"herbalism", 3, 0.65], &"stag_remains": [&"skinning", 2, 0.9],
	&"elk_remains": [&"skinning", 3, 0.9],
}
const RANGES := {&"woodcutting": [2, 4], &"mining": [3, 5], &"herbalism": [1, 3], &"skinning": [2, 3]}

var db: GameDatabase
var character: Character


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)


func after_each() -> void:
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _raise(profession_id: StringName, level: int) -> void:
	while character.professions.level(profession_id) < level:
		character.professions.add_xp(profession_id, 50)


func test_step_data_follows_the_design() -> void:
	for node_id: StringName in NODES:
		var node: ResourceNodeDefinition = db.resource_nodes[node_id]
		var entry: Array = NODES[node_id]
		check_eq(node.profession_id, entry[0], "%s profession" % node_id)
		check_eq(node.steps, entry[1], "%s steps" % node_id)
		var span: Array = RANGES[node.profession_id]
		check(node.steps >= span[0] and node.steps <= span[1], "%s: steps within the %s range" % [node_id, node.profession_id])
		var profession: ProfessionDefinition = db.professions[node.profession_id]
		check_near(profession.gather_step_seconds, entry[2], 0.0001, "%s step time" % node.profession_id)
		check(node.completion_bonus >= 1 and node.completion_bonus <= node.yield_quantity, "%s: bonus inside the budget" % node_id)


func test_plan_budgets_bonus_and_determinism() -> void:
	for node_id: StringName in NODES:
		var node: ResourceNodeDefinition = db.resource_nodes[node_id]
		_raise(node.profession_id, node.required_level)
		var plan := ResourceGathering.make_plan(character, MAP, node_id, node)
		var items := 0
		var xp := 0
		for index in node.steps:
			items += int(plan.items[index])
			xp += int(plan.xp[index])
		check_eq(items, node.yield_quantity, "%s: material budget = the old total yield" % node_id)
		check_eq(xp, ProfessionService.gather_xp_budget(character, node), "%s: XP budget = the old gather XP" % node_id)
		check(int(plan.items[node.steps - 1]) >= node.completion_bonus, "%s: completion bonus on the last step" % node_id)
		check_eq(ResourceGathering.make_plan(character, MAP, node_id, node), plan, "%s: the same plan every time (no re-roll)" % node_id)
