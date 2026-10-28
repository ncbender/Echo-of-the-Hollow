class_name GalleryScreens
extends RefCounted
## The screens of the UI gallery (tests/playtest/ui_gallery.gd) and how to open
## each one with real data. Returns the screen label, or "" when skipped.

const ALL := ["title", "hud", "hud_combat", "hud_boss", "hud_death", "inventory", "inventory_tooltip", "character", "character_armor", "character_weapons", "classes", "classes_locked", "talents", "talents_full", "talents_locked", "talents_arcanist", "talents_shadowrunner", "skills", "presets", "forge_imprint",
	"forge_affixes", "forge_reforge", "forge_essences", "forge_sockets", "forge_quality", "forge_evolution", "forge_craft",
	"recipes", "restoration", "dialogue", "choice", "waystones", "journal", "journal_haven", "map", "stash", "stash_materials", "stash_restored",
	"professions", "professions_locked", "professions_tooltip", "professions_salvage", "professions_gathering", "professions_smithy", "hud_artisan_quarter",
	"hud_artisan_stages", "restoration_revitalize", "hud_consumables", "flask_upgrades", "quest_rewards",
	"quest_rewards_claimed", "quest_rewards_none", "hud_edrin_reward", "hud_edrin_story", "journal_reward",
	"pause", "save", "load", "options", "confirm"]


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
			hud.toggle_character()
		"character_armor":   # leather and cloth worn, some mastery
			for item_id: StringName in [&"leather_cap", &"leather_gloves", &"worn_boots", &"linen_trousers"]:
				var added := character.inventory.add_item(item_id, 1)   # the gallery bag may be full
				if not added.is_empty():
					character.equipment.equip(added[0].instance_id)
			if character.armor_mastery.level(ItemDefinition.ArmorType.LEATHER) < 5:
				ArmorMasteryService.add_xp(character, 3000.0)
			hud.toggle_character()
			hud.class_panel.show_page("Armor")
		"character_weapons":   # a few families levelled, the sword wielded
			for entry: Array in [[&"one_handed_sword", 900], [&"bow", 1600], [&"dagger", 250]]:
				if character.mastery.get_level(entry[0]) < 2:
					character.mastery.add_xp(entry[0], entry[1])
			hud.toggle_character()
			hud.class_panel.show_page("Weapons")
		"classes", "talents", "skills", "presets":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, screen.capitalize())
		"talents_full":
			await _stand_at(gallery, map.get_node("ClassStation"))
			_spend_all_points(character)
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(4)
			_hover_talent(hud.class_panel, 0, 7)   # capstone of the first tree
		"talents_locked":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, "Talents")
			await gallery.frames(4)
			_hover_talent(hud.class_panel, 2, 6, 1)   # right-most tree, right column: tooltip at the right edge
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
			var house := map.get_node("Ruins/WeaversHouse") as RuinSite
			if character.inventory.count(&"traveler_cloak") < 2:
				character.inventory.add_item(&"traveler_cloak", 1, ItemInstance.ORIGIN_FOUND)
				var locked: ItemInstance = character.inventory.add_item(&"traveler_cloak", 1, ItemInstance.ORIGIN_CRAFTED)[0]
				ItemProtection.set_locked(character, locked.instance_id, true)
			await _stand_at(gallery, house)
			house.interact(hud)
			hud.professions_panel.show_page("Salvage")
			await gallery.frames(3)
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


## Shows the talent tooltip of the node in tree `tree_index`, `tier` (and
## `column`, if that tier has two) - as a hover would.
static func _hover_talent(panel: ClassStationPanel, tree_index: int, tier: int, column: int = 0) -> void:
	var view: TalentTreeView = panel._trees[tree_index]
	for node in view.tree.nodes:
		if node.tier == tier and (node.column == column or view.tree.nodes.filter(func(n: TalentNodeDefinition) -> bool: return n.tier == tier).size() == 1):
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
