extends TestCase
## Class Trials 2.0 M3.1 (docs/CLASS_TRIALS_2_0_M31.md): the Sanctum Warden on
## the Hardened Husk reference (no Grove Warden claws, the real Grove Warden
## untouched), the Arcanist finale completed by a real Arcane Bolt kill (the
## player's own skill pipeline - no objective is set by hand), Passage Alpha
## unchanged, sealed inventory potions inside a trial only, and Hearth Flask
## charges restored after success, death and leaving and never saved while
## spent. M3.1b: the Arcanist finale in two steps - two Hollowfang Wolves
## (the vanguard encounter), then the Sanctum Warden alone - on the real enemy
## death / encounter path, with leaving, death and saving mid-fight.
## Real scene changes; saves only under user://test_saves/.

const DIR := "user://test_saves/class_trials_m31"
const PROFILE := DIR + "/slot_1.save.json"
const SAVE := DIR + "/during_trial.save.json"
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro"]
## Combat identity a trial boss copies from its reference (everything but name, rank, rewards).
const IDENTITY_FREE := ["id", "display_name", "rank", "drops", "mastery_xp_reward", "class_xp_reward",
		"resource_local_to_scene", "resource_path", "resource_name", "resource_scene_unique_id", "script"]

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String
var _finished: Array = []
var _messages: PackedStringArray = []


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	session.set_character(character)
	_finished.clear()
	_messages.clear()
	character.prologue.trial_finished.connect(_on_trial_finished)
	for event: StringName in TO_THE_STONE:
		StoryService.notify(character, event)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE) + [SAVE]:
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _on_trial_finished(trial_id: StringName, completed: bool) -> void:
	_finished.append([trial_id, completed])


func _on_message(text: String) -> void:
	_messages.append(text)


# --- helpers --------------------------------------------------------------------

func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			if not map.bridge.message.is_connected(_on_message):
				map.bridge.message.connect(_on_message)
			await get_tree().physics_frame
			await get_tree().physics_frame
			return current
	fail("%s not reached" % map_id)
	return null


func _open_stone() -> GameMap:
	character.world.map_id = &"whispering_stone"
	session.travel(&"whispering_stone", &"from_haven", false)
	return await _await_map(&"whispering_stone")


func _begin(class_id: StringName, map_id: StringName) -> GameMap:
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	check_eq(map.hud.class_choice_panel.begin(class_id), "", "%s trial begins at the altar" % class_id)
	var grounds := await _await_map(map_id)
	if grounds != null:
		grounds.player.health.max_health = 100000.0   # test setup: the player outlives the fight
		grounds.player.health.reset()
	return grounds


func _enemies(variant: StringName = &"") -> Array:
	return map.find_children("*", "Enemy", true, false).filter(func(e: Enemy) -> bool:
		return e.state != Enemy.State.DEAD and (variant == &"" or e.config.id == variant))


func _training_goals(trial_id: StringName) -> void:
	for objective in (db.trials[trial_id] as TrialDefinition).objectives:
		if not objective.finale:
			PrologueService.record(character, objective.kind, objective.target_id, objective.amount)


## The player kills `enemy` with real Arcane Bolts (skill -> projectile -> hit
## pipeline -> PlayerProgressionBridge). Test setup only lowers its current health.
func _bolt_kill(enemy: Enemy) -> bool:
	enemy.health.health = 1.0
	for attempt in 6:
		if not is_instance_valid(enemy) or enemy.state == Enemy.State.DEAD:
			return true
		map.player.global_position = enemy.global_position + Vector2(-70, 0)
		var aim := (enemy.global_position - map.player.global_position).normalized()
		for i in 40:
			var frame := InputFrame.new()
			frame.aim_direction = aim
			frame.ability_slot = 0 if i == 0 else -1
			map.player.feed_input(frame)
			await get_tree().physics_frame
			if not is_instance_valid(enemy) or enemy.state == Enemy.State.DEAD:
				return true
	return not is_instance_valid(enemy) or enemy.state == Enemy.State.DEAD


func _drink(kind: int) -> bool:
	if not map.bridge.try_use(kind):
		return false
	var rules := db.rules
	var seconds := rules.flask_drink_time if kind == 0 else rules.potion_drink_time
	for i in ceili(seconds * 60.0) + 20:
		map.player.feed_input(InputFrame.new())
		await get_tree().physics_frame
	return true


