class_name SaveMigrations
extends RefCounted
## Upgrades older save payloads step by step to SaveSystem.VERSION.
##
## How to change the save schema:
##   1. bump SaveSystem.VERSION to N
##   2. add `N - 1: _v{N-1}_to_v{N}` to _steps() and implement the function
##      (pure Dictionary -> Dictionary, no game objects involved)
##   3. add a test that loads a stored version N-1 payload
## Old files are never rewritten in place; they are upgraded in memory and
## saved in the new format on the next save.

static func _steps() -> Dictionary:
	return {
		1: _v1_to_v2,
		2: _v2_to_v3,
		3: _v3_to_v4,
		4: _v4_to_v5,
		5: _v5_to_v6,
		6: _v6_to_v7,
		7: _v7_to_v8,
		8: _v8_to_v9,
		9: _v9_to_v10,
		10: _v10_to_v11,
		11: _v11_to_v12,
	}


static func migrate(payload: Dictionary, from_version: int, errors: PackedStringArray) -> Variant:
	var data := payload
	var version := from_version
	while version < SaveSystem.VERSION:
		var steps := _steps()
		if not steps.has(version):
			errors.append("no migration from save version %d" % version)
			return null
		var step: Callable = steps[version]
		data = step.call(data)
		version += 1
	return data


## v2 (Overnight 3): world.map_states added (persistent per-map state).
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var world: Dictionary = data.get("world", {}) if data.get("world") is Dictionary else {}
	if not world.has("map_states"):
		world["map_states"] = {}
	data["world"] = world
	return data


## v3 (Crafting Foundation 0.1): items carry crafting state. Existing items get
## valid defaults (item level 1, quality 0, no material); nothing is rolled.
## The prepared v2 field "essence" (never written by the game) becomes the
## "essences" list; unrecognised content is kept in "progress".
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	for key: String in ["inventory", "orphaned_items"]:
		var items: Variant = data.get(key, [])
		if not items is Array:
			continue
		for entry: Variant in items:
			if entry is Dictionary:
				_upgrade_item_v3(entry)
	return data


static func _upgrade_item_v3(item: Dictionary) -> void:
	if not item.has("ilvl"):
		item["ilvl"] = 1
	if not item.has("quality"):
		item["quality"] = 0
	var legacy: Variant = item.get("essence")
	if legacy != null:
		item.erase("essence")
		if legacy is Dictionary and legacy.get("slots") is Array:
			item["essences"] = legacy["slots"]
		elif legacy is Dictionary and not legacy.is_empty():
			var progress: Dictionary = item.get("progress", {}) if item.get("progress") is Dictionary else {}
			progress["legacy_essence"] = legacy
			item["progress"] = progress
	if item.get("evolution") is Dictionary and not item["evolution"].is_empty() and not item["evolution"].has("stage"):
		item["evolution"]["stage"] = 1
	var affixes: Variant = item.get("affixes")
	if affixes is Array:
		for affix: Variant in affixes:
			if affix is Dictionary and not affix.has("affix"):
				affix["legacy"] = true   # plain stat roll from before crafting; applied, not reforgeable


## v4 (Class Foundation 0.2): class builds (talents, skill slots, mods, presets),
## prologue state and class quests. Old characters start with empty builds; the
## class level they already reached gives its talent points automatically.
## Prologue: a save that already has a prologue class unlocked (debug unlocks
## before 0.2) counts as "prologue completed" with that class - nothing that was
## unlocked is ever locked again. Otherwise the prologue has not started.
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	if not data.get("class_builds") is Dictionary:
		data["class_builds"] = {}
	if not data.get("quests") is Dictionary:
		data["quests"] = {}
	if not data.get("prologue") is Dictionary:
		var progress: Dictionary = {}
		if data.get("classes") is Dictionary and data.classes.get("progress") is Dictionary:
			progress = data.classes.progress
		var chosen := ""
		for class_id: String in ["warrior", "arcanist", "shadowrunner"]:
			if progress.get(class_id) is Dictionary and bool(progress[class_id].get("unlocked", false)):
				chosen = class_id
				break
		data["prologue"] = {"stage": "completed" if chosen != "" else "not_started", "completed_trials": [], "chosen_class": chosen}
	return data


