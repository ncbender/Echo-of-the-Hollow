extends GameplayTestCase
## Weapon Base Damage 1.0 (docs/WEAPON_BASE_DAMAGE_1_0.md): every player weapon node
## against the recorded pre-change damage (tests/fixtures/weapon_damage_baseline_2_7.json),
## the ten weapons on the model, quality, the local affixes Tempered Blade / Striking,
## real hits incl. Thousand Cuts, wand forks, Precision Shot and Flowing Draw, and the
## weapons that stay on their previous damage (compatibility through the family reference).
## 1.1 (docs/WEAPON_BASE_DAMAGE_1_1.md): base stored per instance at creation (ItemCreation),
## model factors, forged weapons (V3), save v12 migration, bag/stash/save persistence.

const S := EquipSlot.Slot
const BASELINE := "res://tests/fixtures/weapon_damage_baseline_2_7.json"
const SAVE_DIR := "user://test_saves"
## Approved family reference bases B1 (item level 1).
const REFERENCES := {&"one_handed_sword": 12.0, &"two_handed_sword": 22.0, &"axe": 14.0, &"dagger": 9.0,
	&"mace": 15.0, &"spear": 13.0, &"staff": 13.0, &"wand": 10.0, &"bow": 13.0}
## Weapons on the model: approved base at their creation item level.
const ON_MODEL := {&"iron_sword": 12.0, &"militia_sword": 12.6, &"steel_greatsword": 22.0, &"iron_axe": 14.0,
	&"iron_dagger": 9.0, &"iron_mace": 15.0, &"ash_spear": 13.0, &"oak_staff": 13.0, &"oak_wand": 10.0, &"hunting_bow": 13.0,
	&"forged_blade": 14.4, &"forged_greatsword": 27.39}
## 1.2 Special Weapons V2: [global physical %, global poise %] kept (never scaled by quality).
const SPECIALS := {&"stormcaller_fang": [8.0, 4.0], &"crushing_oath": [4.0, 0.0], &"echo_blade": [8.0, 0.0]}

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
		var weapon_damage := WeaponDamage.of(ItemCreation.create(definition, 1, db), definition, db)
		check_near(weapon_damage, ON_MODEL[item_id], 1e-9, "%s D_weapon at quality 0" % item_id)
		var family: WeaponFamily = db.weapons[definition.weapon_family_id]
		var heavy := "P" if family.is_bow() else "H"
		var ratio: float = ON_MODEL[item_id] / REFERENCES[definition.weapon_family_id]
		check_near(CombatComponent.base_damage(family.node("L"), weapon_damage), _old(family.id, "L") * ratio, 1e-9, "%s quick" % item_id)
		check_near(CombatComponent.base_damage(family.node(heavy), weapon_damage), _old(family.id, heavy) * ratio, 1e-9, "%s heavy" % item_id)
	var militia := db.get_item(&"militia_sword")
	check(militia.base_stats.is_empty(), "militia: global +5 % physical damage removed")
	check_near(CombatComponent.base_damage(db.weapons[&"one_handed_sword"].node("H"), 12.6), 27.3, 1e-9, "militia heavy 26 x 1.05")
	check_near(WeaponDamage.model_factor(militia, db), 1.05, 1e-12, "militia model factor 1.05")
	for item_id: StringName in [&"iron_sword", &"steel_greatsword", &"iron_axe", &"iron_dagger", &"iron_mace", &"ash_spear", &"oak_staff", &"oak_wand", &"hunting_bow"]:
		check_eq(WeaponDamage.model_factor(db.get_item(item_id), db), 1.0, "%s model factor 1.0" % item_id)
		check_eq(db.get_item(item_id).creation_item_level(), 1, "%s approved item level 1" % item_id)
	check_near(WeaponDamage.model_factor(db.get_item(&"forged_blade"), db), 14.4 / 13.584, 1e-15, "forged blade factor exactly 14.40 / B_ref(12)")
	check_near(WeaponDamage.model_factor(db.get_item(&"forged_greatsword"), db), 27.39 / 24.904, 1e-15, "forged greatsword factor exactly 27.39 / B_ref(12)")
	for item_id: StringName in [&"forged_blade", &"forged_greatsword"]:
		var forged := db.get_item(item_id)
		check_eq(forged.creation_item_level(), 12, "%s item level 12 from its profile" % item_id)
		check_eq(forged.base_stats.size(), 1, "%s: only the global poise base left" % item_id)
		check_eq(forged.base_stats[0].stat, Stats.POISE_DAMAGE, "%s: physical base removed, poise kept" % item_id)
		check(forged.validate().is_empty(), "%s valid" % item_id)


