extends GameplayTestCase
## Class Foundation A1: the Attack Speed stat really changes attack timings
## (phases, chain delay, lunge spread) through CombatComponent.attack_speed,
## clamped by ProgressionRules - and never touches charge tiers or dashes.

var db: GameDatabase
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	db = GameDatabase.get_default()
	character = CharacterFactory.create_new(db)
	for slot: int in EquipSlot.Slot.values():
		character.equipment.unequip(slot)


func _bind() -> void:
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)


func _speed_buff(percent: float) -> void:
	var mods: Array[StatModifier] = [StatModifier.make(Stats.ATTACK_SPEED, percent)]
	character.set_runtime_modifiers(&"test_speed", mods)


## Ticks from pressing light until the combat component is idle again.
func _light_ticks() -> int:
	var f := frame()
	await tick(light(f))
	var ticks := 1
	while player.combat.is_busy() and ticks < 120:
		await tick(f)
		ticks += 1
	return ticks


func test_stat_drives_speed_with_bounds_and_no_double_application() -> void:
	_bind()
	check_eq(player.combat.attack_speed, 1.0, "neutral without bonuses")
	_speed_buff(25.0)
	check_near(player.combat.attack_speed, 1.25, 0.0001, "+25 % attack speed")
	bridge.apply_stats()
	bridge.apply_stats()
	check_near(player.combat.attack_speed, 1.25, 0.0001, "re-applying stats never stacks")
	_speed_buff(200.0)
	check_near(player.combat.attack_speed, db.rules.attack_speed_max, 0.0001, "clamped to the data maximum")
	_speed_buff(-90.0)
	check_near(player.combat.attack_speed, db.rules.attack_speed_min, 0.0001, "clamped to the data minimum")
	character.clear_runtime_modifiers(&"test_speed")
	check_eq(player.combat.attack_speed, 1.0, "removing the buff restores the data timings")


func test_faster_attacks_finish_sooner_and_still_hit_once() -> void:
	_bind()
	add_target(Vector2(22, 0))
	await wait_physics(2)
	var base_ticks: int = await _light_ticks()
	await tick(frame(), 40)
	_speed_buff(30.0)
	var fast_ticks: int = await _light_ticks()
	var attack := SWORD.get_attack(&"sword_light_1")
	check_eq(base_ticks, seconds_to_ticks(attack.total_duration()) + 1, "base timing from data")
	check(fast_ticks <= ceili(attack.total_duration() / 1.3 / FRAME) + 2 and fast_ticks < base_ticks - 3,
		"+30 %% attack speed shortens the swing (%d -> %d ticks)" % [base_ticks, fast_ticks])
	check_eq(hits.size(), 2, "exactly one hit per swing at both speeds")


func test_lunge_distance_and_combo_preserved() -> void:
	_bind()
	track_player_attacks()
	_speed_buff(40.0)
	await wait_physics(2)
	var f := frame()
	var start := player.global_position
	await tick(light(f))
	await tick(f, 30)
	var lunge := SWORD.get_attack(&"sword_light_1").lunge_distance
	check_near(player.global_position.distance_to(start), lunge, 0.6, "lunge covers exactly its distance faster")
	await tick(f, 40)
	started_attacks.clear()
	for i in 3:
		await tick(light(f))
		await tick(f, 14)
	check_eq(started_attacks, [&"sword_light_1", &"sword_light_2", &"sword_light_3"] as Array[StringName],
		"combo chain intact at higher attack speed")


func test_charge_tiers_and_dash_unaffected() -> void:
	_bind()
	_speed_buff(40.0)
	await wait_physics(2)
	var f := frame()
	await tick(heavy_down(f))
	var profile := player.combat.charging_attack.charge_profile
	var ticks := 1
	while player.combat.get_charge_tier_preview() < 1:
		await tick(f)
		ticks += 1
	check_eq(ticks, ceili(profile.tier_thresholds[0] / FRAME) + 1, "charge tier 1 after the data threshold")
	await tick(heavy_up(f))
	await tick(f, 60)
	var fast: Array = await _dash_profile(f)
	character.clear_runtime_modifiers(&"test_speed")
	await tick(f, 200)
	var normal: Array = await _dash_profile(f)
	check_eq(fast, normal, "dash duration and iFrames unchanged (%s)" % [fast])
	check_eq(player.dash.charges, player.dash.config.max_charges - 1, "dash charges unchanged")


## [dash ticks, invulnerable ticks] of one dash.
func _dash_profile(f: InputFrame) -> Array:
	var dashing := 0
	var invulnerable := 0
	await tick(dash_press(f))
	while player.dash.is_dashing():
		dashing += 1
		invulnerable += 1 if player.dash.is_invulnerable() else 0
		await tick(f)
	return [dashing, invulnerable]


func test_attack_speed_scaling_per_attack() -> void:
	var combat := new_combat()
	combat.attack_speed = 1.3
	var attack := SWORD.get_attack(&"sword_light_1").duplicate() as AttackDefinition
	check_near(combat.effective_speed(attack), 1.3, 0.0001, "full scaling")
	attack.attack_speed_scaling = 0.0
	check_eq(combat.effective_speed(attack), 1.0, "scaling 0 keeps the data timing")
	attack.attack_speed_scaling = 0.5
	check_near(combat.effective_speed(attack), 1.15, 0.0001, "half scaling")
