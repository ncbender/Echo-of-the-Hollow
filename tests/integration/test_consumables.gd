extends TestCase
## Hearth Flask & Consumables 1.0: flask charges, heal on completion only,
## interrupts (dash, stagger, death) consume nothing, slowed and locked while
## drinking, no cooldown, rest points refill; Mara's gold upgrades (exact costs,
## refusals, persistence, real mouse); special potions consumed on completion,
## one exclusive buff replaced by the next, durations and expiry, shared 30 s
## cooldown, the buff stats (damage dealt, resource costs never negative,
## damage taken, walking speed but never the dash, status resistance), death
## ends the buff; save v9 and the v8 -> v9 migration; the potion slot kept with
## an empty stack; the HUD effect icon with its clockwise timer (display only).
## Only user://test_saves/.

const DIR := "user://test_saves/consumables"
const PATH := DIR + "/slot_1.save.json"
const DT := 1.0 / 60.0

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var player: Player
var frame := InputFrame.new()
var _previous: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous = session.character
	_previous_path = session.save_path
	session.save_path = DIR + "/session.save.json"
	character = CharacterFactory.create_new(db)
	character.world.set_flag(&"prologue.haven_discovered")
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	player = map.player
	frame = InputFrame.new()
	player.feed_input(frame)
	await get_tree().physics_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in [PATH] + SaveSlots.all_paths(DIR + "/session.save.json"):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous)


## Runs `seconds` of physics with the current frame (edges consumed on the first tick).
func _run(seconds: float) -> void:
	for i in ceili(seconds / DT):
		await get_tree().physics_frame


func _press_flask() -> void:
	frame.flask_pressed = true
	await get_tree().physics_frame


func _press_potion() -> void:
	frame.potion_pressed = true
	await get_tree().physics_frame


func _hurt(fraction: float) -> void:
	player.health.health = player.health.max_health * (1.0 - fraction)


func test_flask_heals_on_completion_and_uses_one_charge() -> void:
	check_eq(character.consumables.charges, 2, "new character: 2 charges")
	_hurt(0.6)
	var before := player.health.health
	await _press_flask()
	check(player.is_using(), "drinking")
	check_eq(character.consumables.charges, 2, "no charge used before the drink completes")
	await _run(1.0)
	check_eq(player.health.health, before, "no heal before 1.1 s")
	await _run(0.2)
	check(not player.is_using(), "drink finished")
	check_eq(character.consumables.charges, 1, "one charge used")
	check(is_equal_approx(player.health.health, before + player.health.max_health * 0.3), "healed 30 %% of max health (%.1f -> %.1f)" % [before, player.health.health])
	await _press_flask()   # no cooldown: right away again
	check(player.is_using(), "second drink starts at once (no cooldown)")
	await _run(1.2)
	check_eq(character.consumables.charges, 0, "both charges used")
	await _press_flask()
	check(not player.is_using(), "empty flask: no drink")


func test_drinking_slows_and_locks_actions() -> void:
	await _press_flask()
	frame.move = Vector2.RIGHT
	frame.light_pressed = true
	await _run(0.5)
	check_eq(player.combat.state, CombatComponent.State.IDLE, "no attack while drinking")
	check(not player.can_start_skill(), "no skill while drinking")
	check(not player.can_start_defense(), "no block while drinking")
	var speed := player.velocity.length()
	var full := player.movement.config.move_speed
	check(absf(speed - full * 0.45) < 2.0, "walking at 45 %% (%.1f of %.1f)" % [speed, full])
	frame.move = Vector2.ZERO


func test_interrupts_consume_nothing() -> void:
	_hurt(0.5)
	var health := player.health.health
	# dash
	await _press_flask()
	await _run(0.5)
	frame.dash_pressed = true
	await get_tree().physics_frame
	check(not player.is_using(), "a dash interrupts the drink")
	await _run(1.0)
	check_eq(character.consumables.charges, 2, "dash: no charge used")
	check_eq(player.health.health, health, "dash: no heal")
	await _run(0.5)
	# stagger
	await _press_flask()
	await _run(0.3)
	player.hurtbox.hit_received.emit(_stagger_hit())
	await get_tree().physics_frame
	check(not player.is_using(), "a stagger interrupts the drink")
	await _run(1.2)
	check_eq(character.consumables.charges, 2, "stagger: no charge used")
	# death
	await _run(1.0)
	await _press_flask()
	player.health.apply_hit(_lethal_hit())
	await get_tree().physics_frame
	check(not player.is_using(), "death interrupts the drink")
	check_eq(character.consumables.charges, 2, "death: no charge used")


