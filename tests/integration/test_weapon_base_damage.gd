extends GameplayTestCase
## Weapon Base Damage 1.0 (docs/WEAPON_BASE_DAMAGE_1_0.md): every player weapon node
## against the recorded pre-change damage (tests/fixtures/weapon_damage_baseline_2_7.json),
## the ten weapons on the model, quality, the local affixes Tempered Blade / Striking,
## real hits incl. Thousand Cuts, wand forks, Precision Shot and Flowing Draw, and the
## weapons that stay on their previous damage (compatibility through the family reference).

const S := EquipSlot.Slot
const BASELINE := "res://tests/fixtures/weapon_damage_baseline_2_7.json"
## Approved family reference bases B1 (item level 1).
const REFERENCES := {&"one_handed_sword": 12.0, &"two_handed_sword": 22.0, &"axe": 14.0, &"dagger": 9.0,
	&"mace": 15.0, &"spear": 13.0, &"staff": 13.0, &"wand": 10.0, &"bow": 13.0}
## Weapons on the model: base_weapon_damage.
const ON_MODEL := {&"iron_sword": 12.0, &"militia_sword": 12.6, &"steel_greatsword": 22.0, &"iron_axe": 14.0,
	&"iron_dagger": 9.0, &"iron_mace": 15.0, &"ash_spear": 13.0, &"oak_staff": 13.0, &"oak_wand": 10.0, &"hunting_bow": 13.0}
## Not converted (special weapons, blocked forged bases): global base stats kept as they were.
const UNCHANGED := {&"stormcaller_fang": [8.0, 4.0], &"crushing_oath": [4.0, 0.0], &"echo_blade": [8.0, 0.0],
	&"forged_blade": [6.0, 4.0], &"forged_greatsword": [10.0, 8.0]}

var db: GameDatabase
var baseline: Dictionary
var character: Character
var bridge: PlayerProgressionBridge


func before_each() -> void:
	super.before_each()
	db = GameDatabase.get_default()
	baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	character = null


func _old(family_id: StringName, node: String) -> float:
	return float(baseline[String(family_id)][node].damage)


# --- data -----------------------------------------------------------------------------

## The family reference base reproduces every node's previous damage exactly (no rounded
## multipliers), poise and hit structure stay as they were.
func test_every_node_keeps_its_reference_damage() -> void:
	check_eq(baseline.size(), 9, "baseline of nine families")
	for family_id: StringName in REFERENCES:
		var family: WeaponFamily = db.weapons[family_id]
		check_eq(family.reference_base_damage, REFERENCES[family_id], "%s reference base" % family_id)
		var nodes: Dictionary = baseline[String(family_id)]
		check_eq(family.attacks.size(), nodes.size(), "%s: same nodes" % family_id)
		for attack in family.attacks:
			var old: Dictionary = nodes[attack.combo_input]
			check(attack.weapon_damage_multiplier > 0.0, "%s scales with the weapon" % attack.id)
			check_near(CombatComponent.base_damage(attack, family.reference_base_damage), float(old.damage), 1e-9,
				"%s: reference damage unchanged" % attack.id)
			check_near(attack.weapon_damage_multiplier, float(old.damage) / REFERENCES[family_id], 1e-12, "%s: multiplier unrounded" % attack.id)
			check_eq(attack.damage, float(old.damage), "%s: reference value kept" % attack.id)
			check_eq(attack.poise_damage, float(old.poise), "%s: poise stays absolute" % attack.id)
			check_eq(attack.projectile_count, int(old.projectiles), "%s: projectiles" % attack.id)
			check_eq(attack.max_hits_per_target, int(old.hits_per_target), "%s: hits per target" % attack.id)
	check_near(db.weapons[&"dagger"].node("HHH").weapon_damage_multiplier, 7.0 / 9.0, 1e-12, "Thousand Cuts: per hit 7/9")
	check_near(db.weapons[&"wand"].node("LHL").weapon_damage_multiplier, 0.5, 1e-12, "wand fork: per projectile 5/10")
	check_near(db.weapons[&"bow"].node("P").weapon_damage_multiplier, 32.0 / 13.0, 1e-12, "Precision Shot 32/13")


## Enemy (legacy) attacks keep their absolute damage.
func test_enemy_attacks_stay_absolute() -> void:
	for path: String in ["res://data/enemies/grunt_attacks.tres", "res://data/enemies/grove_warden_attacks.tres"]:
		var family: WeaponFamily = load(path)
		check(not family.uses_flow(), "%s legacy" % family.id)
		for attack in family.attacks:
			check_eq(attack.weapon_damage_multiplier, 0.0, "%s absolute" % attack.id)
			check_eq(CombatComponent.base_damage(attack, 99.0), attack.damage, "%s ignores any weapon base" % attack.id)


