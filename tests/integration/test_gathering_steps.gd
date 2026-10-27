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



## One node of each gathering profession, stepped one by one.
func test_each_profession_steps_budget_and_bonus() -> void:
	for node_id: StringName in [&"oak_tree", &"iron_vein", &"wild_flax", &"stag_remains"]:
		var node: ResourceNodeDefinition = db.resource_nodes[node_id]
		_raise(node.profession_id, node.required_level)
		var plan := ResourceGathering.make_plan(character, MAP, node_id, node)
		var bag := character.inventory.count(node.yield_item_id)
		var xp := _total_xp(node.profession_id)
		for index in node.steps:
			var result := ResourceGathering.complete_step(character, MAP, node_id, node, 1000.0)
			check_eq(result.error, "", "%s step %d" % [node_id, index + 1])
			check_eq(result.items, int(plan.items[index]), "%s step %d: its planned materials (may be 0)" % [node_id, index + 1])
			check_eq(result.xp, int(plan.xp[index]), "%s step %d: its planned XP" % [node_id, index + 1])
			check_eq(character.inventory.count(node.yield_item_id), bag + _sum(plan.items, index + 1), "%s: bag follows the steps" % node_id)
			check_eq(result.exhausted, index == node.steps - 1, "%s: exhausted only after the last step" % node_id)
			if index == node.steps - 1:
				check(result.items >= node.completion_bonus, "%s: guaranteed completion bonus" % node_id)
		check_eq(character.inventory.count(node.yield_item_id) - bag, node.yield_quantity, "%s: total = the budget" % node_id)
		check_eq(_total_xp(node.profession_id) - xp, _sum(plan.xp, node.steps), "%s: XP = the budget" % node_id)
		var again := ResourceGathering.complete_step(character, MAP, node_id, node, 1001.0)
		check(String(again.error).ends_with("depleted") and int(again.items) == 0, "%s: nothing after exhaustion" % node_id)
		check(ResourceGathering.is_available(character.world, MAP, node_id, 1000.0 + node.respawn_seconds), "%s: back after its respawn time" % node_id)


## Total XP ever earned in a profession (level-ups reset the bar).
func _total_xp(profession_id: StringName) -> int:
	var definition: ProfessionDefinition = db.professions[profession_id]
	var total := character.professions.xp(profession_id)
	for level in range(1, character.professions.level(profession_id)):
		total += definition.xp_to_next(level)
	return total


func _sum(values: Array, count: int) -> int:
	var total := 0
	for index in count:
		total += int(values[index])
	return total


func test_refusals_change_nothing() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"elk_remains"]   # skinning level 3
	var result := ResourceGathering.complete_step(character, MAP, &"elk_1", node, 1000.0)
	check(String(result.error).contains("level 3"), "level requirement: %s" % result.error)
	check_eq(ResourceGathering.progress(character.world, MAP, &"elk_1"), {}, "no state written")
	check_eq(character.professions.xp(&"skinning"), 0, "no XP")
	# full bag on a step that carries materials
	var rock: ResourceNodeDefinition = db.resource_nodes[&"forest_rock"]
	var plan := ResourceGathering.make_plan(character, MAP, &"rock_1", rock)
	var first_with_items := 0
	while int(plan.items[first_with_items]) == 0:
		ResourceGathering.complete_step(character, MAP, &"rock_1", rock, 1000.0)
		first_with_items += 1
	var filler := 0
	while character.inventory.room_for(&"stone") > 0 and filler < 200:
		character.inventory.add_item(&"iron_sword")   # one slot each
		filler += 1
	var before := ResourceGathering.progress(character.world, MAP, &"rock_1")
	var xp := character.professions.xp(&"mining")
	var full := ResourceGathering.complete_step(character, MAP, &"rock_1", rock, 1000.0)
	check_eq(full.error, "inventory full", "refused with a full bag")
	check_eq(ResourceGathering.progress(character.world, MAP, &"rock_1"), before, "progress unchanged")
	check_eq(character.professions.xp(&"mining"), xp, "XP unchanged")