func _to_trial_area() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	map.player.global_position = (map.get_node("Finale") as Node2D).global_position + Vector2(0, 60)
	for i in 6:
		await get_tree().physics_frame


func _combat_values(config: EnemyConfig) -> Dictionary:
	var values := {}
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and not property.name in IDENTITY_FREE:
			values[property.name] = config.get(property.name)
	return values


# --- tests ----------------------------------------------------------------------

func test_sanctum_warden_follows_the_hardened_husk_reference() -> void:
	var warden: EnemyConfig = load("res://data/enemies/sanctum_warden.tres")
	var husk: EnemyConfig = load("res://data/enemies/hardened_husk.tres")
	check_eq(warden.id, &"sanctum_warden", "stable variant id")
	check_eq(warden.rank, 2, "boss rank (boss bar)")
	check_eq(_combat_values(warden), _combat_values(husk), "every combat value from the Hardened Husk")
	check(warden.drops.is_empty() and warden.mastery_xp_reward == 0 and warden.class_xp_reward == 0, "no drops, no XP")
	var scene: GameMap = load("res://scenes/maps/trial_arcanist.tscn").instantiate()
	var spawns: Array = scene.get_node("Finale").find_children("*", "EncounterSpawn", false, false)
	check_eq(spawns.map(func(s: EncounterSpawn) -> StringName: return s.config.id), [&"sanctum_warden"], "arcanist finale: the warden alone")
	check(spawns.all(func(s: EncounterSpawn) -> bool: return s.attacks == null), "no own attack family: the grunt claws of the husk")
	var vanguard: Array = scene.get_node("Vanguard").find_children("*", "EncounterSpawn", false, false)
	check_eq(vanguard.map(func(s: EncounterSpawn) -> StringName: return s.config.id), [&"hollowfang_wolf", &"hollowfang_wolf"],
		"arcanist vanguard: exactly two Hollowfang Wolves (M3.1b)")
	check(vanguard.all(func(s: EncounterSpawn) -> bool: return s.config == load("res://data/enemies/hollowfang_wolf.tres") and s.attacks == null),
		"the plain wolf config, no own attacks")
	check_eq((scene.get_node("TrialGrounds") as TrialGrounds).vanguard, scene.get_node("Vanguard"), "the grounds run the vanguard first")
	scene.free()
	for path: String in ["res://scenes/maps/trial_warrior.tscn", "res://scenes/maps/trial_shadowrunner.tscn"]:
		var other: GameMap = load(path).instantiate()
		check((other.get_node("TrialGrounds") as TrialGrounds).vanguard == null and other.get_node_or_null("Vanguard") == null,
			"%s: no vanguard, the finale as before" % path)
		other.free()
	var grove: EnemyConfig = load("res://data/enemies/grove_warden_config.tres")
	check(grove.id == &"grove_warden" and grove.rank == 2 and grove.move_speed == 70.0 and grove.knockback_resistance == 1.0 \
		and not grove.parry_interrupts and grove.parry_poise_multiplier == 0.3 and grove.drops.size() == 3 \
		and grove.mastery_xp_reward == 20 and grove.class_xp_reward == 30, "the real Grove Warden keeps its values and drops")
	var forest: Node = load("res://scenes/maps/whisper_forest.tscn").instantiate()
	var real: Enemy = forest.get_node("Enemies/GroveWarden")
	check(real.config.id == &"grove_warden" and real.attacks.id == &"warden_claws" and real.persistent_id == &"whisper_forest_grove_warden",
		"the Whisper Forest Grove Warden keeps its claws and identity")
	forest.free()