func test_items_on_the_model_and_their_quick_heavy_damage() -> void:
	for item_id: StringName in ON_MODEL:
		var definition := db.get_item(item_id)
		check(WeaponDamage.is_on_model(definition), "%s on the model" % item_id)
		check_eq(definition.base_weapon_damage, ON_MODEL[item_id], "%s base" % item_id)
		var weapon_damage := WeaponDamage.of(ItemInstance.create(item_id), definition, db)
		check_near(weapon_damage, ON_MODEL[item_id], 1e-9, "%s D_weapon at quality 0" % item_id)
		var family: WeaponFamily = db.weapons[definition.weapon_family_id]
		var heavy := "P" if family.is_bow() else "H"
		var ratio: float = ON_MODEL[item_id] / REFERENCES[definition.weapon_family_id]
		check_near(CombatComponent.base_damage(family.node("L"), weapon_damage), _old(family.id, "L") * ratio, 1e-9, "%s quick" % item_id)
		check_near(CombatComponent.base_damage(family.node(heavy), weapon_damage), _old(family.id, heavy) * ratio, 1e-9, "%s heavy" % item_id)
	var militia := db.get_item(&"militia_sword")
	check(militia.base_stats.is_empty(), "militia: global +5 % physical damage removed")
	check_near(CombatComponent.base_damage(db.weapons[&"one_handed_sword"].node("H"), 12.6), 27.3, 1e-9, "militia heavy 26 x 1.05")


func test_unconverted_weapons_keep_their_global_bonuses() -> void:
	for item_id: StringName in UNCHANGED:
		var definition := db.get_item(item_id)
		check(not WeaponDamage.is_on_model(definition), "%s not on the model" % item_id)
		check_eq(WeaponDamage.of(ItemInstance.create(item_id), definition, db), 0.0, "%s: D_weapon 0 = family reference" % item_id)
		var totals := ItemDescriber.totals(ItemStats.modifiers(ItemInstance.create(item_id), definition, db))
		check_near(float(totals.get("physical_damage|flat", 0.0)), UNCHANGED[item_id][0], 1e-9, "%s physical damage kept" % item_id)
		check_near(float(totals.get("poise_damage|flat", 0.0)), UNCHANGED[item_id][1], 1e-9, "%s poise damage kept" % item_id)
	var fang := ItemInstance.create(&"stormcaller_fang")
	fang.quality = 20
	var scaled := ItemDescriber.totals(ItemStats.modifiers(fang, db.get_item(&"stormcaller_fang"), db))
	check_near(float(scaled["physical_damage|flat"]), 8.8, 1e-9, "unconverted: quality still on the global base stat")


# --- quality and local affixes -------------------------------------------------------------

## A test definition on the model with a crafting profile (none of the data weapons has one yet).
func _craftable(item_id: StringName = &"iron_sword") -> ItemDefinition:
	var definition: ItemDefinition = db.get_item(item_id).duplicate()
	definition.crafting = CraftingProfile.new()
	definition.crafting.affix_slots = 5
	definition.crafting.allowed_operations = [CraftingOps.AUGMENT, CraftingOps.QUALITY] as Array[StringName]
	var bonus := StatModifier.make(Stats.PHYSICAL_DAMAGE, 5.0, 0.0)
	definition.base_stats = [bonus] as Array[StatModifier]
	return definition


func test_quality_only_on_the_weapon_base() -> void:
	var definition := _craftable()
	var item := ItemInstance.create(&"iron_sword")
	check_near(WeaponDamage.of(item, definition, db), 12.0, 1e-9, "quality 0")
	item.quality = 20
	check_near(WeaponDamage.of(item, definition, db), 13.2, 1e-9, "quality 20: 12 x 1.1")
	item.quality = 35
	check_near(WeaponDamage.of(item, definition, db), 13.2, 1e-9, "never above quality 20")
	item.quality = 20
	var totals := ItemDescriber.totals(ItemStats.modifiers(item, definition, db))
	check_near(float(totals["physical_damage|flat"]), 5.0, 1e-9, "quality never scales global stats of a model weapon")
	check(not totals.has("poise_damage|flat"), "no poise base invented")


