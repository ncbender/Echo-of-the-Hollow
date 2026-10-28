extends TestCase
## Chapter 1 "The Roots Remember" M3 (docs/ROOTS_REMEMBER_M3.md): Warden's Rest beyond the Chapel's
## east way, the one-time Rootbound Sentinel (slow, braced slam windup, exposed recovery), the Split
## Watchstone that exists only after its defeat, the_first_signs steps 3-5, saves on steps 0-3,
## resettle, boss reset/death/persistence. Real maps only through SessionState.travel().

const DIR := "user://test_saves/roots_m3"
const PROFILE := DIR + "/slot_1.save.json"
const QUEST := &"the_first_signs"
const EVENTS: Array[StringName] = [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone",
	&"enter:wardens_rest", &"interact:wardens_rest_watchstone"]
const REST := &"enter:wardens_rest"
const WATCHSTONE := &"interact:wardens_rest_watchstone"
const SENTINEL_ID := &"wardens_rest_rootbound_sentinel"
const DEFEATED := &"defeated.wardens_rest_rootbound_sentinel"
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]
## Counters and one-time flags a long-running save may carry (prologue, M1, M2, Grove Warden, trials).
const HISTORIC := {
	"count.enter:whisper_forest": 37, "count.enter:home_base": 21, "count.encounter:road_side_wolves": 5,
	"count.encounter:tangled_path_husks": 8, "count.encounter:chapel_yard": 6, "count.enter:chapel": 9,
	"count.trial_complete": 3, "count.waystone:whispering_stone": 3,
	"defeated.whisper_forest_grove_warden": true, "boss_reward.whisper_forest_grove_warden": true,
	"read.chapel_faded_note": true, "hint.chapel_east_way": true,
}

var db: GameDatabase
var session: SessionState
var _previous_character: Character
var _previous_path: String
var _critical_saves: int = 0


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = PROFILE
	session.saves.reset()
	_critical_saves = 0
	_clean()


func after_each() -> void:
	if session.saves.save_started.is_connected(_on_save_started):
		session.saves.save_started.disconnect(_on_save_started)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	var paths := SaveSlots.all_paths(PROFILE)
	paths.append(DIR + "/roundtrip.save.json")
	for path in paths:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


func _on_save_started(kind: SaveCoordinator.Kind) -> void:
	if kind == SaveCoordinator.Kind.CRITICAL:
		_critical_saves += 1


## Finished prologue (class chosen, Edrin reward pending, Mara reward claimed), the_first_signs at `step`.
func _character_at(step: int) -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
		for quest_step in quest.steps:
			if quest_step.completion_flag != &"":
				character.world.set_flag(quest_step.completion_flag)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	character.prologue.completed_trials = [&"trial_arcanist"] as Array[StringName]
	character.prologue.chosen_class = &"arcanist"
	character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	character.world.set_flag(QuestRewardService.claimed_flag(&"the_broken_cart"))
	StoryService.start(character, QUEST)
	if step >= 5:
		character.world.set_flag(DEFEATED)
	for event: StringName in EVENTS.slice(0, step):
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, step), "set up at step %d" % step)
	return character


func _load_payload(payload: Dictionary) -> Character:
	var path := DIR + "/roundtrip.save.json"
	check_eq(SaveSystem.write_payload(payload, path), OK, "payload written")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded %s" % [loaded.errors])
	return loaded.character


func _step_text(character: Character) -> String:
	var step := StoryService.current_step(character, QUEST)
	return step.description if step != null else ""


func _untouched_state(character: Character) -> void:
	check_eq(character.prologue.chosen_class, &"arcanist", "class choice kept")
	check_eq(character.prologue.completed_trials, [&"trial_arcanist"] as Array[StringName], "trials kept")
	check_eq(QuestRewardService.state(character, &"the_first_binding"), QuestRewardService.PENDING, "Edrin reward pending")
	check_eq(QuestRewardService.state(character, &"the_broken_cart"), QuestRewardService.CLAIMED, "Mara reward claimed")
	check_eq(QuestRewardService.state(character, QUEST), QuestRewardService.NONE, "no reward for the_first_signs")
	for waystone_id: StringName in [&"chapel_waystone", &"wardens_rest"]:
		check(not WaystoneService.is_active(character, waystone_id) and not character.world.has_flag(StringName("waystone.%s" % waystone_id)),
			"%s not awake" % waystone_id)
	check(not StoryService.is_completed(character, QUEST), "quest never completes")