func test_arcanist_finale_only_by_a_real_warden_kill_and_flask_restored() -> void:
	if await _open_stone() == null:
		return
	var charges := character.consumables.charges
	if await _begin(&"arcanist", &"shattered_sanctum") == null:
		return
	check(await _drink(0), "the Hearth Flask answers in the trial")
	check_eq(character.consumables.charges, charges - 1, "a charge is spent")
	_training_goals(&"trial_arcanist")
	var husk: Enemy = _enemies(&"rootbound_husk")[0] if not _enemies(&"rootbound_husk").is_empty() else null
	if check(husk != null, "a training husk") and check(await _bolt_kill(husk), "a husk falls to Arcane Bolt"):
		check(character.classes.in_trial() and not character.prologue.has_completed_trial(&"trial_arcanist"), "the wrong enemy completes nothing")
	await _to_trial_area()
	for wolf: Enemy in _enemies(&"hollowfang_wolf"):   # M3.1b: the vanguard first
		check(await _bolt_kill(wolf), "a vanguard wolf falls to Arcane Bolt")
	for i in 4:
		await get_tree().physics_frame
	var wardens := _enemies(&"sanctum_warden")
	if not check_eq(wardens.size(), 1, "one Sanctum Warden in the trial area"):
		return
	var warden: Enemy = wardens[0]
	check_eq(warden.attacks.id, &"grunt_claws", "it fights with the husk's attacks")
	check_eq(warden.health.max_health, 160.0, "husk health")
	check_eq(warden.health.max_poise, 70.0, "husk poise")
	check(await _bolt_kill(warden), "the warden falls to Arcane Bolt")
	check(character.prologue.has_completed_trial(&"trial_arcanist"), "the real kill passes the trial")
	check_eq(_finished.filter(func(f: Array) -> bool: return f[0] == &"trial_arcanist" and f[1]).size(), 1, "exactly one completion signal")
	check_eq(StoryService.counter(character, &"trial_complete"), 1, "one trial_complete event")
	check_eq(character.consumables.charges, charges, "flask charges restored after success")
	if await _await_map(&"whispering_stone") == null:
		return
	check_eq(_finished.size(), 1, "no further trial signal on the way home")
	check_eq(character.consumables.charges, charges, "and still restored at the altar")


func test_passage_alpha_and_its_pack_unchanged() -> void:
	var alpha: EnemyConfig = load("res://data/enemies/passage_alpha.tres")
	var wolf: EnemyConfig = load("res://data/enemies/hollowfang_wolf.tres")
	check_eq(alpha.max_health, 50.0, "50 HP (copied from the Hollowfang Wolf)")
	check_eq(_combat_values(alpha), _combat_values(wolf), "every combat value from the wolf")
	check(alpha.drops.is_empty() and alpha.mastery_xp_reward == 0 and alpha.class_xp_reward == 0, "no drops, no XP")
	if await _open_stone() == null:
		return
	if await _begin(&"shadowrunner", &"veiled_passage") == null:
		return
	_training_goals(&"trial_shadowrunner")
	await _to_trial_area()
	var finale := map.get_node("Finale") as Encounter
	var variants: Array = finale.enemies.map(func(e: Enemy) -> StringName: return e.config.id)
	check(variants.size() == 3 and variants.count(&"passage_alpha") == 1 and variants.count(&"hollowfang_wolf") == 2, "the alpha and its two wolves: %s" % [variants])
	var cleared := [0]
	finale.cleared.connect(func() -> void: cleared[0] += 1)
	for enemy: Enemy in finale.enemies.duplicate():
		if enemy.config.id != &"passage_alpha":
			var hit := HitData.new()
			hit.damage = 99999.0
			enemy.hurtbox.receive_hit(hit)
	await get_tree().physics_frame
	check_eq(cleared[0], 0, "the pack is not cleared while the alpha stands")
	check(character.classes.in_trial(), "wolves never complete the trial")


func test_potions_sealed_only_inside_a_trial() -> void:
	if await _open_stone() == null:
		return
	character.inventory.add_item(&"barkskin_tonic", 2)   # test setup: two special potions in the bag
	check_eq(ConsumableService.assign_potion(character, &"barkskin_tonic"), "", "a special potion on the slot")
	var potions := character.inventory.count(&"barkskin_tonic")
	check_eq(potions, 2, "two potions in the bag")
	if await _begin(&"warrior", &"broken_bastion") == null:
		return
	_messages.clear()
	check(not await _drink(1), "a potion cannot be drunk in a trial")
	check_eq(character.inventory.count(&"barkskin_tonic"), potions, "no potion used")
	check(_messages.has(ConsumableService.potion_error(character)), "the refusal is shown: %s" % [_messages])
	check(await _drink(0), "the Hearth Flask still answers")
	var exit := map.get_node("ToHeart") as MapTransition
	exit._on_body_entered(map.player)   # leaving
	if await _await_map(&"whispering_stone") == null:
		return
	check(await _drink(1), "outside a trial the potion works as before")
	check_eq(character.inventory.count(&"barkskin_tonic"), potions - 1, "one potion used outside")


