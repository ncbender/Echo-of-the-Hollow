extends TestCase
## Whisper Forest – Placed Enemy Target Fix 1.0 (docs/WHISPER_FOREST_TARGET_FIX.md): placed Grunts and
## the Grove Warden find the player (Player precedes Enemies in the scene), attack only inside their
## unchanged aggro/attack ranges, keep working after map changes and save/load; defeat, cache and
## values unchanged; encounter enemies and the Rootbound Sentinel unaffected. Real maps only.

const DIR := "user://test_saves/forest_target_fix"
const PROFILE := DIR + "/slot_1.save.json"
const WARDEN_ID := &"whisper_forest_grove_warden"
const GRUNTS: Array[String] = ["Enemies/GruntA", "Enemies/GruntB", "Enemies/GruntC"]
const PROLOGUE_QUESTS: Array[StringName] = [&"a_road_forgotten", &"the_broken_cart", &"shelter_among_the_trees",
	&"the_whispering_stone", &"the_first_binding"]

var db: GameDatabase
var session: SessionState
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	session.save_path = PROFILE
	session.saves.reset()
	_clean()


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	_clean()
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _clean() -> void:
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)


## Finished prologue, the_first_signs at `step` (east exit open, chapter maps reachable).
func _after_prologue(step: int = 0) -> Character:
	var character := CharacterFactory.create_new(db)
	for quest_id in PROLOGUE_QUESTS:
		var quest: StoryQuestDefinition = db.story_quests[quest_id]
		character.quests.entries[quest_id] = {"state": "completed", "step": quest.steps.size(), "progress": {}}
		if quest.completion_flag != &"":
			character.world.set_flag(quest.completion_flag)
	StoryService.start(character, &"the_first_signs")
	for event: StringName in [&"enter:tangled_wood", &"interact:tangled_roots", &"interact:chapel_waystone", &"enter:wardens_rest"].slice(0, step):
		StoryService.notify(character, event)
	return character


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


func _place(map: GameMap, at: Vector2) -> void:
	map.player.feed_input(InputFrame.new())   # stands still
	map.player.global_position = at
	map.player.reset_physics_interpolation()


## Waits up to `frames` physics frames for `enemy` to start an attack; true if it did.
func _attacks_within(enemy: Enemy, frames: int) -> bool:
	for i in frames:
		await get_tree().physics_frame
		if enemy.combat.state == CombatComponent.State.ATTACKING:
			return true
	return false


func _all_targets(map: GameMap) -> bool:
	for path in GRUNTS + ["Enemies/GroveWarden"]:
		var enemy := map.get_node_or_null(path) as Enemy
		if enemy != null and not enemy.is_queued_for_deletion() and enemy.target != map.player:
			return false
	return true


# --- target acquisition -------------------------------------------------------------------------

func test_placed_grunts_and_warden_target_the_player() -> void:
	session.set_character(CharacterFactory.create_new(db))
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	check(forest.get_node("Player").get_index() < forest.get_node("Enemies").get_index(), "Player precedes Enemies in the scene")
	for path in GRUNTS:
		check((forest.get_node(path) as Enemy).target == forest.player, "%s targets the player" % path)
	check((forest.get_node("Enemies/GroveWarden") as Enemy).target == forest.player, "the Grove Warden targets the player")


func test_no_player_no_invalid_target_access() -> void:
	var stage := Node2D.new()
	get_tree().root.add_child(stage)
	var grunt: Enemy = load("res://scenes/enemies/grunt.tscn").instantiate()
	stage.add_child(grunt)
	check(grunt.target == null, "no player in the tree: no target")
	var start := grunt.global_position
	for i in 30:
		grunt.physics_step(1.0 / 60.0)
	check(grunt.global_position.distance_to(start) < 0.01 and grunt.combat.state == CombatComponent.State.IDLE, "idle without a target")
	var gone := Node2D.new()
	stage.add_child(gone)
	grunt.target = gone
	gone.free()
	for i in 30:
		grunt.physics_step(1.0 / 60.0)
	check(grunt.combat.state == CombatComponent.State.IDLE, "a freed target is ignored, no error")
	stage.queue_free()
	await get_tree().process_frame