func _travel(map_id: StringName, spawn_id: StringName) -> GameMap:
	check(session.travel(map_id, spawn_id, false), "travel to %s accepted" % map_id)
	return await _await_map(map_id)


func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _walk(map: GameMap, from: Vector2, direction: Vector2) -> void:
	map.player.global_position = from
	map.player.reset_physics_interpolation()
	var input := InputFrame.new()
	input.move = direction
	map.player.feed_input(input)


func _blocked_at(map: GameMap, at: Vector2) -> Array:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	query.shape = circle
	query.transform = Transform2D(0.0, at)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hits := map.get_world_2d().direct_space_state.intersect_shape(query)
	return hits.filter(func(hit: Dictionary) -> bool: return hit.collider is StaticBody2D)


func _sentinel(map: GameMap) -> Enemy:
	var node := map.get_node_or_null("Enemies/RootboundSentinel") as Enemy
	return node if node != null and not node.is_queued_for_deletion() else null


func _watchstone(map: GameMap) -> Readable:
	return map.get_node("AfterSentinel/SplitWatchstone") as Readable


func _kill(enemy: Enemy) -> void:
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	enemy.health.apply_hit(lethal)


func _poise_hit(enemy: Enemy, poise: float) -> void:
	var hit := HitData.new()
	hit.damage = 0.0
	hit.poise_damage = poise
	hit.knockback = Vector2.ZERO
	enemy.hurtbox.receive_hit(hit)


## The player stands still next to the Sentinel; returns once it starts the requested attack.
func _provoke(map: GameMap, sentinel: Enemy, heavy: bool) -> bool:
	map.player.feed_input(InputFrame.new())
	map.player.global_position = sentinel.global_position + Vector2(0, 26)
	map.player.reset_physics_interpolation()
	sentinel._attacks_started = 1 if heavy else 0   # interval 2: the next attack is heavy / light
	sentinel._cooldown = 0.0
	for i in 120:
		await get_tree().physics_frame
		if sentinel.combat.state == CombatComponent.State.ATTACKING:
			return (sentinel.combat.current_attack.input_type == AttackDefinition.InputType.HEAVY) == heavy
	return false


# --- data ---------------------------------------------------------------------------------------

func test_quest_extends_from_index_three() -> void:
	check(StoryService.validate_data(db).is_empty(), "story data valid: %s" % [StoryService.validate_data(db)])
	check(db.load_errors.is_empty(), "database errors: %s" % [db.load_errors])
	var quest: StoryQuestDefinition = db.story_quests[QUEST]
	var steps := quest.steps
	check_eq(steps.size(), 6, "M1 (0, 1), M2 (2), M3 (3, 4), M4 placeholder (5)")
	for index in 3:
		check_eq(steps[index].objectives[0].event_id, EVENTS[index], "step %d unchanged" % index)
	check_eq([steps[0].completion_flag, steps[1].completion_flag, steps[2].completion_flag],
		[&"chapter1.tangled_wood_reached", &"chapter1.roots_examined", &"chapter1.chapel_waystone_examined"], "earlier flags unchanged")
	var rest := steps[3].objectives
	check(rest.size() == 1 and rest[0].event_id == REST and not rest[0].cumulative, "step 3: reach Warden's Rest, counted live")
	var post := steps[4].objectives
	check(post.size() == 1 and post[0].event_id == WATCHSTONE and post[0].cumulative and post[0].amount == 1,
		"step 4: one-time watchstone examination (new id, cumulative)")
	check_eq([steps[3].completion_flag, steps[4].completion_flag], [&"chapter1.wardens_rest_reached", &"chapter1.watchstone_examined"], "M3 flags")
	check(steps[5].objectives.size() == 1 and steps[5].description.contains("Edrin"),
		"step 5: back to Edrin (M4 gives it its report objective)")
	check(not QuestRewardService.has_reward(quest) and quest.next_quest_ids.size() <= 1, "no reward, at most one successor")
	for other: StoryQuestDefinition in db.story_quests.values():
		if other.id == QUEST:
			continue
		for step in other.steps:
			for objective in step.objectives:
				check(not objective.event_id in [REST, WATCHSTONE], "%s does not use the M3 events" % other.id)


