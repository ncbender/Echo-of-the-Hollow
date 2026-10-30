class_name Readable
extends Interactable
## A sign, note or inscription read with G. The first reading can hand out a
## small reward (once per character: "read.<id>") and report a story event.

enum Look { SIGNPOST, NOTE, STONE, ROOTS, WAYSTONE }

@export var persistent_id: StringName
@export var title: String = "Note"
## Prompt verb: "Read Old Signpost", "Examine Twisted Roots".
@export var verb: String = "Read"
@export_multiline var text: String
@export var look: Look = Look.NOTE
@export var rewards: Array[ItemCost] = []
@export var event_id: StringName

var character: Character


func _ready() -> void:
	super._ready()
	prompt = "%s %s" % [verb, title]
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()


func read_flag() -> StringName:
	return StringName("read.%s" % persistent_id)


func is_read() -> bool:
	return character != null and character.world.has_flag(read_flag())


func interact(hud: GameHud) -> void:
	var lines: Array[Dictionary] = [{"name": title, "text": text, "color": UiTheme.PARCHMENT, "note": true}]
	hud.open_lines(lines)
	if character == null or is_read():
		return
	for reward in rewards:
		if character.inventory.room_for(reward.item_id) < reward.quantity:
			hud.notify("Your pack is full. Make room to take what was left here.")
			return   # nothing taken, nothing marked: read it again later
	character.world.set_flag(read_flag())
	for reward in rewards:
		if character.inventory.add_item(reward.item_id, reward.quantity, ItemInstance.ORIGIN_FOUND).is_empty():
			continue
		if hud.bridge != null:   # Loot & Progress Feedback 1.0: what was found goes to the loot feed
			hud.bridge.item_received.emit(reward.item_id, reward.quantity, null)
		else:
			var definition := character.database.get_item(reward.item_id)
			hud.notify("Found: %d x %s" % [reward.quantity, definition.display_name if definition != null else String(reward.item_id)])
	if event_id != &"":
		StoryService.notify(character, event_id)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var glow := Color(1, 0.9, 0.5, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.006)) if player_inside else Color(0, 0, 0, 0)
	match look:
		Look.SIGNPOST:
			draw_rect(Rect2(-1.5, -22, 3, 22), Color(0.4, 0.3, 0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -22), Vector2(10, -22), Vector2(14, -18), Vector2(10, -14), Vector2(-12, -14)]), Color(0.55, 0.42, 0.28))
			draw_rect(Rect2(-12, -22, 26, 8), glow, false, 1.0)
		Look.STONE:
			draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(-7, -14), Vector2(0, -18), Vector2(7, -13), Vector2(8, 0)]), Color(0.45, 0.45, 0.5))
			draw_rect(Rect2(-9, -19, 18, 20), glow, false, 1.0)
		Look.ROOTS:
			var bark := Color(0.36, 0.26, 0.16)
			draw_polyline(PackedVector2Array([Vector2(-14, 2), Vector2(-6, -6), Vector2(2, -4), Vector2(12, -12)]), bark, 3.0)
			draw_polyline(PackedVector2Array([Vector2(-12, -10), Vector2(-4, -3), Vector2(6, 0), Vector2(14, -2)]), bark, 3.0)
			draw_polyline(PackedVector2Array([Vector2(-6, 4), Vector2(0, -2), Vector2(8, -8), Vector2(14, -16)]), bark.darkened(0.2), 3.0)
			draw_rect(Rect2(-16, -18, 32, 24), glow, false, 1.0)
			if not is_read():
				WorldText.draw(self, Vector2(-2, -21), "?", 8, Color(1, 0.9, 0.5), 2, Color.BLACK)
		Look.WAYSTONE:   # a dormant waystone (same silhouette as a silent Waystone), roots wound around its foot
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
			draw_set_transform(Vector2.ZERO)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(-6, -26), Vector2(0, -32), Vector2(6, -26), Vector2(7, 0)]), Color(0.36, 0.36, 0.38))
			draw_polyline(PackedVector2Array([Vector2(-3, -28), Vector2(1, -20), Vector2(-2, -14), Vector2(3, -6)]), Color(0.15, 0.15, 0.16), 1.0)
			var bark := Color(0.36, 0.26, 0.16)
			draw_polyline(PackedVector2Array([Vector2(-16, 2), Vector2(-8, -3), Vector2(-6, -10), Vector2(2, -8), Vector2(7, -4), Vector2(16, -6)]), bark, 2.5)
			draw_polyline(PackedVector2Array([Vector2(-12, 4), Vector2(-4, 0), Vector2(5, -14), Vector2(8, -16), Vector2(18, -10)]), bark.darkened(0.2), 2.0)
			draw_rect(Rect2(-18, -34, 36, 40), glow, false, 1.0)
			var label := "%s (silent)" % title
			WorldText.draw(self, Vector2(-WorldText.width(label, 6) * 0.5, -40), label, 6, Color(0.7, 0.7, 0.72), 2, Color.BLACK)
			if not is_read():
				WorldText.draw(self, Vector2(-2, -48), "?", 8, Color(1, 0.9, 0.5), 2, Color.BLACK)
		_:
			draw_rect(Rect2(-5, -8, 10, 8), Color(0.88, 0.82, 0.66))
			draw_line(Vector2(-3, -6), Vector2(3, -6), Color(0.4, 0.35, 0.3), 1.0)
			draw_line(Vector2(-3, -3), Vector2(2, -3), Color(0.4, 0.35, 0.3), 1.0)
			draw_rect(Rect2(-7, -10, 14, 12), glow, false, 1.0)
			if not is_read():
				WorldText.draw(self, Vector2(-2, -13), "?", 8, Color(1, 0.9, 0.5), 2, Color.BLACK)
