extends SceneTree
## Generates the nine Combat Flow weapon families (data/weapons) and their
## mastery tracks (data/mastery) from the tables below - Weapon Mastery 1.4 /
## Combat Flow 1.5 (docs/WEAPON_MASTERY_COMBAT_FLOW.md). Reproducible:
##   Godot --headless --path . -s res://tools/generate_weapon_families.gd
## Timings, movement factors, path names and unlock levels are the design's
## prototype values. Damage, poise, geometry and attack movement are documented
## PLACEHOLDERS (not designed yet, see the doc), never presented as final.

const PATH_LEVELS := {"LLL": 2, "LLH": 4, "LHL": 6, "HLL": 9, "LHH": 11, "HLH": 14, "HHL": 17, "HHH": 20}
const BOW_LEVELS := {"LL": 2, "LP": 4, "PL": 6, "LLP": 9, "PLP": 14, "LPL": 17, "PLLP": 20}
const BOW_FLOWING_LEVEL := 10
const PATH_ORDER := ["LLL", "LLH", "LHL", "HLL", "LHH", "HLH", "HHL", "HHH"]
const BOW_ORDER := ["LL", "LP", "PL", "LLP", "PLP", "LPL", "PLLP"]

## Reference for the placeholder damage: one-handed sword quick 12 / heavy 26
## per 550 / 850 ms; other new families scale by their total duration (equal
## damage per second, no family advantage). Existing families keep their values.
const REF_QUICK := [12.0, 8.0, 0.55]   # damage, poise, total seconds
const REF_HEAVY := [26.0, 30.0, 0.85]

const SWORD_GUARD := "res://data/combat/defense/sword_guard.tres"
const HEAVY_GUARD := "res://data/combat/defense/heavy_guard.tres"

