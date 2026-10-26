extends TestCase
## Prologue part 1 on the real Old Road map: New Game start, triggers and
## tutorial hints, encounters with the enemy variants, Mara (dialogue, bark,
## combat support, escort follow incl. recovery), the two supply crates (no
## duplication), the second wave, save/load in the middle of it, the road to
## Haven and the road staying open after the prologue.

const DIR := "user://test_saves/old_road"
const PROFILE := DIR + "/slot_1.save.json"

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE) + [DIR + "/mid.save.json"]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _open(map_id: StringName, spawn_id: StringName = &"") -> GameMap:
	if spawn_id != &"":
		character.world.map_id = map_id
		character.world.spawn_id = spawn_id
	session.travel(map_id, spawn_id if spawn_id != &"" else character.world.spawn_id, false)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			return current
	fail("map %s not loaded" % map_id)
	return null


func _go(at: Vector2, frames: int = 3) -> void:
	map.player.global_position = at
	map.player.reset_physics_interpolation()
	for i in frames:
		await get_tree().physics_frame


func _node(path: String) -> Node:
	return map.get_node(path)


func _kill(encounter: Encounter) -> void:
	for enemy in encounter.enemies:
		if is_instance_valid(enemy) and enemy.state != Enemy.State.DEAD:
			var hit := HitData.new()
			hit.damage = 9999.0
			enemy.hurtbox.receive_hit(hit)
	await get_tree().physics_frame


func _talk(npc: StoryNpc) -> void:
	npc.interact(map.hud)
	var guard := 0
	while map.hud.dialogue_panel.visible and guard < 20:
		map.hud.dialogue_panel.advance()
		guard += 1


