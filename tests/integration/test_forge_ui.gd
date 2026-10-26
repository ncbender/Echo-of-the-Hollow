extends TestCase
## UI/UX redesign C: Resonance Forge 2.0 - seven sections in one window, the
## window only presents CraftingService (chances are the service's pool, the
## reforge replaces exactly the shown affix, costs and limits come from the
## service), quality before/after values, smithing recipes inside the forge.

var session: SessionState
var map: GameMap
var character: Character
var panel: CraftingPanel
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	GameMap.give_crafting_kit(character)
	character.world.set_restoration(&"old_smithy", &"restored")
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
	map.player.global_position = smithy.global_position + Vector2(0, 26)
	for i in 4:
		await get_tree().physics_frame
	smithy.interact(map.hud)
	panel = map.hud.crafting_panel
	panel.rng.seed = 11


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _item(item_id: StringName) -> ItemInstance:
	return character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == item_id)[0]


func test_sections_and_tabs() -> void:
	check(panel.visible, "forge open at the restored smithy")
	for id in CraftingPanel.SECTIONS:
		check(panel.find_child("Tab%s" % id, true, false) != null, "section tab %s" % id)
	check_eq(CraftingPanel.section_of(CraftingOps.REFORGE), "Affixes", "reforge lives in Affixes")
	check_eq(CraftingPanel.section_of(CraftingOps.SOCKET_REMOVE), "Sockets", "socket ops in Sockets")
	panel.select_item(_item(&"forged_blade").instance_id)
	panel.select_section("Evolution")
	check((panel.find_child("Confirm", true, false) as Button).disabled, "blade cannot evolve: no action")
	check(not map.hud.build_panel.visible, "no second window")


func test_chances_come_from_the_service_and_reforge_replaces_the_shown_affix() -> void:
	var blade := _item(&"forged_blade")
	panel.select_item(blade.instance_id)
	panel.select_operation(CraftingOps.IMPRINT)
	panel.choose_material(&"storm_ore")
	var shown := panel.current_preview()
	var service := CraftingService.preview(character, panel.current_request())
	check_eq(AffixPool.by_affix(shown.outcomes), AffixPool.by_affix(service.outcomes), "same pool as the service")
	var total := 0.0
	for entry in shown.outcomes:
		total += entry.probability
	check(is_equal_approx(total, 1.0), "chances add up to 100 %")
	check(panel.confirm().ok, "imprinted")
	panel.select_operation(CraftingOps.AUGMENT)
	check(panel.confirm().ok, "augmented")
	var before := blade.affixes.duplicate(true)
	panel.select_operation(CraftingOps.REFORGE)
	panel.choose_affix(0)
	check(ItemDescriber.affix_text(character.database, before[0]) in _texts(panel), "the affix to be replaced is shown")
	check(panel.confirm().ok, "reforged")
	check_eq(blade.affixes.size(), before.size(), "no extra affix slot")
	check_eq(blade.affixes[1], before[1], "the other affix is untouched")


func test_costs_and_missing_materials_block_the_action() -> void:
	var blade := _item(&"forged_blade")
	panel.select_item(blade.instance_id)
	panel.select_operation(CraftingOps.QUALITY)
	check(not (panel.find_child("Confirm", true, false) as Button).disabled, "quality possible with crystals")
	character.inventory.remove_quantity(&"forge_crystal", character.inventory.count(&"forge_crystal"))
	panel.rebuild()
	check((panel.find_child("Confirm", true, false) as Button).disabled, "no crystal: no action")
	check(" ".join(_texts(panel)).contains("(missing)"), "missing cost marked in words")


func test_quality_before_after() -> void:
	panel.select_item(_item(&"forged_blade").instance_id)
	panel.select_operation(CraftingOps.QUALITY)
	check(" ".join(_texts(panel)).contains("->"), "before -> after values shown")


func test_smithing_recipes_inside_the_forge() -> void:
	panel.select_section("Craft")
	var swords := character.inventory.count(&"iron_sword")
	var button := panel.find_child("Craft_forge_iron_sword", true, false) as Button
	check(button != null and not button.disabled, "recipe available")
	button.pressed.emit()
	check_eq(character.inventory.count(&"iron_sword"), swords + 1, "crafted through BaseBuilder")


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text)
	for button: Button in node.find_children("*", "Button", true, false):
		texts.append(button.text)
	return texts