func _tempered(percent: float, tier: int = 5) -> Dictionary:
	return {"affix": "tempered_blade", "tier": tier, "tier_model": 5, "stat": "weapon_damage", "flat": 0.0, "percent": percent}


func test_local_affix_definitions() -> void:
	var tempered: AffixDefinition = db.affixes[&"tempered_blade"]
	var striking: AffixDefinition = db.affixes[&"striking"]
	for affix in [tempered, striking]:
		check(affix.validate().is_empty(), "%s valid: %s" % [affix.id, affix.validate()])
		check_eq(affix.scope, AffixDefinition.Scope.LOCAL, "%s local" % affix.id)
		check_eq(affix.tier_model, AffixTiers.MODEL_FIVE, "%s five tiers" % affix.id)
		check(affix.allows_slot(ItemDefinition.SlotKind.TWO_HAND_WEAPON) and not affix.allows_slot(ItemDefinition.SlotKind.RING), "%s weapons only" % affix.id)
	var expected := {
		tempered: {5: [1, 3, 5], 4: [10, 6, 8], 3: [25, 9, 12], 2: [45, 13, 16], 1: [70, 17, 20]},
		striking: {5: [1, 3, 6], 4: [10, 5, 9], 3: [25, 8, 12], 2: [45, 11, 16], 1: [70, 15, 22]},
	}
	for affix: AffixDefinition in expected:
		for tier_number: int in expected[affix]:
			var tier := affix.get_tier(tier_number)
			var values: Array = expected[affix][tier_number]
			check_eq([tier.min_item_level, tier.min_value, tier.max_value], [values[0], float(values[1]), float(values[2])], "%s T%d" % [affix.id, tier_number])
	check_eq(tempered.value_kind, AffixDefinition.ValueKind.PERCENT, "Tempered Blade: percent")
	check(striking.reference_share and striking.value_kind == AffixDefinition.ValueKind.FLAT, "Striking: flat share of B_ref")
	check(db.affixes[&"sharpened"].scope == AffixDefinition.Scope.GLOBAL and db.affixes[&"guarded"].scope == AffixDefinition.Scope.GLOBAL, "Sharpened / Guarded stay global")


func test_striking_is_rolled_once_from_the_reference_curve() -> void:
	var striking: AffixDefinition = db.affixes[&"striking"]
	check_near(WeaponDamage.reference_at(12.0, 1), 12.0, 1e-9, "B_ref(1)")
	check_near(WeaponDamage.reference_at(12.0, 25), 12.0 * 1.288, 1e-9, "B_ref(25) = B1 x 1.288")
	check_near(WeaponDamage.reference_at(12.0, 100), 12.0 * 2.188, 1e-9, "B_ref(100)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for level: int in [1, 25, 70]:
		var item := ItemInstance.create(&"steel_greatsword")
		item.item_level = level
		var reference := WeaponDamage.reference_of(item, db.get_item(&"steel_greatsword"), db)
		check_near(reference, WeaponDamage.reference_at(22.0, level), 1e-9, "greatsword B_ref at %d" % level)
		var tier := striking.get_tier(AffixTiers.highest_tier(level))
		for i in 20:
			var entry := striking.roll(tier, rng, reference)
			var share := float(entry["share"])
			check(share >= tier.min_value and share <= tier.max_value, "share %s inside T%d" % [share, tier.tier])
			check_near(float(entry["flat"]), reference * share / 100.0, 1e-9, "flat = B_ref x share")
			check_eq(float(entry["percent"]), 0.0, "Striking has no percent part")
	var sword := ItemInstance.create(&"iron_sword")
	sword.affixes.append({"affix": "striking", "tier": 5, "tier_model": 5, "stat": "weapon_damage", "flat": 0.6, "percent": 0.0, "share": 5.0})
	var definition := _craftable()
	check_near(WeaponDamage.of(sword, definition, db), 12.6, 1e-9, "12 + 0.6")
	sword.quality = 20
	check_near(WeaponDamage.of(sword, definition, db), 13.2 + 0.6, 1e-9, "quality on the base only, Striking stays 0.6")
	var restored := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(sword.to_dict())))
	check_near(WeaponDamage.of(restored, definition, db), 13.8, 1e-9, "saved Striking value restored as rolled")