func _stagger_hit() -> HitData:
	var hit := HitData.new()
	hit.damage = 1.0
	hit.reaction = HitReaction.Type.INTERRUPT
	return hit


func _lethal_hit() -> HitData:
	var hit := HitData.new()
	hit.damage = 100000.0
	return hit


func test_rest_point_refills_and_heals() -> void:
	character.consumables.charges = 0
	_hurt(0.7)
	var rest := Checkpoint.new()
	rest.spawn_id = &"test_rest"
	map.add_child(rest)
	rest._on_body_entered(player)
	check_eq(character.consumables.charges, 2, "flask refilled")
	check_eq(player.health.health, player.health.max_health, "health restored")
	check_eq(character.world.spawn_id, &"test_rest", "respawn point set")
	check(map.find_children("*", "Enemy", true, false).is_empty(), "no enemy brought back")
	check(not FileAccess.file_exists(DIR + "/session.save.json"), "resting does not save")


func test_mara_upgrades_cost_gold_and_persist() -> void:
	var expected_capacity := [150, 450, 1100, 2400]
	var expected_potency := [200, 550, 1300, 2800]
	check(ConsumableService.upgrade(character, ConsumableService.CAPACITY).begins_with("Not enough gold"), "no gold: refused")
	check_eq(character.consumables.capacity_level, 0, "nothing changed")
	character.inventory.add_item(&"gold_coin", 10000)
	for index in 4:
		var gold := character.inventory.count(&"gold_coin")
		check_eq(ConsumableService.upgrade(character, ConsumableService.CAPACITY), "", "capacity %d bought" % (index + 1))
		check_eq(gold - character.inventory.count(&"gold_coin"), expected_capacity[index], "capacity %d costs %d" % [index + 1, expected_capacity[index]])
		check_eq(ConsumableService.max_charges(character), 3 + index, "%d charges" % (3 + index))
	check_eq(ConsumableService.upgrade(character, ConsumableService.CAPACITY), "Fully upgraded.", "capacity ends at 6")
	character.inventory.add_item(&"gold_coin", 10000)
	for index in 4:
		var gold := character.inventory.count(&"gold_coin")
		check_eq(ConsumableService.upgrade(character, ConsumableService.POTENCY), "", "potency %d bought" % (index + 1))
		check_eq(gold - character.inventory.count(&"gold_coin"), expected_potency[index], "potency %d costs %d" % [index + 1, expected_potency[index]])
	check(is_equal_approx(ConsumableService.heal_share(character), 0.7), "heals 70 %")
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok() and loaded.character.consumables.capacity_level == 4 and loaded.character.consumables.potency_level == 4, "upgrades saved")
	check_eq(ConsumableService.max_charges(loaded.character), 6, "6 charges after loading")