## Weapon Base Damage 1.0 (docs/WEAPON_BASE_DAMAGE_1_0.md): "base" is the approved family
## reference base damage at item level 1 (B1). Every attack stores the placeholder damage
## below as weapon_damage_multiplier = damage / base (unrounded), so a weapon with base B1
## deals exactly the previous damage; `damage` stays as the reference value.
## id, family reference base, display name, scheme, colour, blade length, defense profile,
## quick [W, A, R] s, heavy [W, A, R] s, quick move [windup, active], heavy move,
## quick geometry [reach, arc], heavy geometry, base names [L, H],
## fixed base values (null = scaled) [quick dmg, quick poise, quick kb, heavy dmg, heavy poise, heavy kb, heavy hitstop]
const FAMILIES := [
	{"id": "dagger", "base": 9.0, "name": "Dagger", "bow": false, "color": Color(0.80, 0.86, 0.90), "blade": 9.0, "guard": SWORD_GUARD,
		"q": [0.10, 0.09, 0.23], "h": [0.19, 0.12, 0.37], "qm": [0.90, 0.80], "hm": [0.75, 0.65],
		"qg": [24.0, 90.0], "hg": [28.0, 100.0], "names": ["Quick Attack", "Heavy Attack"],
		"anim": "placeholder.swing",
		"finishers": ["Quick Fangs", "Twin Fang", "Shadow Rhythm", "Hunter's Opening", "Serpent's Bite", "Crossed Blades", "Serpent's Dance", "Thousand Cuts"]},
	{"id": "wand", "base": 10.0, "name": "Scepter / Wand", "bow": false, "color": Color(0.78, 0.66, 1.0), "blade": 10.0, "guard": SWORD_GUARD,
		"q": [0.13, 0.07, 0.28], "h": [0.24, 0.10, 0.42], "qm": [0.85, 0.75], "hm": [0.70, 0.60],
		"qp": [360.0, 220.0, 3.0], "hp": [300.0, 240.0, 5.0], "names": ["Quick Spell", "Heavy Spell"],
		"anim": "placeholder.bolt",
		"finishers": ["Spark Pattern", "Focused Bolt", "Twin Spark", "Guided Sequence", "Arcane Cadence", "Prismatic Weave", "Forked Current", "Spellweaver's Finale"]},
	{"id": "one_handed_sword", "base": 12.0, "name": "One-Handed Sword", "bow": false, "color": Color(0.91, 0.89, 0.82), "blade": 14.0, "guard": SWORD_GUARD,
		"q": [0.14, 0.11, 0.30], "h": [0.27, 0.14, 0.44], "qm": [0.80, 0.70], "hm": [0.65, 0.50],
		"qg": [30.0, 110.0], "hg": [38.0, 130.0], "names": ["Slash", "Heavy Cleave"],
		"anim": "placeholder.swing", "fixed": [12.0, 8.0, 6.0, 26.0, 30.0, 18.0, 0.06],
		"ids": {"L": "sword_light_1", "H": "sword_heavy", "LL": "sword_light_2", "LH": "sword_lh_thrust", "LLL": "sword_light_3", "LLH": "sword_llh_crush"},
		"step_names": {"LL": "Backhand", "LH": "Lunging Thrust"},
		"finishers": ["Threefold Edge", "Guard Splitter", "Crosscut", "Duelist's Advance", "Twin Crescent", "Flowing Reversal", "Steel Tempest", "Final Oath"]},
	{"id": "staff", "base": 13.0, "name": "Staff", "bow": false, "color": Color(0.55, 0.85, 1.0), "blade": 18.0, "guard": HEAVY_GUARD,
		"q": [0.16, 0.10, 0.32], "h": [0.30, 0.14, 0.48], "qm": [0.75, 0.65], "hm": [0.60, 0.45],
		"qg": [40.0, 90.0], "hg": [48.0, 110.0], "names": ["Quick Spell", "Heavy Spell"],
		"anim": "placeholder.arcane_strike",
		"finishers": ["Ember Sequence", "Arcane Sweep", "Echo Reversal", "Channeler's Reach", "Resonant Current", "Crossing Echoes", "Resonant Spiral", "Astral Convergence"]},
	{"id": "spear", "base": 13.0, "name": "Spear", "bow": false, "color": Color(0.86, 0.80, 0.62), "blade": 24.0, "guard": HEAVY_GUARD,
		"q": [0.17, 0.10, 0.34], "h": [0.32, 0.14, 0.52], "qm": [0.75, 0.60], "hm": [0.55, 0.40],
		"qg": [50.0, 30.0], "hg": [56.0, 40.0], "names": ["Quick Attack", "Heavy Attack"],
		"anim": "placeholder.thrust",
		"finishers": ["Sentinel's Rhythm", "Driving Thrust", "Sweeping Point", "Advancing Spear", "Iron Reach", "Measured Reversal", "Spearwheel", "Unbroken Reach"]},
	{"id": "axe", "base": 14.0, "name": "Axe", "bow": false, "color": Color(0.85, 0.70, 0.55), "blade": 13.0, "guard": SWORD_GUARD,
		"q": [0.19, 0.12, 0.35], "h": [0.36, 0.15, 0.54], "qm": [0.70, 0.55], "hm": [0.50, 0.35],
		"qg": [34.0, 120.0], "hg": [40.0, 140.0], "names": ["Quick Attack", "Heavy Attack"],
		"anim": "placeholder.swing",
		"finishers": ["Rough Hewing", "Splitting Strike", "Hooking Chop", "Ravager's Step", "Double Cleave", "Reaper's Turn", "Splintering Arc", "Reaver's Crown"]},
	{"id": "mace", "base": 15.0, "name": "Mace / Hammer", "bow": false, "color": Color(0.75, 0.75, 0.80), "blade": 12.0, "guard": SWORD_GUARD,
		"q": [0.22, 0.12, 0.36], "h": [0.40, 0.16, 0.56], "qm": [0.65, 0.50], "hm": [0.45, 0.30],
		"qg": [32.0, 110.0], "hg": [38.0, 120.0], "names": ["Quick Attack", "Heavy Attack"],
		"anim": "placeholder.swing",
		"finishers": ["Iron Rhythm", "Breaker Strike", "Counterweight", "Hammer March", "Crushing Follow-Through", "Anvil Turn", "Shatterfall", "Shatterpoint"]},
	{"id": "two_handed_sword", "base": 22.0, "name": "Two-Handed Sword", "bow": false, "color": Color(0.72, 0.84, 1.0), "blade": 22.0, "guard": HEAVY_GUARD,
		"q": [0.25, 0.15, 0.36], "h": [0.44, 0.18, 0.60], "qm": [0.60, 0.45], "hm": [0.40, 0.25],
		"qg": [44.0, 130.0], "hg": [52.0, 150.0], "names": ["Heavy Swing", "Sundering Blow"],
		"anim": "placeholder.swing", "fixed": [22.0, 16.0, 12.0, 48.0, 50.0, 35.0, 0.09],
		"ids": {"L": "greatsword_light_1", "H": "greatsword_heavy", "LL": "greatsword_light_2", "LH": "greatsword_lh_overhead", "LLL": "greatsword_light_3", "LLH": "greatsword_llh_whirl"},
		"step_names": {"LL": "Return Swing", "LH": "Overhead Slam"},
		"finishers": ["Broadsteel Sequence", "Falling Judgment", "Rising Cleave", "March of Iron", "Relentless Swing", "Iron Reversal", "Broken Horizon", "Executioner's Sequence"]},
	{"id": "bow", "base": 13.0, "name": "Bow", "bow": true, "color": Color(0.80, 0.72, 0.50), "blade": 12.0, "guard": HEAVY_GUARD,
		"q": [0.18, 0.04, 0.38], "h": [0.38, 0.05, 0.62], "qm": [0.75, 0.60], "hm": [0.60, 0.45],
		"qp": [520.0, 300.0, 3.0], "hp": [700.0, 380.0, 3.0], "names": ["Quick Shot", "Precision Shot"],
		"anim": "placeholder.shot",
		"finishers": ["Twin Arrow", "Finishing Aim", "Rapid Recovery", "Hunter's Rhythm", "Piercing Sequence", "Split Volley", "Master's Volley"]},
]