func test_sentinel_data_from_existing_references() -> void:
	var sentinel: EnemyConfig = load("res://data/enemies/rootbound_sentinel.tres")
	var guardian: EnemyConfig = load("res://data/enemies/bastion_guardian.tres")
	var husk: EnemyConfig = load("res://data/enemies/hardened_husk.tres")
	var warden: EnemyConfig = load("res://data/enemies/grove_warden_config.tres")
	check(sentinel.move_speed < guardian.move_speed and sentinel.move_speed < warden.move_speed, "slower than Guardian and Warden")
	check(sentinel.max_health > guardian.max_health and sentinel.max_health <= guardian.max_health * 1.5, "tougher than the Guardian, no jump")
	check(sentinel.max_poise >= guardian.max_poise, "heavy poise")
	check(sentinel.braced_poise_taken < 1.0 and sentinel.recovery_cue, "braces and shows its recovery")
	for config: EnemyConfig in [guardian, husk, warden, load("res://data/enemies/rootbound_husk.tres"), load("res://data/enemies/grunt_config.tres")]:
		check(is_equal_approx(config.braced_poise_taken, 1.0) and not config.recovery_cue, "%s: no bracing, no cue (unchanged)" % config.id)
	var fixed := {}
	for drop in sentinel.drops:
		fixed[drop.item_id] = drop.quantity
	var husk_drops := {}
	for drop in husk.drops:
		husk_drops[drop.item_id] = drop.quantity
	check_eq(fixed, husk_drops, "regular Hardened Husk drops, no special reward")
	var family: WeaponFamily = load("res://data/enemies/sentinel_attacks.tres")
	check(family.validate().is_empty(), "family valid: %s" % [family.validate()])
	var slam := family.get_attack(family.root_heavy)
	var strike := family.get_attack(family.root_light)
	var warden_slam := (load("res://data/enemies/grove_warden_attacks.tres") as WeaponFamily).get_attack(&"warden_slam")
	check(slam.startup > warden_slam.startup and slam.recovery > warden_slam.recovery, "longer windup and recovery than the Warden's slam")
	check(slam.damage <= warden_slam.damage * 1.2, "slam damage close to existing heavies")
	check_eq(slam.uninterruptible_phases, 1, "braced only in the windup")
	check_eq(strike.uninterruptible_phases, 0, "the light strike is never braced")
	check(slam.defense_flags != 0, "the slam is blockable (no unblockable surprise)")


# --- quest flow and saves -----------------------------------------------------------------------

func test_saves_on_steps_0_to_3_keep_their_step() -> void:
	for step in 4:
		var payload := _character_at(step).to_dict()
		var flags: Dictionary = (payload.world as Dictionary).flags
		for flag: String in HISTORIC:
			flags[flag] = HISTORIC[flag]
		for index in step:
			flags["count." + String(EVENTS[index])] = 3
		var loaded := _load_payload(payload)
		if loaded == null:
			return
		check(StoryService.at_step(loaded, QUEST, step), "save on step %d loads on step %d" % [step, step])
		for i in 3:
			check(StoryService.resettle(loaded).is_empty(), "step %d: resettle %d moves nothing" % [step, i])
		check(StoryService.at_step(loaded, QUEST, step), "no skip by historic counters (step %d)" % step)
		_untouched_state(loaded)
		for event: StringName in EVENTS.slice(step, 4):
			StoryService.notify(loaded, event)
		check(StoryService.at_step(loaded, QUEST, 4), "step %d save reaches the Sentinel step" % step)


