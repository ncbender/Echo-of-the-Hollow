extends GameplayTestCase
## Combat Telegraphs 1.0 (docs/COMBAT_TELEGRAPHS_1_0.md): the windup symbol follows the real defense rules
## (DefenseComponent.resolve) for every flag combination, every production enemy attack gets its kind from the
## data, the telegraph shows only during the startup and ends with the active phase, a stagger and death, the
## symbol never lies on the attack area, and a parry shows no "PARRY" text. Display only - no data or timing changed.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")
const K := AttackDefinition.Telegraph


func _attack(flags: int) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"telegraph_probe"
	attack.defense_flags = flags
	return attack


## What the defender really gets against `attack`, standing in `state` and facing the attacker.
func _outcome(state: DefenseComponent.State, attack: AttackDefinition) -> DefenseComponent.Outcome:
	var defense := player.defense
	defense.cancel()
	defense.state = state
	defense.state_left = 1.0
	var hit := HitData.new()
	hit.attack = attack
	hit.damage = 10.0
	return defense.resolve(hit, Vector2.ZERO, Vector2.RIGHT)


## Every flag combination (also ones the content does not use, e.g. parryable but not blockable): the kind equals
## what the defense really allows - a parry works <=> PARRYABLE; else a holding block <=> BLOCK_ONLY; else neither.
func test_kind_follows_the_real_defense_rules() -> void:
	spawn_player()
	await wait_physics(2)
	if not check(player.defense.profile() != null, "the player has a guard profile"):
		return
	var names := {K.PARRYABLE: "PARRYABLE", K.BLOCK_ONLY: "BLOCK_ONLY", K.UNDEFENDABLE: "UNDEFENDABLE"}
	for flags in 8:
		var attack := _attack(flags)
		var parried := _outcome(DefenseComponent.State.PARRY, attack) == DefenseComponent.Outcome.PARRIED
		var blocked := _outcome(DefenseComponent.State.BLOCK, attack) == DefenseComponent.Outcome.BLOCKED
		var expected := K.PARRYABLE if parried else (K.BLOCK_ONLY if blocked else K.UNDEFENDABLE)
		check_eq(names[attack.telegraph_kind()], names[expected], "flags %d (parry %s, block holds %s)" % [flags, parried, blocked])
	player.defense.cancel()
	# Guard Breaking is not "unblockable": blockable + guard break meets the block and breaks it
	var breaker := _attack(AttackDefinition.DEFENSE_BLOCKABLE | AttackDefinition.DEFENSE_GUARD_BREAK)
	check(not breaker.is_unblockable(), "guard break is not unblockable")
	check_eq(_outcome(DefenseComponent.State.BLOCK, breaker), DefenseComponent.Outcome.GUARD_BROKEN, "the block is broken")
	check_eq(breaker.telegraph_kind(), K.UNDEFENDABLE, "so it can be neither parried nor safely blocked")
	check_eq(_attack(AttackDefinition.DEFENSE_PARRYABLE).telegraph_kind(), K.PARRYABLE, "parryable but not blockable: still parryable")
	player.defense.cancel()


## The production enemy attacks: their kind comes from their own flags (nothing changed in the data).
func test_production_attacks() -> void:
	var expected := {
		&"grunt_swipe": K.PARRYABLE, &"grunt_slam": K.PARRYABLE,
		&"warden_swipe": K.BLOCK_ONLY, &"warden_slam": K.UNDEFENDABLE,
		&"sentinel_strike": K.PARRYABLE, &"sentinel_root_slam": K.BLOCK_ONLY,
	}
	var flags := {&"grunt_swipe": 3, &"grunt_slam": 7, &"warden_swipe": 1, &"warden_slam": 0, &"sentinel_strike": 3, &"sentinel_root_slam": 1}
	for path: String in ["res://data/enemies/grunt_attacks.tres", "res://data/enemies/grove_warden_attacks.tres", "res://data/enemies/sentinel_attacks.tres"]:
		var family := load(path) as WeaponFamily
		for attack: AttackDefinition in family.attacks:
			check_eq(attack.defense_flags, int(flags[attack.id]), "%s flags unchanged" % attack.id)
			check_eq(attack.telegraph_kind(), expected[attack.id], "%s telegraph" % attack.id)


## A real grunt: the symbol only during the startup, gone in the active phase, after a stagger and after death.
func test_shown_only_during_startup() -> void:
	spawn_player()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(140, 0)   # out of reach: it chases first
	enemy.target = player
	add_child(enemy)
	var view := enemy.get_node("View") as EnemyView
	await wait_physics(2)
	check_eq(view.current_telegraph(), -1, "nothing while chasing")
	var seen := -1
	for i in 240:
		await tick(frame(), 1)
		if enemy.state == Enemy.State.TELEGRAPH:
			seen = view.current_telegraph()
			break
	check_eq(seen, enemy.combat.current_attack.telegraph_kind() if enemy.combat.current_attack != null else -2, "the windup shows its kind")
	var startup := enemy.combat.current_attack.startup
	for i in 240:
		await tick(frame(), 1)
		if enemy.state != Enemy.State.TELEGRAPH:
			break
	check(enemy.state != Enemy.State.TELEGRAPH and view.current_telegraph() == -1, "gone after the startup (%.2f s)" % startup)
	# the next windup, interrupted by a poise break
	for i in 240:
		await tick(frame(), 1)
		if enemy.state == Enemy.State.TELEGRAPH:
			break
	var breaker := HitData.new()
	breaker.poise_damage = 1000.0
	enemy.hurtbox.receive_hit(breaker)
	await tick(frame(), 1)
	check_eq(view.current_telegraph(), -1, "gone when staggered")
	enemy.health.apply_hit(_kill())
	await tick(frame(), 1)
	check_eq(view.current_telegraph(), -1, "gone when dead")
	enemy.queue_free()


func _kill() -> HitData:
	var hit := HitData.new()
	hit.damage = 99999.0
	return hit


## The symbol never lies on the attack area (cone from the enemy in the attack direction), whatever the direction.
func test_symbol_off_the_area() -> void:
	spawn_player()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	add_child(enemy)
	var view := enemy.get_node("View") as EnemyView
	await wait_physics(1)
	for attack: AttackDefinition in (load("res://data/enemies/grove_warden_attacks.tres") as WeaponFamily).attacks:
		for step in 16:
			var direction := Vector2.from_angle(TAU * step / 16.0)
			var anchor := view.symbol_anchor(direction)
			var reach := attack.reach + 8.0   # symbol size and the reach bonus of the current phase
			var inside := anchor.length() <= reach and absf(direction.angle_to(anchor)) <= deg_to_rad(attack.arc_degrees) * 0.5 + 0.2
			check(not inside, "%s %d: symbol %s off the area" % [attack.id, step, anchor])
	enemy.queue_free()
