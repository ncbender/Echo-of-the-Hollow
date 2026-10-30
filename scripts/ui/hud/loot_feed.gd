class_name LootFeed
extends VBoxContainer
## Bottom-right feed of what was really received (Loot & Progress Feedback 1.0, docs/LOOT_PROGRESS_FEEDBACK_1_0.md):
## items ("[icon] Iron Ore ×3", name in the rarity colour, the rarity word for special loot), gold ("+40 Gold") and
## profession XP ("Mining +12 XP", quieter). Fed only after a successful grant: PlayerProgressionBridge.item_received
## and .profession_xp (world pickups, gathering steps, caches, found items). Display only - it never changes a grant.
##
## Bundling: the same stackable item (same rarity) or the same profession's XP within BUNDLE_WINDOW of the row's
## first event adds up in that row (its fade restarts, but never past BUNDLE_WINDOW + LIFETIME). Single items
## (max_stack 1: rolled equipment, uniques) always get their own row. At most `max_rows` rows; further events wait
## in a queue (merged by the same rule) and the oldest row leaves early to make room. Rows that are still young
## when the map changes come back on the next map (session memory only, never saved).

const LIFETIME := 4.0
const FADE := 0.6
const FADE_IN := 0.15
## A newer row may join a bundle only this long after the row first appeared.
const BUNDLE_WINDOW := 2.5
## While events wait, the oldest row is shortened to this much life left.
const MAKE_ROOM := 0.6
const MAX_ROWS := 5
const QUEUE_LIMIT := 20
## Rows younger than this when the map changes are shown again on the next map.
const CARRY_AGE := 2.0

var bridge: PlayerProgressionBridge:
	set(value):
		bridge = value
		_restore_carry.call_deferred()   # bound to the new map's player: the last map's young rows come back
## Fewer rows when the HUD is cramped (set by GameHud at high UI scale).
var max_rows: int = MAX_ROWS

var _queue: Array[Dictionary] = []
## Events of the last map that were still on screen (same character only).
static var _carry: Array[Dictionary] = []
static var _carry_owner: Character


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 4)


## An item went into the bag. `item` (optional): the received instance - its own rarity is shown (a Rare instance
## of a Magic definition reads Rare); without one the definition's rarity.
func push(item_id: StringName, quantity: int, item: ItemInstance = null) -> void:
	var definition := _database().get_item(item_id) if _database() != null else null
	if definition == null or quantity <= 0:
		return
	var rarity := item.effective_rarity(definition) if item != null else definition.rarity
	# a single item (rolled equipment, a unique) is its own row: never shown as a stack of "the same" thing
	var key := "item:%s:%d" % [item_id, rarity] if definition.max_stack > 1 else "one:%s" % (item.instance_id if item != null else str(Time.get_ticks_usec()))
	_add({"kind": &"item", "key": key, "item_id": item_id, "quantity": quantity, "rarity": rarity})


## Profession XP that was really granted (Mining +12 XP).
func push_xp(profession_id: StringName, amount: int) -> void:
	var db := _database()
	if db == null or amount <= 0 or not db.professions.has(profession_id):
		return
	_add({"kind": &"xp", "key": "xp:%s" % profession_id, "profession_id": profession_id, "quantity": amount})


func rows() -> int:
	return get_child_count()


## Waiting events (tests).
func queued() -> int:
	return _queue.size()


## The visible rows' texts, oldest first (tests, debugging).
func texts() -> PackedStringArray:
	var result: PackedStringArray = []
	for row: Control in get_children():
		var label := row.find_child("Text", true, false) as Label
		if label != null:
			result.append(label.text)
	return result


func _database() -> GameDatabase:
	return bridge.character.database if bridge != null and bridge.character != null else null


func _add(event: Dictionary) -> void:
	for row: Control in get_children():
		if row.get_meta(&"key") == event.key and float(row.get_meta(&"born")) < BUNDLE_WINDOW and not row.is_queued_for_deletion():
			var total: int = int(row.get_meta(&"quantity")) + int(event.quantity)
			row.set_meta(&"quantity", total)
			row.set_meta(&"age", 0.0)
			_fill(row, row.get_meta(&"event"), total)
			return
	for waiting in _queue:
		if waiting.key == event.key:
			waiting.quantity = int(waiting.quantity) + int(event.quantity)
			return
	if get_child_count() >= max_rows:
		if _queue.size() < QUEUE_LIMIT:
			_queue.append(event)
		_make_room()
		return
	_show(event)