## 1.2 Special Weapons V2: on the model at item level 15 (base 14.016, factor 1.0); their
## global base bonuses stay global, exactly once, and quality never scales them.
func test_special_weapons_v2_keep_global_bonuses_unscaled() -> void:
	for item_id: StringName in SPECIALS:
		var definition := db.get_item(item_id)
		check(WeaponDamage.is_on_model(definition) and definition.validate().is_empty(), "%s on the model" % item_id)
		check_eq(definition.creation_item_level(), 15, "%s prototype item level 15" % item_id)
		check_near(WeaponDamage.model_factor(definition, db), 1.0, 1e-15, "%s model factor 1.0" % item_id)
		for quality: int in [0, 20]:
			var item := ItemCreation.create(definition, 1, db)
			item.quality = quality
			check_eq(item.item_level, 15, "%s created at 15" % item_id)
			check_near(item.base_weapon_damage, 14.016, 1e-12, "%s stored base 14.016" % item_id)
			check_near(WeaponDamage.of(item, definition, db), 14.016 * ItemStats.quality_factor(quality), 1e-12, "%s Q%d only on the base" % [item_id, quality])
			var totals := ItemDescriber.totals(ItemStats.modifiers(item, definition, db))
			check_near(float(totals.get("physical_damage|flat", 0.0)), SPECIALS[item_id][0], 1e-12, "%s Q%d: global physical once, unscaled" % [item_id, quality])
			check_near(float(totals.get("poise_damage|flat", 0.0)), SPECIALS[item_id][1], 1e-12, "%s Q%d: global poise unscaled" % [item_id, quality])
	check_eq(db.get_item(&"crushing_oath").effects[0].reach_multiplier, 1.25, "Crushing Oath reach effect unchanged")
	check_eq(db.get_item(&"crushing_oath").effects[0].poise_multiplier, 1.5, "Crushing Oath poise effect unchanged")
	var echo: EchoShockwaveEffect = db.get_item(&"echo_blade").effects[0]
	check_eq([echo.radius, echo.damage_ratio, echo.poise_damage, echo.cooldown], [52.0, 0.4, 10.0, 0.5], "echo shockwave data unchanged")
	check(db.get_item(&"echo_blade").crafting == null, "echo blade: still no crafting profile (no quality)")


## Stormcaller evolution stage 2: its +6 % physical (and +10 % finisher power) apply once,
## on top of the kept global +8 %, never scaled by quality.
func test_stormcaller_stage_two_bonus_once() -> void:
	character = CharacterFactory.create_new(db)
	var fang := character.inventory.add_item(&"stormcaller_fang")[0]
	check_eq(character.equipment.equip(fang.instance_id, S.MAIN_HAND), "", "equipped")
	var before := character.get_stat(Stats.PHYSICAL_DAMAGE)
	check_near(before, 8.0, 1e-12, "stage 1: global +8 once")
	fang.evolution = {"stage": 2, "xp": 0, "path": ""}
	fang.quality = 20
	character.notify_item_changed(fang.instance_id)
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE), 8.0 + 6.0, 1e-12, "stage 2: +6 exactly once, quality never on it")
	check_near(character.get_stat(Stats.FINISHER_POWER), 10.0, 1e-12, "stage 2 finisher power once")
	check_near(character.get_stat(Stats.POISE_DAMAGE), 4.0, 1e-12, "global poise 4, unscaled")
	check_near(fang.base_weapon_damage, 14.016, 1e-12, "evolution never touches the stored base")


# --- quality and local affixes -------------------------------------------------------------

