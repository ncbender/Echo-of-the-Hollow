extends GameplayTestCase
## Weapon Mastery 1.4: the nine families as data - exact path names and unlock
## levels of the design, the reference timings and movement factors, hit limits,
## and every one of the 64 non-bow end nodes executed on the real player with
## real hit events (placeholder animations, see docs/WEAPON_MASTERY_COMBAT_FLOW.md).

const FAMILY_IDS := [&"one_handed_sword", &"two_handed_sword", &"axe", &"dagger", &"spear", &"staff", &"wand", &"mace", &"bow"]
const PATHS := ["LLL", "LLH", "LHL", "HLL", "LHH", "HLH", "HHL", "HHH"]
const LEVELS := [2, 4, 6, 9, 11, 14, 17, 20]
const CATALOG := {
	&"one_handed_sword": ["Threefold Edge", "Guard Splitter", "Crosscut", "Duelist's Advance", "Twin Crescent", "Flowing Reversal", "Steel Tempest", "Final Oath"],
	&"two_handed_sword": ["Broadsteel Sequence", "Falling Judgment", "Rising Cleave", "March of Iron", "Relentless Swing", "Iron Reversal", "Broken Horizon", "Executioner's Sequence"],
	&"axe": ["Rough Hewing", "Splitting Strike", "Hooking Chop", "Ravager's Step", "Double Cleave", "Reaper's Turn", "Splintering Arc", "Reaver's Crown"],
	&"dagger": ["Quick Fangs", "Twin Fang", "Shadow Rhythm", "Hunter's Opening", "Serpent's Bite", "Crossed Blades", "Serpent's Dance", "Thousand Cuts"],
	&"spear": ["Sentinel's Rhythm", "Driving Thrust", "Sweeping Point", "Advancing Spear", "Iron Reach", "Measured Reversal", "Spearwheel", "Unbroken Reach"],
	&"staff": ["Ember Sequence", "Arcane Sweep", "Echo Reversal", "Channeler's Reach", "Resonant Current", "Crossing Echoes", "Resonant Spiral", "Astral Convergence"],
	&"wand": ["Spark Pattern", "Focused Bolt", "Twin Spark", "Guided Sequence", "Arcane Cadence", "Prismatic Weave", "Forked Current", "Spellweaver's Finale"],
	&"mace": ["Iron Rhythm", "Breaker Strike", "Counterweight", "Hammer March", "Crushing Follow-Through", "Anvil Turn", "Shatterfall", "Shatterpoint"],
}
const BOW := {"LL": [2, "Twin Arrow"], "LP": [4, "Finishing Aim"], "PL": [6, "Rapid Recovery"], "LLP": [9, "Hunter's Rhythm"],
	"PLP": [14, "Piercing Sequence"], "LPL": [17, "Split Volley"], "PLLP": [20, "Master's Volley"]}
## Reference W/A/R in ms (quick, heavy) and movement % (quick windup/active, heavy windup/active).
const TIMINGS := {
	&"dagger": [[100, 90, 230], [190, 120, 370], [90, 80, 75, 65]],
	&"wand": [[130, 70, 280], [240, 100, 420], [85, 75, 70, 60]],
	&"one_handed_sword": [[140, 110, 300], [270, 140, 440], [80, 70, 65, 50]],
	&"staff": [[160, 100, 320], [300, 140, 480], [75, 65, 60, 45]],
	&"spear": [[170, 100, 340], [320, 140, 520], [75, 60, 55, 40]],
	&"axe": [[190, 120, 350], [360, 150, 540], [70, 55, 50, 35]],
	&"mace": [[220, 120, 360], [400, 160, 560], [65, 50, 45, 30]],
	&"two_handed_sword": [[250, 150, 360], [440, 180, 600], [60, 45, 40, 25]],
	&"bow": [[180, 40, 380], [380, 50, 620], [75, 60, 60, 45]],
}

var db: GameDatabase


func before_each() -> void:
	super.before_each()
	db = GameDatabase.get_default()
	hits.clear()
	started_attacks.clear()


func family(id: StringName) -> WeaponFamily:
	return db.weapons.get(id)


