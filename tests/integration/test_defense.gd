extends GameplayTestCase
## Combat Defense & Feedback 0.4 B: Block & Parry on Shift - parry window,
## block, whiff recovery, direction, unblockable / guard-breaking attacks,
## anti-spam, interaction with heavy charge, dash, hit reactions and death,
## enemy and boss reactions, profiles per weapon/shield, real grunt attacks.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const GRUNT_ATTACKS: WeaponFamily = preload("res://data/enemies/grunt_attacks.tres")
const WARDEN_ATTACKS: WeaponFamily = preload("res://data/enemies/grove_warden_attacks.tres")
const BOSS_CONFIG: EnemyConfig = preload("res://data/enemies/grove_warden_config.tres")
const GREATSWORD: WeaponFamily = LEGACY_GREATSWORD

var enemy: Enemy


func _setup(enemy_at: Vector2 = Vector2(24, 0), config: EnemyConfig = null) -> void:
	spawn_legacy_player()
	enemy = GRUNT_SCENE.instantiate()
	if config != null:
		enemy.config = config
	enemy.position = enemy_at
	enemy.target = player
	add_child(enemy)
	enemy.config = enemy.config.duplicate()
	enemy.config.move_speed = 0.0
	enemy.config.attack_range = 0.0   # never attacks on its own unless a test wants it
	await wait_physics(2)


## A hit of `attack` from the test enemy onto the player (the real hurtbox path).
func _hit(attack: AttackDefinition) -> HitData:
	var hit := HitData.new()
	hit.attacker = enemy
	hit.attack = attack
	hit.damage = attack.damage
	hit.poise_damage = attack.poise_damage
	hit.knockback = (player.global_position - enemy.global_position).normalized() * attack.knockback
	hit.reaction = attack.hit_reaction
	hit.tags = attack.effect_tags.duplicate()
	player.hurtbox.receive_hit(hit)
	return hit


func _shift(f: InputFrame, held: bool = true) -> InputFrame:
	f.defend_pressed = true
	f.defend_held = held
	return f


func _hold(held: bool = true) -> InputFrame:
	var f := frame()
	f.defend_held = held
	return f


func _swipe() -> AttackDefinition:
	return GRUNT_ATTACKS.get_attack(&"grunt_swipe")


func test_profiles_follow_weapon_and_shield() -> void:
	spawn_legacy_player()
	await wait_physics(1)
	check_eq(player.defense.profile().id, &"sword_guard", "one-handed sword: Sword Guard")
	player.set_weapon_family(GREATSWORD)
	check_eq(player.defense.profile().id, &"heavy_guard", "greatsword: Heavy Guard")
	var db := GameDatabase.get_default()
	var character := CharacterFactory.create_new(db)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	var bridge := PlayerProgressionBridge.new()
	player.add_child(bridge)
	bridge.bind(player, character)
	var sword := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"iron_sword")[0] as ItemInstance
	var shield := character.inventory.add_item(&"oak_shield")[0]
	character.equipment.equip(sword.instance_id, EquipSlot.Slot.MAIN_HAND)
	check_eq(character.equipment.equip(shield.instance_id, EquipSlot.Slot.OFF_HAND), "", "shield equipped")
	check_eq(player.defense.profile().id, &"shield_guard", "shield overrides: Shield Guard")
	character.equipment.unequip(EquipSlot.Slot.OFF_HAND)
	check_eq(player.defense.profile().id, &"sword_guard", "shield removed: weapon profile again")
	var guards := [db.get_item(&"oak_shield").defense_profile, GREATSWORD.defense_profile, preload("res://data/weapons/one_handed_sword.tres").defense_profile]
	check(guards[0].block_reduction > guards[2].block_reduction and guards[2].block_reduction > guards[1].block_reduction,
		"shield blocks most, greatsword least")


func test_parry_in_window_negates_rewards_and_opens_counter() -> void:
	await _setup()
	var hp := player.health.health
	await tick(_shift(frame()))
	check_eq(player.defense.state, DefenseComponent.State.PARRY, "Shift opens the parry window")
	await tick(_hold(), 4)   # 5 ticks = 83 ms < 150 ms
	var poise := enemy.health.poise
	var hit := _hit(_swipe())
	check(&"parried" in hit.tags, "parried")
	check_eq(player.health.health, hp, "no damage")
	check_near(poise - enemy.health.poise, player.defense.profile().parry_poise_damage, 0.01, "attacker takes parry poise damage")
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "free to act after a parry")
	check(player.defense.counter_left > 0.0, "counter window open")
	var target := add_target(enemy.global_position + Vector2(0, -50))
	target.get_parent().position = Vector2(22, 0)
	enemy.queue_free()
	await wait_physics(2)
	await tick(light(frame()))
	await tick(frame(), 10)
	check(hits.size() == 1 and &"counter" in hits[0].tags, "the next weapon hit is a counter")
	if not hits.is_empty():
		check_near(hits[0].damage, SWORD.get_attack(&"sword_light_1").damage * 1.5, 0.01, "counter damage x1.5")
	check_eq(player.defense.counter_left, 0.0, "counter used once")