## v5 (Prologue & Haven Vertical Slice 0.1): play time, activated waystones,
## Haven ruin restoration and the story prologue quests.
##  * plot buildings become restored ruins (smithy -> Old Smithy, storage -> Old
##    Storehouse, training ground -> Fallen Barracks) and leave the plot list
##  * a v4 character already lives in Haven, so the road part of the prologue is
##    complete and the Old Smithy counts as rekindled (forge access as before);
##    with a finished class choice the whole prologue is complete and the main
##    quest starts, otherwise the story continues at "The Whispering Stone"
##  * nothing is taken away: items, classes, builds and loadouts stay untouched
static func _v4_to_v5(data: Dictionary) -> Dictionary:
	if not data.has("play_time"):
		data["play_time"] = 0.0
	var world: Dictionary = data.get("world", {}) if data.get("world") is Dictionary else {}
	if not world.get("waystones") is Array:
		world["waystones"] = ["haven"]
	var restoration: Dictionary = world.get("restoration", {}) if world.get("restoration") is Dictionary else {}
	var plot_buildings: Dictionary = world.get("buildings", {}) if world.get("buildings") is Dictionary else {}
	var ruin_of := {"smithy": "old_smithy", "storage": "old_storehouse", "training_ground": "fallen_barracks"}
	for plot: Variant in plot_buildings.keys():
		var building := str(plot_buildings[plot])
		if ruin_of.has(building):
			restoration[ruin_of[building]] = "restored"
			plot_buildings.erase(plot)   # the ruin now provides it (no double storage bonus)
	world["buildings"] = plot_buildings
	restoration["old_smithy"] = "restored"
	world["restoration"] = restoration
	var flags: Dictionary = world.get("flags", {}) if world.get("flags") is Dictionary else {}
	for flag: String in ["prologue.started", "prologue.road_cleared", "prologue.road_walked", "prologue.mara_rescued",
			"prologue.supplies_recovered", "prologue.cart_defended", "prologue.cart_done", "prologue.haven_discovered",
			"prologue.smithy_restored", "prologue.haven_settled"]:
		flags[flag] = true
	for ruin: String in restoration:
		flags["haven.%s.restored" % ruin] = true   # RestorationService flag of every restored ruin
	var quests: Dictionary = data.get("quests", {}) if data.get("quests") is Dictionary else {}
	var prologue: Dictionary = data.get("prologue", {}) if data.get("prologue") is Dictionary else {}
	var finished := str(prologue.get("stage", "")) == "completed"
	# story counters ("count.<event>") that cumulative objectives read
	flags["count.interact:supply_crate"] = 2
	var trials: Variant = prologue.get("completed_trials", [])
	var trials_done: int = (trials as Array).size() if trials is Array else 0
	flags["count.trial_complete"] = 3 if finished else trials_done
	if finished and not "whispering_stone" in world.waystones:
		world.waystones.append("whispering_stone")
	world["flags"] = flags
	data["world"] = world
	var done := {"state": "completed", "step": 0, "progress": {}}
	for quest_id: String in ["a_road_forgotten", "the_broken_cart", "shelter_among_the_trees"]:
		if not quests.has(quest_id):
			quests[quest_id] = done.duplicate(true)
	if finished:
		for quest_id: String in ["the_whispering_stone", "the_first_binding"]:
			if not quests.has(quest_id):
				quests[quest_id] = done.duplicate(true)
		for flag: String in ["prologue.shrine_reached", "prologue.first_class_selected", "prologue.stone_awakened",
				"prologue.completed"]:
			flags[flag] = true
		if not quests.has("the_first_signs"):
			quests["the_first_signs"] = {"state": "active", "step": 0, "progress": {}}
	elif not quests.has("the_whispering_stone"):
		quests["the_whispering_stone"] = {"state": "active", "step": 0, "progress": {}}
	data["quests"] = quests
	return data


## v6 (Inventory & Haven Stash 1.0): the Haven stash - an empty one for every
## older save. Inventory, loadouts, quests, classes and talents stay untouched.
static func _v5_to_v6(data: Dictionary) -> Dictionary:
	if not data.get("stash") is Dictionary:
		data["stash"] = {"items": []}
	elif not (data["stash"] as Dictionary).get("items") is Array:
		data["stash"]["items"] = []
	return data


## v7 (Professions Foundation 1.0): profession progress - every profession at
## level 1 without XP; the level-1 recipes are learned on load
## (ProfessionService.learn_automatic). Nothing else changes.
static func _v6_to_v7(data: Dictionary) -> Dictionary:
	if not data.get("professions") is Dictionary:
		data["professions"] = {"levels": {}, "known_recipes": [], "first_crafts": []}
	return data


