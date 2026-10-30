class_name GalleryScreens
extends RefCounted
## The screens of the UI gallery (tests/playtest/ui_gallery.gd) and how to open
## each one with real data. Returns the screen label, or "" when skipped.

const ALL := ["title", "hud", "hud_combat", "hud_boss", "hud_death", "inventory", "inventory_tooltip", "inventory_overview", "inventory_details", "character", "character_armor", "character_weapons", "classes", "classes_locked", "classes_active", "classes_switch", "classes_blocked", "classes_shadowrunner", "classes_start", "armor_none", "armor_mixed", "armor_mail", "talents", "talents_full", "talents_locked", "talents_arcanist", "talents_shadowrunner", "skills", "skills_locked", "skills_arcanist", "skills_shadowrunner", "presets", "presets_saved", "presets_invalid", "quests_warrior", "quests_arcanist", "quests_shadowrunner", "forge_imprint",
	"forge_affixes", "forge_reforge", "forge_essences", "forge_sockets", "forge_quality", "forge_evolution", "forge_craft",
	"recipes", "recipes_stash", "restoration", "dialogue", "choice", "waystones", "journal", "journal_haven", "map", "map_region", "stash", "stash_materials", "stash_restored",
	"professions", "professions_locked", "professions_tooltip", "professions_salvage", "professions_gathering", "professions_smithy", "hud_artisan_quarter",
	"hud_artisan_stages", "restoration_revitalize", "hud_consumables", "hud_notifications", "flask_upgrades", "quest_rewards",
	"quest_rewards_claimed", "quest_rewards_none", "hud_edrin_reward", "hud_edrin_story", "journal_reward",
	"flask_quest_rewards", "mara_rewards", "mara_rewards_claimed", "mara_rewards_none", "mara_rewards_full",
	"hud_mara_reward", "hud_both_rewards", "hud_mara_story", "journal_cart_reward", "journal_cart_claimed",
	"hud_full", "hud_low", "hud_empty", "hud_arcanist", "hud_shadowrunner", "hud_basic", "hud_dash", "hud_tracker_many", "hud_tracker_collapsed",
	"professions_alchemy", "professions_blacksmithing", "professions_tailoring", "professions_woodworking", "professions_salvage_empty",
	"talents_no_points", "talents_help", "skills_mods_open", "skills_away", "presets_away", "quests_away", "armor_help",
	"inventory_details_active", "journal_earlier", "hud_loot_feed", "hud_level_hero", "hud_level_mastery",
	"hud_telegraphs", "hud_telegraph_fight", "hud_husk_mix", "talents_tip_col3", "talents_tip_col1", "hud_level_mastery_dash", "hud_level_both",
	"pause", "save", "load", "options", "confirm"]

## Bag-full screen fillers and the "!" screen's hidden mara_welcome, undone by reset().
static var _fillers: Array[String] = []
static var _topped: Dictionary = {}
static var _welcome_hidden: bool = false
## The forge-with-stash screen's stash additions (item id -> quantity), undone by reset().
static var _stashed: Dictionary = {}
## Combat HUD UX 2.0 screens: undo steps run by reset() (class, flask, potion, quests, tracker state).
static var _restore: Array[Callable] = []


## The `count` items with the longest display names (loot rows at their widest).
static func longest_item_names(db: GameDatabase, count: int) -> Array[StringName]:
	var ids: Array = db.items.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var la := db.get_item(a).display_name.length()
		var lb := db.get_item(b).display_name.length()
		return la > lb or (la == lb and String(a) < String(b)))
	var result: Array[StringName] = []
	for item_id: StringName in ids.slice(0, count):
		result.append(item_id)
	return result


