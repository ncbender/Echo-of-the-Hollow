extends TestCase
## Crafting vertical slice end to end (headless, real scenes, real combat):
## base -> smithy -> Resonance Forge UI (imprint, augment, reforge, two essences,
## socket + rune, quality) -> equip -> arena fight (discharge, rune) -> save ->
## load -> the same item instance with the same properties.

const TEST_SAVE := "user://test_saves/crafting_loop.save.json"
const S := EquipSlot.Slot

var session: SessionState
var _previous_character: Character
var _previous_path: String
var f := InputFrame.new()


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = TEST_SAVE
	session.set_character(CharacterFactory.create_new(session.database))


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_SAVE + suffix):
			DirAccess.remove_absolute(TEST_SAVE + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


func _await_map(map_id: StringName, limit: int = 300) -> GameMap:
	for i in limit:
		await get_tree().process_frame
		var map := get_tree().current_scene as GameMap
		if map != null and map.map_id == map_id and map.is_node_ready() and not session.is_traveling():
			f = InputFrame.new()
			map.player.feed_input(f)
			await get_tree().physics_frame
			return map
	fail("map %s not reached" % map_id)
	return null


func _confirm(panel: CraftingPanel, label: String) -> CraftingService.Result:
	var preview := panel.current_preview()
	check(preview != null and preview.ok(), "%s preview ok: %s" % [label, preview.reason() if preview else "none"])
	var result := panel.confirm()
	check(result != null and result.ok, "%s executed: %s" % [label, result.error if result else "no result"])
	return result


func test_crafting_vertical_slice() -> void:
	var character := session.character
	character.inventory.add_item(&"timber", 6)
	character.inventory.add_item(&"stone", 4)
	character.inventory.add_item(&"iron_ore", 3)
	check(GameMap.give_crafting_kit(character) >= 15, "F4 crafting kit")
	get_tree().change_scene_to_file("res://scenes/maps/home_base.tscn")
	var home := await _await_map(&"home_base")
	if home == null:
		return
	# the restored Old Smithy, then interact (G) -> Resonance Forge
	var plot := home.get_node("Ruins/OldSmithy") as RuinSite
	character.world.set_restoration(&"old_smithy", &"restored")   # the prologue rekindled it
	plot.refresh()
	home.player.global_position = plot.global_position + Vector2(0, 26)
	for i in 4:
		await get_tree().physics_frame
	check(plot.player_inside, "player at the smithy")
	plot.interact(home.hud)
	var panel := home.hud.crafting_panel
	check(panel.visible, "Resonance Forge opened by interacting with the smithy")
	panel.rng.seed = 2024
	var blade := character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"forged_blade")[0] as ItemInstance
	var blade_id := blade.instance_id
	panel.select_item(blade_id)
	# imprint with Storm Ore (probabilities shown = engine pool)
	panel.select_operation(CraftingOps.IMPRINT)
	panel.choose_material(&"storm_ore")
	var shown := AffixPool.by_affix(panel.current_preview().outcomes)
	var engine := AffixPool.by_affix(AffixPool.compute(blade, session.database.get_item(&"forged_blade"), session.database.materials[&"storm_ore"], session.database))
	check_eq(shown, engine, "UI shows the engine's exact probabilities")
	_confirm(panel, "imprint")
	panel.select_operation(CraftingOps.AUGMENT)
	_confirm(panel, "augment")
	var before_reforge := blade.affixes[0].duplicate()
	panel.select_operation(CraftingOps.REFORGE)
	panel.choose_affix(0)
	var reforged := _confirm(panel, "reforge")
	if reforged != null and reforged.ok:
		check_eq(blade.affixes[0], reforged.rolled, "reforge replaced affix 0 immediately")
	check(blade.affixes[0] != before_reforge or reforged.rolled == before_reforge, "no keep-or-discard step")
	for essence_id: StringName in [&"storm_wolf", &"stone_golem"]:
		panel.select_operation(CraftingOps.ESSENCE_INSERT)
		panel.choose_essence(essence_id)
		_confirm(panel, "bind %s" % essence_id)
	panel.select_operation(CraftingOps.SOCKET_OPEN)
	_confirm(panel, "open socket")
	panel.select_operation(CraftingOps.SOCKET_INSERT)
	panel.choose_socketable(&"impact_rune")
	_confirm(panel, "insert rune")
	for i in 3:
		panel.select_operation(CraftingOps.QUALITY)
		_confirm(panel, "quality %d" % (i + 1))
	check_eq(blade.essences.size(), 2, "two essences")
	check_eq(blade.sockets, [&"impact_rune"] as Array[StringName], "rune socketed")
	check_eq(blade.quality, 3, "quality 3")
	check_eq(character.inventory.find(blade_id), blade, "still the same instance")
	home.hud.close_windows()
	check_eq(character.equipment.equip(blade_id, S.MAIN_HAND), "", "equip the crafted blade")
	check(home.bridge.effects.has_effect(&"thunder_quake"), "resonance active on the player")
	# fight in the arena: heavy finisher -> discharge
	session.travel(&"test_arena", &"from_home", false)
	var arena := await _await_map(&"test_arena")
	if arena == null:
		return
	var enemy: Enemy = arena.call(&"spawn_enemy", arena.player.global_position + Vector2(26, 0))
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	enemy.health.max_health = 100000.0
	enemy.health.reset()
	var heavy_tags := []
	arena.player.combat.hit_landed.connect(func(hit: HitData) -> void:
		if hit.attack != null and hit.attack.id == &"sword_llh_crush":
			heavy_tags.append_array(hit.tags))
	for i in 3:
		await get_tree().physics_frame
	f.aim_direction = Vector2.RIGHT
	for step: String in ["L", "L", "H"]:
		if step == "L":
			f.light_pressed = true
		else:
			f.heavy_pressed = true
		for t in 14:
			await get_tree().physics_frame
	for t in 50:
		await get_tree().physics_frame
	var discharges: int = arena.bridge.effects.shared_state(&"storm_wolf_discharge").get("triggers", 0)
	check(discharges >= 1, "storm wolf discharge in the arena fight (%d)" % discharges)
	check(&"impact_rune" in heavy_tags, "rune modified the heavy finisher")
	# save -> load -> same instance, same properties
	var expected := character.inventory.find(blade_id).to_dict()
	check_eq(session.save_game(), OK, "saved")
	session.set_character(CharacterFactory.create_new(session.database))
	check(session.load_game().ok(), "loaded")
	var reloaded := await _await_map(&"test_arena")
	if reloaded == null:
		return
	var loaded_blade := session.character.inventory.find(blade_id)
	check(loaded_blade != null, "same instance id after load")
	if loaded_blade != null:
		check_eq(loaded_blade.to_dict(), expected, "identical crafted properties after load")
	check_eq(session.character.equipment.get_item(S.MAIN_HAND), loaded_blade, "still equipped")
	check(reloaded.bridge.effects.has_effect(&"thunder_quake"), "effects rebuilt after load")
	check(session.character.inventory.integrity_errors().is_empty(), "no duplication")