# --- ranges: no fight outside, a real fight inside ----------------------------------------------

func test_out_of_range_nothing_starts() -> void:
	session.set_character(CharacterFactory.create_new(db))
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	_place(forest, forest.find_spawn(&"from_home").global_position)
	var starts := {}
	for path in GRUNTS + ["Enemies/GroveWarden"]:
		var enemy := forest.get_node(path) as Enemy
		starts[path] = enemy.global_position
		check(forest.player.global_position.distance_to(enemy.global_position) > enemy.config.aggro_range, "%s out of reach at the Haven entrance" % path)
	for i in 120:
		await get_tree().physics_frame
	for path in starts:
		var enemy := forest.get_node(path) as Enemy
		check(enemy.global_position.distance_to(starts[path]) < 0.5 and enemy.combat.state == CombatComponent.State.IDLE, "%s stays put" % path)
	check(is_equal_approx(forest.player.health.health, forest.player.health.max_health), "no damage at the entrance")


func test_inside_range_grunt_and_warden_really_attack() -> void:
	session.set_character(CharacterFactory.create_new(db))
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var grunt := forest.get_node("Enemies/GruntB") as Enemy
	var start := grunt.global_position
	_place(forest, grunt.global_position + Vector2(-120, 0))   # inside aggro 260, outside attack range 28
	for i in 30:
		await get_tree().physics_frame
	check(grunt.global_position.distance_to(start) > 5.0, "the grunt closes in")
	var hp := forest.player.health.health
	check(await _attacks_within(grunt, 240), "the grunt attacks")
	for i in 90:
		await get_tree().physics_frame
	check(forest.player.health.health < hp, "the grunt's attack deals damage (%.0f -> %.0f)" % [hp, forest.player.health.health])
	# the Warden, alone: move the grunts out of the way first
	for path in GRUNTS:
		(forest.get_node(path) as Enemy).queue_free()
	forest.player.health.reset()
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	_place(forest, warden.global_position + Vector2(-60, -20))
	hp = forest.player.health.health
	check(await _attacks_within(warden, 240), "the Grove Warden attacks")
	for i in 90:
		await get_tree().physics_frame
	check(forest.player.health.health < hp, "the Warden's attack deals damage (%.0f -> %.0f)" % [hp, forest.player.health.health])


func test_east_exit_keeps_the_warden_calm_and_works() -> void:
	var character := _after_prologue()
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	var home := warden.global_position
	for at: Vector2 in [Vector2(290, -156), forest.find_spawn(&"from_tangled").global_position]:
		check(at.distance_to(home) > warden.config.aggro_range, "%s lies outside the Warden's aggro (%.0f px)" % [at, at.distance_to(home)])
	for path in GRUNTS:
		(forest.get_node(path) as Enemy).queue_free()   # only the Warden matters here
	_place(forest, Vector2(290, -156))
	for i in 120:
		await get_tree().physics_frame
	check(warden.global_position.distance_to(home) < 0.5 and warden.combat.state == CombatComponent.State.IDLE, "the Warden stays calm at the exit")
	var input := InputFrame.new()
	input.move = Vector2.RIGHT
	forest.player.feed_input(input)
	var wood := await _await_map(&"tangled_wood")
	check(wood != null, "the east exit still leads into the Tangled Wood")
	forest = await _travel(&"whisper_forest", &"from_tangled")
	if forest == null:
		return
	warden = forest.get_node("Enemies/GroveWarden") as Enemy
	_place(forest, forest.find_spawn(&"from_tangled").global_position)
	for i in 120:
		await get_tree().physics_frame
	check(warden.global_position.distance_to(home) < 0.5 and warden.combat.state == CombatComponent.State.IDLE, "arriving from the east does not wake the Warden")


# --- persistence ----------------------------------------------------------------------------------