## A test definition on the model with a crafting profile (none of the data weapons has one yet).
func _craftable(item_id: StringName = &"iron_sword") -> ItemDefinition:
	var definition: ItemDefinition = db.get_item(item_id).duplicate()
	definition.crafting = CraftingProfile.new()
	definition.crafting.affix_slots = 5
	definition.crafting.allowed_operations = [CraftingOps.AUGMENT, CraftingOps.QUALITY] as Array[StringName]
	var bonus := StatModifier.make(Stats.PHYSICAL_DAMAGE, 5.0, 0.0)
	definition.base_stats = [bonus] as Array[StatModifier]
	definition.base_item_level = 0   # the crafting profile is the item level source
	return definition


func test_quality_only_on_the_weapon_base() -> void:
	var definition := _craftable()
	var item := ItemCreation.create(definition, 1, db)
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
	var sword := ItemCreation.create(_craftable(), 1, db)
	sword.affixes.append({"affix": "striking", "tier": 5, "tier_model": 5, "stat": "weapon_damage", "flat": 0.6, "percent": 0.0, "share": 5.0})
	var definition := _craftable()
	check_near(WeaponDamage.of(sword, definition, db), 12.6, 1e-9, "12 + 0.6")
	sword.quality = 20
	check_near(WeaponDamage.of(sword, definition, db), 13.2 + 0.6, 1e-9, "quality on the base only, Striking stays 0.6")
	var restored := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(sword.to_dict())))
	check_near(WeaponDamage.of(restored, definition, db), 13.8, 1e-9, "saved Striking value restored as rolled")


func test_tempered_blade_striking_and_both() -> void:
	var definition := _craftable()
	var item := ItemCreation.create(definition, 1, db)
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


## No pool offers the local affixes yet (activation not decided): converting the forged
## weapons adds no new rolls to augment / reforge.
func test_local_affixes_are_offered_by_no_pool() -> void:
	var forged := ItemCreation.create(db.get_item(&"forged_blade"), 1, db)
	for level: int in [12, 70]:
		forged.item_level = level
		var pool := AffixPool.by_affix(AffixPool.compute(forged, db.get_item(&"forged_blade"), null, db))
		check(not pool.has(&"tempered_blade") and not pool.has(&"striking"), "forged blade ilvl %d: no local affixes" % level)
		check_eq(pool.size(), 11, "forged blade pool as before (ilvl %d)" % level)
	var other := AffixPool.by_affix(AffixPool.compute(ItemCreation.create(_craftable(), 1, db), _craftable(), null, db))
	check(not other.has(&"tempered_blade") and not other.has(&"striking"), "no model weapon gets them")


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


## Special weapons V2 on the real player: quick and heavy = 14.016 x Q x multiplier, then
## the kept global physical bonus exactly once (CharacterStatModifier).
func test_special_weapons_quick_and_heavy_hits() -> void:
	_bind()
	var cases := [[&"stormcaller_fang", 0], [&"stormcaller_fang", 20], [&"crushing_oath", 0], [&"crushing_oath", 20], [&"echo_blade", 0]]
	for entry: Array in cases:
		var item := _equip(entry[0])
		item.quality = entry[1]
		character.notify_item_changed(item.instance_id)
		await wait_physics(2)
		var global: float = 1.0 + SPECIALS[entry[0]][0] / 100.0
		var weapon := 14.016 * ItemStats.quality_factor(entry[1])
		check_near(player.combat.weapon_base_damage, weapon, 1e-9, "%s Q%d D_weapon" % entry)
		var quick := await _quick_hit()
		check(quick != null and absf(quick.damage - 12.0 * weapon / 12.0 * global) < 1e-6, "%s Q%d quick %.4f (got %s)" % [entry[0], entry[1], weapon * global, quick.damage if quick else -1.0])
		hits.clear()
		var target := add_target(Vector2(18, 0), 20.0)
		await perform_path("H", Vector2.RIGHT, 4)
		target.get_parent().queue_free()
		var heavy: HitData = hits[0] if not hits.is_empty() else null
		check(heavy != null and absf(heavy.damage - 26.0 * weapon / 12.0 * global) < 1e-6, "%s Q%d heavy %.4f (got %s)" % [entry[0], entry[1], 26.0 * weapon / 12.0 * global, heavy.damage if heavy else -1.0])
		character.equipment.unequip(S.MAIN_HAND)


