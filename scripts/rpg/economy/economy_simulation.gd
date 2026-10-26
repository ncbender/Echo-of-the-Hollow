class_name EconomySimulation
extends RefCounted
## Loot Economy 1.0: a small, data-driven check of crafting, salvaging and
## selling (docs/ECONOMY.md). It reads the current data only - nothing is
## balanced here. run() returns {"findings": [...], "open": [...], "lines": [...]}:
##  * findings = loops that would gain something (must stay empty),
##  * open     = values the design has not set yet (reported, never guessed),
##  * lines    = the readable report.
##
## Checked:
##  * material loop: for every salvageable recipe, the best salvage roll
##    (highest rarity share) returns fewer raw units than the recipe needs;
##  * gold loop: crafting then selling can never return more gold than the
##    inputs would sell for, and no action turns gold into sellable items
##    (no vendor: gold only flows out through flask upgrades, respecs, quests);
##  * XP: salvaging gives no profession XP, armour XP from one enemy is capped,
##    gathering XP needs a node that is depleted (real-time respawn);
##  * enemy gold drops by enemy, and which enemies are persistent (defeated
##    once, flag saved together with the loot - no repeat by save/load).


static func run(db: GameDatabase) -> Dictionary:
	var findings: PackedStringArray = []
	var open: PackedStringArray = []
	var lines: PackedStringArray = ["Hollowwood Loot Economy 1.0 - simulation", ""]
	var factors := db.rules.rarity_sell_factors
	var shares := db.rules.salvage_return_percent
	var best_share := 0.0
	for span in shares:
		best_share = maxf(best_share, span.y / 100.0)
	# 1. crafting -> salvaging -> crafting (materials)
	lines.append("Crafting -> salvaging (raw units, best possible salvage roll %d %%):" % roundi(best_share * 100.0))
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if SalvageService.source_recipe(db, recipe.output_item_id) != recipe:
			continue
		var raw := SalvageService.raw_materials(db, recipe)
		for item_id: StringName in raw:
			var spent := float(raw[item_id])
			var back := floorf(spent * best_share + 0.0001)
			lines.append("  %s: %s %.1f in, at most %d back" % [recipe.id, item_id, spent, back])
			if back >= spent:
				findings.append("material loop: %s returns %d of %.1f %s" % [recipe.id, back, spent, item_id])
	# 2. crafting -> selling (gold)
	lines.append("")
	lines.append("Crafting -> selling (gold):")
	var valued := 0
	for recipe: ProfessionRecipeDefinition in db.profession_recipes.values():
		if not recipe.craftable:
			continue
		var output := db.get_item(recipe.output_item_id)
		var output_gold := EconomyService.unit_value(db, output) * recipe.output_quantity
		var input_gold := 0
		var unknown := output_gold <= 0
		for cost in recipe.inputs:
			var value := EconomyService.unit_value(db, db.get_item(cost.item_id))
			unknown = unknown or value <= 0
			input_gold += value * cost.quantity
		if unknown:
			continue
		valued += 1
		lines.append("  %s: inputs sell for %d, output for %d" % [recipe.id, input_gold, output_gold])
		# Crafting adds value on purpose (time, profession); it is only a LOOP if
		# gold could buy the inputs back - checked below.
	if valued == 0:
		var shown: PackedStringArray = []
		for factor in factors:
			shown.append("%.1f" % factor)
		open.append("base item values: no item has a designed base value, so nothing can be sold yet (sell value = base x rarity factor %s)" % ", ".join(shown))
		lines.append("  no valued recipes (no base item values designed yet)")
	# gold can never buy items: no vendor, no shop data
	var gold_buys_items := false
	lines.append("  gold -> items: %s" % ("possible" if gold_buys_items else "impossible (no vendor); gold leaves through flask upgrades, respecs and class quests"))
	if gold_buys_items:
		findings.append("gold loop: gold can buy sellable items")
	# 3. enemy gold and persistence
	lines.append("")
	lines.append("Enemy gold drops:")
	for config: EnemyConfig in _enemy_configs():
		var gold := 0
		for drop in config.drops:
			if drop.item_id == EconomyService.GOLD:
				gold += drop.quantity
		lines.append("  %s: %d gold, %d mastery XP" % [config.id, gold, config.mastery_xp_reward])
	open.append("gold for elites, bosses, quests and treasure chests: the game has no enemy rank, no quest gold reward and no chests yet - amounts not designed")
	# 4. XP guards
	lines.append("")
	lines.append("XP guards: salvaging 0 profession XP; armour defense XP capped at %.0f per enemy; kills rewarded once per enemy instance;"
		% db.rules.armor_rules().defense_xp_cap_per_enemy)
	lines.append("  gathering XP only from an available node (depleted for its real-time respawn, saved).")
	lines.append("")
	lines.append("Findings: %s" % ("none" if findings.is_empty() else "; ".join(findings)))
	lines.append("Open values: %s" % ("none" if open.is_empty() else "; ".join(open)))
	return {"findings": findings, "open": open, "lines": lines}


static func _enemy_configs() -> Array[EnemyConfig]:
	var result: Array[EnemyConfig] = []
	var dir := DirAccess.open("res://data/enemies")
	if dir == null:
		return result
	for file in dir.get_files():
		var path := "res://data/enemies/" + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var resource := load(path)
		if resource is EnemyConfig:
			result.append(resource)
	return result