func test_defeat_before_or_after_the_step_never_soft_locks() -> void:
	# the watchstone examined while the quest still waited for the arrival (counted, cumulative)
	var early := _character_at(3)
	early.world.set_flag(DEFEATED)
	StoryService.notify(early, WATCHSTONE)
	check(StoryService.at_step(early, QUEST, 3), "step 3 still waits for the arrival")
	StoryService.notify(early, REST)
	check(StoryService.at_step(early, QUEST, 5), "the earlier examination counts: straight to step 5")
	# and the same over a save made in between
	var behind := _character_at(4)
	var payload := behind.to_dict()
	(payload.world as Dictionary).flags[String(DEFEATED)] = true
	(payload.world as Dictionary).flags["count." + String(WATCHSTONE)] = 1
	var loaded := _load_payload(payload)
	check(StoryService.at_step(loaded, QUEST, 5), "resettle catches up a counted examination")
	# the defeat flag alone never moves the story (the find does)
	var killed := _character_at(4)
	killed.world.set_flag(DEFEATED)
	check(StoryService.resettle(killed).is_empty() and StoryService.at_step(killed, QUEST, 4), "no progress without the find")


func test_step_five_is_open_and_settles_once() -> void:
	var character := _character_at(4)
	character.world.set_flag(DEFEATED)
	var progressed: Array = []
	character.quests.story_progressed.connect(func(id: StringName, step: int, finished: bool) -> void: progressed.append([id, step, finished]))
	for event: StringName in [REST, &"enter:chapel", &"interact:chapel_waystone", &"encounter:chapel_yard"]:
		StoryService.notify(character, event)
	check(StoryService.at_step(character, QUEST, 4), "only the watchstone finishes step 4")
	for i in 3:
		StoryService.notify(character, WATCHSTONE)
		check(StoryService.resettle(character).is_empty(), "resettle %d" % i)
	check(StoryService.at_step(character, QUEST, 5), "step 5")
	check_eq(progressed, [[QUEST, 5, false]], "one live step event, no completion")
	check(character.world.has_flag(&"chapter1.watchstone_examined"), "flag")
	var lines := StoryService.tracker_lines(character)
	check(lines.size() == 2 and lines[1].contains("Edrin"), "tracker: headline + Edrin hint %s" % [lines])
	_untouched_state(character)


# --- real maps ----------------------------------------------------------------------------------

func test_route_topology_behind_the_gates() -> void:
	var map_def: MapDefinition = db.maps.get(&"wardens_rest")
	if not check(map_def != null, "map definition"):
		return
	check_eq([map_def.region_id, map_def.map_cell, map_def.display_name], [&"hollow_outskirts", Vector2i(4, 1), "Warden's Rest"], "map data")
	check(&"wardens_rest" in (db.maps[&"chapel"] as MapDefinition).neighbors, "world map: chapel -> rest")
	var stone: WaystoneDefinition = db.waystones[&"wardens_rest"]
	check(not stone.available and stone.map_id == &"", "Warden's Rest waystone definition unchanged")
	var ways: Array = []
	for other: MapDefinition in db.maps.values():
		var scene: GameMap = load(other.scene_path).instantiate()
		for transition: MapTransition in scene.find_children("*", "MapTransition", true, false):
			if transition.target_map_id == &"wardens_rest":
				var gate := transition.get_parent() as StoryConditional
				ways.append([other.id, gate.condition.required_flags if gate != null and gate.condition != null else []])
		if other.id == &"wardens_rest":
			check(scene.find_children("*", "Waystone", true, false).is_empty(), "no Waystone node")
			check(scene.find_children("*", "BossRewardCache", true, false).is_empty(), "no reward cache")
		scene.free()
	check_eq(ways, [[&"chapel", [&"chapter1.chapel_waystone_examined"] as Array[StringName]]],
		"reached only from the Chapel, behind the waystone examination (the Chapel itself only behind the prologue gate)")


