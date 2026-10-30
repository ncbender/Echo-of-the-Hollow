extends TestCase
## Class Trials 2.0 M3 (docs/CLASS_TRIALS_2_0_M3.md): real class trials on their
## own grounds - begun at the Heart of the Stone, temporary class, training waves,
## the trial gate, the mini-boss (stable variant id), success / death / leaving
## with the return to the altar, no rewards, Hearth Flask and potions, save/load
## during a trial, no pedestal shortcut, location display. Real scene changes
## through SessionState.travel; saves only under user://test_saves/.

const DIR := "user://test_saves/class_trials_m3"
const PROFILE := DIR + "/slot_1.save.json"
const SAVE := DIR + "/during_trial.save.json"
const TRIALS := {
	&"warrior": {"trial": &"trial_warrior", "map": &"broken_bastion", "boss": &"bastion_guardian"},
	&"arcanist": {"trial": &"trial_arcanist", "map": &"shattered_sanctum", "boss": &"sanctum_warden"},
	&"shadowrunner": {"trial": &"trial_shadowrunner", "map": &"veiled_passage", "boss": &"passage_alpha"},
}
const TO_THE_STONE := [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
		&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
		&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome", &"restore:old_smithy", &"talk:edrin_intro"]

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


# --- helpers --------------------------------------------------------------------

func _await_map(map_id: StringName, limit: int = 240) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == map_id and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			await get_tree().physics_frame   # TrialGrounds sets up deferred
			return current
	fail("%s not reached" % map_id)
	return null


func _open_stone() -> GameMap:
	character.world.map_id = &"whispering_stone"
	session.travel(&"whispering_stone", &"from_haven", false)
	return await _await_map(&"whispering_stone")


func _altar() -> ClassChoicePanel:
	var stone := map.get_node("TheStone") as ClassChoiceStation
	map.player.global_position = stone.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	stone.interact(map.hud)
	return map.hud.class_choice_panel


## Begins the trial of `class_id` at the altar and waits on its grounds.
func _begin(class_id: StringName) -> GameMap:
	var panel := await _altar()
	var button := panel.find_child("Begin_%s" % class_id, true, false) as Button
	if not check(button != null and not button.disabled, "%s: Begin offered" % class_id):
		return null
	check_eq(panel.begin(class_id), "", "%s: trial begins" % class_id)
	return await _await_map(TRIALS[class_id].map)


func _training_goals(trial_id: StringName) -> void:
	for objective in (db.trials[trial_id] as TrialDefinition).objectives:
		if not objective.finale:
			PrologueService.record(character, objective.kind, objective.target_id, objective.amount)


func _enemies(variant: StringName = &"") -> Array:
	return map.find_children("*", "Enemy", true, false).filter(func(e: Enemy) -> bool:
		return e.state != Enemy.State.DEAD and (variant == &"" or e.config.id == variant))


func _kill(enemy: Enemy) -> void:
	var hit := HitData.new()
	hit.damage = 99999.0
	enemy.hurtbox.receive_hit(hit)


## The kill/poise events of the player's own hit pipeline (same path as real combat).
func _player_hit(enemy: Enemy, killed: bool, broke_poise: bool) -> void:
	var hit := HitData.new()
	hit.target = enemy
	hit.killed = killed
	hit.broke_poise = broke_poise
	map.bridge._on_hit_dispatched(hit)


func _walk_north(frames: int) -> void:
	for i in frames:
		var frame := InputFrame.new()
		frame.move = Vector2.UP
		map.player.feed_input(frame)
		await get_tree().physics_frame


func _gate() -> TrialGate:
	return map.get_node("TrialGate") as TrialGate


## Opens the gate and calls the mini-boss into the trial area.
func _to_the_boss(class_id: StringName) -> Enemy:
	_training_goals(TRIALS[class_id].trial)
	await get_tree().physics_frame
	await get_tree().physics_frame
	map.player.global_position = (map.get_node("Finale") as Node2D).global_position + Vector2(0, 60)
	for i in 6:
		await get_tree().physics_frame
	var bosses := _enemies(TRIALS[class_id].boss)
	check_eq(bosses.size(), 1, "%s: exactly one mini-boss" % class_id)
	return bosses[0] if not bosses.is_empty() else null


func _snapshot() -> Dictionary:
	var data := character.to_dict()
	return {"classes": data.classes, "class_builds": data.class_builds, "loadouts": data.loadouts, "inventory": data.inventory,
		"stash": data.stash, "mastery": data.mastery, "armor_mastery": data.armor_mastery, "consumables": data.consumables,
		"professions": data.professions}


# --- tests ----------------------------------------------------------------------

func test_each_trial_runs_on_its_grounds() -> void:
	if await _open_stone() == null:
		return
	for class_id: StringName in TRIALS:
		var before := _snapshot()
		var grounds := await _begin(class_id)
		if grounds == null:
			return
		var trial: TrialDefinition = db.trials[TRIALS[class_id].trial]
		check(character.classes.in_trial() and character.classes.active_class_id == class_id, "%s: temporary class active" % class_id)
		check_eq(character.classes.get_level(class_id), trial.trial_level, "%s: trial level" % class_id)
		check_eq(character.builds.trial_build().slots.filter(func(s: StringName) -> bool: return s != &""),
			trial.skill_slots.filter(func(s: StringName) -> bool: return s != &""), "%s: trial skills slotted" % class_id)
		check(not character.classes.is_unlocked(class_id), "%s: never unlocked by the trial" % class_id)
		check_eq(character.to_dict().classes.active, "basic_adventurer", "%s: the saved class stays Basic Adventurer" % class_id)
		check(not _gate().is_open, "%s: gate sealed before the training" % class_id)
		check(not _enemies().is_empty(), "%s: training wave" % class_id)
		var gate_y := _gate().global_position.y
		await _walk_north(300)
		check(map.player.global_position.y > gate_y, "%s: the sealed gate stops the player (%s)" % [class_id, map.player.global_position])
		for enemy: Enemy in _enemies():
			_kill(enemy)
		for i in 4:
			await get_tree().physics_frame
		check(not _enemies().is_empty(), "%s: a new wave while training goals are open" % class_id)
		check(_enemies(TRIALS[class_id].boss).is_empty(), "%s: no boss before the gate" % class_id)
		_training_goals(trial.id)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(_gate().is_open, "%s: gate open after the training" % class_id)
		await _walk_north(300)
		check(map.player.global_position.y < gate_y - 60.0, "%s: through the open gate" % class_id)
		for i in 4:
			await get_tree().physics_frame
		var vanguard := (map.get_node("TrialGrounds") as TrialGrounds).vanguard   # M3.1b: arcanist wolves first
		if vanguard != null:
			check(_enemies(TRIALS[class_id].boss).is_empty(), "%s: no boss while the vanguard fights" % class_id)
			check_eq(vanguard.enemies.size(), 2, "%s: the vanguard is up" % class_id)
			for enemy: Enemy in vanguard.enemies:
				_kill(enemy)
			for i in 4:
				await get_tree().physics_frame
		var bosses := _enemies(TRIALS[class_id].boss)
		check_eq(bosses.size(), 1, "%s: mini-boss %s in the trial area" % [class_id, TRIALS[class_id].boss])
		if class_id == &"arcanist" and not bosses.is_empty():
			check_eq((bosses[0] as Enemy).attacks.id, &"grunt_claws", "arcanist boss fights like the Hardened Husk (M3.1)")
		for enemy: Enemy in _enemies():   # the wrong enemies: training variants, escorts
			if enemy.config.id != TRIALS[class_id].boss:
				_player_hit(enemy, true, true)
		check(character.classes.in_trial() and not character.prologue.has_completed_trial(trial.id), "%s: other enemies never complete it" % class_id)
		var boss: Enemy = bosses[0] if not bosses.is_empty() else null
		if boss == null:
			return
		_player_hit(boss, false, true)   # poise break (warrior finale) ...
		_player_hit(boss, true, false)   # ... and the kill
		check(character.prologue.has_completed_trial(trial.id), "%s: trial passed" % class_id)
		check(not character.classes.in_trial() and character.classes.active_class_id == &"basic_adventurer", "%s: trial class gone" % class_id)
		check_eq(character.prologue.chosen_class, &"", "%s: passing never chooses the class" % class_id)
		var stone := await _await_map(&"whispering_stone")
		if stone == null:
			return
		check_eq(stone.player.global_position, stone.find_spawn(&"heart").global_position, "%s: back at the Heart of the Stone" % class_id)
		check_eq(PrologueService.can_choose(character, class_id), "", "%s: now choosable (M1 rule)" % class_id)
		var after := _snapshot()
		for key: String in ["classes", "class_builds", "loadouts", "inventory", "stash", "mastery", "armor_mastery", "consumables", "professions"]:
			check_eq(after[key], before[key], "%s: %s unchanged by the trial" % [class_id, key])
	check(StoryService.at_step(character, &"the_whispering_stone", 2), "one passed trial moved the story")
	check_eq(StoryService.counter(character, &"trial_complete"), 3, "three first completions")


func test_preview_starts_nothing() -> void:
	if await _open_stone() == null:
		return
	var panel := await _altar()
	check_eq(panel.visit(&"warrior"), "", "preview visit")
	if await _await_map(&"broken_bastion") == null:
		return
	for i in 20:
		await get_tree().physics_frame
	check(not character.classes.in_trial(), "no trial session")
	check(_enemies().is_empty(), "no training wave in a preview")
	check(not _gate().is_open, "gate sealed in a preview")
	_training_goals(&"trial_warrior")   # combat events in a preview count for nothing
	await get_tree().physics_frame
	check(not _gate().is_open and character.prologue.trial_progress.is_empty(), "no progress, gate stays sealed")
	check(character.prologue.completed_trials.is_empty(), "nothing completed")


func test_death_and_leaving_fail_and_allow_a_retry() -> void:
	if await _open_stone() == null:
		return
	if await _begin(&"shadowrunner") == null:
		return
	_training_goals(&"trial_shadowrunner")
	map.player.health.died.emit()   # falling in the trial
	check(not character.classes.in_trial(), "death ends the trial")
	if await _await_map(&"whispering_stone") == null:
		return
	check(character.prologue.completed_trials.is_empty(), "death never passes the trial")
	check_eq(map.player.global_position, map.find_spawn(&"heart").global_position, "carried back to the altar")
	if await _begin(&"shadowrunner") == null:   # retry
		return
	check(not PrologueService.training_done(character, &"trial_shadowrunner"), "a retry starts from zero (training open again)")
	check(not _gate().is_open, "and with a sealed gate")
	var exit := map.get_node("ToHeart") as MapTransition
	exit._on_body_entered(map.player)   # leaving = abort
	if await _await_map(&"whispering_stone") == null:
		return
	check(not character.classes.in_trial() and character.prologue.completed_trials.is_empty(), "leaving ends without passing")
	check_eq(character.classes.active_class_id, &"basic_adventurer", "Basic Adventurer again")
	check(await _begin(&"shadowrunner") != null, "can be begun again after leaving")


func test_no_double_sessions_or_transitions() -> void:
	if await _open_stone() == null:
		return
	var panel := await _altar()
	check_eq(panel.begin(&"warrior"), "", "first begin")
	check(panel.begin(&"warrior") != "", "second begin refused (journey running)")
	check(panel.begin(&"arcanist") != "", "another trial refused too")
	check_eq(character.prologue.active_trial, &"trial_warrior", "exactly one trial session")
	check_eq(PrologueService.begin_trial(character, &"trial_arcanist"), "Finish or leave the current trial first.", "service refuses a parallel trial")
	if await _await_map(&"broken_bastion") == null:
		return
	check_eq(character.prologue.active_trial, &"trial_warrior", "still the one session on the grounds")
	var grounds := map.get_node("TrialGrounds") as TrialGrounds
	PrologueService.end_trial(character, false)
	check(grounds.returning, "one return requested")
	grounds.return_to_altar()   # a second request changes nothing
	check(session.is_traveling(), "exactly one transition running")


func test_no_drops_or_xp_inside_but_outside_unchanged() -> void:
	if await _open_stone() == null:
		return
	var outside := map.spawn_enemy(map.player.global_position + Vector2(60, 0), db.trials[&"trial_warrior"].enemy_configs[0])
	await get_tree().physics_frame
	_kill(outside)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not map.find_children("*", "ItemPickup", true, false).is_empty(), "regular enemies still drop (outside a trial)")
	if await _begin(&"warrior") == null:
		return
	var before := _snapshot()
	var evolution_before := JSON.stringify(character.inventory.to_array())
	check(PrologueService.rewards_blocked(character), "rewards blocked on the grounds")
	for enemy: Enemy in _enemies():
		_kill(enemy)
		_player_hit(enemy, true, false)
		map.bridge.rewards.reward_kill(_kill_hit(enemy))
	var boss := await _to_the_boss(&"warrior")
	if boss != null:
		_kill(boss)
		map.bridge.rewards.reward_kill(_kill_hit(boss))
	for i in 3:
		await get_tree().process_frame
	check(map.find_children("*", "ItemPickup", true, false).is_empty(), "no drops in the trial")
	var after := _snapshot()
	check_eq(after.mastery, before.mastery, "no weapon mastery XP")
	check_eq(after.armor_mastery, before.armor_mastery, "no armor mastery XP")
	check_eq(JSON.stringify(character.inventory.to_array()), evolution_before, "no item (evolution) changes")


