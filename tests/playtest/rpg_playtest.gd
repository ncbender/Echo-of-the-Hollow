extends SceneTree
## Scripted RPG integration playtest in the real arena (NOT headless).
## Drives the player via feed_input() and the UI via real InputEventActions and
## button presses; saves screenshots + log to tests/output/. Run:
##   godot --path . --fixed-fps 60 -s res://tests/playtest/rpg_playtest.gd

const ARENA := "res://scenes/arena/test_arena.tscn"
const OUTPUT := "res://tests/output"

var arena: Node2D
var player: Player
var hud: GameHud
var session: SessionState
var f := InputFrame.new()
var log_lines: PackedStringArray = []
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.set_character(CharacterFactory.create_new(session.database))
	await _load_arena()
	await _class_station_flow()
	await _pickup_and_inventory_flow()
	_log("RESULT: %s (%d failed checks)" % ["OK" if failures == 0 else "FAILED", failures])
	var file := FileAccess.open(OUTPUT.path_join("rpg_playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _load_arena() -> void:
	if arena != null:
		arena.queue_free()
		await process_frame
	arena = load(ARENA).instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	hud = arena.get_node("GameHud")
	player.feed_input(f)
	await _ticks(5)


func _class_station_flow() -> void:
	var station: Node2D = arena.get_node("ClassStation")
	await _walk_to(station.global_position)
	_check(Interactable.find_active(self) == station, "standing in class station")
	await _press(&"interact")
	_check(hud.class_panel.visible, "class panel opened with G")
	await _shot("r01_class_panel")
	_click_button(hud.class_panel, "Unlock (debug)")
	await _ticks(2)
	_check(session.character.classes.is_unlocked(&"warrior"), "warrior unlocked via panel")
	_click_button(hud.class_panel, "Activate")
	await _ticks(2)
	_check(session.character.classes.active_class_id == &"warrior", "warrior active")
	_check(is_equal_approx(player.health.max_health, session.character.get_stat(Stats.MAX_HEALTH)) and player.health.max_health > 120.0, "warrior health (class + inherited gear) applied to player")
	await _shot("r02_warrior_active")
	await _press(&"interact")
	_check(not hud.class_panel.visible, "panel closed with G")


func _pickup_and_inventory_flow() -> void:
	var inventory := session.character.inventory
	var before := inventory.used_slots()
	for pickup_name in ["PickupMilitiaSword", "PickupOakShield", "PickupCopperRing"]:
		var pickup := arena.get_node_or_null(pickup_name) as Node2D
		if pickup != null:
			await _walk_to(pickup.global_position)
	_check(inventory.count(&"militia_sword") == 1 and inventory.count(&"oak_shield") == 1 and inventory.count(&"copper_ring") == 1, "three pickups collected")
	_check(inventory.used_slots() == before + 3, "exactly three new slots used")
	await _press(&"ui_inventory")
	_check(hud.inventory_panel.visible, "inventory opened with I")
	await _shot("r03_inventory")
	await _equipment_flow()
	await _legendary_flow()


func _equipment_flow() -> void:
	var character := session.character
	var panel := hud.inventory_panel
	var shield := _instance_of(&"oak_shield")
	panel._select(shield)
	_click_button(panel, "Equip")
	_check(character.equipment.get_item(EquipSlot.Slot.OFF_HAND) != null, "warrior equipped the shield via UI")
	var armor_with_shield := character.get_stat(Stats.ARMOR)
	panel._select(_instance_of(&"steel_greatsword"))
	_click_button(panel, "Equip")
	await _ticks(3)
	_check(character.equipment.get_item(EquipSlot.Slot.OFF_HAND) == null, "greatsword displaced the shield")
	_check(character.inventory.has(shield), "shield still in the inventory")
	_check(player.combat.weapon.id == &"two_handed_sword", "combat weapon is now the greatsword")
	_check(character.get_stat(Stats.ARMOR) < armor_with_shield, "shield armor removed")
	await _shot("r04_equipment")
	await _press(&"ui_inventory")
	_check(not panel.visible, "inventory closed with I")


func _legendary_flow() -> void:
	var character := session.character
	var blade := character.inventory.add_item(&"echo_blade")[0]
	_check(character.equipment.equip(blade.instance_id) == "", "echo blade equipped")
	await _ticks(3)
	var extra: Node2D = load("res://scenes/dummy/training_dummy.tscn").instantiate()
	var dummy_a: Node2D = arena.get_node("Dummies/DummyA")
	extra.position = dummy_a.position + Vector2(10, 34)
	arena.get_node("Dummies").add_child(extra)
	await _walk_to(dummy_a.global_position + Vector2(-26, 0))
	var bridge: PlayerProgressionBridge = player.get_node("ProgressionBridge")
	f.aim_direction = Vector2.RIGHT
	for i in 2:
		f.light_pressed = true
		await _ticks(14)
	f.heavy_pressed = true
	var shot_taken := false
	for i in 40:
		await _ticks(1)
		if not shot_taken and not arena.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/fx/shockwave_fx.gd")).is_empty():
			await _shot("r05_echo_shockwave")
			shot_taken = true
	_check(shot_taken, "shockwave visual spawned")
	_check((extra.get(&"hits_taken") as int) >= 1, "nearby dummy hit by the shockwave")
	_check(bridge.effects.has_effect(&"echo_shockwave"), "legendary effect active")


func _instance_of(item_id: StringName) -> String:
	for item in session.character.inventory.items():
		if item.definition_id == item_id:
			return item.instance_id
	return ""


# --- helpers ---------------------------------------------------------------

func _walk_to(target: Vector2, limit: int = 300) -> void:
	for i in limit:
		var to := target - player.global_position
		if to.length() < 6.0:
			break
		f.move = to.normalized()
		f.aim_direction = to.normalized()
		await physics_frame
	f.move = Vector2.ZERO
	await _ticks(3)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _ticks(2)


func _click_button(container: Node, text: String) -> void:
	for button in container.find_children("*", "Button", true, false):
		if (button as Button).text == text and not (button as Button).disabled and not button.is_queued_for_deletion():
			(button as Button).pressed.emit()
			_log("clicked '%s'" % text)
			return
	_check(false, "button '%s' found" % text)


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s.png" % label)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(condition: bool, text: String) -> void:
	if not condition:
		failures += 1
	_log("%s %s" % ["CHECK OK  " if condition else "CHECK FAIL", text])


func _log(text: String) -> void:
	var line := "[%5d] %s" % [Engine.get_physics_frames(), text]
	log_lines.append(line)
	print(line)