func test_partial_progress_survives_save_load_without_reroll_or_dupe() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"rich_iron_vein"]
	_raise(&"mining", node.required_level)
	var plan := ResourceGathering.make_plan(character, MAP, &"vein_1", node)
	for i in 2:
		ResourceGathering.complete_step(character, MAP, &"vein_1", node, 1000.0)
	var ore := character.inventory.count(&"iron_ore")
	var xp := character.professions.xp(&"mining")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved mid-node")
	# a third step after saving; loading the save simply returns to the saved state
	ResourceGathering.complete_step(character, MAP, &"vein_1", node, 1000.0)
	var loaded := SaveSystem.load_from(PATH, db).character
	check_eq(ResourceGathering.steps_done(loaded.world, MAP, &"vein_1"), 2, "two steps done after loading")
	check_eq(loaded.inventory.count(&"iron_ore"), ore, "the bag as saved")
	check_eq(loaded.professions.xp(&"mining"), xp, "the XP as saved")
	var stored := ResourceGathering.progress(loaded.world, MAP, &"vein_1")
	var stored_items: Array = (stored.items as Array).map(func(v: Variant) -> int: return int(v))
	check_eq(stored_items, plan.items, "the same material plan (no re-roll)")
	check_eq(int(stored.given_items), _sum(plan.items, 2), "given materials recorded")
	check_eq(ResourceGathering.remaining_items(loaded.world, MAP, &"vein_1", node), node.yield_quantity - _sum(plan.items, 2), "remaining budget")
	var gained := 0
	for i in 3:
		gained += int(ResourceGathering.complete_step(loaded, MAP, &"vein_1", node, 1000.0).items)
	check_eq(gained, node.yield_quantity - _sum(plan.items, 2), "the rest of the budget, nothing more")
	check(not ResourceGathering.is_available(loaded.world, MAP, &"vein_1", 1001.0), "exhausted")
	check_eq(SaveSystem.save_to(loaded, PATH), OK, "saved exhausted")
	var again := SaveSystem.load_from(PATH, db).character
	check(not ResourceGathering.is_available(again.world, MAP, &"vein_1", 1001.0), "still exhausted after loading")
	check_eq(ResourceGathering.progress(again.world, MAP, &"vein_1"), {}, "no partial state left")
	check(ResourceGathering.is_available(again.world, MAP, &"vein_1", 1000.0 + node.respawn_seconds), "respawns as before")
	check_eq(int(again.world.get_map_value(MAP, ResourceGathering.CYCLE_KEY % &"vein_1", 0)), 1, "the next cycle gets its own fixed plan")


func test_tampered_or_old_states_never_create_rewards() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"oak_tree"]
	var tampered := {"steps": 3, "done": 1, "item": "timber", "items": [0, 9, 9], "xp": [1, 1, 1], "given_items": 5, "given_xp": 1}
	character.world.set_map_value(MAP, ResourceGathering.progress_key(&"oak_1"), JSON.stringify(tampered))
	var before := character.inventory.count(&"timber")
	var result := ResourceGathering.complete_step(character, MAP, &"oak_1", node, 1000.0)
	check(String(result.error).ends_with("depleted"), "an inconsistent state is treated as exhausted")
	check_eq(character.inventory.count(&"timber"), before, "no materials from it")
	check(not ResourceGathering.is_available(character.world, MAP, &"oak_1", 1001.0), "depleted until its respawn time")
	character.world.set_map_value(MAP, ResourceGathering.progress_key(&"oak_4"), "not json")
	check(String(ResourceGathering.complete_step(character, MAP, &"oak_4", node, 1000.0).error).ends_with("depleted"), "unreadable state: no reward")
	# a v10 save knows only the depletion key: depleted stays depleted, untouched starts fresh
	character.world.set_map_value(MAP, ResourceGathering.state_key(&"oak_2"), ResourceGathering.PERMANENT)
	check(String(ResourceGathering.complete_step(character, MAP, &"oak_2", node, 1000.0).error).ends_with("depleted"), "old permanent depletion respected")
	check_eq(ResourceGathering.complete_step(character, MAP, &"oak_3", node, 1000.0).error, "", "an untouched old node starts a fresh cycle")
	check_eq(ResourceGathering.steps_done(character.world, MAP, &"oak_3"), 1, "first step recorded")