func test_block_after_window_and_whiff_without_holding() -> void:
	await _setup()
	var swipe := _swipe()
	await tick(_shift(frame()))
	await tick(_hold(), 15)   # window over, still holding -> block
	check_eq(player.defense.state, DefenseComponent.State.BLOCK, "holding turns into a block")
	var hp := player.health.health
	var hit := _hit(swipe)
	check(&"blocked" in hit.tags, "blocked")
	check_near(hp - player.health.health, swipe.damage * (1.0 - 0.45), 0.01, "45 %% less damage")
	check_near(hit.knockback.length(), swipe.knockback * 0.5, 0.01, "half knockback")
	check_eq(player.defense.state, DefenseComponent.State.BLOCK, "the block holds")
	await tick(_hold(false))
	check_eq(player.defense.state, DefenseComponent.State.RECOVERY, "release -> block recovery")
	await tick(frame(), 20)
	await tick(_shift(frame(), false))   # tap: window, then whiff
	await tick(frame(), 10)
	check_eq(player.defense.state, DefenseComponent.State.RECOVERY, "released parry = whiff recovery")
	hp = player.health.health
	_hit(swipe)
	check_near(hp - player.health.health, swipe.damage, 0.01, "a missed parry does not protect")
	track_player_attacks()
	await tick(light(frame()))
	check(started_attacks.is_empty(), "no attack during the recovery")


func test_direction_and_unblockable_and_guard_break() -> void:
	await _setup(Vector2(-24, 0))   # behind the player (player faces right)
	await tick(_shift(frame()))
	var hp := player.health.health
	var hit := _hit(_swipe())
	check(not &"parried" in hit.tags and not &"blocked" in hit.tags, "attack from behind ignores the defense")
	check_near(hp - player.health.health, _swipe().damage, 0.01, "full damage from behind")
	enemy.global_position = Vector2(24, 0)
	await tick(frame(), 40)
	await tick(_shift(frame()))
	var slam := WARDEN_ATTACKS.get_attack(&"warden_slam")
	check(slam.is_unblockable(), "Grove Warden slam is unblockable")
	hp = player.health.health
	hit = _hit(slam)
	check(&"unblockable" in hit.tags, "tagged unblockable")
	check_near(hp - player.health.health, slam.damage, 0.01, "unblockable: full damage even in the parry window")
	await tick(frame(), 60)
	await tick(_shift(frame()))
	await tick(_hold(), 15)
	var grunt_slam := GRUNT_ATTACKS.get_attack(&"grunt_slam")
	hp = player.health.health
	hit = _hit(grunt_slam)
	check(&"guard_break" in hit.tags, "grunt slam breaks the guard")
	check_near(hp - player.health.health, grunt_slam.damage, 0.01, "guard break: full damage")
	check(player.defense.state != DefenseComponent.State.BLOCK, "block is gone")


func test_anti_spam_and_holding_never_reopens_the_window() -> void:
	await _setup()
	await tick(_shift(frame()))
	await tick(_hold(), 20)
	check_eq(player.defense.state, DefenseComponent.State.BLOCK, "holding: block, no new parry window")
	await tick(_hold(false))
	await tick(_shift(frame()))
	check(player.defense.state != DefenseComponent.State.PARRY, "a new press during the recovery/cooldown opens no window")
	await tick(frame(), 40)
	await tick(_shift(frame()))
	check_eq(player.defense.state, DefenseComponent.State.PARRY, "after the anti-spam cooldown a new parry works")


func test_parry_cancels_heavy_charge_but_not_a_committed_heavy() -> void:
	await _setup()
	await tick(heavy_down(frame()))
	await tick(_hold_charge(), 10)
	check_eq(player.combat.state, CombatComponent.State.CHARGING, "charging")
	var f := _hold_charge()
	await tick(_shift(f))
	check_eq(player.defense.state, DefenseComponent.State.PARRY, "Shift cancels the heavy charge (like a dash)")
	check_eq(player.combat.state, CombatComponent.State.IDLE, "charge gone")
	await tick(frame(), 60)
	await tick(heavy_down(frame()))
	await tick(heavy_up(frame()))
	await tick(frame(), seconds_to_ticks(SWORD.get_attack(&"sword_heavy").startup) + 1)
	check_eq(player.combat.phase, CombatComponent.Phase.ACTIVE, "heavy in its active phase")
	await tick(_shift(frame()))
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "no defense cancel where a dash cancel is not allowed")