func _kill_hit(enemy: Enemy) -> HitData:
	var hit := HitData.new()
	hit.target = enemy
	hit.killed = true
	return hit


func test_flask_potions_inventory_and_loadout_safety() -> void:
	if await _open_stone() == null:
		return
	var charges := character.consumables.charges
	var loadouts: Dictionary = character.to_dict().loadouts
	var items := JSON.stringify(character.inventory.to_array())
	if await _begin(&"warrior") == null:
		return
	check(ConsumableService.complete_flask(character) > 0.0, "the Hearth Flask answers in a trial")
	check_eq(character.consumables.charges, charges - 1, "a charge is used")
	check_eq(int(character.to_dict().consumables.charges), charges, "a save during the trial keeps the charges from before")
	check(ConsumableService.potion_error(character) != "", "potions (items) stay sealed in a trial")
	var weapon := character.inventory.to_array().filter(func(e: Dictionary) -> bool: return e.def == "steel_greatsword")
	if not weapon.is_empty():
		character.equipment.equip(weapon[0].id)   # equipping in the trial changes only the trial loadout copy
	PrologueService.end_trial(character, false)
	check_eq(character.consumables.charges, charges, "charges restored when the trial ends (no farm, no loss)")
	check_eq(character.to_dict().loadouts, loadouts, "the real loadouts are untouched")
	check_eq(JSON.stringify(character.inventory.to_array()), items, "inventory unchanged")