func test_potions_buffs_cooldown_and_exclusivity() -> void:
	character.inventory.add_item(&"ember_draught", 2)
	character.inventory.add_item(&"barkskin_tonic", 1)
	check(ConsumableService.potion_error(character).begins_with("No potion on the potion slot"), "nothing slotted")
	check_eq(ConsumableService.assign_potion(character, &"timber"), "Only special potions go on the potion slot.", "only potions")
	check_eq(ConsumableService.assign_potion(character, &"ember_draught"), "", "ember slotted")
	await _press_potion()
	check(player.is_using(), "drinking the potion")
	await _run(0.5)
	check_eq(character.inventory.count(&"ember_draught"), 2, "not consumed before 0.7 s")
	frame.dash_pressed = true
	await get_tree().physics_frame
	await _run(0.5)
	check_eq(character.inventory.count(&"ember_draught"), 2, "interrupted: not consumed")
	check_eq(character.consumables.buff_item, &"", "interrupted: no buff")
	await _run(1.0)
	await _press_potion()
	await _run(0.8)
	check_eq(character.inventory.count(&"ember_draught"), 1, "one potion consumed")
	check_eq(character.consumables.buff_item, &"ember_draught", "ember buff active")
	check(absf(character.consumables.buff_left - (45.0 - 0.1)) < 0.2, "45 s buff (%.2f left)" % character.consumables.buff_left)
	check_eq(character.get_stat(Stats.DAMAGE_DEALT), 8.0, "+8 % damage dealt")
	var hit := HitData.new()
	hit.damage = 100.0
	var modifier := CharacterStatModifier.new()
	modifier.stats = character.get_stats()
	modifier.modify_hit(hit)
	check(absf(hit.damage - 108.0) < 0.01, "outgoing hit x1.08 (%.2f)" % hit.damage)
	check_eq(character.consumables.cooldown_left > 29.0, true, "30 s shared cooldown started")
	await _press_potion()
	check(not player.is_using(), "cooldown: no second potion")
	# cooldown over: barkskin replaces ember
	ConsumableService.step(character, 30.0)
	ConsumableService.assign_potion(character, &"barkskin_tonic")
	await _press_potion()
	await _run(0.8)
	check_eq(character.consumables.buff_item, &"barkskin_tonic", "barkskin replaced ember")
	check_eq(character.get_stat(Stats.DAMAGE_DEALT), 0.0, "ember gone (no stacking)")
	check_eq(character.get_stat(Stats.DAMAGE_REDUCTION), 8.0, "-8 % damage taken")
	check(absf(player.incoming_damage_multiplier - (Stats.ARMOR_CONSTANT / (Stats.ARMOR_CONSTANT + character.get_stat(Stats.ARMOR))) * 0.92) < 0.0001, "incoming damage x0.92")
	check_eq(ConsumableService.active_effects(character).size(), 1, "exactly one potion effect")
	# slot keeps its type with an empty stack
	check_eq(character.inventory.count(&"barkskin_tonic"), 0, "stack used up")
	check_eq(character.consumables.potion_slot, &"barkskin_tonic", "the slot keeps the type")
	check(ConsumableService.potion_error(character).begins_with("No Barkskin Tonic left"), "says why")
	# expiry
	ConsumableService.step(character, 179.0)
	check_eq(character.consumables.buff_item, &"barkskin_tonic", "still active before 3 min")
	ConsumableService.step(character, 2.0)
	check_eq(character.consumables.buff_item, &"", "expired after 3 min")
	check_eq(character.get_stat(Stats.DAMAGE_REDUCTION), 0.0, "modifier removed")


func test_buff_values_and_limits() -> void:
	for entry: Array in [[&"ember_draught", 45.0], [&"resonance_elixir", 60.0], [&"barkskin_tonic", 180.0], [&"quickstep_tincture", 240.0], [&"whisperbloom_concentrate", 180.0]]:
		var effect := db.get_item(entry[0]).potion_effect
		check(effect != null and is_equal_approx(effect.duration, entry[1]), "%s lasts %d s" % [entry[0], entry[1]])
	# Quickstep: walking only
	var dash_distance := player.dash.config.distance
	var dash_iframes := player.dash.config.iframe_duration
	var dash_recharge := player.dash.config.recharge_time
	var dash_charges := player.dash.config.max_charges
	_drink_now(&"quickstep_tincture")
	await get_tree().physics_frame
	check(is_equal_approx(player.move_speed_multiplier, 1.07), "walking x1.07")
	check(player.dash.config.distance == dash_distance and player.dash.config.iframe_duration == dash_iframes
		and player.dash.config.recharge_time == dash_recharge and player.dash.config.max_charges == dash_charges, "dash untouched")
	frame.move = Vector2.RIGHT
	await _run(0.6)
	check(absf(player.velocity.length() - player.movement.config.move_speed * 1.07) < 2.0, "walks 7 %% faster (%.1f)" % player.velocity.length())
	frame.move = Vector2.ZERO
	var start := player.global_position
	frame.dash_pressed = true
	await _run(0.5)
	check(absf(player.global_position.distance_to(start) - dash_distance) < 6.0, "dash distance unchanged (%.1f)" % player.global_position.distance_to(start))
	# Resonance Elixir: lower costs, never negative
	_drink_now(&"resonance_elixir")
	check_eq(character.get_stat(Stats.RESOURCE_EFFICIENCY), 10.0, "-10 % resource costs")
	var skill: SkillDefinition = null
	for candidate: SkillDefinition in db.skills.values():
		if candidate.resource_cost > 0.0:
			skill = candidate
			break
	if skill != null:
		var runtime := map.bridge.class_runtime
		var cost := runtime.params_for(skill).cost
		check(cost > 0.0 and cost <= skill.resource_cost * 0.9 + 0.01, "%s costs %.1f of %.1f" % [skill.id, cost, skill.resource_cost])
		character.set_runtime_modifiers(&"test_many", [StatModifier.make(Stats.RESOURCE_EFFICIENCY, 500.0, 0.0)])
		check(runtime.params_for(skill).cost >= 0.0, "never a negative cost")
		character.clear_runtime_modifiers(&"test_many")
	# Whisperbloom: the general status resistance on a status component
	_drink_now(&"whisperbloom_concentrate")
	var statuses := StatusComponent.of(player, true)
	map.bridge.apply_stats()
	check(is_equal_approx(statuses.general_resistance, 0.15), "status resistance 15 %")
	# death ends the buff
	player.health.apply_hit(_lethal_hit())
	await get_tree().physics_frame
	check_eq(character.consumables.buff_item, &"", "death ends the buff")


