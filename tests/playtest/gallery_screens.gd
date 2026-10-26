class_name GalleryScreens
extends RefCounted
## The screens of the UI gallery (tests/playtest/ui_gallery.gd) and how to open
## each one with real data. Returns the screen label, or "" when skipped.

const ALL := ["title", "hud", "inventory", "character", "classes", "talents", "skills", "presets", "forge",
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
		"character":
			hud.toggle_character()
		"classes", "talents", "skills", "presets":
			hud.class_panel.open(character, map.get_node("ClassStation") as ClassStation, screen.capitalize())
		"forge":
			var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
			hud.open_crafting_panel(smithy)
			var blade := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"forged_blade")
			if not blade.is_empty():
				hud.crafting_panel.select_item((blade[0] as ItemInstance).instance_id)
				hud.crafting_panel.select_operation(CraftingOps.IMPRINT)
				hud.crafting_panel.choose_material(&"storm_ore")
		"recipes":
			hud.open_build_panel(map.get_node("Ruins/OldSmithy") as RuinSite)
		"restoration":
			hud.open_restoration(map.get_node("Ruins/OldStorehouse") as RuinSite)
		"dialogue":
			var lines: Array[Dictionary] = [{"name": "Mara Veyne", "text": "There's a place north of here. Haven. Not much to look at, but it's got walls, a forge, and people who still give a damn.", "color": UiTheme.RESONANCE}]
			hud.open_lines(lines)
		"choice":
			hud.class_choice_panel.open(character, null)
		"waystones":
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