func test_tempered_blade_striking_and_both() -> void:
	var definition := _craftable()
	var item := ItemInstance.create(&"iron_sword")
	item.quality = 20
	item.affixes.append(_tempered(10.0, 3))
	check_near(WeaponDamage.of(item, definition, db), 13.2 * 1.1, 1e-9, "Tempered Blade: (12 x 1.1) x 1.1")
	item.affixes.clear()
	item.affixes.append({"affix": "striking", "tier": 5, "tier_model": 5, "stat": "weapon_damage", "flat": 0.72, "percent": 0.0, "share": 6.0})
	check_near(WeaponDamage.of(item, definition, db), 13.2 + 0.72, 1e-9, "Striking: 12 x 1.1 + 0.72")
	item.affixes.append(_tempered(5.0))
	check_near(WeaponDamage.of(item, definition, db), (13.2 + 0.72) * 1.05, 1e-9, "both: flat before percent")
	item.affixes.append({"affix": "sharpened", "tier": 3, "tier_model": 3, "stat": "physical_damage", "flat": 6.0, "percent": 0.0})
	var totals := ItemDescriber.totals(ItemStats.modifiers(item, definition, db))
	check(not totals.has("weapon_damage|flat") and not totals.has("weapon_damage|%"), "local affixes never reach the character stats")
	check_near(float(totals["physical_damage|flat"]), 5.0 + 6.0, 1e-9, "global affixes unchanged (Sharpened stays global)")
	check_near(WeaponDamage.of(item, definition, db), (13.2 + 0.72) * 1.05, 1e-9, "a global affix never changes D_weapon")
	var text := ItemDescriber.affix_text(db, item.affixes[0])
	check(text.contains("Weapon Damage") and text.contains("(local)"), "described as local: %s" % text)
	check(item.affixes.size() <= CraftingProfile.MAX_AFFIX_SLOTS, "local affixes use the regular slots")


func test_local_affixes_only_offered_on_model_weapons() -> void:
	var item := ItemInstance.create(&"iron_sword")
	var pool := AffixPool.by_affix(AffixPool.compute(item, _craftable(), null, db))
	check(pool.has(&"tempered_blade") and pool.has(&"striking"), "model weapon: local affixes offered")
	var tiers := AffixPool.compute(item, _craftable(), null, db).filter(func(entry: Dictionary) -> bool: return (entry.affix as AffixDefinition).scope == AffixDefinition.Scope.LOCAL)
	for entry: Dictionary in tiers:
		check_eq((entry.tier as AffixTier).tier, 5, "item level 1: only T5")
	var forged := ItemInstance.create(&"forged_blade")
	forged.item_level = 12
	var forged_pool := AffixPool.by_affix(AffixPool.compute(forged, db.get_item(&"forged_blade"), null, db))
	check(not forged_pool.has(&"tempered_blade") and not forged_pool.has(&"striking"), "forged blade (not converted): no local affixes")
	check_eq(forged_pool.size(), 11, "forged blade pool as before")


# --- real hits -------------------------------------------------------------------------------

func _bind() -> void:
	character = CharacterFactory.create_new(db)
	spawn_player()
	bridge = PlayerProgressionBridge.new()
	bridge.name = "ProgressionBridge"
	player.add_child(bridge)
	bridge.bind(player, character)


func _equip(item_id: StringName) -> ItemInstance:
	var item := character.inventory.add_item(item_id)[0]
	check_eq(character.equipment.equip(item.instance_id, S.MAIN_HAND), "", "equip %s" % item_id)
	return item


func _quick_hit() -> HitData:
	hits.clear()
	var target := add_target(Vector2(18, 0), 20.0)
	await perform_path("L", Vector2.RIGHT, 4)
	target.get_parent().queue_free()
	return hits[0] if not hits.is_empty() else null


## Bound player: militia deals 12.6 per quick slash, never 12.6 x 1.05 (no global bonus
## left); local affixes and equipment changes are recomputed from the instance.
func test_bound_player_deals_d_weapon_without_double_bonus() -> void:
	_bind()
	var militia := _equip(&"militia_sword")
	await wait_physics(2)
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE), 0.0, 1e-9, "no global physical damage from the militia sword")
	check_near(player.combat.weapon_base_damage, 12.6, 1e-9, "D_weapon pushed by the bridge")
	var hit := await _quick_hit()
	check(hit != null and absf(hit.damage - 12.6) < 1e-6, "militia quick 12.6 (got %s)" % (hit.damage if hit else -1.0))
	militia.affixes.append(_tempered(10.0))
	character.notify_item_changed(militia.instance_id)
	check_near(player.combat.weapon_base_damage, 12.6 * 1.1, 1e-9, "local affix recomputed after an item change")
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE), 0.0, 1e-9, "the local affix is no character stat")
	hit = await _quick_hit()
	check(hit != null and absf(hit.damage - 13.86) < 1e-6, "quick with Tempered Blade 13.86 (got %s)" % (hit.damage if hit else -1.0))
	character.equipment.unequip(S.MAIN_HAND)
	await wait_physics(2)
	check_eq(player.combat.weapon_base_damage, 0.0, "unequipped: back to the family reference")