## Echo shockwave after V2: 40 % of the (higher) real crush hit to a bystander in the radius,
## once per swing, nothing outside the radius, the triggering target never hit by its own echo.
func test_echo_shockwave_follows_the_real_hit() -> void:
	_bind()
	character.mastery.add_xp(&"one_handed_sword", 400)   # L-L-H needs mastery 4
	_equip(&"echo_blade")
	var main := add_target(Vector2(24, 0), 10.0)
	var near := add_target(Vector2(24, 44), 8.0)   # inside the 52 px radius, outside the crush reach
	var far := add_target(Vector2(24, 140), 8.0)
	await wait_physics(2)
	hits.clear()
	await perform_path("LLH", Vector2.RIGHT, 10)
	var crush: Array = hits.filter(func(hit: HitData) -> bool: return hit.attack != null and hit.attack.id == &"sword_llh_crush" and not &"echo_shockwave" in hit.tags)
	var echoes: Array = hits.filter(func(hit: HitData) -> bool: return &"echo_shockwave" in hit.tags)
	check(not crush.is_empty(), "crush landed")
	check_eq(echoes.size(), 1, "one echo: the bystander, never the struck target, never outside the radius")
	if not crush.is_empty() and not echoes.is_empty():
		var main_crush: HitData = crush.filter(func(hit: HitData) -> bool: return hit.target == main.get_entity()).front()
		check_near(main_crush.damage, 26.0 * 14.016 / 12.0 * 1.08, 1e-6, "crush on the new base, global +8 once")
		check_near(echoes[0].damage, main_crush.damage * 0.4, 1e-6, "echo = 40 % of the real hit")
		check_eq(echoes[0].poise_damage, 10.0, "echo poise unchanged")
		check(echoes[0].target == null or echoes[0].target != main.get_entity(), "triggering target excluded")
	check(not hits.any(func(hit: HitData) -> bool: return hit.target == far.get_entity()), "nothing outside the radius")
	check(near != null, "bystander exists")


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



# --- 1.1: instance base, forged weapons, persistence, migration ----------------------------

## Forged weapons, quality 0, before (family reference x global +6 % / +10 %) and after (V3).
func test_forged_weapons_before_and_after() -> void:
	var sword: WeaponFamily = db.weapons[&"one_handed_sword"]
	var great: WeaponFamily = db.weapons[&"two_handed_sword"]
	var cases := [[&"forged_blade", sword, 6.0, 14.4], [&"forged_greatsword", great, 10.0, 27.39]]
	for entry: Array in cases:
		var definition := db.get_item(entry[0])
		var item := ItemCreation.create(definition, 1, db)
		check_eq(item.item_level, 12, "%s created at item level 12" % entry[0])
		check_near(item.base_weapon_damage, entry[3], 1e-12, "%s stored base" % entry[0])
		var family: WeaponFamily = entry[1]
		for node: String in ["L", "H"]:
			var before: float = family.node(node).damage * (1.0 + entry[2] / 100.0)
			var after := CombatComponent.base_damage(family.node(node), WeaponDamage.of(item, definition, db))
			check_near(after, family.node(node).damage * entry[3] / family.reference_base_damage, 1e-9, "%s %s after" % [entry[0], node])
			check(after > before, "%s %s: %.3f -> %.3f" % [entry[0], node, before, after])
		item.quality = 20
		check_near(WeaponDamage.of(item, definition, db), entry[3] * 1.1, 1e-9, "%s quality 20" % entry[0])
		check_near(item.base_weapon_damage, entry[3], 1e-12, "%s raw base unchanged by quality" % entry[0])