## v8 (Item Integrity 1.0): item protection and origin. Every saved item of
## the bag, the stash and the kept orphans is marked "unknown_legacy" - its
## origin is never guessed. No item is favourite or locked; all other item
## data (id, affixes, quality, essences, sockets ...) stays as it is.
static func _v7_to_v8(data: Dictionary) -> Dictionary:
	var lists: Array = [data.get("inventory"), data.get("orphaned_items")]
	if data.get("stash") is Dictionary:
		lists.append(data["stash"].get("items"))
	for list: Variant in lists:
		if not list is Array:
			continue
		for entry: Variant in list:
			if entry is Dictionary and not (entry as Dictionary).has("origin"):
				entry["origin"] = "unknown_legacy"
	return data


## v9 (Hearth Flask & Consumables 1.0): the flask without upgrades and with
## full base charges (-1 = filled from the rules on load), no potion slot, no
## buff, no cooldown. Nothing else changes.
static func _v8_to_v9(data: Dictionary) -> Dictionary:
	if not data.get("consumables") is Dictionary:
		data["consumables"] = {"capacity": 0, "potency": 0, "charges": -1, "potion_slot": "", "buff": "", "buff_left": 0.0, "cooldown": 0.0}
	return data


## v10 (Armor Mastery 1.0): every armour track at level 1 without XP. Items,
## equipment slots and loadouts are not touched (no slot assumptions).
static func _v9_to_v10(data: Dictionary) -> Dictionary:
	if not data.get("armor_mastery") is Dictionary:
		data["armor_mastery"] = {}
	return data


## v11 (Item Foundation 1.0): rolled affixes name the tier model of their tier
## number. Every affix rolled before v11 came from the three-tier prototype model
## (AffixTiers.MODEL_THREE), so it is marked as such - never read as a five-tier
## tier. Values (flat/percent), legacy stat rolls and all other data stay as they are.
static func _v10_to_v11(data: Dictionary) -> Dictionary:
	var lists: Array = [data.get("inventory"), data.get("orphaned_items")]
	if data.get("stash") is Dictionary:
		lists.append(data["stash"].get("items"))
	for list: Variant in lists:
		if not list is Array:
			continue
		for entry: Variant in list:
			if not entry is Dictionary or not (entry as Dictionary).get("affixes") is Array:
				continue
			for affix: Variant in entry["affixes"]:
				if affix is Dictionary and affix.has("affix") and affix.has("tier") and not affix.has("tier_model"):
					affix["tier_model"] = AffixTiers.MODEL_THREE
	return data


## Weapon models on the base damage model at v12, frozen as they were approved (Weapon
## Base Damage 1.1): id -> [family B1, approved base, creation item level]. A migration
## never reads the live item data, so later rebalancing cannot change old conversions.
const V12_WEAPON_MODELS := {
	"iron_sword": [12.0, 12.0, 1], "militia_sword": [12.0, 12.6, 1], "steel_greatsword": [22.0, 22.0, 1],
	"iron_axe": [14.0, 14.0, 1], "iron_dagger": [9.0, 9.0, 1], "iron_mace": [15.0, 15.0, 1],
	"ash_spear": [13.0, 13.0, 1], "oak_staff": [13.0, 13.0, 1], "oak_wand": [10.0, 10.0, 1],
	"hunting_bow": [13.0, 13.0, 1], "forged_blade": [12.0, 14.4, 12], "forged_greatsword": [22.0, 27.39, 12],
}


## v12 (Weapon Base Damage 1.1): every weapon instance stores its raw base damage. Weapons
## of the models above get it once, deterministically from their saved item level:
## B_ref(level) x (approved base / B_ref(creation level)) - nothing is rolled, all other
## data (quality, affixes incl. global Sharpened rolls, sockets, essences) stays as it is.
static func _v11_to_v12(data: Dictionary) -> Dictionary:
	var lists: Array = [data.get("inventory"), data.get("orphaned_items")]
	if data.get("stash") is Dictionary:
		lists.append(data["stash"].get("items"))
	for list: Variant in lists:
		if not list is Array:
			continue
		for entry: Variant in list:
			if not entry is Dictionary or entry.has("base_damage") or not V12_WEAPON_MODELS.has(str(entry.get("def", ""))):
				continue
			var model: Array = V12_WEAPON_MODELS[str(entry["def"])]
			var level: Variant = entry.get("ilvl", 1)
			var item_level := clampi(int(level) if level is int or level is float else 1, 1, WeaponDamage.MAX_ITEM_LEVEL)
			entry["base_damage"] = _v12_reference(model[0], item_level) * float(model[1]) / _v12_reference(model[0], int(model[2]))
	return data


static func _v12_reference(family_base: float, item_level: int) -> float:
	return family_base * (1.0 + 0.012 * (item_level - 1))
