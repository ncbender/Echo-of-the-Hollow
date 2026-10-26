extends TestCase
## UI/UX redesign E: gameplay HUD - player frame (health, resource, dash,
## defense in words), skill bar reasons, enemy / elite / boss frame, loot feed,
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


func test_player_frame_shows_real_values() -> void:
	var frame := map.hud.player_frame
	map.player.health.apply_hit(_damage(30.0))
	await get_tree().process_frame
	check(frame.visible, "player frame shown")
	check_eq(frame._health_text.text, "%d / %d" % [ceili(map.player.health.health), roundi(map.player.health.max_health)], "health in numbers")
	check(frame._resource_text.text.begins_with("Rage"), "class resource: %s" % frame._resource_text.text)
	check_eq(frame._dash.max_charges, map.player.dash.config.max_charges, "dash pips = dash charges")
	check(frame._defense.text.begins_with("Shift:"), "defense ready in words: %s" % frame._defense.text)
	map.player.defense.counter_left = 0.3
	check_eq(PlayerFrame.defense_text(map.player.defense), "COUNTER - strike now!", "counter window in words")
	map.player.defense.counter_left = 0.0


func test_skill_bar_says_why_a_skill_is_not_ready() -> void:
	var bar := map.hud.skill_bar
	await get_tree().process_frame
	check(bar.visible, "skill bar shown")
	var texts: PackedStringArray = []
	for label in bar._infos:
		texts.append(label.text)
	check(" ".join(texts).contains("Need "), "unaffordable skills say what they need: %s" % [texts])


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
	for control: Control in [map.hud.player_frame, map.hud.skill_bar, map.hud.objectives, map.hud.target_frame, map.hud.loot_feed]:
		if control.is_visible_in_tree():
			check(not middle.intersects(control.get_global_rect()), "%s stays out of the middle (%s)" % [control.name, control.get_global_rect()])