## Attack movement (placeholder, only where the move's name or the family
## identity declares a step): family -> node -> [distance px, angle degrees].
const MOVES := {
	"one_handed_sword": {"LL": [12.0, 0.0], "LH": [36.0, 0.0], "HLL": [24.0, 0.0]},
	"two_handed_sword": {"HLL": [24.0, 0.0]},
	"axe": {"HLL": [20.0, 0.0]},
	"dagger": {"LHL": [28.0, 90.0], "HHL": [28.0, -90.0]},
	"spear": {"LLH": [32.0, 0.0], "HLL": [26.0, 0.0]},
	"mace": {"HLL": [22.0, 0.0]},
}
## Wide sweeps of the spear (named sweeps): arc in degrees.
const SWEEPS := {"spear": {"LHL": 160.0, "HHL": 160.0}}
## Projectile forks (named twins / forks): node -> projectile count, spread.
const FORKS := {"wand": {"LHL": [2, 12.0], "HHL": [2, 20.0]}}
## Explicit multi-hit (Thousand Cuts): node -> hits per target.
const MULTI_HITS := {"dagger": {"HHH": 3}}


func _init() -> void:
	for family_data: Dictionary in FAMILIES:
		var family := _build(family_data)
		var errors := family.validate()
		if not errors.is_empty():
			push_error("%s: %s" % [family.id, errors])
			quit(1)
			return
		var error := ResourceSaver.save(family, "res://data/weapons/%s.tres" % family.id)
		if error != OK:
			push_error("saving %s failed: %d" % [family.id, error])
		var track := MasteryTrack.new()
		track.family_id = family.id
		track.max_level = 20
		track.xp_base = 100
		track.xp_growth = 1.15
		ResourceSaver.save(track, "res://data/mastery/%s.tres" % family.id)
		print("%s: %d attacks, %d paths" % [family.id, family.attacks.size(), family.combo_paths.size()])
	quit(0)


func _build(data: Dictionary) -> WeaponFamily:
	var family := WeaponFamily.new()
	family.id = StringName(data.id)
	family.display_name = data.name
	family.reference_base_damage = data.base
	family.input_scheme = WeaponFamily.InputScheme.BOW if data.bow else WeaponFamily.InputScheme.MELEE
	family.display_color = data.color
	family.visual_blade_length = data.blade
	family.defense_profile = load(data.guard)
	var levels: Dictionary = BOW_LEVELS if data.bow else PATH_LEVELS
	var order: Array = BOW_ORDER if data.bow else PATH_ORDER
	var nodes := {}
	for index in order.size():
		var path := ComboPathDefinition.new()
		path.inputs = order[index]
		path.unlock_level = levels[order[index]]
		path.display_name = data.finishers[index]
		path.description = "%s: %s." % [path.input_label(), path.display_name]
		family.combo_paths.append(path)
		for length in range(1, path.inputs.length() + 1):
			nodes[path.inputs.left(length)] = true
	if data.bow:
		var flowing := ComboPathDefinition.new()
		flowing.kind = ComboPathDefinition.Kind.FLOWING_DRAW
		flowing.unlock_level = BOW_FLOWING_LEVEL
		flowing.display_name = "Flowing Draw"
		flowing.description = "Hold LMB: an automatic sequence of three Quick Shots, then a full recovery."
		family.combo_paths.append(flowing)
	var sequences: Array = nodes.keys()
	sequences.sort_custom(func(a: String, b: String) -> bool: return a.length() < b.length() or (a.length() == b.length() and a < b))
	for sequence: String in sequences:
		family.attacks.append(_attack(data, family, sequence, levels, order))
	family.root_light = family.node("L").id
	family.root_heavy = family.node("P" if data.bow else "H").id
	return family