func test_flask_restored_after_death_and_leaving_and_never_saved_spent() -> void:
	if await _open_stone() == null:
		return
	var charges := character.consumables.charges
	if await _begin(&"warrior", &"broken_bastion") == null:
		return
	check(await _drink(0), "flask in the trial")
	check_eq(character.consumables.charges, charges - 1, "spent")
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved during the trial (test path)")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok() and loaded.character.consumables.charges == charges, "the save keeps the charges from before the trial")
	map.player.health.died.emit()   # death
	check_eq(character.consumables.charges, charges, "restored after death")
	if await _await_map(&"whispering_stone") == null:
		return
	if await _begin(&"warrior", &"broken_bastion") == null:
		return
	check(await _drink(0), "flask again")
	check(await _drink(0), "and the last charge")
	check_eq(character.consumables.charges, maxi(charges - 2, 0), "spent twice")
	var exit := map.get_node("ToHeart") as MapTransition
	exit._on_body_entered(map.player)   # leaving
	if await _await_map(&"whispering_stone") == null:
		return
	check_eq(character.consumables.charges, charges, "restored after leaving")
	check(character.prologue.completed_trials.is_empty(), "no trial passed by dying or leaving")


# --- M3.1b: Arcanist finale = vanguard (two wolves), then the warden alone ----------

## Kills `enemy` on the real enemy death path (hurtbox -> health -> defeated -> encounter).
func _kill(enemy: Enemy) -> void:
	var hit := HitData.new()
	hit.damage = 99999.0
	enemy.hurtbox.receive_hit(hit)


func _settle(frames: int = 6) -> void:
	for i in frames:
		await get_tree().physics_frame


func _rewards() -> Dictionary:
	var data := character.to_dict()
	return {"classes": data.classes, "mastery": data.mastery, "armor_mastery": data.armor_mastery, "inventory": data.inventory}


## Nothing of the two finale encounters survives in a save: no cleared flag (both
## are non-persistent). The story's plain event counter ("count.encounter:...")
## is written for every encounter, the training waves too, and restores nothing.
func _no_finale_state(saved: Character) -> bool:
	return not saved.world.has_flag(&"encounter.trial_arcanist_vanguard") and not saved.world.has_flag(&"encounter.trial_arcanist_finale")


## Through the gate into the trial area: phase 1 (two wolves, no warden).
func _phase_one() -> Array:
	_training_goals(&"trial_arcanist")
	await _to_trial_area()
	var wolves := _enemies(&"hollowfang_wolf")
	check_eq(wolves.size(), 2, "phase 1: exactly two wolves")
	check(_enemies(&"sanctum_warden").is_empty(), "phase 1: no warden yet")
	return wolves


func test_arcanist_finale_wolves_first_then_the_warden_alone() -> void:
	if await _open_stone() == null:
		return
	var before := _rewards()
	if await _begin(&"arcanist", &"shattered_sanctum") == null:
		return
	var finale := map.get_node("Finale") as Encounter
	var vanguard := map.get_node("Vanguard") as Encounter
	var starts := {"finale": 0, "vanguard": 0}
	finale.started.connect(func() -> void: starts.finale += 1)
	vanguard.started.connect(func() -> void: starts.vanguard += 1)
	var wolves := await _phase_one()
	if wolves.size() != 2:
		return
	var wolf_config: EnemyConfig = load("res://data/enemies/hollowfang_wolf.tres")
	for wolf: Enemy in wolves:
		check(wolf.config == wolf_config and wolf.health.max_health == 50.0 and wolf.health.max_poise == 20.0,
			"the wolves keep every wolf value (50/20)")
	check(not finale.running and starts.finale == 0, "the finale encounter is not running")
	check(await _bolt_kill(wolves[0]), "the first wolf falls to Arcane Bolt")
	await _settle()
	check(_enemies(&"sanctum_warden").is_empty() and starts.finale == 0, "one wolf down: still no warden")
	check_eq(_enemies(&"hollowfang_wolf").size(), 1, "the other wolf still fights")
	check(character.classes.in_trial() and not character.prologue.has_completed_trial(&"trial_arcanist"), "a wolf kill completes nothing")
	check(await _bolt_kill(wolves[1]), "the second wolf falls to Arcane Bolt")
	await _settle()
	check(vanguard.done and not vanguard.running, "the vanguard is cleared")
	var wardens := _enemies(&"sanctum_warden")
	check_eq(wardens.size(), 1, "both wolves down: the warden appears")
	check_eq(starts.finale, 1, "phase 2 starts once")
	check(character.classes.in_trial() and not character.prologue.has_completed_trial(&"trial_arcanist"), "wolf kills never complete the trial")
	map.player.global_position = finale.global_position + Vector2(0, 60)
	await _settle(90)   # the player stays in the trigger radius
	check_eq(_enemies(&"sanctum_warden").size(), 1, "still exactly one warden")
	check(_enemies(&"hollowfang_wolf").is_empty(), "no further wolves in phase 2")
	check_eq(starts, {"finale": 1, "vanguard": 1}, "no wave starts again")
	check_eq(finale.enemies.size(), 1, "the finale encounter is the warden alone")
	if wardens.is_empty():
		return
	check(await _bolt_kill(wardens[0]), "the warden falls to Arcane Bolt")
	check(character.prologue.has_completed_trial(&"trial_arcanist"), "the real warden kill passes the trial")
	check_eq(_finished.filter(func(f: Array) -> bool: return f[0] == &"trial_arcanist" and f[1]).size(), 1, "exactly one completion")
	check_eq(StoryService.counter(character, &"trial_complete"), 1, "one trial_complete event")
	check(map.find_children("*", "ItemPickup", true, false).is_empty(), "no drops on the trial grounds")
	check_eq(character.prologue.chosen_class, &"", "passing never chooses the class")
	if await _await_map(&"whispering_stone") == null:
		return
	check_eq(_finished.size(), 1, "no further trial signal on the way home")
	check_eq(_rewards(), before, "no class/mastery XP, no items from the trial")