func test_chapel_way_opens_after_the_waystone_and_both_ways_work() -> void:
	var character := _character_at(2)
	session.set_character(character)
	var chapel := await _travel(&"chapel", &"from_tangled")
	if chapel == null:
		return
	check(not (chapel.get_node("OpenEast/ToWardensRest") as MapTransition).can_process(), "closed before the waystone")
	(chapel.get_node("ChapelWaystone") as Readable).interact(chapel.hud)
	chapel.hud.close_windows()
	for i in 3:
		await get_tree().physics_frame
	check(not chapel.get_node("SealedEast").visible, "roots gone")
	check((chapel.get_node("OpenEast/ToWardensRest") as MapTransition).can_process(), "open after the waystone")
	_walk(chapel, Vector2(290, -162), Vector2.RIGHT)
	var rest := await _await_map(&"wardens_rest")
	if rest == null:
		return
	check(rest.player.global_position.distance_to(rest.find_spawn(&"from_chapel").global_position) < 1.0, "arrived at the old access")
	check(StoryService.at_step(character, QUEST, 4), "arrival finished step 3")
	_walk(rest, Vector2(-300, 0), Vector2.LEFT)
	chapel = await _await_map(&"chapel")
	if chapel == null:
		return
	check(chapel.player.global_position.distance_to(chapel.find_spawn(&"from_wardens_rest").global_position) < 1.0, "back at the chapel's east way")
	await _travel(&"wardens_rest", &"from_chapel")
	await _travel(&"chapel", &"from_wardens_rest")
	check(StoryService.at_step(character, QUEST, 4), "repeated changes: still step 4")
	check_eq(StoryService.counter(character, REST), 2, "two arrivals counted")


func test_spawns_free_no_false_prompts_and_safe_arrival() -> void:
	session.set_character(_character_at(4))
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	for i in 30:
		await get_tree().physics_frame
	var sentinel := _sentinel(rest)
	if not check(sentinel != null, "the Sentinel waits"):
		return
	check(sentinel.target == rest.player, "the Sentinel targets the player (Player precedes Enemies in the scene)")
	for point: SpawnPoint in rest.find_children("*", "SpawnPoint", true, false):
		check(_blocked_at(rest, point.global_position).is_empty(), "spawn %s free" % point.spawn_id)
		check(point.global_position.distance_to(sentinel.global_position) > sentinel.config.aggro_range + 100.0, "spawn %s far from the Sentinel" % point.spawn_id)
	check(Interactable.find_active(get_tree()) == null, "no prompt at the arrival")
	check(sentinel.velocity.length() < 0.1 and sentinel.combat.state == CombatComponent.State.IDLE, "the Sentinel does not wake on arrival")
	var gate := Vector2(-110, 0)
	check(gate.distance_to(sentinel.global_position) > sentinel.config.aggro_range, "passing the gate does not wake it either")
	var exit := rest.get_node("ToChapel") as MapTransition
	check(exit.global_position.distance_to(Vector2(-90, 0)) > 200.0, "the exit lies well away from the arena edge")
	var visible: Array = []
	for node in get_tree().get_nodes_in_group(&"interactable"):
		if (node as Interactable).is_visible_in_tree():
			visible.append(String((node as Node).name))
	check_eq(visible, ["ScratchedTally"], "before the defeat only the optional tally can be used")
	check(not _watchstone(rest).is_visible_in_tree() and not _watchstone(rest).can_process(), "the watchstone find waits for the defeat")
	for name: String in ["ScratchedTally", "AfterSentinel/SplitWatchstone"]:
		check(_blocked_at(rest, rest.get_node(name).global_position).is_empty(), "%s reachable" % name)