## Not converted: the Echo Blade keeps 12 x (1 + 8 %) on a quick slash exactly as before.
func test_special_weapon_damage_unchanged() -> void:
	_bind()
	_equip(&"echo_blade")
	await wait_physics(2)
	check_eq(player.combat.weapon_base_damage, 0.0, "echo blade: compatibility (family reference)")
	var hit := await _quick_hit()
	check(hit != null and absf(hit.damage - 12.0 * 1.08) < 1e-6, "echo blade quick 12 x 1.08 (got %s)" % (hit.damage if hit else -1.0))


func _hits_of(attack: AttackDefinition) -> Array:
	return hits.filter(func(hit: HitData) -> bool: return hit.attack == attack)


func test_thousand_cuts_three_scaled_hits() -> void:
	spawn_player()
	var dagger: WeaponFamily = db.weapons[&"dagger"]
	player.set_weapon_family(dagger)
	player.combat.mastery_level = 20
	player.combat.weapon_base_damage = 18.0
	add_target(Vector2(16, 0), 26.0)
	await perform_path("HHH", Vector2.RIGHT, 4)
	var cuts := _hits_of(dagger.node("HHH"))
	check_eq(cuts.size(), 3, "Thousand Cuts: three single hits")
	for hit: HitData in cuts:
		check_near(hit.damage, 14.0, 1e-6, "each cut 7 x 18/9")


func test_wand_fork_two_scaled_projectiles() -> void:
	spawn_player()
	var wand: WeaponFamily = db.weapons[&"wand"]
	player.set_weapon_family(wand)
	player.combat.mastery_level = 20
	player.combat.weapon_base_damage = 20.0
	add_target(Vector2(60, 0), 26.0)
	await perform_path("LHL", Vector2.RIGHT, 40)
	var forks := _hits_of(wand.node("LHL"))
	check_eq(forks.size(), 2, "two single projectiles hit")
	for hit: HitData in forks:
		check_near(hit.damage, 10.0, 1e-6, "each fork 5 x 20/10")


func test_precision_shot_and_flowing_draw() -> void:
	spawn_player()
	var bow: WeaponFamily = db.weapons[&"bow"]
	player.set_weapon_family(bow)
	player.combat.mastery_level = 10
	player.combat.weapon_base_damage = 26.0
	add_target(Vector2(60, 0), 26.0)
	await perform_path("P", Vector2.RIGHT, 40)
	var precise := _hits_of(bow.node("P"))
	check_eq(precise.size(), 1, "one Precision Shot")
	if not precise.is_empty():
		check_near(precise[0].damage, 64.0, 1e-6, "Precision 32 x 26/13")
	hits.clear()
	var hold := frame()
	hold.light_pressed = true
	hold.light_held = true
	await tick(hold)
	hold = frame()
	hold.light_held = true
	var guard := 0
	while _hits_of(bow.node("L")).size() < 3 and guard < 400:
		await tick(hold)
		guard += 1
	check(player.combat.flowing_draw or _hits_of(bow.node("L")).size() >= 3, "Flowing Draw ran")
	var arrows := _hits_of(bow.node("L"))
	check(arrows.size() >= 3, "three normal shots (%d)" % arrows.size())
	for hit: HitData in arrows:
		check_near(hit.damage, 26.0, 1e-6, "each Flowing Draw arrow is a normal shot 13 x 26/13")


## A projectile keeps the D_weapon it left with.
func test_projectile_snapshots_weapon_damage() -> void:
	spawn_player()
	var bow: WeaponFamily = db.weapons[&"bow"]
	player.set_weapon_family(bow)
	player.combat.weapon_base_damage = 13.0
	add_target(Vector2(120, 0), 20.0)
	var press := frame()
	press.light_pressed = true
	var fired := [false]
	player.combat.projectile_fired.connect(func(_attack: AttackDefinition, _p: Node2D) -> void: fired[0] = true)
	await tick(press)
	var guard := 0
	while not fired[0] and guard < 120:
		await tick(frame())
		guard += 1
	player.combat.weapon_base_damage = 1000.0
	await tick(frame(), 40)
	check(not hits.is_empty() and absf(hits[0].damage - 13.0) < 1e-6, "arrow deals the damage it was fired with")