## Final integration: a partly worked node stays partly worked (no timer while
## partial); the existing respawn time starts only at exhaustion.
func test_partial_node_persists_and_respawn_starts_at_exhaustion() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"old_oak"]
	_raise(&"woodcutting", node.required_level)
	ResourceGathering.complete_step(character, MAP, &"oak_p", node, 1000.0)
	for later: float in [1000.0 + node.respawn_seconds, 1000.0 + 100000.0]:
		check(ResourceGathering.is_available(character.world, MAP, &"oak_p", later), "partial: still workable at t+%d" % (later - 1000.0))
		check_eq(ResourceGathering.steps_done(character.world, MAP, &"oak_p"), 1, "partial progress kept")
	for i in node.steps - 1:
		ResourceGathering.complete_step(character, MAP, &"oak_p", node, 5000.0)
	check_near(ResourceGathering.seconds_left(character.world, MAP, &"oak_p", 5000.0), node.respawn_seconds, 0.001, "the existing respawn time starts at exhaustion")


## The completion bonus never creates material outside the budget.
func test_bonus_inside_the_budget_and_zero_budgets() -> void:
	var base: ResourceNodeDefinition = db.resource_nodes[&"forest_rock"]
	for case: Array in [[0, 1, 3], [1, 3, 3], [2, 1, 1], [3, -2, 3], [2, 1, 0]]:   # yield, bonus, steps
		var node := base.duplicate() as ResourceNodeDefinition
		node.yield_quantity = case[0]
		node.completion_bonus = case[1]
		node.steps = case[2]
		var plan := ResourceGathering.make_plan(character, MAP, &"budget", node)
		var total := 0
		for value: int in plan.items:
			check(value >= 0, "no negative step")
			total += value
		check_eq(total, case[0], "yield %d / bonus %d / steps %d: exactly the budget" % case)
		check(int(plan.bonus) <= case[0] and int(plan.bonus) >= 0, "bonus clamped into the budget")
		check(int(plan.steps) >= 1, "at least one step")
	var zero := base.duplicate() as ResourceNodeDefinition
	zero.gather_xp = 0
	var zero_plan := ResourceGathering.make_plan(character, MAP, &"budget_xp", zero)
	check((zero_plan.xp as Array).all(func(v: int) -> bool: return v == 0), "zero XP budget: no XP")
	check(db.load_errors.is_empty(), "all data nodes: bonus inside the yield, steps >= 1 (%s)" % [db.load_errors])



# --- final guarantee: first and last step give main material -----------------------

func _node(yield_quantity: int, steps: int, bonus: int = 1) -> ResourceNodeDefinition:
	var node := (db.resource_nodes[&"forest_rock"] as ResourceNodeDefinition).duplicate() as ResourceNodeDefinition
	node.id = &"test_budget"
	node.yield_quantity = yield_quantity
	node.steps = steps
	node.completion_bonus = bonus
	return node


func _plan_at_cycle(node_id: StringName, node: ResourceNodeDefinition, cycle: int) -> Dictionary:
	character.world.set_map_value(MAP, ResourceGathering.CYCLE_KEY % node_id, cycle)
	return ResourceGathering.make_plan(character, MAP, node_id, node)


func test_every_data_node_guarantees_first_and_last_unit() -> void:
	for node_id: StringName in NODES:
		var node: ResourceNodeDefinition = db.resource_nodes[node_id]
		check(node.budget_errors().is_empty(), "%s: budget holds the guarantees (%s)" % [node_id, node.budget_errors()])
		for cycle in 25:   # many cycles = many different fixed plans
			var plan := _plan_at_cycle(node_id, node, cycle)
			var items: Array = plan.items
			check_eq(_sum(items, node.steps), node.yield_quantity, "%s cycle %d: exactly the budget" % [node_id, cycle])
			check(int(items[node.steps - 1]) >= 1, "%s cycle %d: last step >= 1 (completion bonus)" % [node_id, cycle])
			if node.steps >= 2:
				check(int(items[0]) >= 1, "%s cycle %d: first step >= 1" % [node_id, cycle])
			check(items.all(func(v: int) -> bool: return v >= 0), "%s cycle %d: no negative step" % [node_id, cycle])