func test_telegraph_brace_and_recovery() -> void:
	session.set_character(_character_at(4))
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := _sentinel(rest)
	if not check(sentinel != null, "Sentinel"):
		return
	var view := sentinel.get_node("View")
	check(await _provoke(rest, sentinel, true), "the slam starts")
	var startup := 0
	var braced := true
	while sentinel.combat.state == CombatComponent.State.ATTACKING and sentinel.combat.phase == CombatComponent.Phase.STARTUP:
		startup += 1
		braced = braced and sentinel.is_braced() and sentinel.state == Enemy.State.TELEGRAPH
		await get_tree().physics_frame
	check(startup >= 54 and startup <= 66, "slam windup about 1 s (%d frames)" % startup)
	check(braced, "braced and telegraphed through the whole windup")
	while sentinel.combat.phase == CombatComponent.Phase.ACTIVE:
		await get_tree().physics_frame
	var at := sentinel.global_position
	var recovery := 0
	var exposed := true
	while sentinel.combat.state == CombatComponent.State.ATTACKING and sentinel.combat.phase == CombatComponent.Phase.RECOVERY:
		recovery += 1
		exposed = exposed and view.is_exposed() and not sentinel.is_braced()
		await get_tree().physics_frame
	check(recovery >= 72 and recovery <= 84, "recovery about 1.3 s (%d frames)" % recovery)
	check(exposed, "exposed, not braced, during the recovery")
	check(sentinel.global_position.distance_to(at) < 1.0, "stands still while it recovers")
	check(not view.is_exposed(), "the cue ends with the recovery")
	# the light strike is never braced
	check(await _provoke(rest, sentinel, false), "the strike starts")
	check(not sentinel.is_braced(), "light windup not braced")
	check(not view.is_exposed(), "no exposed cue for light attacks")


func test_braced_windup_is_harder_but_not_impossible_to_break() -> void:
	session.set_character(_character_at(4))
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := _sentinel(rest)
	if not check(sentinel != null, "Sentinel"):
		return
	rest.player.global_position = Vector2(-280, 0)   # far away: idle
	rest.player.reset_physics_interpolation()
	await get_tree().physics_frame
	var poise := sentinel.health.poise
	_poise_hit(sentinel, 20.0)
	check(is_equal_approx(poise - sentinel.health.poise, 20.0), "idle: full poise damage (%.1f)" % (poise - sentinel.health.poise))
	sentinel.health.reset()
	check(await _provoke(rest, sentinel, true), "the slam starts")
	poise = sentinel.health.poise
	_poise_hit(sentinel, 20.0)
	check(is_equal_approx(poise - sentinel.health.poise, 20.0 * sentinel.config.braced_poise_taken), "braced: reduced poise damage (%.1f)" % (poise - sentinel.health.poise))
	check(sentinel.combat.state == CombatComponent.State.ATTACKING, "a normal hit does not stop the braced slam")
	_poise_hit(sentinel, sentinel.config.max_poise / sentinel.config.braced_poise_taken + 1.0)
	check(sentinel.state == Enemy.State.STAGGERED and sentinel.combat.state != CombatComponent.State.ATTACKING, "enough poise still breaks it")


