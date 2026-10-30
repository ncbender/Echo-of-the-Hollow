extends TestCase
## UI/UX redesign E: gameplay HUD - health / resource vessels and dash meter (Combat HUD UX 2.0, details in
## test_combat_hud), skill bar reasons in the tooltip, enemy / elite / boss frame, loot feed,
## death overlay, the debug overlay kept apart (hidden, F12), and the middle of
## the screen kept free for telegraphs.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _damage(amount: float) -> HitData:
	var hit := HitData.new()
	hit.damage = amount
	return hit


func test_vessels_show_real_values() -> void:
	map.player.health.apply_hit(_damage(30.0))
	await get_tree().process_frame
	check(map.hud.health_vessel.visible, "health vessel shown")
	check_eq(map.hud.health_vessel.value_text, str(ceili(map.player.health.health)), "health as a number")
	check(map.hud.resource_vessel.tooltip_text.begins_with("Rage"), "class resource: %s" % map.hud.resource_vessel.tooltip_text)
	map.player.defense.counter_left = 0.3
	await get_tree().process_frame
	check(not map.hud.dash_meter.visible and not map.hud.dash_meter.has_method(&"defense_text"), "no parry / counter text in the HUD (Loot & Progress Feedback 1.0)")
	map.player.defense.counter_left = 0.0


func test_skill_bar_says_why_a_skill_is_not_ready() -> void:
	var bar := map.hud.skill_bar
	await get_tree().process_frame
	check(bar.visible, "skill bar shown")
	var texts := bar.status_texts()
	check("".join(texts) == "", "no permanent slot words (Combat HUD UX 2.0): %s" % [texts])
	var tips := ""
	for slot in bar.get_children():
		tips += (slot as Control).tooltip_text
	check(tips.contains("Not enough Rage"), "the tooltip names the missing cost: %s" % tips)


func test_target_and_boss_frames() -> void:
	var frame := map.hud.target_frame
	var husk := map.spawn_enemy(map.player.global_position + Vector2(200, 0), load("res://data/enemies/hardened_husk.tres"))
	await get_tree().process_frame
	check(not frame.visible, "no frame before a fight")
	var hit := HitData.new()
	hit.target = husk
	frame.on_player_hit(hit)
	await get_tree().process_frame
	check(frame.visible and frame._name.text == "Hardened Husk" and frame._rank.text == "ELITE", "elite frame after a hit")
	check(frame._poise.max_value > 0.0, "poise shown")
	frame._since_hit = TargetFrame.LINGER + 1.0
	await get_tree().process_frame
	check(not frame.visible, "frame fades after the fight")
	var warden := map.spawn_enemy(map.player.global_position + Vector2(100, 0), load("res://data/enemies/grove_warden_config.tres"))
	await get_tree().process_frame
	check(frame.visible and frame._rank.text == "BOSS" and frame._name.text == "Grove Warden", "boss bar while engaged")
	warden.queue_free()
	husk.queue_free()


func test_loot_feed_and_pickups() -> void:
	var pickup := map.spawn_pickup(&"iron_ore", 2, map.player.global_position)
	for i in 6:
		await get_tree().physics_frame
	check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "picked up")
	check(map.hud.loot_feed.rows() >= 1, "loot feed row")


func test_death_overlay() -> void:
	map.player.health.apply_hit(_damage(9999.0))
	await get_tree().process_frame
	check(map.hud.death_overlay.visible, "you have fallen")
	check(map.hud.death_overlay._detail.text.contains("rise again"), "respawn time shown")


func test_debug_overlay_is_separate() -> void:
	var overlay := map.get_node("DebugOverlay") as CanvasLayer
	check(not overlay.visible, "debug overlay hidden by default")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F12
	key.pressed = true
	overlay._unhandled_key_input(key)
	check(overlay.visible, "F12 shows it")
	overlay._unhandled_key_input(key)
	check(not overlay.visible, "F12 hides it")


func test_hud_keeps_the_middle_free() -> void:
	map.spawn_enemy(map.player.global_position + Vector2(100, 0), load("res://data/enemies/grove_warden_config.tres"))
	map.hud.show_hint("A hint")
	await get_tree().process_frame
	await get_tree().process_frame
	var view := get_tree().root.get_visible_rect()
	var middle := Rect2(view.size * Vector2(0.25, 0.25), view.size * Vector2(0.5, 0.45))
	for control: Control in [map.hud.health_vessel, map.hud.resource_vessel, map.hud.skill_bar, map.hud.objectives, map.hud.target_frame, map.hud.loot_feed]:
		if control.is_visible_in_tree():
			check(not middle.intersects(control.get_global_rect()), "%s stays out of the middle (%s)" % [control.name, control.get_global_rect()])