static func open(gallery: Object, screen: String) -> String:
	var map: GameMap = gallery.map
	var hud := map.hud
	var character: Character = gallery.session.character
	match screen:
		"hud":
			hud.show_hint("RMB: heavy attack. Bows: hold RMB for the Precision Stance.")
			hud.notify("Quest complete: The Broken Cart")
		"hud_combat", "hud_boss", "hud_death":
			var player := map.player
			player.global_position = Vector2(0, 60)
			var configs: Array = [load("res://data/enemies/hardened_husk.tres"), load("res://data/enemies/rootbound_husk.tres"), load("res://data/enemies/hollowfang_wolf.tres")]
			if screen == "hud_boss":
				configs = [load("res://data/enemies/grove_warden_config.tres")]
			var spawned: Array[Enemy] = []
			for index in configs.size():
				spawned.append(map.spawn_enemy(player.global_position + Vector2(-70 + 70 * index, -70), configs[index]))
			await gallery.frames(3)
			var hit := HitData.new()
			hit.damage = 40.0
			hit.poise_damage = 25.0
			spawned[0].hurtbox.receive_hit(hit)
			var shown := HitData.new()
			shown.target = spawned[0]
			hud.target_frame.on_player_hit(shown)
			map.bridge.class_runtime.apply_status(spawned[0], &"bleeding")
			map.bridge.class_runtime.add_buff(&"buff:battle_cry", 8.0, [] as Array[StatModifier])
			hud.loot_feed.push(&"storm_ore", 2)
			hud.loot_feed.push(&"stormcaller_fang", 1)
			player.health.apply_hit(_damage(120.0))
			if screen == "hud_death":
				player.health.apply_hit(_damage(9999.0))
			for enemy in spawned:
				enemy.set_physics_process(false)   # frozen for a stable screenshot
		"inventory":
			hud.toggle_inventory()
			var crafted := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"stormcaller_fang")
			if not crafted.is_empty():
				hud.inventory_panel.select_item((crafted[0] as ItemInstance).instance_id)
		"inventory_tooltip":
			hud.toggle_inventory()
			await gallery.frames(3)
			var blade := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"forged_blade")
			var cell := hud.inventory_panel.find_child("Item_%s" % (blade[0] as ItemInstance).instance_id, true, false) as ItemCell
			hud.inventory_panel._on_cell_hovered(cell)
		"character":
			hud.toggle_talents()
		"character_armor":   # leather and cloth worn, some mastery
			for item_id: StringName in [&"leather_cap", &"leather_gloves", &"worn_boots", &"linen_trousers"]:
				var added := character.inventory.add_item(item_id, 1)   # the gallery bag may be full
				if not added.is_empty():
					character.equipment.equip(added[0].instance_id)
			if character.armor_mastery.level(ItemDefinition.ArmorType.LEATHER) < 5:
				ArmorMasteryService.add_xp(character, 3000.0)
			hud.toggle_talents()
			hud.class_panel.show_page("Armor")
		"character_weapons":   # a few families levelled, the sword wielded
			for entry: Array in [[&"one_handed_sword", 900], [&"bow", 1600], [&"dagger", 250]]:
				if character.mastery.get_level(entry[0]) < 2:
					character.mastery.add_xp(entry[0], entry[1])
			hud.toggle_talents()
			hud.class_panel.show_page("Weapons")
		"classes", "talents", "skills", "presets":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, screen.capitalize())
		"talents_full":
			await _stand_at(gallery, map.get_node("ClassStation"))
			_spend_all_points(character)
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(4)
			_hover_talent(hud.class_panel, 0, TalentRules.TIERS)   # capstone of the first tree
		"talents_locked":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(4)
			_hover_talent(hud.class_panel, 2, 3, 3)   # third tree, right column: a locked node, chosen and hovered
		"talents_tip_col3", "talents_tip_col1":   # Playtest Corrections 1.0: tooltips of the 2nd column from the right / the left
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(4)
			_hover_talent(hud.class_panel, 1, 2, 2 if screen == "talents_tip_col3" else 0)
		"talents_arcanist", "talents_shadowrunner":
			# a separate character of that class (the gallery character stays as it is)
			var other := CharacterFactory.create_new(character.database)
			var class_id := StringName(screen.get_slice("_", 1))
			other.classes.unlock(class_id)
			other.switch_class(class_id, true)
			other.classes.add_xp(class_id, 40000)
			_spend_all_points(other)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Talents")
			# the second tree (partly learned) with its upgrade lines; its tier 3 upgrade chosen
			hud.class_panel.show_tree(TalentService.trees_of(other.database, class_id)[1].id)
			hud.class_panel.select_talent(&"arc_rm_grandrift" if class_id == &"arcanist" else &"sr_bs_returning")
		"skills_locked", "skills_arcanist", "skills_shadowrunner":
			# Skills & Talents UX 2.0 Phase 3 - a separate character (the gallery character stays as it is):
			# locked = a level 6 warrior (Q/E/R used, F empty) with the locked Whirlwind chosen; arcanist = level 50,
			# talents spent (Glyph Lore: a talent mod), Arcane Bolt chosen; shadowrunner = level 50, keyboard focus
			# on a list entry while Shadowstep is chosen.
			var class_id: StringName = {"skills_locked": &"warrior", "skills_arcanist": &"arcanist", "skills_shadowrunner": &"shadowrunner"}[screen]
			var other := CharacterFactory.create_new(character.database)
			other.classes.unlock(class_id)
			other.switch_class(class_id, true)
			if screen == "skills_locked":
				var definition := other.database.get_class_def(class_id)
				var xp := 0
				for level in range(1, 6):
					xp += definition.xp_to_next(level)
				other.classes.add_xp(class_id, xp)
			else:
				other.classes.add_xp(class_id, 40000)
				_spend_all_points(other)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Skills")
			await gallery.frames(3)
			hud.class_panel.select_skill({"skills_locked": &"whirlwind", "skills_arcanist": &"arcane_bolt", "skills_shadowrunner": &"shadowstep"}[screen])
			if screen == "skills_shadowrunner":
				var entry := hud.class_panel.find_child("Skill_expose_weakness", true, false) as Control
				if entry != null:
					entry.grab_focus()
		"presets_saved", "presets_invalid":
			# Skills & Talents UX 2.0 Phase 4 - a separate warrior (the gallery character stays as it is) with three
			# saved presets: 1 Berserker talents, 2 Warbreaker talents with a long name (the current build),
			# 3 = 2 with a vanished item reference. saved: preset 2 chosen (same talents, free); invalid: preset 3
			# chosen (missing item) - preset 1 would need the respec gold.
			var other := CharacterFactory.create_new(character.database)
			other.classes.unlock(&"warrior")
			other.switch_class(&"warrior", true)
			other.classes.add_xp(&"warrior", 4000)
			for node_id: StringName in [&"war_b_seething", &"war_b_seething", &"war_b_seething", &"war_b_seething", &"war_b_seething", &"war_b_whirlwind", &"war_b_cyclone"]:
				TalentService.learn(other, &"warrior", node_id)
			PresetService.save_preset(other, &"warrior", 0, "Berserker Whirl")
			TalentService.respec(other, &"warrior", true)
			for node_id: StringName in [&"war_wb_hands", &"war_wb_hands", &"war_wb_hands", &"war_wb_skin", &"war_wb_skin", &"war_wb_finish", &"war_wb_earthshaker"]:
				TalentService.learn(other, &"warrior", node_id)
			PresetService.save_preset(other, &"warrior", 1, "Warbreaker Juggernaut - Heavy Hands and Thick Skin for long boss fights")
			PresetService.save_preset(other, &"warrior", 2, "Old Haven Kit")
			var kit := PresetService.get_preset(other, &"warrior", 2)
			var refs: Dictionary = kit.get("equipment", {})
			if not refs.is_empty():
				refs[refs.keys()[0]] = "itm_vanished"   # the item of this reference no longer exists
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Presets")
			await gallery.frames(2)
			hud.class_panel.select_preset(1 if screen == "presets_saved" else 2)
		"quests_warrior", "quests_arcanist", "quests_shadowrunner":
			# Skills & Talents UX 2.0 Phase 5 - a separate character per class (the gallery character stays as it is):
			# warrior = prologue chose the warrior; Path of the Arcane active at 5/8, Path of Shadows available
			# (arcane chosen). arcanist = prologue chose the arcanist; Path of Steel ready to turn in (8/8, items in
			# the bag), Path of Shadows completed (chosen: Steel). shadowrunner = prologue not finished: every quest
			# locked (chosen: Shadows), keyboard focus on an entry.
			var class_id := StringName(screen.get_slice("_", 1))
			var other := CharacterFactory.create_new(character.database)
			other.classes.unlock(class_id)
			other.switch_class(class_id, true)
			if class_id != &"shadowrunner":
				other.prologue.chosen_class = class_id
				other.prologue.stage = PrologueState.Stage.COMPLETED
			var chosen := &"unlock_shadowrunner"
			if class_id == &"warrior":
				QuestService.start(other, &"unlock_arcanist")
				QuestService.record(other, TrialObjective.Kind.KILLS, &"grunt", 5.0)
				chosen = &"unlock_arcanist"
			elif class_id == &"arcanist":
				QuestService.start(other, &"unlock_warrior")
				QuestService.start(other, &"unlock_shadowrunner")
				QuestService.record(other, TrialObjective.Kind.KILLS, &"grunt", 8.0)
				other.inventory.add_item(&"hollow_essence", 6)
				other.inventory.add_item(&"gold_coin", 40)
				QuestService.turn_in(other, &"unlock_shadowrunner", true)
				chosen = &"unlock_warrior"
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Quests")
			await gallery.frames(2)
			hud.class_panel.select_quest(chosen)
			if class_id == &"shadowrunner":
				await gallery.frames(2)
				var entry := hud.class_panel.find_child("Quest_unlock_warrior", true, false) as Control
				if entry != null:
					entry.grab_focus()
		"classes_active", "classes_switch", "classes_blocked", "classes_shadowrunner":
			# Skills & Talents UX 2.0 Phase 6 - a separate character (the gallery character stays as it is): an active
			# warrior (level 12) with the arcanist unlocked (level 4), the shadowrunner locked. active = the warrior
			# chosen (A); switch = the arcanist chosen, switch possible (B, D, F); blocked = the same with a full bag
			# - the warrior's gear would not fit back (E); shadowrunner = the locked class chosen, keyboard focus on
			# the arcanist card (C).
			var other := CharacterFactory.create_new(character.database)
			for class_id: StringName in [&"warrior", &"arcanist"]:
				other.classes.unlock(class_id)
			other.switch_class(&"warrior", true)
			other.prologue.chosen_class = &"warrior"
			other.prologue.stage = PrologueState.Stage.COMPLETED
			other.classes.add_xp(&"warrior", 2500)
			other.classes.add_xp(&"arcanist", 400)
			if screen == "classes_blocked":
				# the arcanist wears nothing of its own: the warrior's gear would have to go back into the full bag
				other.equipment.apply_loadout(&"arcanist", {})
				while other.inventory.free_slots() > 0:
					other.inventory.add_item(&"worn_boots", 1, ItemInstance.ORIGIN_STARTING)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Classes")
			await gallery.frames(2)
			hud.class_panel.select_class({"classes_active": &"warrior", "classes_switch": &"arcanist", "classes_blocked": &"arcanist", "classes_shadowrunner": &"shadowrunner"}[screen])
			if screen == "classes_shadowrunner":
				await gallery.frames(2)
				var card := hud.class_panel.find_child("Class_arcanist", true, false) as Control
				if card != null:
					card.grab_focus()
		"classes_start":
			# Skills & Talents UX 2.0 Phase 7 - before the prologue choice the start class is still active: its card
			# is the one exception to "only the three classes" (a fresh character, the gallery character stays as it is)
			var fresh := CharacterFactory.create_new(character.database)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(fresh, map.get_node("ClassStation") as ClassStation, "Classes")
		"armor_none", "armor_mixed", "armor_mail":
			# Skills & Talents UX 2.0 Phase 7 - a separate warrior (the gallery character stays as it is):
			# none = no typed armour worn; mixed = leather cap, gloves and boots + linen trousers (leather mastery
			# mid-level, cloth low, chosen: leather); mail = the Warden mail set + leather gloves and boots, mail
			# mastered (20), the highest burden the item data allows (no plate items exist yet)
			var other := CharacterFactory.create_new(character.database)
			other.classes.unlock(&"warrior")
			other.switch_class(&"warrior", true)
			var armor_rules := ArmorMasteryService.rules(other)
			for slot: int in ArmorMasteryRules.SLOTS:
				if other.equipment.get_item(slot) != null:
					other.equipment.unequip(slot)
			var wear: Array = {"armor_none": [], "armor_mixed": [&"leather_cap", &"leather_gloves", &"linen_trousers", &"worn_boots"],
				"armor_mail": [&"warden_helm", &"warden_mail", &"warden_greaves", &"leather_gloves", &"worn_boots"]}[screen]
			for item_id: StringName in wear:
				var piece: ItemInstance = null
				for item in other.inventory.items():
					if item.definition_id == item_id:
						piece = item
				if piece == null:
					piece = other.inventory.add_item(item_id, 1, ItemInstance.ORIGIN_STARTING)[0]
				other.equipment.equip(piece.instance_id)
			if screen == "armor_mixed":
				other.armor_mastery.add_xp(ItemDefinition.ArmorType.LEATHER, 1400.0, armor_rules)
				other.armor_mastery.add_xp(ItemDefinition.ArmorType.CLOTH, 260.0, armor_rules)
			elif screen == "armor_mail":
				other.armor_mastery.add_xp(ItemDefinition.ArmorType.MAIL, 200000.0, armor_rules)
				other.armor_mastery.add_xp(ItemDefinition.ArmorType.LEATHER, 600.0, armor_rules)
			other.invalidate_stats()
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(other, map.get_node("ClassStation") as ClassStation, "Armor")
			await gallery.frames(2)
			hud.class_panel.select_armor_type(ItemDefinition.ArmorType.LEATHER if screen == "armor_mixed"
				else (ItemDefinition.ArmorType.MAIL if screen == "armor_mail" else ItemDefinition.ArmorType.CLOTH))
		"classes_locked":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Classes")
			hud.class_panel.select_class(&"arcanist")
		"forge", "forge_imprint", "forge_affixes", "forge_reforge", "forge_essences", "forge_sockets", "forge_quality", "forge_evolution", "forge_craft":
			var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
			await _stand_at(gallery, smithy)
			hud.open_crafting_panel(smithy)
			var panel := hud.crafting_panel
			var pick := func(item_id: StringName) -> void:
				var found := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == item_id)
				if not found.is_empty():
					panel.select_item((found[0] as ItemInstance).instance_id)
			match screen:
				"forge", "forge_imprint":
					pick.call(&"forged_greatsword")
					panel.select_operation(CraftingOps.IMPRINT)
					panel.choose_material(&"storm_ore")
				"forge_affixes":
					pick.call(&"forged_blade")
					panel.select_operation(CraftingOps.AUGMENT)
				"forge_reforge":
					pick.call(&"forged_blade")
					panel.select_operation(CraftingOps.REFORGE)
					panel.choose_affix(1)
				"forge_essences":
					pick.call(&"forged_blade")
					panel.select_operation(CraftingOps.ESSENCE_EXTRACT)
					panel.choose_slot(0)
				"forge_sockets":
					pick.call(&"forged_blade")
					panel.select_operation(CraftingOps.SOCKET_OPEN)
				"forge_quality":
					pick.call(&"forged_blade")
					panel.select_operation(CraftingOps.QUALITY)
				"forge_evolution":
					pick.call(&"stormcaller_fang")
					panel.select_operation(CraftingOps.EVOLVE)
				"forge_craft":
					panel.select_section("Craft")
		"recipes":
			await _stand_at(gallery, map.get_node("Ruins/OldSmithy"))
			hud.open_build_panel(map.get_node("Ruins/OldSmithy") as RuinSite)
		"recipes_stash":   # UI Usability & Haven Crafting 1.0: forge costs read bag + stash
			await _stand_at(gallery, map.get_node("Ruins/OldSmithy"))
			for item_id: StringName in [&"iron_ore", &"timber"]:
				character.stash.add_item(item_id, 5)
				_stashed[item_id] = int(_stashed.get(item_id, 0)) + 5
			hud.open_build_panel(map.get_node("Ruins/OldSmithy") as RuinSite)
		"restoration":
			await _stand_at(gallery, map.get_node("Ruins/OldStorehouse"))
			hud.open_restoration(map.get_node("Ruins/OldStorehouse") as RuinSite)
			await gallery.frames(3)
		"dialogue":
			var lines: Array[Dictionary] = [{"name": "Mara Veyne", "text": "There's a place north of here. Haven. Not much to look at, but it's got walls, a forge, and people who still give a damn.", "color": UiTheme.RESONANCE}]
			hud.open_lines(lines)
		"choice":
			hud.class_choice_panel.open(character, null)
		"waystones":
			await _stand_at(gallery, map.get_node("Waystone"))
			hud.open_waystones(map.get_node("Waystone") as Waystone)
		"journal":
			hud.toggle_journal()
		"journal_haven":
			hud.toggle_journal()
			hud.journal_panel.show_page("Haven")
		"map":
			hud.toggle_map()
		"map_region":
			hud.toggle_map()
			hud.world_map_panel.show_page("Region")
		"stash", "stash_materials":
			var store := map.get_node("Ruins/OldStorehouse") as RuinSite
			await _stand_at(gallery, store)
			_fill_stash(character)
			hud.open_stash(store)
			await gallery.frames(3)
			if screen == "stash_materials":
				hud.stash_panel.select_category(StashService.MATERIALS)
			else:
				var cells := hud.stash_panel.find_children("Stash_*", "ItemCell", true, false)
				if not cells.is_empty():
					hud.stash_panel._on_cell_hovered(cells[cells.size() - 1] as ItemCell)   # tooltip with comparison
		"stash_restored":
			var other := CharacterFactory.create_new(character.database)
			GameMap.give_debug_items(other)
			other.world.set_restoration(&"old_storehouse", &"restored")
			other.refresh_inventory_capacity()
			_fill_stash(other)
			var store := map.get_node("Ruins/OldStorehouse") as RuinSite
			await _stand_at(gallery, store)
			hud.close_windows()
			hud.stash_panel.open(other, store)
			hud.stash_panel.select_category(StashService.COLLECTION)
		"professions", "professions_locked", "professions_tooltip":
			var lodge := map.get_node("Ruins/TannersLodge") as RuinSite
			await _stand_at(gallery, lodge)
			if character.inventory.count(&"raw_hide") < 4:
				character.inventory.add_item(&"raw_hide", 6)
				character.inventory.add_item(&"flax_fiber", 4)
			lodge.interact(hud)
			await gallery.frames(3)
			if screen == "professions" and not character.professions.crafted_before(&"lw_tan_hide"):
				hud.professions_panel.craft_selected()   # real craft: XP bar and feedback shown
			if screen == "professions_locked":
				hud.professions_panel.select_recipe(&"lw_leather_bracers")
			if screen == "professions_tooltip":
				hud.professions_panel.select_recipe(&"lw_leather_gloves")
				await gallery.frames(3)
				var output := hud.professions_panel.find_child("Output", true, false) as Control
				if output != null:
					hud.professions_panel._show_item(output, &"leather_gloves", 1)
		"professions_salvage":   # a found cloak to salvage, a locked one, the Salvage page at the Weaver's House
			# Menu UX Polish 1.1: a separate character (the gallery bag may be full - the old add failed there)
			var house := map.get_node("Ruins/WeaversHouse") as RuinSite
			var other := CharacterFactory.create_new(character.database)
			other.inventory.add_item(&"traveler_cloak", 1, ItemInstance.ORIGIN_FOUND)
			var locked: ItemInstance = other.inventory.add_item(&"traveler_cloak", 1, ItemInstance.ORIGIN_CRAFTED)[0]
			ItemProtection.set_locked(other, locked.instance_id, true)
			await _stand_at(gallery, house)
			hud.professions_panel.open(other, &"weavers_house", house)
			hud.professions_panel.show_page("Salvage")
			await gallery.frames(3)
		"professions_alchemy", "professions_blacksmithing", "professions_tailoring", "professions_woodworking":
			# Menu UX Polish 1.1: every crafting profession in the one shared layout - looked at away from its workshop
			hud.toggle_professions()
			hud.professions_panel.show_page("Crafting")
			hud.professions_panel.select_profession(StringName(screen.get_slice("_", 1)))
		"hud_loot_feed":   # Loot & Progress Feedback 1.0: bundled ore, gold, profession XP, a Rare single item
			var feed := hud.loot_feed
			feed.push(&"iron_ore", 2)
			feed.push(&"iron_ore", 1)
			feed.push(&"gold_coin", 40)
			hud.bridge.profession_xp.emit(&"mining", 6)
			hud.bridge.profession_xp.emit(&"mining", 6)
			var rare := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"forged_blade")
			if not rare.is_empty():
				feed.push(&"forged_blade", 1, rare[0])
			feed.push(&"duskleaf", 3)
			await gallery.frames(12)   # past the fade-in
		"hud_level_hero", "hud_level_mastery":   # a real grant to the gallery character (session only, no save)
			if screen == "hud_level_hero":
				var class_id := character.classes.active_class_id
				var level := character.classes.get_level(class_id)
				var xp := 0
				for next in range(level, mini(level + 2, character.database.get_class_def(class_id).max_level)):
					xp += character.database.get_class_def(class_id).xp_to_next(next)
				character.classes.add_xp(class_id, xp)
			else:
				var family_id := &"mace_hammer" if character.database.weapons.has(&"mace_hammer") else &"axe"
				var track := character.database.get_track(family_id)
				character.mastery.add_xp(family_id, track.xp_to_next(character.mastery.get_level(family_id)))
			await gallery.frames(8)   # the pulse is about a third through
		"hud_telegraphs":
			# Combat Telegraphs 1.0: the three defense kinds frozen late in their windup, from the real attack data -
			# left a grunt swipe (parryable), right the Grove Warden swipe (block only), below the Warden slam (neither)
			var player := map.player
			player.global_position = Vector2(0, 40)
			var grunt_config: EnemyConfig = load("res://data/enemies/grunt_config.tres")
			var warden: WeaponFamily = load("res://data/enemies/grove_warden_attacks.tres")
			var plan := [[Vector2(-26, 0), 0, null], [Vector2(26, 0), 0, warden], [Vector2(0, 26), 1, warden]]
			var enemies: Array[Enemy] = []
			for entry: Array in plan:
				var config := grunt_config.duplicate() as EnemyConfig
				config.heavy_attack_interval = entry[1]   # 0 = light only, 1 = heavy every time (gallery copy only)
				config.max_health = 9999.0
				enemies.append(map.spawn_enemy(player.global_position + entry[0], config, entry[2]))
			var frozen := 0
			for i in 400:
				await gallery.frames(1)
				for enemy in enemies:
					if enemy.is_physics_processing() and enemy.state == Enemy.State.TELEGRAPH and enemy.combat.phase_progress() >= 0.75:
						enemy.set_physics_process(false)   # frozen for a stable screenshot
						frozen += 1
				if frozen == enemies.size():
					break
			player.health.health = player.health.max_health
			for enemy in enemies:
				_restore.append(func() -> void: if is_instance_valid(enemy): enemy.queue_free())
		"hud_husk_mix":
			# Hardened Husk Defense Mix 1.0: left the husk swipe (cross spark), right the husk slam (shield), below a
			# normal grunt slam for comparison (cross spark) - real configs, copies only force light / heavy
			var player := map.player
			player.global_position = Vector2(0, 40)
			var husk_config: EnemyConfig = load("res://data/enemies/hardened_husk.tres")
			var grunt_config: EnemyConfig = load("res://data/enemies/grunt_config.tres")
			var plan := [[Vector2(-28, 0), 0, husk_config], [Vector2(28, 0), 1, husk_config], [Vector2(0, 28), 1, grunt_config]]
			var enemies: Array[Enemy] = []
			for entry: Array in plan:
				var config := (entry[2] as EnemyConfig).duplicate() as EnemyConfig
				config.heavy_attack_interval = entry[1]
				config.max_health = 9999.0
				enemies.append(map.spawn_enemy(player.global_position + entry[0], config))
			var frozen := 0
			for i in 400:
				await gallery.frames(1)
				for enemy in enemies:
					if enemy.is_physics_processing() and enemy.state == Enemy.State.TELEGRAPH and enemy.combat.phase_progress() >= 0.75:
						enemy.set_physics_process(false)
						frozen += 1
				if frozen == enemies.size():
					break
			player.health.health = player.health.max_health
			for enemy in enemies:
				_restore.append(func() -> void: if is_instance_valid(enemy): enemy.queue_free())
		"hud_telegraph_fight":   # a short real fight with the present enemies (grunt, Hardened Husk, Hollowfang Wolf)
			var player := map.player
			player.global_position = Vector2(0, 40)
			var spawned: Array[Enemy] = []
			for entry: Array in [[Vector2(-40, -10), "res://data/enemies/grunt_config.tres"], [Vector2(40, -10), "res://data/enemies/hardened_husk.tres"], [Vector2(0, 50), "res://data/enemies/hollowfang_wolf.tres"]]:
				spawned.append(map.spawn_enemy(player.global_position + entry[0], load(entry[1])))
			for i in 240:
				await gallery.frames(1)
				if spawned.any(func(e: Enemy) -> bool: return e.state == Enemy.State.TELEGRAPH and e.combat.phase_progress() > 0.5):
					break
			for enemy in spawned:
				enemy.set_physics_process(false)
				_restore.append(func() -> void: if is_instance_valid(enemy): enemy.queue_free())
			player.health.health = player.health.max_health
		"hud_level_mastery_dash", "hud_level_both":   # the final diamond with a spent dash (and with a hero level at once)
			map.player.dash.charges = maxi(0, map.player.dash.charges - 1)
			var family_id := &"mace_hammer" if character.database.weapons.has(&"mace_hammer") else &"axe"
			character.mastery.add_xp(family_id, character.database.get_track(family_id).xp_to_next(character.mastery.get_level(family_id)))
			if screen == "hud_level_both":
				var class_id := character.classes.active_class_id
				character.classes.add_xp(class_id, character.database.get_class_def(class_id).xp_to_next(character.classes.get_level(class_id)))
				await gallery.frames(4)
			else:
				await gallery.frames(8)
		"professions_salvage_empty":   # Salvage of a profession with nothing in the bag to break down
			var empty := CharacterFactory.create_new(character.database)
			hud.professions_panel.open(empty)
			hud.professions_panel.show_page("Salvage")
			hud.professions_panel.select_profession(&"woodworking")
		"talents_no_points", "talents_help":
			# no free point: an untouched tree's tier 1 is "requirements met" (no padlock), tier 2 locked; help: the
			# "?" opened by keyboard focus (a separate warrior, the gallery character stays as it is)
			var spent := CharacterFactory.create_new(character.database)
			spent.classes.unlock(&"warrior")
			spent.switch_class(&"warrior", true)
			spent.classes.add_xp(&"warrior", 4000)
			_spend_all_points(spent)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(spent, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(3)
			var untouched := TalentService.trees_of(spent.database, &"warrior")[2]
			hud.class_panel.show_tree(untouched.id)
			hud.class_panel.select_talent(untouched.nodes[0].id)
			if screen == "talents_help":
				await gallery.frames(2)
				(hud.class_panel.find_child("TalentHelp", true, false) as Control).grab_focus()
		"skills_mods_open":   # the arcanist's Arcane Bolt with "All modifications" opened
			var mage := CharacterFactory.create_new(character.database)
			mage.classes.unlock(&"arcanist")
			mage.switch_class(&"arcanist", true)
			mage.classes.add_xp(&"arcanist", 40000)
			_spend_all_points(mage)
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(mage, map.get_node("ClassStation") as ClassStation, "Skills")
			await gallery.frames(3)
			hud.class_panel._show_all_mods = true
			hud.class_panel.select_skill(&"arcane_bolt")
		"skills_away", "presets_away", "quests_away":   # T away from a station: reading works, the actions say why not
			hud.toggle_talents()
			hud.class_panel.show_page(screen.get_slice("_", 0).capitalize())
		"armor_help":   # the burden help opened by keyboard focus
			hud.toggle_talents()
			hud.class_panel.show_page("Armor")
			await gallery.frames(3)
			(hud.class_panel.find_child("BurdenHelp", true, false) as Control).grab_focus()
		"inventory_details_active":
			# Playtest Corrections 1.0: Details shows only what is in effect - a short buff with a positive and a
			# negative bonus (gallery session only), the zero bonuses and empty groups hidden
			var bonus: Array[StatModifier] = [StatModifier.make(Stats.CRIT_CHANCE, 5.0), StatModifier.make(Stats.MOVE_SPEED, -10.0)]
			map.bridge.class_runtime.add_buff(&"buff:gallery_details", 30.0, bonus)
			_restore.append(func() -> void: character.clear_runtime_modifiers(&"buff:gallery_details"))
			hud.toggle_inventory()
			hud.inventory_panel.left_page = "Details"
			hud.inventory_panel.rebuild()
			_restore.append(func() -> void: hud.inventory_panel.left_page = "Equipment")
		"journal_earlier":
			hud.toggle_journal()
			hud.journal_panel.earlier_open = true
			hud.journal_panel.show_page("Main Story")
			_restore.append(func() -> void: hud.journal_panel.earlier_open = false)
		"professions_gathering":
			hud.toggle_professions()
			hud.professions_panel.show_page("Gathering")
			hud.professions_panel.select_profession(&"herbalism")
		"professions_smithy":
			var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
			await _stand_at(gallery, smithy)
			character.world.set_restoration(&"old_storehouse", &"restored")   # stash materials reach the bench
			if character.stash.count(&"iron_ore") == 0:
				character.stash.add_item(&"iron_ore", 6)
			hud.open_professions(&"old_smithy", smithy)
			hud.professions_panel.select_recipe(&"bs_smelt_iron")
		"hud_artisan_quarter":
			map.player.global_position = Vector2(-560, 0)
			await gallery.frames(12)   # the old station's prompt has left
		"hud_artisan_stages":   # Tanner's Lodge ruined, Weaver's House restored, the other two revitalized
			character.world.restoration.erase(&"tanners_lodge")
			character.world.set_restoration(&"tanners_lodge", RestorationService.RUINED)
			character.world.set_restoration(&"weavers_house", RestorationService.RESTORED)
			character.world.set_restoration(&"woodwrights_workshop", RestorationService.REVITALIZED)
			character.world.set_restoration(&"alchemists_cottage", RestorationService.REVITALIZED)
			map.player.global_position = Vector2(-560, 0)
			await gallery.frames(12)
		"inventory_overview", "inventory_details":   # Main Window Layout Lock 1.0: the character pages (C)
			hud.toggle_character()
			hud.inventory_panel._left_tabs.select("Overview" if screen == "inventory_overview" else "Details", true)
		"hud_notifications":   # HUD Notification Collision Fix 1.0: every feed row (long names) + "Progress saved"
			hud.loot_feed.push(&"iron_ore", 3)
			for item_id: StringName in longest_item_names(character.database, hud.loot_feed.max_rows - 1):
				hud.loot_feed.push(item_id, 1)
			hud.save_indicator.show_text("Progress saved", UiTheme.COLOR_ACCENT, 30.0)
		"hud_full", "hud_low", "hud_empty", "hud_arcanist", "hud_shadowrunner", "hud_basic", "hud_dash":
			await _combat_hud_state(gallery, screen)
		"hud_tracker_many", "hud_tracker_collapsed":   # Combat HUD UX 2.0: Journey with every kind of entry / collapsed
			for quest_id: StringName in [&"the_first_signs", &"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]:
				if character.quests.state(quest_id) != "active":
					var before: Variant = character.quests.entries.get(quest_id)
					_restore.append(func() -> void:
						if before == null:
							character.quests.entries.erase(quest_id)
						else:
							character.quests.entries[quest_id] = before)
					character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
			var extra: StoryQuestDefinition = character.database.story_quests[&"the_lost_hunter"].duplicate()
			extra.id = &"gallery_extra_side"
			character.database.story_quests[extra.id] = extra
			character.quests.entries[extra.id] = {"state": "active", "step": 1, "progress": {}}
			_restore.append(func() -> void:
				character.database.story_quests.erase(extra.id)
				character.quests.entries.erase(extra.id))
			if screen == "hud_tracker_collapsed":
				ObjectivePanel.collapsed = true
				_restore.append(func() -> void: ObjectivePanel.collapsed = false)
			await gallery.frames(4)
		"hud_consumables":   # one charge used, an Ember Draught running (15 s in), potion on cooldown
			character.consumables.charges = 1
			character.inventory.add_item(&"ember_draught", 3)
			ConsumableService.assign_potion(character, &"ember_draught")
			character.consumables.cooldown_left = 0.0
			ConsumableService.complete_potion(character)
			ConsumableService.step(character, 15.0)
			map.player.global_position = Vector2(60, 60)
			await gallery.frames(8)
		"flask_upgrades":
			if character.inventory.count(&"gold_coin") < 300:
				character.inventory.add_item(&"gold_coin", 300)
			var mara := map.get_node("Mara") as StoryNpc
			await _stand_at(gallery, mara)
			hud.open_npc_service(&"hearth_flask", mara)
			await gallery.frames(3)
		"quest_rewards", "quest_rewards_claimed", "quest_rewards_none":   # Edrin's window: pending / claimed / none
			_binding_reward(character, screen.trim_prefix("quest_rewards").trim_prefix("_"))
			var edrin := map.get_node("Edrin") as StoryNpc
			await _stand_at(gallery, edrin)
			hud.open_npc_service(&"quest_rewards", edrin)
			await gallery.frames(3)
		"hud_edrin_reward":   # "?" over Edrin: reward pending, no story talk
			_binding_reward(character, "")
			await _stand_at(gallery, map.get_node("Edrin") as StoryNpc)
		"hud_edrin_story":   # "!" over Edrin: The First Binding waits for his talk
			_binding_reward(character, "none")
			character.quests.entries[&"the_first_binding"] = {"state": "active", "step": 2, "progress": {}}
			character.world.flags.erase(&"dialogue.edrin_threat")
			await _stand_at(gallery, map.get_node("Edrin") as StoryNpc)
		"journal_reward":   # completed quest card with the pending reward line
			_binding_reward(character, "")
			hud.toggle_journal()
		# NPC Quest Turn-ins 1.1 M3: Mara's mixed reward (The Broken Cart, 30 Gold + 3 Timber + 2 Stone)
		"flask_quest_rewards":   # Hearth Flask window with the Quest Rewards button
			_cart_reward(character, "")
			var mara := map.get_node("Mara") as StoryNpc
			await _stand_at(gallery, mara)
			hud.open_npc_service(&"hearth_flask", mara)
			await gallery.frames(3)
		"mara_rewards", "mara_rewards_claimed", "mara_rewards_none", "mara_rewards_full":
			var state := screen.trim_prefix("mara_rewards").trim_prefix("_")
			_cart_reward(character, "" if state == "full" else state)
			if state == "full":   # no free slot, the kit's timber/stone stacks full: BAG_FULL
				while character.inventory.free_slots() > 0:
					_fillers.append(character.inventory.add_item(&"iron_sword", 1, ItemInstance.ORIGIN_FOUND)[0].instance_id)
				for item_id: StringName in [&"timber", &"stone"]:
					var room := character.inventory.room_for(item_id)   # stack room only (no free slot left)
					if room > 0 and not character.inventory.add_item(item_id, room).is_empty():
						_topped[item_id] = room
			var mara := map.get_node("Mara") as StoryNpc
			await _stand_at(gallery, mara)
			if state == "none":   # no button without a reward: the window itself, opened directly
				hud.open_npc_service(&"quest_rewards", mara)
			else:   # the player's way: Hearth Flask -> Quest Rewards
				hud.open_npc_service(&"hearth_flask", mara)
				await gallery.frames(2)
				hud.flask_panel.open_quest_rewards()
			await gallery.frames(3)
		"hud_mara_reward":   # "?" over Mara and the tracker hint "Collect your reward from Mara in Haven."
			_cart_reward(character, "")
			await _stand_at(gallery, map.get_node("Mara") as StoryNpc)
		"hud_both_rewards":   # both rewards pending: two tracker hints, "?" over Mara
			_cart_reward(character, "")
			_binding_reward(character, "")
			await _stand_at(gallery, map.get_node("Mara") as StoryNpc)
		"hud_mara_story":   # "!" over Mara: mara_welcome not heard yet, reward pending
			_cart_reward(character, "")
			character.quests.entries[&"shelter_among_the_trees"]["step"] = 1
			character.world.flags.erase(&"dialogue.mara_welcome")
			_welcome_hidden = true
			await _stand_at(gallery, map.get_node("Mara") as StoryNpc)
		"journal_cart_reward", "journal_cart_claimed":
			_cart_reward(character, "claimed" if screen.ends_with("claimed") else "")
			hud.toggle_journal()
		"restoration_revitalize":
			character.world.set_restoration(&"tanners_lodge", RestorationService.RESTORED)
			var lodge := map.get_node("Ruins/TannersLodge") as RuinSite
			await _stand_at(gallery, lodge)
			hud.open_restoration(lodge)
			await gallery.frames(3)
		"pause":
			hud.open_pause_menu()
		"save":
			hud.open_pause_menu()
			hud.pause_menu.show_page("save")
		"load":
			hud.open_pause_menu()
			hud.pause_menu.show_page("load")
		"options":
			hud.toggle_options()
		"confirm":
			hud.confirm_dialog.ask("Overwrite Slot 2?", "The saved journey in Slot 2 will be replaced by your current progress.", "Overwrite", Callable(), true)
		_:
			if hud.has_method(&"gallery_open"):
				return hud.call(&"gallery_open", screen)
			return ""
	return screen


## Clean state between screens: no enemies from the combat screens, the player
## alive again (otherwise stations would not open after "hud_death").
static func reset(gallery: Object) -> void:
	var map: GameMap = gallery.map
	var character: Character = gallery.session.character
	for instance_id: String in _fillers:   # the bag-full screen's swords
		character.inventory.remove_instance(instance_id)
	_fillers.clear()
	for item_id: StringName in _topped:
		character.inventory.remove_quantity(item_id, int(_topped[item_id]))
	_topped.clear()
	for item_id: StringName in _stashed:
		character.stash.remove_quantity(item_id, int(_stashed[item_id]))
	_stashed.clear()
	if _welcome_hidden:   # the "!" screen: mara_welcome heard again (Shelter Among the Trees, step 2)
		character.quests.entries[&"shelter_among_the_trees"]["step"] = 2
		character.world.set_flag(&"dialogue.mara_welcome")
		_welcome_hidden = false
	for undo: Callable in _restore:
		undo.call()
	_restore.clear()
	for enemy in map.find_children("*", "Enemy", true, false):
		enemy.queue_free()
	for i in 240:
		if not map.player.health.is_dead():
			break
		await gallery.frames(1)
	await gallery.frames(2)


## The First Binding completed, its 60 gold reward "" = pending, "claimed" or "none"
## (no entitlement, like a save from before the reward system).
static func _binding_reward(character: Character, state: String) -> void:
	character.quests.entries[&"the_first_binding"] = {"state": "completed", "step": 3, "progress": {}}
	character.world.set_flag(&"dialogue.edrin_threat")
	for flag in [QuestRewardService.entitled_flag(&"the_first_binding"), QuestRewardService.claimed_flag(&"the_first_binding")]:
		character.world.flags.erase(flag)
	if state != "none":
		character.world.set_flag(QuestRewardService.entitled_flag(&"the_first_binding"))
	if state == "claimed":
		character.world.set_flag(QuestRewardService.claimed_flag(&"the_first_binding"))


## The Broken Cart (completed live by the gallery character) with Mara's reward "" = pending,
## "claimed" or "none" (no entitlement, like a save from before M2).
static func _cart_reward(character: Character, state: String) -> void:
	for flag in [QuestRewardService.entitled_flag(&"the_broken_cart"), QuestRewardService.claimed_flag(&"the_broken_cart")]:
		character.world.flags.erase(flag)
	if state != "none":
		character.world.set_flag(QuestRewardService.entitled_flag(&"the_broken_cart"))
	if state == "claimed":
		character.world.set_flag(QuestRewardService.claimed_flag(&"the_broken_cart"))


## Puts the player into the interaction area of `node` (stations close their
## windows when the player walks away).
static func _stand_at(gallery: Object, node: Node2D) -> void:
	var map: GameMap = gallery.map
	map.player.global_position = node.global_position + Vector2(0, 20)
	map.player.reset_physics_interpolation()
	for i in 8:   # the station area sees the player only after physics steps
		await (gallery as SceneTree).physics_frame
	await gallery.frames(4)


static func _damage(amount: float) -> HitData:
	var hit := HitData.new()
	hit.damage = amount
	return hit


## Spends every free talent point of the active class through TalentService
## (tree by tree, lowest tier first), so the trees show a complete build.
static func _spend_all_points(character: Character) -> void:
	var class_id := character.classes.active_class_id
	var nodes: Array = []
	for tree in TalentService.trees_of(character.database, class_id):
		var ordered: Array = tree.nodes.duplicate()
		ordered.sort_custom(func(a: TalentNodeDefinition, b: TalentNodeDefinition) -> bool: return a.tier < b.tier)
		nodes.append_array(ordered)   # one tree after the other: the first reaches its capstone
	var learned := true
	while learned and TalentService.points_available(character, class_id) > 0:
		learned = false
		for node: TalentNodeDefinition in nodes:
			if TalentService.learn(character, class_id, node.id) == "":
				learned = true
				break


## Shows tree `tree_index` (Skills & Talents UX 2.0 Phase 2: one tree at a time), chooses its node in `tier`
## (and data `column`, unless the tier has one node) and shows its tooltip - as a click and a hover would.
static func _hover_talent(panel: ClassStationPanel, tree_index: int, tier: int, column: int = 0) -> void:
	var trees := TalentService.trees_of(panel.character.database, panel.character.classes.active_class_id)
	panel.show_tree(trees[tree_index].id)
	var view: TalentTreeView = panel._trees[0]
	for node in view.tree.nodes:
		if node.tier == tier and (node.column == column or view.tree.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == tier).size() == 1):
			panel.select_talent(node.id)
			panel._on_talent_hovered(node.id, view)
			return


## A few things in the stash (through StashService, as the player would):
## spare weapons, a unique, a set piece and materials. Forge items stay in the bag.
static func _fill_stash(character: Character) -> void:
	if not character.stash.items().is_empty():
		return
	for item in character.inventory.items():
		if item.definition_id in [&"militia_sword", &"iron_greatsword", &"crushing_oath", &"warden_helm", &"leather_cap"] \
				and not character.equipment.is_referenced(item.instance_id):
			StashService.deposit(character, item.instance_id)
	character.inventory.add_item(&"iron_ore", 20)
	StashService.deposit_all_materials(character)


## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): the combat unit in one state - "hud_full" (all full, the
## potion stack full), "hud_low" (low health / resource, one flask charge, one potion on cooldown, a skill on
## cooldown, a dash spent), "hud_empty" (1 health, no resource, flask and potion empty), one per other class
## ("hud_arcanist", "hud_shadowrunner", "hud_basic": no resource) and "hud_dash" (both charges spent). Every
## change is undone by reset().
static func _combat_hud_state(gallery: Object, screen: String) -> void:
	var map: GameMap = gallery.map
	var character: Character = gallery.session.character
	var player := map.player
	var state := character.consumables
	var old_class := character.classes.active_class_id
	var old_charges := state.charges
	var old_potion := state.potion_slot
	var old_count := character.inventory.count(&"ember_draught")
	_restore.append(func() -> void:
		character.classes.set_active(old_class)
		state.charges = old_charges
		state.cooldown_left = 0.0
		state.potion_slot = old_potion
		var now := character.inventory.count(&"ember_draught")
		if now > old_count:
			character.inventory.remove_quantity(&"ember_draught", now - old_count)
		elif now < old_count:
			character.inventory.add_item(&"ember_draught", old_count - now)
		if is_instance_valid(player):   # a new pass may have loaded a new map meanwhile
			player.health.heal(player.health.max_health)
		state.changed.emit())
	player.global_position = Vector2(60, 60)
	var class_id: StringName = {"hud_arcanist": &"arcanist", "hud_shadowrunner": &"shadowrunner", "hud_basic": &"basic_adventurer"}.get(screen, old_class)
	character.classes.unlock(class_id)
	character.classes.set_active(class_id)
	await gallery.frames(3)
	var pool := map.bridge.resource_pool
	var full := ConsumableService.max_charges(character)
	var stack := character.database.get_item(&"ember_draught").max_stack
	ConsumableService.assign_potion(character, &"ember_draught")
	var potions: int = {"hud_full": stack, "hud_low": 1, "hud_empty": 0}.get(screen, 3)
	var have := character.inventory.count(&"ember_draught")
	if have < potions:
		character.inventory.add_item(&"ember_draught", potions - have)
	elif have > potions:
		character.inventory.remove_quantity(&"ember_draught", have - potions)
	state.charges = {"hud_full": full, "hud_low": 1, "hud_empty": 0}.get(screen, maxi(1, full - 1))
	state.cooldown_left = 14.0 if screen == "hud_low" else 0.0
	var health_share: float = {"hud_full": 1.0, "hud_low": 0.18, "hud_empty": 0.0}.get(screen, 0.7)
	player.health.health = maxf(1.0, player.health.max_health * health_share)
	if pool != null:
		pool.value = pool.max_value() * float({"hud_full": 1.0, "hud_low": 0.1, "hud_empty": 0.0}.get(screen, 0.55))
	var runtime := map.bridge.class_runtime
	var skill := runtime.skill_in_slot(1)
	if screen == "hud_low" and skill != null:
		runtime.cooldowns[skill.id] = runtime.time + runtime.params_for(skill).cooldown * 0.6
	if screen in ["hud_low", "hud_dash"]:
		player.dash.try_start(Vector2.RIGHT)
		await gallery.frames(2)
		if screen == "hud_dash":
			await gallery.frames(20)
			player.dash.try_start(Vector2.LEFT)
		for i in 24:   # the dash is over, the charge is recharging
			await gallery.frames(1)
	state.changed.emit()
	await gallery.frames(4)
