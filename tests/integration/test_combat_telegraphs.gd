extends GameplayTestCase
## Combat Telegraphs 1.0 (docs/COMBAT_TELEGRAPHS_1_0.md): the telegraph kind follows the real defense rules
## (DefenseComponent.resolve) for every flag combination, every production enemy attack gets its kind from the
## data, the telegraph shows only during the startup and ends with the active phase, a stagger and death, and a
## parry shows no "PARRY" text. The symbols are gone (Parry Timing Cue 1.0, test_parry_timing_cue). Display only.

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
		&"husk_swipe": K.PARRYABLE, &"husk_slam": K.BLOCK_ONLY,   # Hardened Husk Defense Mix 1.0
	}
	var flags := {&"grunt_swipe": 3, &"grunt_slam": 7, &"warden_swipe": 1, &"warden_slam": 0, &"sentinel_strike": 3, &"sentinel_root_slam": 1,
		&"husk_swipe": 3, &"husk_slam": 1}
	for path: String in ["res://data/enemies/grunt_attacks.tres", "res://data/enemies/grove_warden_attacks.tres", "res://data/enemies/sentinel_attacks.tres",
			"res://data/enemies/hardened_husk_attacks.tres"]:
		var family := load(path) as WeaponFamily
		for attack: AttackDefinition in family.attacks:
			check_eq(attack.defense_flags, int(flags[attack.id]), "%s flags unchanged" % attack.id)
			check_eq(attack.telegraph_kind(), expected[attack.id], "%s telegraph" % attack.id)


## A real grunt: the telegraph only during the startup, gone in the active phase, after a stagger and after death.
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


# --- Hardened Husk Defense Mix 1.0 ---------------------------------------------------------------------------------

const HUSK := preload("res://data/enemies/hardened_husk.tres")
const HUSK_ATTACKS := preload("res://data/enemies/hardened_husk_attacks.tres")
const GRUNT_ATTACKS := preload("res://data/enemies/grunt_attacks.tres")
## The only differences the mix may have from the grunt attacks it is copied from.
const OWN := [&"id", &"display_name", &"weapon_family_id", &"defense_flags", &"resource_path", &"resource_name", &"script"]


## Every value and timing of the husk attacks equals the grunt attack it comes from - only the ids and the slam's
## flags differ (swipe 3 = parryable, slam 1 = blockable only, no guard break); the grunt data is untouched.
func test_husk_family_is_the_grunt_family_with_new_flags() -> void:
	check_eq([HUSK_ATTACKS.root_light, HUSK_ATTACKS.root_heavy], [&"husk_swipe", &"husk_slam"], "light and heavy roots")
	for pair: Array in [[&"grunt_swipe", &"husk_swipe"], [&"grunt_slam", &"husk_slam"]]:
		var grunt := GRUNT_ATTACKS.get_attack(pair[0])
		var husk := HUSK_ATTACKS.get_attack(pair[1])
		var differ: PackedStringArray = []
		for property: Dictionary in grunt.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE == 0 or StringName(property.name) in OWN:
				continue
			if _value(grunt.get(property.name)) != _value(husk.get(property.name)):
				differ.append(property.name)
		check(differ.is_empty(), "%s: same values and timings as %s (%s)" % [pair[1], pair[0], differ])
	check_eq([GRUNT_ATTACKS.get_attack(&"grunt_swipe").defense_flags, GRUNT_ATTACKS.get_attack(&"grunt_slam").defense_flags], [3, 7], "grunt flags unchanged")
	check_eq([HUSK_ATTACKS.get_attack(&"husk_swipe").defense_flags, HUSK_ATTACKS.get_attack(&"husk_slam").defense_flags], [3, 1], "husk: swipe parryable, slam block only")
	check(HUSK.attacks == HUSK_ATTACKS, "the Hardened Husk config carries its family")


