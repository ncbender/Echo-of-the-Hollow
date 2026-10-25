extends GameplayTestCase
## Weapon/attack data integrity and charge-tier rules.


func test_sword_data_is_valid() -> void:
	var errors := SWORD.validate()
	check(errors.is_empty(), "sword validates: %s" % [errors])
	check_eq(SWORD.attacks.size(), 7, "sword attack count")
	for attack in SWORD.attacks:
		check_eq(attack.weapon_family_id, SWORD.id, "%s family" % attack.id)


func test_all_weapon_files_are_valid() -> void:
	var dir := "res://data/weapons"
	var family_ids := {}
	var attack_ids := {}
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tres"):
			continue
		var family := load(dir.path_join(file)) as WeaponFamily
		if not check(family != null, "%s is a WeaponFamily" % file):
			continue
		var errors := family.validate()
		check(errors.is_empty(), "%s validates: %s" % [file, errors])
		check(not family_ids.has(family.id), "unique family id %s" % family.id)
		family_ids[family.id] = true
		for attack in family.attacks:
			check(not attack_ids.has(attack.id), "attack id %s unique across families" % attack.id)
			attack_ids[attack.id] = true
	check(family_ids.size() >= 2, "at least two weapon families")


func test_validation_detects_broken_trees() -> void:
	var family := WeaponFamily.new()
	family.id = &"broken"
	family.root_light = &"a"
	family.root_heavy = &"missing_heavy"
	var a := _attack(&"a", AttackDefinition.InputType.LIGHT)
	a.next_light = &"h"          # wrong input type: light link to a heavy attack
	a.next_heavy = &"ghost"      # unknown attack
	var duplicate := _attack(&"a", AttackDefinition.InputType.LIGHT)
	var h := _attack(&"h", AttackDefinition.InputType.HEAVY)   # heavy without charge profile
	family.attacks = [a, duplicate, h]
	var errors := "\n".join(family.validate())
	check(errors.contains("duplicate attack id a"), "duplicate id reported")
	check(errors.contains("a.next_light points to h with wrong input type"), "wrong input type reported")
	check(errors.contains("unknown attack ghost"), "unknown link reported")
	check(errors.contains("unknown attack missing_heavy"), "missing root reported")
	check(errors.contains("no charge profile"), "missing charge profile reported")


func test_charge_tier_thresholds() -> void:
	var profile: ChargeProfile = SWORD.get_attack(&"sword_heavy").charge_profile
	check_eq(profile.get_tier(0.0), 0, "0 ms -> normal")
	check_eq(profile.get_tier(0.249), 0, "249 ms -> normal")
	check_eq(profile.get_tier(0.25), 1, "250 ms -> empowered")
	check_eq(profile.get_tier(0.699), 1, "699 ms -> empowered")
	check_eq(profile.get_tier(0.7), 2, "700 ms -> full")
	check_eq(profile.get_tier(5.0), 2, "long hold stays full")
	# Tick-accumulated hold times must hit the same boundaries.
	var accumulated := 0.0
	for i in 15:
		accumulated += FRAME
	check_eq(profile.get_tier(accumulated), 1, "15 ticks (250 ms) -> empowered")


func test_follow_up_is_unique_per_input() -> void:
	# The data model has exactly one follow-up field per input type.
	var input_fields := 0
	for property in AttackDefinition.new().get_property_list():
		if String(property.name).begins_with("next_"):
			input_fields += 1
	check_eq(input_fields, AttackDefinition.InputType.size(), "one follow-up field per input type")


func _attack(attack_id: StringName, input: AttackDefinition.InputType) -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = attack_id
	attack.weapon_family_id = &"broken"
	attack.input_type = input
	return attack
