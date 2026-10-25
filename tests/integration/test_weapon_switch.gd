extends GameplayTestCase
## Weapon family switching and correct selection of attack definitions.

const GREATSWORD: WeaponFamily = preload("res://data/weapons/two_handed_sword.tres")


func _switch(slot: int) -> void:
	var f := frame()
	f.weapon_slot = slot
	await tick(f)


func test_loadout_and_switch() -> void:
	spawn_player()
	check_eq(player.weapons.size(), 2, "two weapon families in loadout")
	check_eq(player.combat.weapon.id, &"one_handed_sword", "starts with sword")
	await _switch(1)
	check_eq(player.combat.weapon.id, &"two_handed_sword", "switched to greatsword")
	await _switch(0)
	check_eq(player.combat.weapon.id, &"one_handed_sword", "switched back")


func test_switch_refused_during_action_and_resets_combo() -> void:
	spawn_player()
	var f := frame()
	await tick(light(f))
	await _switch(1)
	check_eq(player.combat.weapon.id, &"one_handed_sword", "no switch mid-attack")
	await tick(f, 24)
	check(player.combat.combo.current != null, "combo window open")
	await _switch(1)
	check_eq(player.combat.weapon.id, &"two_handed_sword", "switch when idle")
	check(player.combat.combo.current == null, "switch resets combo")


func test_greatsword_combos_use_own_definitions() -> void:
	var combat := new_combat(GREATSWORD)
	var f := frame()
	step_combat(combat, light(f))
	step_combat(combat, f, 18)
	step_combat(combat, light(f))
	step_combat(combat, f, 18)
	step_combat(combat, heavy_down(f))
	step_combat(combat, heavy_up(f))
	check_eq(started_attacks, [&"greatsword_light_1", &"greatsword_light_2", &"greatsword_llh_whirl"] as Array[StringName], "L-L-H on greatsword")
	for attack_id in started_attacks:
		check_eq(GREATSWORD.get_attack(attack_id).weapon_family_id, &"two_handed_sword", "%s from greatsword family" % attack_id)


func test_greatsword_is_slower_with_more_reach_and_heavier_heavies() -> void:
	var sword_light := SWORD.get_attack(SWORD.root_light)
	var great_light := GREATSWORD.get_attack(GREATSWORD.root_light)
	check(great_light.total_duration() > sword_light.total_duration(), "greatsword light is slower")
	check(great_light.reach > sword_light.reach, "greatsword light reaches further")
	var sword_heavy := SWORD.get_attack(SWORD.root_heavy)
	var great_heavy := GREATSWORD.get_attack(GREATSWORD.root_heavy)
	var max_tier := great_heavy.charge_profile.max_tier()
	check(great_heavy.damage * great_heavy.charge_profile.damage_multiplier(max_tier)
		> 1.5 * sword_heavy.damage * sword_heavy.charge_profile.damage_multiplier(max_tier), "full greatsword heavy much stronger")
	check(great_heavy.poise_damage > sword_heavy.poise_damage, "more poise damage")


func test_greatsword_hits_at_longer_range() -> void:
	spawn_player()
	add_target(Vector2(44, 0), 6.0)   # beyond sword reach (30 + 6), within greatsword (44)
	await wait_physics(2)
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	await tick(f, 30)
	check_eq(hits.size(), 0, "sword light misses at 44 px")
	await _switch(1)
	await tick(light(f))
	await tick(f, 30)
	check_eq(hits.size(), 1, "greatsword light hits at 44 px")