## Story events up to the cart fight, without walking the road.
func _skip_to_cart() -> void:
	for event: StringName in [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site"]:
		StoryService.notify(character, event)
	character.world.set_flag(&"encounter.road_ambush")


func test_new_game_starts_on_the_old_road() -> void:
	check_eq(character.world.map_id, &"old_road", "new journeys start on the Old Road")
	session.new_game()
	for i in 240:
		await get_tree().process_frame
		if get_tree().current_scene is GameMap and not session.is_traveling():
			break
	map = get_tree().current_scene as GameMap
	if not check(map != null and map.map_id == &"old_road", "Old Road loaded by New Game"):
		return
	character = session.character
	check_eq(character.classes.active_class_id, &"basic_adventurer", "Basic Adventurer")
	check(map.player.global_position.y > 500.0, "starts at the southern end")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(map.hud.current_hint().contains("WASD"), "movement hint: %s" % map.hud.current_hint())
	check(not (_node("Mara") as StoryNpc).visible, "Mara is not on the road yet")


func test_road_triggers_and_first_fight() -> void:
	if await _open(&"old_road", &"default") == null:
		return
	await _go(Vector2(0, 420))
	check(StoryService.at_step(character, &"a_road_forgotten", 1), "signpost reached")
	check(map.hud.has_hint("Press G"), "interact hint")
	var ambush := _node("Encounters/RoadAmbush") as Encounter
	check(not ambush.running, "ambush not started yet")
	await _go(Vector2(0, 160))
	check(ambush.running and ambush.enemies.size() == 2, "ambush started")
	check_eq(ambush.enemies[0].config.display_name, "Rootbound Husk", "variant config")
	check_eq(ambush.enemies[0].health.max_health, 70.0, "variant health")
	check(map.hud.has_hint("Click LMB"), "attack hint")
	await _kill(ambush)
	check(StoryService.at_step(character, &"a_road_forgotten", 2), "road cleared")
	check(character.world.has_flag(&"encounter.road_ambush"), "persistent encounter cleared")
	await _go(Vector2(0, -70))
	check_eq(character.world.spawn_id, &"rest", "rest area is the new respawn point")
	await _go(Vector2(0, -225))
	check(StoryService.at_step(character, &"the_broken_cart", 0), "cart reached: next quest")
	check((_node("Mara") as StoryNpc).visible, "Mara at her cart")


func test_cart_sequence_with_mara() -> void:
	_skip_to_cart()
	if await _open(&"old_road", &"rest") == null:
		return
	var mara := _node("Mara") as CompanionNpc
	var attack := _node("Encounters/CartAttack") as Encounter
	await _go(Vector2(0, -300))
	check(attack.running, "cart fight starts")
	check_eq(mara.current_bark(), "If you've got a blade, now's the time to use it!", "Mara's call")
	check(map.hud.has_hint("Hold RMB to charge a heavy attack. Release to strike."), "heavy attack hint")
	check(mara.is_supporting(), "Mara helps in the fight")
	var target: Enemy = attack.enemies[0]
	target.global_position = mara.global_position + Vector2(30, 0)
	var health_before := target.health.health
	for i in 200:
		await get_tree().physics_frame
		if mara.strikes > 0:
			break
	check(mara.strikes > 0 and target.health.health < health_before, "Mara strikes through the hit pipeline")
	await _kill(attack)
	check(StoryService.at_step(character, &"the_broken_cart", 1), "fight won")
	_talk(mara)
	check(StoryService.at_step(character, &"the_broken_cart", 2), "talked to Mara")
	check(character.world.has_flag(&"prologue.mara_rescued"), "flag mara_rescued")
	var west := _node("CrateWest") as StoryPickup
	var south := _node("CrateSouth") as StoryPickup
	check(west.visible and south.visible, "crates appear")
	check_eq(west.take(), "", "first crate")
	check_eq(west.take(), "Nothing to recover.", "no second take")
	check_eq(character.inventory.count(&"supply_crate"), 1, "one crate item")
	check_eq(south.take(), "", "second crate")
	check_eq(character.inventory.count(&"supply_crate"), 2, "exactly two crate items")
	check(StoryService.at_step(character, &"the_broken_cart", 3), "second wave step")
	var wave := _node("Encounters/SecondWave") as Encounter
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(wave.running and wave.enemies.size() == 3, "second wave starts at once")
	var names: Array = wave.enemies.map(func(e: Enemy) -> String: return e.config.display_name)
	check(names.has("Hardened Husk") and names.has("Hollowfang Wolf"), "wave variants %s" % [names])
	await _kill(wave)
	check(StoryService.at_step(character, &"the_broken_cart", 4), "wave survived")
	var debris := _node("NorthDebris") as StoryConditional
	check(debris.visible, "road north still blocked")
	_talk(mara)
	check(StoryService.at_step(character, &"shelter_among_the_trees", 0), "on to Haven")
	await get_tree().process_frame
	check(not debris.visible and debris.process_mode == Node.PROCESS_MODE_DISABLED, "debris gone")
	check(mara.is_following(), "Mara follows")
	check(not mara.is_supporting(), "no more fighting")


func test_escort_follow_never_sticks_and_recovers_once() -> void:
	_skip_to_cart()
	for event: StringName in [&"encounter:cart_attack", &"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate",
			&"encounter:cart_second_wave", &"talk:mara_road_end"]:
		StoryService.notify(character, event)
	if await _open(&"old_road", &"rest") == null:
		return
	var mara := _node("Mara") as CompanionNpc
	check(mara.is_following(), "following after loading the map")
	await get_tree().physics_frame
	check(mara.global_position.distance_to(map.player.global_position) < CompanionNpc.RECOVER_DISTANCE, "Mara starts near the player")
	var largest := 0.0
	for i in 120:   # walk north at normal speed
		map.player.global_position += Vector2(0, -3)
		await get_tree().physics_frame
		largest = maxf(largest, mara.global_position.distance_to(map.player.global_position))
	check(largest < 90.0, "keeps up while walking (max gap %.0f px)" % largest)
	check_eq(mara.recoveries, 0, "no catch-up needed while walking")
	map.player.global_position += Vector2(0, 600)   # far away (simulates a stuck or lost companion)
	for i in 150:
		await get_tree().physics_frame
	check_eq(mara.recoveries, 1, "one recovery")
	check(mara.global_position.distance_to(map.player.global_position) < 60.0, "back behind the player")
	for i in 120:
		await get_tree().physics_frame
	check_eq(mara.recoveries, 1, "no teleport spam")
	await _go(Vector2(0, -694), 4)
	for i in 240:
		await get_tree().process_frame
		if get_tree().current_scene is GameMap and (get_tree().current_scene as GameMap).map_id == &"home_base" and not session.is_traveling():
			break
	map = get_tree().current_scene as GameMap
	check(map != null and map.map_id == &"home_base", "the player alone decides the transition")
	check(StoryService.at_step(character, &"shelter_among_the_trees", 1), "Haven discovered")
	check((_node("Mara") as StoryNpc).visible, "Mara is in Haven")
	await get_tree().process_frame
	await get_tree().process_frame
	check(SaveSlots.latest(PROFILE).get("meta", {}).get("kind") == "milestone", "arrival is a milestone save")


func test_save_and_load_in_the_middle_of_the_cart() -> void:
	_skip_to_cart()
	for event: StringName in [&"encounter:cart_attack", &"talk:mara_cart"]:
		StoryService.notify(character, event)
	character.world.set_flag(&"encounter.cart_attack")
	if await _open(&"old_road", &"rest") == null:
		return
	check_eq((_node("CrateWest") as StoryPickup).take(), "", "one crate taken")
	var path := DIR + "/mid.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved between the crates")
	var loaded := SaveSystem.load_from(path, db)
	check(loaded.ok(), "loaded")
	character = loaded.character
	session.set_character(character)
	if await _open(&"old_road", &"rest") == null:
		return
	check(not (_node("CrateWest") as StoryPickup).visible, "taken crate stays taken")
	check((_node("CrateSouth") as StoryPickup).visible, "the other crate is still there")
	check_eq(character.inventory.count(&"supply_crate"), 1, "exactly one crate in the pack")
	check((_node("Mara") as CompanionNpc).visible and not (_node("Mara") as CompanionNpc).is_following(), "Mara waits at the cart")
	check(not (_node("Encounters/CartAttack") as Encounter).can_start(), "cleared fight does not return")
	check_eq((_node("CrateSouth") as StoryPickup).take(), "", "second crate")
	check(StoryService.at_step(character, &"the_broken_cart", 3), "continues normally")


