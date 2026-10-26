extends GameplayTestCase
## Class Foundation B: active skills on Q/E/R/F through the real Player and
## bridge: slots, availability, resource costs, cooldowns, cancel rules (dash,
## attacks), Form/Resonance mods (fit, unlock, compatibility), transformative
## talents, skill hits as SKILL source with stats applied once.

const CLASS_ID := &"test_mage"
const DUMMY_SCENE: PackedScene = preload("res://scenes/dummy/training_dummy.tscn")

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge
var skill_hits: Array[HitData] = []


func before_each() -> void:
	db = preload("res://tests/integration/test_talents.gd").class_database()
	character = CharacterFactory.create_new(db)
	character.classes.unlock(CLASS_ID)
	character.switch_class(CLASS_ID, true)
	for slot: int in EquipSlot.Slot.values():
		character.equipment.unequip(slot)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	bridge.effects.hit_dispatched.connect(func(hit: HitData) -> void:
		if hit.source == HitData.Source.SKILL:
			skill_hits.append(hit))


func _dummy(at: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _press(slot: int) -> InputFrame:
	var f := frame()
	f.ability_slot = slot
	return f


func _level(level: int) -> void:
	character.classes.add_xp(CLASS_ID, 120 * (level - character.classes.get_level(CLASS_ID)))


func test_slots_availability_and_station_rule() -> void:
	var build := character.builds.get_build()
	check_eq(build.slots[0], &"t_bolt", "level 1 skill auto-slotted on unlock")
	check(not SkillBook.is_skill_available(character, CLASS_ID, &"t_ward"), "level 3 skill locked")
	_level(3)
	check(SkillBook.is_skill_available(character, CLASS_ID, &"t_ward"), "level 3 unlocks t_ward")
	check_eq(build.slot_of(&"t_ward"), 1, "auto-filled into the next empty slot")
	check(SkillBook.assign_slot(character, CLASS_ID, 3, &"t_bolt", false) != "", "rearranging needs a class station")
	check_eq(SkillBook.assign_slot(character, CLASS_ID, 3, &"t_bolt", true), "", "moved at the station")
	check_eq(build.slots[3], &"t_bolt", "now on F")
	check_eq(build.slots.count(&"t_bolt"), 1, "a skill is never slotted twice")
	check(SkillBook.assign_slot(character, CLASS_ID, 2, &"t_nova", true) != "", "locked skill refused")


func test_cast_costs_resource_and_starts_cooldown() -> void:
	_bind()
	var dummy := _dummy(Vector2(60, 0))
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	check_eq(pool.value, 100.0, "mana starts full")
	await tick(_press(0))
	await tick(frame(), 30)
	check_near(pool.value, 90.0 + 5.0 * 31 * FRAME, 0.2, "10 mana spent (plus regen)")
	check_eq(skill_hits.size(), 1, "bolt hit the dummy once")
	if not skill_hits.is_empty():
		check_eq(skill_hits[0].damage_type, &"arcane", "skill damage type")
		check_eq(skill_hits[0].attacker, player, "credited to the player")
		check(dummy.health.health < dummy.health.max_health, "dummy damaged")
	var messages: Array[String] = []
	bridge.message.connect(func(text: String) -> void: messages.append(text))
	await tick(_press(0))
	check(bridge.class_runtime.cooldown_left(&"t_bolt") <= 0.0 or messages.any(func(m: String) -> bool: return m.contains("cooldown")),
		"recast during cooldown refused with a message")
	pool.spend(pool.value)
	await tick(frame(), seconds_to_ticks(1.2))
	pool.spend(pool.value)
	await tick(_press(0))
	check(messages.any(func(m: String) -> bool: return m.contains("Not enough")), "not enough mana: %s" % [messages])


func test_cast_lock_blocks_attacks_and_dash_cancels_it() -> void:
	_bind()
	track_player_attacks()
	await wait_physics(2)
	var f := _press(0)
	f.light_pressed = true
	await tick(f)
	check(player.skill_lock_left > 0.0, "cast lock running")
	check(started_attacks.is_empty(), "no light attack starts during the cast")
	await tick(dash_press(frame()))
	check(player.dash.is_dashing(), "dash still possible")
	check_eq(player.skill_lock_left, 0.0, "dash ends the lock")
	check_eq(player.dash.charges, player.dash.config.max_charges - 1, "normal dash charge used")


func test_skill_cancels_light_attack_like_a_dash() -> void:
	_bind()
	track_player_attacks()
	await wait_physics(2)
	await tick(light(frame()))
	check(player.combat.is_busy(), "attacking")
	await tick(_press(0))
	check(not player.combat.is_busy(), "skill cancelled the light attack")
	check(bridge.class_runtime.cooldown_left(&"t_bolt") > 0.0, "skill was cast")


func test_mods_fit_unlock_and_compatibility() -> void:
	var form := SkillModDefinition.Slot.FORM
	var resonance := SkillModDefinition.Slot.RESONANCE
	check(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", form, &"f_split", false) != "", "station required")
	check_eq(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", form, &"f_split", true), "", "form mod")
	check(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", resonance, &"f_split", true).contains("Form"), "wrong slot type")
	check(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", resonance, &"r_focus", true).contains("not unlocked"), "locked mod")
	character.builds.get_build().unlocked_mods.append(&"r_focus")
	check(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", resonance, &"r_focus", true).contains("cannot be combined"), "incompatible pair")
	check_eq(SkillBook.set_mod(character, CLASS_ID, &"t_bolt", resonance, &"r_siphon", true), "", "compatible resonance")
	_level(3)
	check(SkillBook.set_mod(character, CLASS_ID, &"t_ward", form, &"f_split", true) != "", "mod does not fit another skill")
	var params := bridge_params(&"t_bolt")
	check_eq(params.extra_projectiles, 2, "form mod applied")
	check_eq(params.resource_on_hit, 5.0, "resonance mod applied")
	check_eq(params.mod_ids, [&"f_split", &"r_siphon"] as Array[StringName], "both slots, once each")


func bridge_params(skill_id: StringName) -> SkillParams:
	var runtime := ClassRuntime.new()
	runtime.character = character
	return runtime.params_for(db.skills[skill_id])


func test_transformative_talent_changes_skill_without_slot() -> void:
	_level(25)
	for i in 5:
		TalentService.learn(character, CLASS_ID, &"ta_1")
	for i in 5:
		TalentService.learn(character, CLASS_ID, &"ta_2")
	check_eq(TalentService.learn(character, CLASS_ID, &"ta_3b"), "", "transformative talent learned")
	var params := bridge_params(&"t_bolt")
	check_eq(params.extra_pierce, 1, "bolt pierces through the talent")
	check(&"t_bolt_pierce" in params.mod_ids, "talent transformation listed")
	TalentService.respec(character, CLASS_ID, true)
	check_eq(bridge_params(&"t_bolt").extra_pierce, 0, "respec removes the transformation")


func test_projectile_mods_hit_several_targets_and_refund() -> void:
	_bind()
	character.builds.get_build().set_mod(&"t_bolt", SkillModDefinition.Slot.FORM, &"f_split")
	character.builds.get_build().set_mod(&"t_bolt", SkillModDefinition.Slot.RESONANCE, &"r_siphon")
	for y: float in [-14.0, 0.0, 14.0]:
		_dummy(Vector2(70, y))
	await wait_physics(2)
	var pool := bridge.class_runtime.pool
	pool.spend(50.0)
	var before := pool.value
	await tick(_press(0))
	await tick(frame(), 40)
	var targets := {}
	for hit in skill_hits:
		targets[hit.target] = true
	check(targets.size() >= 2, "split bolts hit several dummies (%d)" % targets.size())
	check(pool.value > before - 10.0 + 5.0 * (skill_hits.size() - 1), "siphon refunds mana per hit")


func test_skill_damage_stat_applies_once() -> void:
	_bind()
	_dummy(Vector2(50, 0))
	var mods: Array[StatModifier] = [StatModifier.make(Stats.SKILL_DAMAGE, 50.0), StatModifier.make(Stats.PHYSICAL_DAMAGE, 100.0)]
	character.set_runtime_modifiers(&"test", mods)
	bridge.apply_stats()
	bridge.apply_stats()
	await wait_physics(2)
	await tick(_press(0))
	await tick(frame(), 30)
	check_eq(skill_hits.size(), 1, "one hit")
	if not skill_hits.is_empty():
		check_near(skill_hits[0].damage, 15.0, 0.01, "+50 % skill damage, physical bonus not for arcane")