func _hold_charge() -> InputFrame:
	var f := frame()
	f.heavy_held = true
	return f


func test_dash_reactions_and_death() -> void:
	await _setup()
	await tick(dash_press(frame()))
	check(player.dash.is_dashing(), "dashing")
	await tick(_shift(frame()))
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "no defense during a dash")
	await tick(frame(), 60)
	await tick(_shift(frame()))
	await tick(_hold(), 15)
	check_eq(player.defense.state, DefenseComponent.State.BLOCK, "blocking")
	var f := _hold()
	var reference := ceili(player.dash.config.iframe_duration / FRAME)   # ticks of a plain dash (test_dash)
	await tick(dash_press(f))
	check(player.dash.is_dashing(), "a dash leaves the block")
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "block cancelled by the dash")
	var invulnerable := 0
	while player.dash.is_dashing():
		invulnerable += 1 if player.dash.is_invulnerable() else 0
		await tick(_hold())
	check_eq(invulnerable, reference, "dash iFrames unchanged")
	await tick(frame(), 30)
	var knock := HitData.new()
	knock.attacker = enemy
	knock.reaction = HitReaction.Type.KNOCKBACK
	player.hurtbox.receive_hit(knock)
	await tick(_shift(frame()))
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "no defense while knocked back")
	await tick(frame(), 40)
	await tick(_shift(frame()))
	var lethal := HitData.new()
	lethal.damage = 100000.0
	player.hurtbox.receive_hit(lethal)   # no attack data: not defendable
	check(player.health.is_dead(), "dead")
	check_eq(player.defense.state, DefenseComponent.State.IDLE, "defense ends on death")


func test_boss_is_never_locked_by_parries() -> void:
	await _setup(Vector2(24, 0), BOSS_CONFIG)
	enemy.config.parry_interrupts = false
	var poise := enemy.health.poise
	await tick(_shift(frame()))
	_hit(_swipe())
	check_near(poise - enemy.health.poise, player.defense.profile().parry_poise_damage * BOSS_CONFIG.parry_poise_multiplier, 0.01,
		"boss takes reduced parry poise")
	var warden_swipe := WARDEN_ATTACKS.get_attack(&"warden_swipe")
	check(warden_swipe.defense_flags == AttackDefinition.DEFENSE_BLOCKABLE, "Warden swipe: blockable, not parryable")
	await tick(frame(), 40)
	await tick(_shift(frame()))
	var hp := player.health.health
	var hit := _hit(warden_swipe)
	check(&"blocked" in hit.tags and not &"parried" in hit.tags, "in the parry window the warden swipe is only blocked")
	check(hp - player.health.health > 0.0, "still some damage")


func test_real_grunt_swipe_parried_and_interrupted() -> void:
	await _setup()
	enemy.config.attack_range = 40.0
	enemy.config.heavy_attack_interval = 0
	var hp := player.health.health
	var parried := false
	for i in 240:
		var f := frame()
		if enemy.combat.state == CombatComponent.State.ATTACKING and enemy.combat.phase == CombatComponent.Phase.STARTUP \
				and enemy.combat.current_attack.startup - enemy.combat.phase_time <= 4 * FRAME and player.defense.state == DefenseComponent.State.IDLE:
			_shift(f)
		await tick(f)
		if player.defense.last_outcome == DefenseComponent.Outcome.PARRIED:
			parried = true
			break
	check(parried, "a real grunt swipe was parried with Shift timed to the telegraph")
	check_eq(player.health.health, hp, "no damage")
	check(enemy.combat.state != CombatComponent.State.ATTACKING, "the grunt's attack was interrupted")


func test_combo_timings_unchanged_with_defense_present() -> void:
	spawn_legacy_player()
	track_player_attacks()
	await wait_physics(1)
	var f := frame()
	await tick(light(f))
	var ticks := 1
	while player.combat.is_busy():
		await tick(f)
		ticks += 1
	check_eq(ticks, seconds_to_ticks(SWORD.get_attack(&"sword_light_1").total_duration()) + 1, "light attack duration unchanged")
	await tick(f, 40)   # let the combo window close
	for i in 3:
		await tick(light(f))
		await tick(f, 14)
	check_eq(started_attacks.slice(1), [&"sword_light_1", &"sword_light_2", &"sword_light_3"] as Array[StringName], "combo chain unchanged")