func _show(event: Dictionary) -> void:
	var row := PanelContainer.new()
	row.theme_type_variation = &"HudPanel"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	var box := HBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	row.set_meta(&"key", event.key)
	row.set_meta(&"event", event)
	row.set_meta(&"quantity", int(event.quantity))
	row.set_meta(&"age", 0.0)
	row.set_meta(&"born", 0.0)
	row.modulate.a = 0.0
	add_child(row)
	_fill(row, event, int(event.quantity))


## The row's content: icon + name ×n (rarity colour, rarity word for special loot), "+n Gold", or "Mining +n XP".
func _fill(row: PanelContainer, event: Dictionary, quantity: int) -> void:
	var box := row.get_node("Box") as HBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var db := _database()
	if event.kind == &"xp":
		var profession: ProfessionDefinition = db.professions.get(event.profession_id)
		var swatch := ColorRect.new()
		swatch.color = profession.color
		swatch.custom_minimum_size = Vector2(4, 0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(swatch)
		var text := UiTheme.styled("%s  +%d XP" % [profession.display_name, quantity], &"CaptionLabel")
		text.name = "Text"
		text.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)   # quieter than loot
		box.add_child(text)
		return
	var definition := db.get_item(event.item_id)
	var icon := ItemIcon.new().setup(definition, 1)   # the amount is said once, in the text
	icon.rarity = int(event.rarity)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label_text := "+%d %s" % [quantity, definition.display_name] if definition.is_currency \
		else ("%s  ×%d" % [definition.display_name, quantity] if quantity > 1 else definition.display_name)
	var name_label := UiTheme.styled(label_text, &"SmallLabel")
	name_label.name = "Text"
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_color_override(&"font_color", UiTheme.WARNING if definition.is_currency else UiTheme.rarity_color(int(event.rarity)))
	box.add_child(name_label)
	if int(event.rarity) != ItemDefinition.Rarity.NORMAL and not definition.is_currency:
		var word := UiTheme.styled(UiTheme.rarity_name(int(event.rarity)), &"CaptionLabel")
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(word)


## Events are waiting: the oldest row leaves soon (never at once - no jump).
func _make_room() -> void:
	for row: Control in get_children():
		if not row.is_queued_for_deletion():
			row.set_meta(&"age", maxf(float(row.get_meta(&"age")), LIFETIME - MAKE_ROOM))
			return


func _process(delta: float) -> void:
	for row: Control in get_children():
		if row.is_queued_for_deletion():
			continue
		var age: float = float(row.get_meta(&"age")) + delta
		row.set_meta(&"age", age)
		row.set_meta(&"born", float(row.get_meta(&"born")) + delta)
		row.modulate.a = clampf(minf((LIFETIME - age) / FADE, float(row.get_meta(&"born")) / FADE_IN), 0.0, 1.0)
		if age >= LIFETIME:
			remove_child(row)
			row.queue_free()
	while not _queue.is_empty() and get_child_count() < max_rows:
		_show(_queue.pop_front())
	if not _queue.is_empty():
		_make_room()


## Map change: rows that were just received (and anything waiting) come back on the next map's feed.
func _exit_tree() -> void:
	if bridge == null or bridge.character == null:
		return
	_carry.clear()
	_carry_owner = bridge.character
	for row: Control in get_children():
		if not row.is_queued_for_deletion() and float(row.get_meta(&"born")) < CARRY_AGE:
			var event: Dictionary = (row.get_meta(&"event") as Dictionary).duplicate()
			event.quantity = int(row.get_meta(&"quantity"))
			_carry.append(event)
	_carry.append_array(_queue)


func _restore_carry() -> void:
	if _carry.is_empty() or bridge == null or bridge.character == null:
		return
	if bridge.character != _carry_owner:
		_carry.clear()
		_carry_owner = null
		return
	_carry_owner = null
	var events := _carry.duplicate()
	_carry.clear()
	for event: Dictionary in events:
		_add(event)