func _attack(data: Dictionary, family: WeaponFamily, sequence: String, levels: Dictionary, order: Array) -> AttackDefinition:
	var heavy := sequence.right(1) != "L"
	var attack := AttackDefinition.new()
	var ids: Dictionary = data.get("ids", {})
	attack.id = StringName(ids.get(sequence, "%s_%s" % [data.id, sequence.to_lower()]))
	attack.weapon_family_id = family.id
	attack.combo_input = sequence
	attack.input_type = AttackDefinition.InputType.HEAVY if heavy else AttackDefinition.InputType.LIGHT
	var timing: Array = data.h if heavy else data.q
	attack.startup = timing[0]
	attack.active = timing[1]
	attack.recovery = timing[2]
	var move: Array = data.hm if heavy else data.qm
	attack.windup_move = move[0]
	attack.active_move = move[1]
	attack.move_multiplier = move[0]
	attack.dash_cancel_phases = AttackDefinition.CANCEL_RECOVERY
	attack.animation_ref = StringName(data.anim)
	attack.placeholder_animation = true
	# role and name
	var finisher := levels.has(sequence)
	if sequence.length() == 1:
		attack.flow_role = AttackDefinition.FlowRole.BASE_HEAVY if heavy else AttackDefinition.FlowRole.BASE_QUICK
		attack.display_name = data.names[1 if heavy else 0]
	elif finisher:
		attack.flow_role = AttackDefinition.FlowRole.HEAVY_FINISHER if heavy else AttackDefinition.FlowRole.QUICK_FINISHER
		attack.display_name = data.finishers[order.find(sequence)]
	else:
		attack.flow_role = AttackDefinition.FlowRole.COMBO_STEP
		attack.display_name = data.get("step_names", {}).get(sequence, "Heavy Follow-up" if heavy else "Quick Follow-up")
	# placeholder values: the family's base attack of the same input
	var fixed: Array = data.get("fixed", [])
	if not fixed.is_empty():
		attack.damage = fixed[3] if heavy else fixed[0]
		attack.poise_damage = fixed[4] if heavy else fixed[1]
		attack.knockback = fixed[5] if heavy else fixed[2]
		attack.hitstop = fixed[6] if heavy else 0.0
	else:
		var reference: Array = REF_HEAVY if heavy else REF_QUICK
		var total: float = timing[0] + timing[1] + timing[2]
		attack.damage = roundf(reference[0] * total / reference[2])
		attack.poise_damage = roundf(reference[1] * total / reference[2])
		attack.knockback = 18.0 if heavy else 6.0
		attack.hitstop = 0.06 if heavy else 0.0
	var tags: Array[StringName] = []
	if heavy:
		tags.append(&"precision" if data.bow else &"heavy")
	if finisher:
		tags.append(&"finisher")
	attack.effect_tags = tags
	# geometry or projectile
	if data.has("qp"):
		var projectile: Array = data.hp if heavy else data.qp
		attack.projectile_speed = projectile[0]
		attack.projectile_range = projectile[1]
		attack.projectile_radius = projectile[2]
		attack.projectile_shape = 2 if data.bow else 0
		attack.reach = projectile[1]
		attack.arc_degrees = 10.0
		var fork: Array = FORKS.get(data.id, {}).get(sequence, [])
		if not fork.is_empty():
			attack.projectile_count = fork[0]
			attack.projectile_spread = fork[1]
			attack.damage = roundf(attack.damage / fork[0])
	else:
		var geometry: Array = data.hg if heavy else data.qg
		attack.reach = geometry[0]
		attack.arc_degrees = SWEEPS.get(data.id, {}).get(sequence, geometry[1])
	var moves: Array = MOVES.get(data.id, {}).get(sequence, [])
	if not moves.is_empty():
		attack.lunge_distance = moves[0]
		attack.lunge_angle = moves[1]
	var multi: int = MULTI_HITS.get(data.id, {}).get(sequence, 1)
	if multi > 1:
		attack.max_hits_per_target = multi
		attack.rehit_interval = attack.active / multi
		attack.damage = roundf(attack.damage / multi)
	attack.weapon_damage_multiplier = attack.damage / data.base   # per hit / per projectile
	return attack