func test_one_time_defeat_milestone_find_and_no_respawn() -> void:
	var character := _character_at(4)
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := _sentinel(rest)
	if not check(sentinel != null, "Sentinel"):
		return
	check_eq(sentinel.persistent_id, SENTINEL_ID, "persistent id")
	check(sentinel.equipment_loot == null, "no equipment roll")
	session.saves.save_started.connect(_on_save_started)
	_kill(sentinel)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(DEFEATED), "defeat flag")
	check_eq(_critical_saves, 1, "one milestone save after the kill")
	check(StoryService.at_step(character, QUEST, 4), "the kill alone moves no step")
	var written := SaveSystem.load_from(str(session.saves.last_result.get("path", "")), db)
	check(written.ok() and written.character.world.has_flag(DEFEATED), "the milestone save holds the defeat")
	sentinel.defeated.emit(sentinel)
	_kill(sentinel)
	for i in 5:
		await get_tree().process_frame
	check_eq(_critical_saves, 1, "repeated death signals: no second save")
	var stone := _watchstone(rest)
	check(stone.is_visible_in_tree(), "the watchstone find appears")
	check_eq(stone.prompt, "Examine Split Watchstone", "prompt")
	check(stone.rewards.is_empty(), "no reward")
	for i in 3:
		stone.interact(rest.hud)
	rest.hud.close_windows()
	check(StoryService.at_step(character, QUEST, 5), "step 5")
	check_eq(StoryService.counter(character, WATCHSTONE), 1, "one event for three examinations")
	for i in 5:
		await get_tree().process_frame
	check_eq(_critical_saves, 2, "the step is the second milestone")
	# later visits and loading: no respawn, the find stays
	await _travel(&"chapel", &"from_wardens_rest")
	rest = await _travel(&"wardens_rest", &"from_chapel")
	await get_tree().process_frame
	check(_sentinel(rest) == null, "no respawn on a later visit")
	check(_watchstone(rest).is_visible_in_tree(), "the find stays")
	check_eq(session.save_game(), OK, "saved in Warden's Rest")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	rest = await _await_map(&"wardens_rest")
	if rest == null:
		return
	await get_tree().process_frame
	check(_sentinel(rest) == null, "no respawn after loading")
	check(StoryService.at_step(session.character, QUEST, 5), "progress restored")
	_watchstone(rest).interact(rest.hud)
	check_eq(StoryService.counter(session.character, WATCHSTONE), 1, "no second event after loading")
	check(not session.character.world.has_flag(&"defeated.whisper_forest_grove_warden"), "the Grove Warden is untouched")
	_untouched_state(session.character)


func test_reset_on_leaving_and_player_death_before_the_kill() -> void:
	var character := _character_at(4)
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := _sentinel(rest)
	var hurt := HitData.new()
	hurt.damage = 120.0
	sentinel.health.apply_hit(hurt)
	check(sentinel.health.health < sentinel.health.max_health, "wounded")
	# player death: respawn in place, no flag, the Sentinel stays (existing rule: no reset on death)
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	rest.player.health.apply_hit(lethal)
	for i in 120:
		await get_tree().physics_frame
	check(not rest.player.health.is_dead(), "the player rose again")
	check(not character.world.has_flag(DEFEATED), "death sets no defeat flag")
	check(_sentinel(rest) != null, "the Sentinel is still there")
	# leaving alive: a fresh Sentinel on return
	await _travel(&"chapel", &"from_wardens_rest")
	rest = await _travel(&"wardens_rest", &"from_chapel")
	var fresh := _sentinel(rest)
	check(fresh != null and is_equal_approx(fresh.health.health, fresh.health.max_health), "reset to full health after leaving")
	check(not character.world.has_flag(DEFEATED), "still undefeated")
	check(not _watchstone(rest).is_visible_in_tree(), "no find without the defeat")
	# save/load before the kill: the Sentinel is back
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	rest = await _await_map(&"wardens_rest")
	check(rest != null and _sentinel(rest) != null, "the undefeated Sentinel is restored")


func test_defeat_before_the_quest_step_in_the_scene() -> void:
	var character := _character_at(3)
	character.world.set_flag(DEFEATED)   # e.g. an older state that already holds the defeat
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	await get_tree().process_frame
	check(StoryService.at_step(character, QUEST, 4), "arrival: step 4")
	check(_sentinel(rest) == null, "no Sentinel when the flag is set")
	var stone := _watchstone(rest)
	check(stone.is_visible_in_tree(), "the find is there at once")
	stone.interact(rest.hud)
	check(StoryService.at_step(character, QUEST, 5), "no soft-lock: step 5")


func test_optional_tally_is_only_flavour() -> void:
	var character := _character_at(4)
	session.set_character(character)
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var tally := rest.get_node("ScratchedTally") as Readable
	check(tally.event_id == &"" and tally.rewards.is_empty(), "no event, no reward")
	tally.interact(rest.hud)
	check(tally.is_read() and StoryService.at_step(character, QUEST, 4), "read, no progress")