## Applies a potion buff the normal way (slot, stack, completion) without the drink time.
func _drink_now(item_id: StringName) -> void:
	character.inventory.add_item(item_id, 1)
	character.consumables.cooldown_left = 0.0
	ConsumableService.assign_potion(character, item_id)
	check_eq(ConsumableService.complete_potion(character), "", "%s drunk" % item_id)


func test_save_load_and_migration() -> void:
	character.inventory.add_item(&"gold_coin", 200)
	ConsumableService.upgrade(character, ConsumableService.CAPACITY)
	character.consumables.charges = 1
	_drink_now(&"ember_draught")
	ConsumableService.step(character, 5.0)
	check_eq(SaveSystem.save_to(character, PATH), OK, "saved")
	var loaded := SaveSystem.load_from(PATH, db)
	check(loaded.ok(), "loaded")
	var state := loaded.character.consumables
	check(state.capacity_level == 1 and state.charges == 1, "charges and capacity kept (no refill by loading)")
	check(state.buff_item == &"ember_draught" and absf(state.buff_left - 40.0) < 0.05, "buff and its time kept")
	check(absf(state.cooldown_left - 25.0) < 0.05, "cooldown kept")
	check_eq(state.potion_slot, &"ember_draught", "slot kept")
	check_eq(loaded.character.get_stat(Stats.DAMAGE_DEALT), 8.0, "buff active again after loading")
	# v8 save: no consumables yet
	var payload := character.to_dict()
	payload.erase("consumables")
	var errors: PackedStringArray = []
	var migrated: Dictionary = SaveMigrations.migrate(payload, 8, errors)
	check(errors.is_empty(), "v8 -> v9")
	var warnings: PackedStringArray = []
	var old := Character.from_dict(migrated, db, warnings)
	check(old.consumables.capacity_level == 0 and old.consumables.potency_level == 0, "no upgrades")
	check_eq(old.consumables.charges, 2, "full base charges")
	check(old.consumables.potion_slot == &"" and old.consumables.buff_item == &"", "no slot, no buff")
	check_eq(old.inventory.to_array(), character.inventory.to_array(), "bag untouched")
	check(int(SaveSystem.VERSION) >= 9, "save version 9 or later")


func test_effect_icon_runs_clockwise_and_is_display_only() -> void:
	_drink_now(&"ember_draught")
	var bar := map.hud.effect_bar
	await get_tree().process_frame
	await get_tree().process_frame
	var icon := bar.find_child("Effect_ember_draught", true, false) as EffectBar.EffectIcon
	if not check(icon != null and icon.is_visible_in_tree(), "icon shown"):
		return
	check(icon.fraction() > 0.98, "full ring at the start (%.3f)" % icon.fraction())
	check_eq((icon.find_child("Time", true, false) as Label).text, "0:45", "time m:ss")
	ConsumableService.step(character, 15.0)
	await get_tree().process_frame
	check(absf(icon.fraction() - 30.0 / 45.0) < 0.01, "two thirds left (%.3f)" % icon.fraction())
	check_eq((icon.find_child("Time", true, false) as Label).text, "0:30", "0:30")
	check_eq(EffectBar.EffectIcon.time_text(240.0), "4:00", "minutes shown")
	var left := character.consumables.buff_left
	bar.refresh([{"id": &"ember_draught", "name": "x", "color": Color.RED, "left": 1.0, "total": 45.0}])
	check_eq(character.consumables.buff_left, left, "the display never changes the timer")
	_drink_now(&"barkskin_tonic")
	await get_tree().process_frame
	await get_tree().process_frame
	check(bar.find_child("Effect_ember_draught", true, false) == null or (bar.find_child("Effect_ember_draught", true, false) as Node).is_queued_for_deletion(), "old icon replaced")
	check(bar.find_child("Effect_barkskin_tonic", true, false) != null, "new icon")
	ConsumableService.step(character, 200.0)
	await get_tree().process_frame
	check(not bar.visible, "expired: no icon")