func test_save_during_a_trial_and_load_after_a_restart() -> void:
	if await _open_stone() == null:
		return
	var charges := character.consumables.charges
	if await _begin(&"arcanist") == null:
		return
	_training_goals(&"trial_arcanist")
	ConsumableService.complete_flask(character)
	check_eq(SaveSystem.save_to(character, SAVE), OK, "saved during the trial (test path)")
	var raw := FileAccess.get_file_as_string(SAVE)
	check(not raw.contains("\"arcanist\""), "no trial class or build in the save")
	var loaded := SaveSystem.load_from(SAVE, db)   # a restart: a fresh character from the file
	if not check(loaded.ok(), "loads"):
		return
	var restored := loaded.character
	check(not restored.classes.in_trial(), "no half-finished trial after a restart")
	check_eq(restored.classes.active_class_id, &"basic_adventurer", "no persisted temporary class")
	check(restored.world.map_id == &"whispering_stone" and restored.world.spawn_id == &"heart", "resumes at the altar")
	check(restored.prologue.completed_trials.is_empty() and restored.prologue.trial_progress.is_empty(), "no trial progress kept")
	check_eq(restored.consumables.charges, charges, "Hearth Flask charges from before the trial")
	check(restored.classes.unlocked_class_ids() == character.classes.unlocked_class_ids(), "permanent classes intact")
	session.set_character(restored)
	character = restored
	session.travel(restored.world.map_id, restored.world.spawn_id, false)
	var stone := await _await_map(&"whispering_stone")
	if stone != null:
		check_eq(stone.player.global_position, stone.find_spawn(&"heart").global_position, "loaded at the Heart of the Stone")
		check(await _begin(&"arcanist") != null, "the trial can be begun again")