func test_one_and_many_steps_and_minimum_budgets() -> void:
	check_eq(ResourceGathering.make_plan(character, MAP, &"one", _node(1, 1)).items, [1], "one step, budget 1: the one guaranteed unit")
	check_eq(ResourceGathering.make_plan(character, MAP, &"two", _node(2, 2)).items, [1, 1], "two steps, minimum budget 2: first and last")
	check_eq(ResourceGathering.make_plan(character, MAP, &"five", _node(2, 5)).items, [1, 0, 0, 0, 1], "five steps, budget 2: the middle gives nothing")
	for cycle in 25:
		var plan := _plan_at_cycle(&"many", _node(5, 4), cycle)
		check(int(plan.items[0]) >= 1 and int(plan.items[3]) >= 1 and _sum(plan.items, 4) == 5, "cycle %d: %s" % [cycle, plan.items])


func test_invalid_budgets_are_reported_and_never_exceeded() -> void:
	for case: Array in [[1, 2, 1], [0, 1, 1], [3, 3, 0], [2, 0, 1], [2, 2, 2]]:   # yield, steps, bonus
		var node := _node(case[0], case[1], case[2])
		check(not node.budget_errors().is_empty(), "yield %d / steps %d / bonus %d is reported as invalid" % case)
		var plan := ResourceGathering.make_plan(character, MAP, &"bad", node)
		check(_sum(plan.items, int(plan.steps)) <= maxi(0, case[0]), "never more than the budget (%s)" % [plan.items])
		check((plan.items as Array).all(func(v: int) -> bool: return v >= 0), "never negative")
	var tight := _node(1, 3)   # cannot hold first + last: the one unit stays the completion bonus
	check_eq(ResourceGathering.make_plan(character, MAP, &"tight", tight).items, [0, 0, 1], "budget 1 on 3 steps: only the bonus, nothing invented")


func test_interruption_after_the_first_step_keeps_the_plan() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"iron_vein"]   # 4 steps, budget 2
	var plan := ResourceGathering.make_plan(character, MAP, &"vein_i", node)
	var first := ResourceGathering.complete_step(character, MAP, &"vein_i", node, 1000.0)
	check(int(first.items) >= 1, "the first step already gives ore")
	# interrupted here (no further step), later resumed
	check_eq(ResourceGathering.remaining_items(character.world, MAP, &"vein_i", node), node.yield_quantity - int(first.items), "the rest of the budget waits")
	var stored := ResourceGathering.progress(character.world, MAP, &"vein_i")
	check_eq((stored.items as Array).map(func(v: Variant) -> int: return int(v)), plan.items, "the stored plan is the fixed one")
	var total := int(first.items)
	for i in node.steps - 1:
		total += int(ResourceGathering.complete_step(character, MAP, &"vein_i", node, 2000.0).items)
	check_eq(total, node.yield_quantity, "resumed: exactly the budget in total")


func test_save_load_before_the_last_step_and_a_single_bonus() -> void:
	var node: ResourceNodeDefinition = db.resource_nodes[&"oak_tree"]   # 3 steps
	var plan := ResourceGathering.make_plan(character, MAP, &"oak_s", node)
	for i in node.steps - 1:
		ResourceGathering.complete_step(character, MAP, &"oak_s", node, 1000.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved before the last step")
	for attempt in 2:   # the same save loaded twice: the same last step both times, never a re-roll
		var loaded := SaveSystem.load_from(PATH, db).character
		var before := loaded.inventory.count(&"timber")
		var last := ResourceGathering.complete_step(loaded, MAP, &"oak_s", node, 1000.0)
		check_eq(int(last.items), int(plan.items[node.steps - 1]), "load %d: the planned last step" % attempt)
		check(int(last.items) >= 1 and last.exhausted, "load %d: completion bonus and exhaustion" % attempt)
		var again := ResourceGathering.complete_step(loaded, MAP, &"oak_s", node, 1001.0)
		check(int(again.items) == 0 and String(again.error) != "", "load %d: the bonus is given once" % attempt)
		check_eq(loaded.inventory.count(&"timber") - before, int(plan.items[node.steps - 1]), "load %d: nothing more" % attempt)
		check(ResourceGathering.is_available(loaded.world, MAP, &"oak_s", 1000.0 + node.respawn_seconds), "load %d: respawns as before" % attempt)