## Quality 0 and 20 never change the global physical / poise stats of a forged weapon.
func test_quality_never_raises_global_poise_or_physical() -> void:
	character = CharacterFactory.create_new(db)
	var physical_before := character.get_stat(Stats.PHYSICAL_DAMAGE)
	var poise_before := character.get_stat(Stats.POISE_DAMAGE)
	var blade := character.inventory.add_item(&"forged_blade")[0]
	blade.affixes.append({"affix": "sharpened", "tier": 3, "tier_model": 3, "stat": "physical_damage", "flat": 5.0, "percent": 0.0})
	check_eq(character.equipment.equip(blade.instance_id, S.MAIN_HAND), "", "equipped")
	for quality: int in [0, 20]:
		blade.quality = quality
		character.notify_item_changed(blade.instance_id)
		check_near(character.get_stat(Stats.PHYSICAL_DAMAGE) - physical_before, 5.0, 1e-9, "quality %d: only the global Sharpened +5" % quality)
		check_near(character.get_stat(Stats.POISE_DAMAGE) - poise_before, 4.0, 1e-9, "quality %d: global poise base 4, never scaled" % quality)
	check_eq(blade.affixes[0].affix, "sharpened", "stored Sharpened stays global and is not converted")


## Physical skills lose the removed global base bonus (report only, no compensation):
## the same physical skill hit with the old and the new stats.
func test_physical_skills_lose_the_removed_global_base() -> void:
	for entry: Array in [[&"forged_blade", 6.0], [&"forged_greatsword", 10.0], [&"militia_sword", 5.0]]:
		character = CharacterFactory.create_new(db)
		var item := character.inventory.add_item(entry[0])[0]
		character.equipment.equip(item.instance_id, S.MAIN_HAND)
		var now := CharacterStatModifier.new()
		now.stats = character.get_stats()
		var old := CharacterStatModifier.new()
		old.stats = character.get_stats().duplicate()
		old.stats[Stats.PHYSICAL_DAMAGE] = float(old.stats.get(Stats.PHYSICAL_DAMAGE, 0.0)) + entry[1]
		check_near(_skill_hit(old) / _skill_hit(now), 1.0 + entry[1] / 100.0, 1e-9, "%s: physical skills %.0f %% lower than before" % [entry[0], entry[1]])


func _skill_hit(modifier: CharacterStatModifier) -> float:
	var hit := HitData.new()
	hit.source = HitData.Source.SKILL
	hit.damage_type = &"physical"
	hit.damage = 100.0
	modifier.modify_hit(hit)
	return hit.damage


## Two item levels through the shared creation contract (explicit caller level and the
## item's own source); the base is B_ref(level) x model factor, stored once.
func test_creation_with_two_item_levels() -> void:
	character = CharacterFactory.create_new(db)
	var forged := db.get_item(&"forged_blade")
	var default_level := character.inventory.add_item(&"forged_blade")[0]
	var level_30 := character.inventory.add_item(&"forged_blade", 1, &"", 30)[0]
	check_eq([default_level.item_level, level_30.item_level], [12, 30], "levels: profile source / explicit")
	check_near(level_30.base_weapon_damage, WeaponDamage.reference_at(12.0, 30) * 14.4 / 13.584, 1e-12, "level 30: B_ref(30) x factor")
	var axe_1 := character.inventory.add_item(&"iron_axe")[0]
	var axe_50 := character.inventory.add_item(&"iron_axe", 1, &"", 50)[0]
	check_eq([axe_1.item_level, axe_50.item_level], [1, 50], "axe levels")
	check_near(axe_1.base_weapon_damage, 14.0, 1e-12, "axe level 1: 14")
	check_near(axe_50.base_weapon_damage, 14.0 * 1.588, 1e-12, "axe level 50: 14 x 1.588")
	check_near(WeaponDamage.of(level_30, forged, db) / WeaponDamage.of(default_level, forged, db),
		WeaponDamage.reference_at(12.0, 30) / WeaponDamage.reference_at(12.0, 12), 1e-12, "both scale along the same curve")
	check_eq(character.inventory.add_item(&"copper_ring")[0].base_weapon_damage, 0.0, "no base on non-weapons")
	var fang := character.inventory.add_item(&"stormcaller_fang")[0]
	check_eq(fang.item_level, 15, "special weapon: approved level 15")
	check_near(fang.base_weapon_damage, 14.016, 1e-12, "special weapon base 14.016")
	var echo_30 := character.inventory.add_item(&"echo_blade", 1, &"", 30)[0]
	check_near(echo_30.base_weapon_damage, WeaponDamage.reference_at(12.0, 30), 1e-12, "explicit level 30: B_ref(30) x 1.0")