func test_no_pedestal_shortcut() -> void:
	var dev_trial: TrialDefinition = db.trials[&"trial_warrior"]
	check_eq(PrologueService.begin_trial(character, dev_trial.id), "", "developer pedestal trial (prologue grounds)")
	for objective in dev_trial.objectives:   # every goal a pedestal wave can give
		if not objective.finale:
			PrologueService.record(character, objective.kind, objective.target_id, objective.amount * 10.0)
	for config: EnemyConfig in dev_trial.enemy_configs:
		PrologueService.record(character, TrialObjective.Kind.KILLS, config.id, 10.0)
		PrologueService.record(character, TrialObjective.Kind.POISE_BREAKS, config.id, 10.0)
	check(not character.prologue.has_completed_trial(dev_trial.id), "pedestal enemies can never pass a trial (boss only on its grounds)")
	PrologueService.end_trial(character, false)
	for trial: TrialDefinition in db.trials.values():
		var finale: Array = trial.objectives.filter(func(o: TrialObjective) -> bool: return o.finale)
		check(not finale.is_empty(), "%s has finale goals" % trial.id)
		for objective: TrialObjective in finale:
			check(objective.target_id != &"" and not objective.target_id in trial.enemy_configs.map(func(c: EnemyConfig) -> StringName: return c.id),
				"%s finale targets its own boss variant %s" % [trial.id, objective.target_id])


func test_location_display_on_the_grounds() -> void:
	if await _open_stone() == null:
		return
	if await _begin(&"warrior") == null:
		return
	check_eq(character.world.here(), &"broken_bastion", "physical location: the grounds")
	check_eq(character.world.map_id, &"whispering_stone", "saved location: the altar (resume)")
	check(&"broken_bastion" not in WorldMapPanel.known_maps(character), "grounds are never drawn on the world map")
	check(map.hud.objectives.visible, "trial objectives shown")
	map.hud.objectives.refresh()
	var text: String = map.hud.objectives.full_text()
	check(text.contains("Warrior") and text.contains(tr("UI_TRIAL_GATE_SEALED")) and text.contains("Bastion Guardian") \
		and text.contains(tr("UI_LEAVE_TRIAL_GROUNDS_HINT")), "trial class, gate, boss goal and leave hint shown: %s" % text)
