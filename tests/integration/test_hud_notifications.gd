extends TestCase
## HUD Notification Collision Fix 1.0 (docs/UI_LAYOUT_LOCK_1_0.md, bottom right): the loot feed and the
## save indicator share one right column - the save slot (measured height, always reserved) at the
## bottom, the feed one GAP above. Their real visible rectangles never intersect, whatever shows,
## grows or fades; nothing jumps. Real HUD controls in the test arena; no save is written.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.prologue.stage = PrologueState.Stage.COMPLETED
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await get_tree().process_frame


func after_each() -> void:
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame


func _clear_feed() -> void:
	for row in map.hud.loot_feed.get_children():
		map.hud.loot_feed.remove_child(row)
		row.queue_free()


## Visible rect of the feed: the union of its shown rows (empty Rect2 when none).
func _feed_rect() -> Rect2:
	var rect := Rect2()
	for row: Control in map.hud.loot_feed.get_children():
		if row.is_visible_in_tree() and row.modulate.a > 0.0:
			rect = row.get_global_rect() if rect.size == Vector2.ZERO else rect.merge(row.get_global_rect())
	return rect


func _apart(label: String) -> void:
	var save := map.hud.save_indicator
	var feed := _feed_rect()
	if save.is_visible_in_tree() and feed.size != Vector2.ZERO:
		check(not feed.intersects(save.get_global_rect()), "%s: feed %s and save %s apart" % [label, feed, save.get_global_rect()])
		check(save.get_global_rect().position.y - feed.end.y >= UiTheme.GAP - 0.5, "%s: at least one GAP between them" % label)
	var canvas := Rect2(Vector2.ZERO, map.get_viewport().get_visible_rect().size)
	for control: Control in [save, map.hud.loot_feed]:
		if control.is_visible_in_tree():
			check(canvas.grow(0.5).encloses(control.get_global_rect()), "%s: %s inside the screen" % [label, control.name])
	var column := map.hud._combat_row.get_parent() as Control   # combat bar + EXP bar
	for rect: Rect2 in [feed, save.get_global_rect() if save.is_visible_in_tree() else Rect2()]:
		if rect.size != Vector2.ZERO:
			check(not rect.intersects(column.get_global_rect()) and not rect.intersects(map.hud.menu_bar.get_global_rect()),
				"%s: no overlap with the combat column or the menu bar" % label)


func test_feed_and_save_never_overlap_at_every_scale() -> void:
	var hud := map.hud
	var long_names := GalleryScreens.longest_item_names(character.database, 6)
	for scale: float in [0.75, 1.0, 1.25, 1.5]:
		var tag := "%d %%" % int(scale * 100)
		session.settings.set_ui_scale(scale)
		_clear_feed()
		hud.save_indicator.visible = false
		await _frames(4)
		var slot := hud.save_indicator.slot_height()
		check(slot >= hud.save_indicator.get_combined_minimum_size().y - 0.5, "%s: the reserved slot holds the real panel (%.0f)" % [tag, slot])
		# A: only the feed
		hud.loot_feed.push(&"iron_ore", 3)
		await _frames()
		var feed_bottom := hud.loot_feed.get_global_rect().end.y
		_apart("%s A" % tag)
		# B: only the save hint (the feed already faded)
		_clear_feed()
		hud.save_indicator.show_text("Progress saved", UiTheme.COLOR_ACCENT, 30.0)
		await _frames()
		check(hud.save_indicator.is_visible_in_tree(), "%s B: save shown" % tag)
		var save_rect := hud.save_indicator.get_global_rect()
		_apart("%s B" % tag)
		# C + D + F: the full feed of long names while the save hint shows
		for item_id: StringName in long_names:
			hud.loot_feed.push(item_id, 1)
			await _frames(2)
			_apart("%s D (%d rows)" % [tag, hud.loot_feed.rows()])
		check_eq(hud.loot_feed.rows(), hud.loot_feed.max_rows, "%s D: the feed is full" % tag)
		check(is_equal_approx(hud.loot_feed.get_global_rect().end.y, feed_bottom), "%s: the feed bottom never moves (%.1f)" % [tag, hud.loot_feed.get_global_rect().end.y])
		check(hud.save_indicator.get_global_rect().is_equal_approx(save_rect), "%s: the save hint never moves" % tag)
		# E: rows fade and vanish while the save hint stays
		for row: Control in hud.loot_feed.get_children():
			row.set_meta(&"age", LootFeed.LIFETIME - 0.3)
		await _frames(2)
		_apart("%s E (fading)" % tag)
		_clear_feed()
		await _frames(2)
		check(hud.save_indicator.is_visible_in_tree() and hud.save_indicator.get_global_rect().is_equal_approx(save_rect), "%s E: save stays, same place" % tag)
		# save ends while new loot arrives: the feed keeps its place
		hud.save_indicator.visible = false
		hud.loot_feed.push(&"iron_ore", 1)
		await _frames()
		check(is_equal_approx(hud.loot_feed.get_global_rect().end.y, feed_bottom), "%s: no jump when the save hint goes" % tag)
		# I: a large window open (right column fades) - the two still never collide
		hud.save_indicator.show_text("Saving...", UiTheme.COLOR_DIM, 30.0)
		hud.open_menu(&"inventory")
		await _frames(3)
		_apart("%s I (window open)" % tag)
		hud.close_windows()
		hud.save_indicator.visible = false
		_clear_feed()