func test_arcanist_finale_leaving_death_and_saving_mid_fight() -> void:
	if await _open_stone() == null:
		return
	# leaving in phase 1, with a save taken in the fight
	if await _begin(&"arcanist", &"shattered_sanctum") == null:
		return
	var wolves := await _phase_one()
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved in phase 1 (test path)")
	var loaded := SaveSystem.load_from(SAVE, db)
	check(loaded.ok() and not loaded.character.classes.in_trial() and loaded.character.prologue.active_trial == &"",
		"the loaded save holds no running trial (no orphaned finale)")
	check(loaded.ok() and _no_finale_state(loaded.character), "no cleared vanguard/finale in the save")
	(map.get_node("ToHeart") as MapTransition)._on_body_entered(map.player)   # leaving = abort
	if await _await_map(&"whispering_stone") == null:
		return
	check(wolves.all(func(w: Variant) -> bool: return not is_instance_valid(w)), "phase 1 wolves gone after leaving")
	check(not character.classes.in_trial() and character.prologue.completed_trials.is_empty(), "leaving passes nothing")
	# again: a clean phase 1, then leaving in phase 2
	if await _begin(&"arcanist", &"shattered_sanctum") == null:
		return
	check(not PrologueService.training_done(character, &"trial_arcanist"), "the retry starts with the training")
	check(_enemies(&"hollowfang_wolf").is_empty() and _enemies(&"sanctum_warden").is_empty(), "no finale enemies before the gate")
	wolves = await _phase_one()
	for wolf: Enemy in wolves:
		_kill(wolf)
	await _settle()
	var wardens := _enemies(&"sanctum_warden")
	check_eq(wardens.size(), 1, "phase 2 after both wolves (real death path)")
	check(character.classes.in_trial() and not character.prologue.has_completed_trial(&"trial_arcanist"), "wolf deaths complete nothing")
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved in phase 2 (test path)")
	loaded = SaveSystem.load_from(SAVE, db)
	check(loaded.ok() and loaded.character.prologue.active_trial == &"", "no running trial or finale in the save")
	check(loaded.ok() and _no_finale_state(loaded.character), "the cleared vanguard is not saved as cleared")
	(map.get_node("ToHeart") as MapTransition)._on_body_entered(map.player)
	if await _await_map(&"whispering_stone") == null:
		return
	check(wardens.all(func(w: Variant) -> bool: return not is_instance_valid(w)), "the warden is gone after leaving")
	# again: phase 1 from the start, then death in phase 2
	if await _begin(&"arcanist", &"shattered_sanctum") == null:
		return
	wolves = await _phase_one()
	for wolf: Enemy in wolves:
		_kill(wolf)
	await _settle()
	check_eq(_enemies(&"sanctum_warden").size(), 1, "phase 2 again")
	map.player.health.died.emit()   # death
	check(not character.classes.in_trial(), "death ends the trial")
	if await _await_map(&"whispering_stone") == null:
		return
	check(character.prologue.completed_trials.is_empty() and _finished.all(func(f: Array) -> bool: return not f[1]),
		"no completion by leaving or dying")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "Basic Adventurer again")