func test_catalog_names_levels_and_count() -> void:
	var endpoints := {}
	for id: StringName in FAMILY_IDS:
		var weapon := family(id)
		if not check(weapon != null, "%s exists" % id):
			continue
		check_eq(weapon.validate().size(), 0, "%s validates: %s" % [id, weapon.validate()])
		check(weapon.uses_flow(), "%s is a Combat Flow family" % id)
	for id: StringName in CATALOG:
		var weapon := family(id)
		check_eq(weapon.combo_paths.size(), 8, "%s: eight paths" % id)
		for index in PATHS.size():
			var path := weapon.path_ending(PATHS[index])
			if not check(path != null, "%s %s exists" % [id, PATHS[index]]):
				continue
			check_eq(path.display_name, CATALOG[id][index], "%s %s name" % [id, PATHS[index]])
			check_eq(path.unlock_level, LEVELS[index], "%s %s level" % [id, PATHS[index]])
			check_eq(weapon.node(PATHS[index]).display_name, CATALOG[id][index], "%s end node carries the path name" % id)
			endpoints["%s:%s" % [id, path.display_name]] = true
		check_eq(weapon.unlocked_paths(1).size(), 0, "%s: nothing unlocked at level 1" % id)
		check(weapon.node("L") != null and weapon.node("H") != null, "%s: one quick and one heavy base attack" % id)
		check_eq(weapon.flowing_draw_level(), 0, "%s: no Flowing Draw" % id)
	var bow := family(&"bow")
	check(bow.is_bow(), "bow uses the bow scheme")
	for inputs: String in BOW:
		var path := bow.path_ending(inputs)
		if check(path != null, "bow %s" % inputs):
			check_eq(path.unlock_level, BOW[inputs][0], "bow %s level" % inputs)
			check_eq(path.display_name, BOW[inputs][1], "bow %s name" % inputs)
			endpoints["bow:%s" % path.display_name] = true
	check_eq(bow.flowing_draw_level(), 10, "Flowing Draw at level 10")
	endpoints["bow:Flowing Draw"] = true
	check_eq(endpoints.size(), 72, "72 unique unlockable paths")
	check(bow.node("H") == null, "the bow has no heavy / charged RMB attack")


func test_reference_timings_and_movement() -> void:
	for id: StringName in TIMINGS:
		var weapon := family(id)
		var spec: Array = TIMINGS[id]
		for attack in weapon.attacks:
			var heavy := attack.combo_input.right(1) != "L"
			var war: Array = spec[1] if heavy else spec[0]
			check_near(attack.startup * 1000.0, war[0], 0.01, "%s windup" % attack.id)
			check_near(attack.active * 1000.0, war[1], 0.01, "%s active" % attack.id)
			check_near(attack.recovery * 1000.0, war[2], 0.01, "%s recovery" % attack.id)
			check_near(attack.windup_move * 100.0, spec[2][2 if heavy else 0], 0.01, "%s windup move" % attack.id)
			check_near(attack.active_move * 100.0, spec[2][3 if heavy else 1], 0.01, "%s active move" % attack.id)
			check(attack.max_hits_per_target >= 1, "%s has a hit limit" % attack.id)
			check(attack.animation_ref != &"" and attack.placeholder_animation, "%s: placeholder animation declared" % attack.id)
			check(attack.charge_profile == null, "%s: no charge" % attack.id)
			check(attack.lunge_distance <= 40.0, "%s: movement within the prototype ranges" % attack.id)
	var cuts := family(&"dagger").node("HHH")
	check_eq(cuts.max_hits_per_target, 3, "Thousand Cuts: explicit multi-hit cap")
	check(family(&"one_handed_sword").node("LLH").id == &"sword_llh_crush", "existing attack id kept for Crushing Oath")


## Presses `path` on the real player against a target and returns the attacks started.
func _run_path(weapon: WeaponFamily, path: String, target_at: Vector2) -> Array[StringName]:
	spawn_player()
	player.set_weapon_family(weapon)
	player.combat.mastery_level = 20
	started_attacks.clear()
	track_player_attacks()
	var target := add_target(target_at, 26.0)
	var f := frame()
	for index in path.length():
		var symbol := path[index]
		if index > 0:
			var guard := 0
			while (player.combat.chain.length() != index or player.combat.attack_clock() < player.combat.accept_from()) and guard < 200:
				await tick(f)
				guard += 1
		var press := frame()
		if symbol == "L":
			press.light_pressed = true
		else:
			press.heavy_pressed = true
			press.heavy_held = true
		await tick(press)
	var guard := 0
	while player.combat.is_busy() and guard < 300:
		await tick(f)
		guard += 1
	for i in 40:   # projectiles in flight
		await tick(f)
	target.get_parent().queue_free()
	player.queue_free()
	await get_tree().physics_frame
	return started_attacks.duplicate()


func test_every_melee_end_node_runs_with_real_hits() -> void:
	for id: StringName in CATALOG:
		var weapon := family(id)
		for path: String in PATHS:
			hits.clear()
			var ranged := weapon.node("L").is_projectile()
			var started := await _run_path(weapon, path, Vector2(60.0 if ranged else 18.0, 0.0))
			var expected: Array[StringName] = []
			for length in range(1, 4):
				expected.append(weapon.node(path.left(length)).id)
			check_eq(started, expected, "%s %s: three real steps" % [id, path])
			var final := weapon.node(path)
			var final_hits := hits.filter(func(hit: HitData) -> bool: return hit.attack == final)
			check(final_hits.size() >= 1, "%s %s (%s) dealt a real hit" % [id, path, final.display_name])
			check(final_hits.size() <= final.max_hits_per_target * maxi(1, final.projectile_count), "%s %s within its hit cap" % [id, path])
	var cuts := family(&"dagger")
	hits.clear()
	await _run_path(cuts, "HHH", Vector2(16.0, 0.0))
	var cut_hits := hits.filter(func(hit: HitData) -> bool: return hit.attack == cuts.node("HHH"))
	check_eq(cut_hits.size(), 3, "Thousand Cuts: exactly its three capped hits on one target")
