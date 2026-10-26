class_name GalleryScreens
extends RefCounted
## The screens of the UI gallery (tests/playtest/ui_gallery.gd) and how to open
## each one with real data. Returns the screen label, or "" when skipped.

const ALL := ["title", "hud", "inventory", "character", "classes", "talents", "skills", "presets", "forge_imprint",
	"forge_affixes", "forge_reforge", "forge_essences", "forge_sockets", "forge_quality", "forge_evolution", "forge_craft",
	"recipes", "restoration", "dialogue", "choice", "waystones", "pause", "save", "load", "options", "confirm"]


static func open(gallery: Object, screen: String) -> String:
	var map: GameMap = gallery.map
	var hud := map.hud
	var character: Character = gallery.session.character
	match screen:
		"hud":
			hud.show_hint("Hold RMB to charge a heavy attack. Release to strike.")
			hud.notify("Picked up Iron Ore x2")
		"inventory":
			hud.toggle_inventory()
			var crafted := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"stormcaller_fang")
			if not crafted.is_empty():
				hud.inventory_panel.select_item((crafted[0] as ItemInstance).instance_id)
		"character":
			hud.toggle_character()
		"classes", "talents", "skills", "presets":
			await _stand_at(gallery, map.get_node("ClassStation"))
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, screen.capitalize())
		"forge", "forge_imprint", "forge_affixes", "forge_reforge", "forge_essences", "forge_sockets", "forge_quality", "forge_evolution", "forge_craft":
			var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
			map.player.global_position = smithy.global_position + Vector2(0, 26)
			await gallery.frames(6)
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
		"dialogue":
			var lines: Array[Dictionary] = [{"name": "Mara Veyne", "text": "There's a place north of here. Haven. Not much to look at, but it's got walls, a forge, and people who still give a damn.", "color": UiTheme.RESONANCE}]
			hud.open_lines(lines)
		"choice":
			hud.class_choice_panel.open(character, null)
		"waystones":
			await _stand_at(gallery, map.get_node("Waystone"))
			hud.open_waystones(map.get_node("Waystone") as Waystone)
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


## Puts the player into the interaction area of `node` (stations close their
## windows when the player walks away).
static func _stand_at(gallery: Object, node: Node2D) -> void:
	var map: GameMap = gallery.map
	map.player.global_position = node.global_position + Vector2(0, 20)
	map.player.reset_physics_interpolation()
	await gallery.frames(6)