func test_note_reward_once_and_side_path() -> void:
	if await _open(&"old_road", &"rest") == null:
		return
	var note := _node("Note") as Readable
	var gold := character.inventory.count(&"gold_coin")
	note.interact(map.hud)
	check_eq(map.hud.dialogue_panel.current_text(), "Third shipment delayed. Mara went ahead before sunrise.", "note text")
	check_eq(character.inventory.count(&"gold_coin"), gold + 12, "small reward")
	map.hud.dialogue_panel.advance()
	note.interact(map.hud)
	check_eq(character.inventory.count(&"gold_coin"), gold + 12, "reward only once")
	var wolves := _node("Encounters/SideWolves") as Encounter
	await _go(Vector2(-430, -60))
	check(wolves.running, "optional wolves")
	await _kill(wolves)
	await get_tree().physics_frame
	check(not wolves.running and not wolves.can_start(), "cleared for this visit")


func test_road_stays_open_after_the_prologue() -> void:
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate({"world": {}, "prologue": {"stage": "completed"}}, 4, errors)
	var warnings: PackedStringArray = []
	character = Character.from_dict(data, db, warnings)
	session.set_character(character)
	if await _open(&"old_road", &"from_haven") == null:
		return
	check(not (_node("NorthDebris") as StoryConditional).visible, "no debris")
	check(not (_node("Mara") as StoryNpc).visible, "Mara lives in Haven now")
	for path: String in ["Encounters/RoadAmbush", "Encounters/CartAttack", "Encounters/SecondWave"]:
		check(not (_node(path) as Encounter).can_start(), "%s does not return" % path)
	check(not (_node("CrateWest") as StoryPickup).visible, "no crates")
	await _go(Vector2(0, -694), 4)
	for i in 240:
		await get_tree().process_frame
		if get_tree().current_scene is GameMap and (get_tree().current_scene as GameMap).map_id == &"home_base" and not session.is_traveling():
			break
	check((get_tree().current_scene as GameMap).map_id == &"home_base", "back to Haven")