## Real defense against the husk: the swipe is parried; the slam is not parried, is blocked with the same damage
## reduction as any held block, and never breaks the guard.
func test_husk_defense_outcomes() -> void:
	spawn_player()
	await wait_physics(2)
	var swipe := HUSK_ATTACKS.get_attack(&"husk_swipe")
	var slam := HUSK_ATTACKS.get_attack(&"husk_slam")
	check_eq(_outcome(DefenseComponent.State.PARRY, swipe), DefenseComponent.Outcome.PARRIED, "swipe parried")
	check(_outcome(DefenseComponent.State.PARRY, slam) != DefenseComponent.Outcome.PARRIED, "slam not parried")
	var reference := HitData.new()
	reference.attack = _attack(AttackDefinition.DEFENSE_BLOCKABLE)
	reference.damage = 20.0
	var blocked := HitData.new()
	blocked.attack = slam
	blocked.damage = 20.0
	for hit: HitData in [reference, blocked]:
		player.defense.cancel()
		player.defense.state = DefenseComponent.State.BLOCK
		player.defense.state_left = 1.0
		check_eq(player.defense.resolve(hit, Vector2.ZERO, Vector2.RIGHT), DefenseComponent.Outcome.BLOCKED, "%s blocked" % hit.attack.id)
	check(is_equal_approx(blocked.damage, reference.damage) and blocked.damage < 20.0, "normal block reduction (%.1f)" % blocked.damage)
	check(not &"guard_break" in blocked.tags and player.defense.last_outcome != DefenseComponent.Outcome.GUARD_BROKEN, "no guard break")
	player.defense.cancel()


## The config decides the husk's attacks wherever it is spawned (maps, encounters, trials all spawn through the same
## Enemy._ready); enemies without EnemyConfig.attacks keep theirs (scene grunt attacks, or a boss family).
func test_husk_spawns_use_the_family_others_keep_theirs() -> void:
	spawn_player()
	var husk: Enemy = GRUNT_SCENE.instantiate()
	husk.config = HUSK
	add_child(husk)
	var grunt: Enemy = GRUNT_SCENE.instantiate()
	grunt.config = load("res://data/enemies/grunt_config.tres")
	add_child(grunt)
	var wolf: Enemy = GRUNT_SCENE.instantiate()
	wolf.config = load("res://data/enemies/hollowfang_wolf.tres")
	add_child(wolf)
	var warden: Enemy = GRUNT_SCENE.instantiate()
	warden.config = load("res://data/enemies/grove_warden_config.tres")
	warden.attacks = load("res://data/enemies/grove_warden_attacks.tres")
	add_child(warden)
	await wait_physics(1)
	check(husk.attacks == HUSK_ATTACKS and husk.combat.weapon == HUSK_ATTACKS, "husk fights with its family")
	check(grunt.attacks == GRUNT_ATTACKS and wolf.attacks == GRUNT_ATTACKS, "grunt and wolf keep the grunt attacks")
	check_eq(warden.attacks.id, &"warden_claws", "a boss keeps its own family")
	for config_path: String in ["res://data/enemies/grunt_config.tres", "res://data/enemies/hollowfang_wolf.tres", "res://data/enemies/rootbound_husk.tres",
			"res://data/enemies/grove_warden_config.tres", "res://data/enemies/rootbound_sentinel.tres"]:
		check((load(config_path) as EnemyConfig).attacks == null, "%s has no override" % config_path.get_file())
	for enemy in [husk, grunt, wolf, warden]:
		enemy.queue_free()


## Every placed or spawned Hardened Husk refers to the one config (no placement carries its own attacks).
func test_every_husk_placement_uses_the_config() -> void:
	var placements := 0
	for path: String in ["res://scenes/maps/old_road.tscn", "res://scenes/maps/tangled_wood.tscn", "res://scenes/maps/whisper_forest.tscn"]:
		var text := FileAccess.get_file_as_string(path)
		var husk_ids: PackedStringArray = []
		for line in text.split("\n"):
			if line.contains("hardened_husk.tres"):
				husk_ids.append(line.get_slice(" id=\"", 1).get_slice("\"", 0))   # " id=", not the "uid="
		for block in text.split("[node "):
			for husk_id in husk_ids:
				if block.contains("config = ExtResource(\"%s\")" % husk_id):
					placements += 1
					check(not block.contains("attacks = "), "%s: a husk placement without its own attacks" % path.get_file())
	check_eq(placements, 4, "four placed Hardened Husks (old road 1, tangled wood 2, whisper forest 1)")
	var trial := load("res://data/trials/trial_warrior.tres")
	check(trial.enemy_configs.has(HUSK), "the warrior trial spawns the same config")


## A comparable form of a stored value: a sub-resource (the charge profile) by its own stored values.
func _value(value: Variant) -> String:
	if value is Resource:
		var parts: PackedStringArray = []
		for property: Dictionary in (value as Resource).get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE != 0 and not StringName(property.name) in [&"resource_path", &"resource_name", &"resource_local_to_scene"]:
				parts.append("%s=%s" % [property.name, str((value as Resource).get(property.name))])
		return "{%s}" % ", ".join(parts)
	return str(value)