## The stored base is never recomputed: quality, equip/unequip, bag <-> stash and
## save/load keep it bit-identical (also a value that differs from today's data).
func test_stored_base_survives_everything_unchanged() -> void:
	character = CharacterFactory.create_new(db)
	var blade := character.inventory.add_item(&"forged_blade", 1, &"", 37)[0]
	blade.affixes.append({"affix": "sharpened", "tier": 3, "tier_model": 3, "stat": "physical_damage", "flat": 5.0, "percent": 0.0})
	var striking: AffixDefinition = db.affixes[&"striking"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	blade.affixes.append(striking.roll(striking.get_tier(4), rng, WeaponDamage.reference_of(blade, db.get_item(&"forged_blade"), db)))
	var odd := character.inventory.add_item(&"iron_dagger")[0]
	odd.base_weapon_damage = 9.123456789012345   # e.g. created under older data: kept as stored
	var base := blade.base_weapon_damage
	var flat: float = blade.affixes[1].flat
	blade.quality = 20
	check_eq(character.equipment.equip(blade.instance_id, S.MAIN_HAND), "", "equip")
	character.equipment.unequip(S.MAIN_HAND)
	check_eq(StashService.deposit(character, blade.instance_id), "", "into the stash")
	check_eq(character.stash.find(blade.instance_id).base_weapon_damage, base, "stash: identical")
	check_eq(StashService.withdraw(character, blade.instance_id), "", "back to the bag")
	check_eq(StashService.deposit(character, odd.instance_id), "", "dagger into the stash")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := SAVE_DIR.path_join("weapon_base_%s.save.json" % IdGenerator.new_id("t"))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := SaveSystem.load_from(path, db)
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	check(result.character != null, "loaded: %s" % [result.errors])
	if result.character == null:
		return
	var loaded := result.character.inventory.find(blade.instance_id)
	check_near(loaded.base_weapon_damage, base, 1e-12, "save/load: base identical (full-precision JSON)")
	check_near(float(loaded.affixes[1].flat), flat, 1e-12, "save/load: Striking flat identical (full-precision JSON)")
	check_eq(loaded.affixes[0].affix, "sharpened", "existing affix kept")
	check_eq([loaded.item_level, loaded.quality], [37, 20], "level and quality kept")
	check_near(result.character.stash.find(odd.instance_id).base_weapon_damage, 9.123456789012345, 1e-12, "stored value never recomputed from data")
	for warning in result.warnings:
		check(not warning.contains("without stored base"), "no base warning: %s" % warning)


func test_striking_tooltip_one_decimal() -> void:
	var entry := {"affix": "striking", "tier": 4, "tier_model": 5, "stat": "weapon_damage", "flat": 0.86724, "percent": 0.0, "share": 7.0}
	var text := ItemDescriber.affix_text(db, entry)
	check(text.begins_with("+0.9 Weapon Damage (local)"), "one decimal in the tooltip: %s" % text)
	check_eq(entry.flat, 0.86724, "stored value not rounded")


## v11 -> v12: one deterministic assignment from the frozen model table and the saved
## item level; everything else (affixes, quality, unconverted items) stays as it is.
func test_migration_v11_to_v12() -> void:
	var sharpened := {"affix": "sharpened", "tier": 2, "tier_model": 3, "stat": "physical_damage", "flat": 9.0, "percent": 0.0}
	var old := {"inventory": [
		{"id": "a", "def": "forged_blade", "qty": 1, "ilvl": 12, "quality": 20, "affixes": [sharpened.duplicate()]},
		{"id": "b", "def": "militia_sword", "qty": 1},
		{"id": "c", "def": "stormcaller_fang", "qty": 1, "ilvl": 15},
		{"id": "d", "def": "iron_ore", "qty": 5},
		{"id": "e", "def": "forged_greatsword", "qty": 1, "ilvl": 20}],
		"stash": {"items": [{"id": "f", "def": "steel_greatsword", "qty": 1}]},
		"orphaned_items": [{"id": "g", "def": "oak_wand", "qty": 1, "base_damage": 11.5}]}
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate(old.duplicate(true), 11, errors)
	check(errors.is_empty(), "migrates: %s" % [errors])
	var items: Array = data.inventory
	check_near(items[0].base_damage, 14.4, 1e-12, "forged blade ilvl 12: 14.40")
	check_eq(items[0].affixes, [sharpened], "Sharpened kept global and untouched")
	check_eq(items[0].quality, 20, "quality kept")
	check_near(items[1].base_damage, 12.6, 1e-12, "militia: 12.6")
	check_near(items[2].base_damage, 14.016, 1e-12, "v13: stormcaller with saved ilvl 15")
	check(not items[3].has("base_damage"), "material untouched")
	check_near(items[4].base_damage, WeaponDamage.reference_at(22.0, 20) * 27.39 / 24.904, 1e-12, "greatsword ilvl 20 along the curve")
	check_near(data.stash.items[0].base_damage, 22.0, 1e-12, "stash items too")
	check_eq(data.orphaned_items[0].base_damage, 11.5, "an existing value is never replaced")
	var again: Dictionary = SaveMigrations.migrate(old.duplicate(true), 11, errors)
	check_eq(again.inventory, data.inventory, "deterministic")
	for model: String in SaveMigrations.V12_WEAPON_MODELS:
		var definition := db.get_item(StringName(model))
		var frozen: Array = SaveMigrations.V12_WEAPON_MODELS[model]
		check_eq([WeaponDamage.family_base(definition, db), definition.base_weapon_damage, definition.creation_item_level()],
			[frozen[0], frozen[1], frozen[2]], "%s: frozen table matches the approved data" % model)
	var restored := Character.from_dict(data, db, PackedStringArray())
	check_near(WeaponDamage.of(restored.inventory.find("a"), db.get_item(&"forged_blade"), db), 14.4 * 1.1, 1e-9, "loaded forged blade: base x quality")


func test_bound_player_forged_greatsword_hits() -> void:
	_bind()
	var great := _equip(&"forged_greatsword")
	await wait_physics(2)
	check_near(player.combat.weapon_base_damage, 27.39, 1e-9, "D_weapon 27.39")
	check_near(character.get_stat(Stats.PHYSICAL_DAMAGE), 0.0, 1e-9, "no global physical base left")
	var hit := await _quick_hit()
	check(hit != null and absf(hit.damage - 27.39) < 1e-6, "forged greatsword quick 27.39 (got %s)" % (hit.damage if hit else -1.0))
	check_near(great.base_weapon_damage, 27.39, 1e-12, "stored base untouched by equipping")



# --- 1.2: special weapons V2 - persistence and v13 migration -----------------------------

## v12 -> v13: the three special weapons get their base once from their SAVED item level
## (an echo blade saved at level 1 stays level 1); evolution, essences, sockets, quality,
## existing values and all other items stay as they are.
func test_migration_v12_to_v13() -> void:
	var evolution := {"stage": 2, "xp": 15, "path": ""}
	var old := {"inventory": [
		{"id": "a", "def": "stormcaller_fang", "qty": 1, "ilvl": 15, "quality": 20, "essences": ["storm_wolf"], "evolution": evolution.duplicate()},
		{"id": "b", "def": "crushing_oath", "qty": 1, "ilvl": 15, "quality": 5, "sockets": ["impact_rune"]},
		{"id": "c", "def": "echo_blade", "qty": 1},
		{"id": "d", "def": "forged_blade", "qty": 1, "ilvl": 12, "base_damage": 14.4}],
		"stash": {"items": [{"id": "e", "def": "echo_blade", "qty": 1, "ilvl": 15}]},
		"orphaned_items": [{"id": "f", "def": "crushing_oath", "qty": 1, "ilvl": 15, "base_damage": 13.5}]}
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate(old.duplicate(true), 12, errors)
	check(errors.is_empty(), "migrates: %s" % [errors])
	var items: Array = data.inventory
	check_near(items[0].base_damage, 14.016, 1e-12, "stormcaller ilvl 15: 14.016")
	check_eq([items[0].quality, items[0].essences, items[0].evolution], [20, ["storm_wolf"], evolution], "quality, essence, evolution kept")
	check_near(items[1].base_damage, 14.016, 1e-12, "oath ilvl 15: 14.016")
	check_eq([items[1].quality, items[1].sockets], [5, ["impact_rune"]], "oath quality and socket kept")
	check(not items[2].has("ilvl"), "old echo blade keeps its saved level 1 (not moved to 15)")
	check_near(items[2].base_damage, 12.0, 1e-12, "echo blade level 1: B_ref(1) x 1.0 = 12")
	check_eq(items[3].base_damage, 14.4, "other weapons untouched")
	check_near(data.stash.items[0].base_damage, 14.016, 1e-12, "stash echo blade ilvl 15")
	check_eq(data.orphaned_items[0].base_damage, 13.5, "an existing value is never replaced")
	check_eq(SaveMigrations.migrate(old.duplicate(true), 12, errors).inventory, items, "deterministic")
	for model: String in SaveMigrations.V13_WEAPON_MODELS:
		var definition := db.get_item(StringName(model))
		var frozen: Array = SaveMigrations.V13_WEAPON_MODELS[model]
		check_eq([WeaponDamage.family_base(definition, db), definition.base_weapon_damage, definition.creation_item_level()],
			[frozen[0], frozen[1], frozen[2]], "%s: frozen table matches the approved data" % model)
	var restored := Character.from_dict(data, db, PackedStringArray())
	var fang := restored.inventory.find("a")
	check_eq([fang.item_level, fang.evolution_stage(), fang.quality], [15, 2, 20], "loaded stormcaller state")
	check_near(WeaponDamage.of(fang, db.get_item(&"stormcaller_fang"), db), 14.016 * 1.1, 1e-9, "loaded: base x quality")
	check_eq(restored.inventory.find("c").item_level, 1, "loaded echo blade level 1")


## Stored special-weapon bases survive equip, bag <-> stash and save/load unchanged.
func test_special_weapon_base_survives_equip_stash_and_save() -> void:
	character = CharacterFactory.create_new(db)
	var ids: Array[String] = []
	for item_id: StringName in SPECIALS:
		ids.append(character.inventory.add_item(item_id)[0].instance_id)
	var oath := character.inventory.find(ids[1])
	oath.quality = 12
	check_eq(character.equipment.equip(ids[0], S.MAIN_HAND), "", "equip stormcaller")
	check_eq(character.equipment.equip(ids[2], S.MAIN_HAND), "", "swap to echo blade")
	character.equipment.unequip(S.MAIN_HAND)
	check_eq(StashService.deposit(character, ids[1]), "", "oath into the stash")
	check_eq(StashService.deposit(character, ids[2]), "", "echo into the stash")
	check_eq(StashService.withdraw(character, ids[2]), "", "echo back")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := SAVE_DIR.path_join("special_base_%s.save.json" % IdGenerator.new_id("t"))
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var result := SaveSystem.load_from(path, db)
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	check(result.character != null, "loaded: %s" % [result.errors])
	if result.character == null:
		return
	for instance_id in ids:
		var loaded := result.character.inventory.find(instance_id)
		if loaded == null:
			loaded = result.character.stash.find(instance_id)
		check(loaded != null, "%s found" % instance_id)
		if loaded != null:
			check_near(loaded.base_weapon_damage, 14.016, 1e-12, "%s base unchanged" % loaded.definition_id)
			check_eq(loaded.item_level, 15, "%s level 15 kept" % loaded.definition_id)
	check_eq(result.character.stash.find(ids[1]).quality, 12, "oath quality kept, raw base unchanged")