func test_mara_window_with_the_mouse() -> void:
	character.inventory.add_item(&"gold_coin", 160)
	var mara := map.get_node("Mara") as StoryNpc
	for dialogue in mara.definition().dialogues:   # the story with Mara is told
		character.world.set_flag(dialogue.done_flag())
	player.global_position = mara.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame
	var dialogue := DialogueService.pick(character, mara.definition())
	mara.interact(map.hud)
	await get_tree().process_frame
	if not check(dialogue == null or character.world.has_flag(dialogue.done_flag()), "only heard dialogues left"):
		return
	var panel := map.hud.flask_panel
	check(panel.visible, "Mara opens the Hearth Flask upgrades")
	check(dialogue == null or panel.find_child("Talk", true, false) != null, "her repeatable talk stays reachable (Talk)")
	var capacity := panel.find_child("Upgrade_capacity", true, false) as Button
	var potency := panel.find_child("Upgrade_potency", true, false) as Button
	check(capacity != null and not capacity.disabled, "capacity affordable (150)")
	check(potency != null and potency.disabled, "potency not affordable (200)")
	await _click(capacity)
	check_eq(character.consumables.capacity_level, 1, "bought with a click")
	check_eq(character.inventory.count(&"gold_coin"), 10, "150 gold paid")
	var again := panel.find_child("Upgrade_capacity", true, false) as Button
	check(again != null and again.disabled, "next level not affordable")


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	await get_tree().process_frame


func test_unheard_dialogue_comes_before_the_service() -> void:
	var mara := map.get_node("Mara") as StoryNpc
	for dialogue in mara.definition().dialogues:
		character.world.set_flag(dialogue.done_flag())
	var history: DialogueDefinition = null
	for dialogue in mara.definition().dialogues:
		if dialogue.id == &"mara_history":
			history = dialogue
	character.world.flags.erase(history.done_flag())
	player.global_position = mara.global_position + Vector2(0, 18)
	for i in 4:
		await get_tree().physics_frame
	mara.interact(map.hud)
	await get_tree().process_frame
	check(map.hud.dialogue_panel.visible and not map.hud.flask_panel.visible, "first the talk not heard yet")


func test_alchemy_brews_working_potions() -> void:
	var plan := {&"al_ember_draught": 1, &"al_quickstep_tincture": 1, &"al_barkskin_tonic": 2, &"al_resonance_elixir": 3}
	for recipe_id: StringName in plan:
		var recipe: ProfessionRecipeDefinition = db.profession_recipes[recipe_id]
		while character.professions.level(&"alchemy") < plan[recipe_id]:
			character.professions.add_xp(&"alchemy", character.professions.xp_to_next(&"alchemy") - character.professions.xp(&"alchemy"))
		ProfessionService.learn_automatic(character)
		for cost in recipe.inputs:
			character.inventory.add_item(cost.item_id, cost.quantity)
		check_eq(ProfessionService.craft(character, recipe_id, &"alchemists_cottage").error, "", "%s brewed at the Alchemist's Cottage" % recipe_id)
		var potion := db.get_item(recipe.output_item_id)
		check(potion.potion_effect != null and character.inventory.count(potion.id) >= 1, "%s works as a potion" % potion.id)
	var whisper: ProfessionRecipeDefinition = db.profession_recipes[&"al_whisperbloom_concentrate"]
	check(not whisper.craftable and whisper.unavailable_reason.contains("status"), "Whisperbloom not brewed while nothing applies statuses to the player")
	check(not (db.profession_recipes[&"al_stoneskin"] as ProfessionRecipeDefinition).craftable, "Stoneskin stays data only")