func test_targets_after_map_change_and_save_load() -> void:
	session.set_character(CharacterFactory.create_new(db))
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	await _travel(&"home_base", &"from_forest")
	forest = await _travel(&"whisper_forest", &"from_home")
	check(_all_targets(forest), "targets after returning")
	check_eq(session.save_game(), OK, "saved in the forest")
	await _travel(&"home_base", &"from_forest")
	session.set_character(CharacterFactory.create_new(db))
	check(session.load_game().ok(), "loaded")
	forest = await _await_map(&"whisper_forest")
	if forest == null:
		return
	check(_all_targets(forest), "targets after loading")
	var grunt := forest.get_node("Enemies/GruntA") as Enemy
	_place(forest, grunt.global_position + Vector2(-40, 0))
	check(await _attacks_within(grunt, 240), "a grunt attacks after loading")


func test_defeated_warden_cache_and_values_unchanged() -> void:
	var character := CharacterFactory.create_new(db)
	session.set_character(character)
	var forest := await _travel(&"whisper_forest", &"from_home")
	if forest == null:
		return
	var warden := forest.get_node("Enemies/GroveWarden") as Enemy
	check(warden.config == load("res://data/enemies/grove_warden_config.tres") and warden.attacks == load("res://data/enemies/grove_warden_attacks.tres"),
		"Warden config and attacks unchanged")
	check_eq([warden.config.aggro_range, warden.config.move_speed, warden.config.rank], [260.0, 70.0, 2], "Warden aggro, speed, rank unchanged")
	check(is_equal_approx(warden.scale.x, 1.3) and warden.persistent_id == WARDEN_ID and warden.equipment_loot == null, "Warden scene values unchanged")
	for path in GRUNTS:
		var grunt := forest.get_node(path) as Enemy
		check(grunt.config == load("res://data/enemies/grunt_config.tres") and grunt.equipment_loot == load("res://data/loot/hollow_grunt_equipment.tres"),
			"%s config and loot unchanged" % path)
	var cache := forest.get_node("WardensCache") as BossRewardCache
	check(cache.loot_table == load("res://data/loot/grove_warden_rare_reward.tres") and cache.boss_id == WARDEN_ID, "cache unchanged")
	check(not cache.visible, "cache hidden before the kill")
	var lethal := HitData.new()
	lethal.damage = 1000000.0
	warden.health.apply_hit(lethal)
	for i in 5:
		await get_tree().process_frame
	check(character.world.has_flag(&"defeated.whisper_forest_grove_warden"), "defeat flag")
	check(cache.visible and BossRewardService.has_claim(character, WARDEN_ID), "cache open after the kill")
	await _travel(&"home_base", &"from_forest")
	forest = await _travel(&"whisper_forest", &"from_home")
	await get_tree().process_frame
	var again := forest.get_node_or_null("Enemies/GroveWarden")
	check(again == null or again.is_queued_for_deletion(), "the defeated Warden does not return")
	check(_all_targets(forest), "the grunts still target the player")


# --- regressions --------------------------------------------------------------------------------

func test_encounter_enemies_and_sentinel_unaffected() -> void:
	session.set_character(_after_prologue(1))
	var wood := await _travel(&"tangled_wood", &"from_forest")
	if wood == null:
		return
	var husks := wood.get_node("Encounters/PathHusks") as Encounter
	husks.start()
	check(not husks.enemies.is_empty() and husks.enemies.all(func(enemy: Enemy) -> bool: return enemy.target == wood.player), "encounter enemies target the player")
	session.set_character(_after_prologue(4))
	var rest := await _travel(&"wardens_rest", &"from_chapel")
	if rest == null:
		return
	var sentinel := rest.get_node("Enemies/RootboundSentinel") as Enemy
	check(sentinel.target == rest.player, "the Rootbound Sentinel targets the player")
	_place(rest, sentinel.global_position + Vector2(0, 26))
	check(await _attacks_within(sentinel, 180), "the Sentinel attacks")
