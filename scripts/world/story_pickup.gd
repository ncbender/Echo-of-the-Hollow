class_name StoryPickup
extends Interactable
## A story object recovered with G (Mara's supply crates): puts `item_id` into
## the inventory exactly once (persistent flag "pickup.<id>", saved together
## with the item - no duplication through saving, loading or map changes) and
## reports `event_id`. Present only while `condition` holds and not taken.

@export var persistent_id: StringName
@export var item_id: StringName
@export var quantity: int = 1
@export var event_id: StringName
@export var condition: StoryCondition
@export var label: String = "Supply Crate"

var character: Character


func _ready() -> void:
	super._ready()
	prompt = "Recover %s" % label
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()
		character.world.flag_changed.connect(_on_flag_changed)
		character.quests.changed.connect(refresh_story)
	refresh_story()


func _exit_tree() -> void:
	if character != null:
		if character.world.flag_changed.is_connected(_on_flag_changed):
			character.world.flag_changed.disconnect(_on_flag_changed)
		if character.quests.changed.is_connected(refresh_story):
			character.quests.changed.disconnect(refresh_story)


func taken_flag() -> StringName:
	return StringName("pickup.%s" % persistent_id)


func is_taken() -> bool:
	return character != null and character.world.has_flag(taken_flag())


func refresh_story() -> void:
	visible = character != null and not is_taken() and StoryCondition.check(condition, character)


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	refresh_story()


## Returns "" on success or the reason (e.g. a full inventory: nothing is lost).
func take() -> String:
	if character == null or not visible or is_taken():
		return "Nothing to recover."
	if item_id != &"" and character.inventory.room_for(item_id) < quantity:
		return "Your pack is full."
	if item_id != &"":
		character.inventory.add_item(item_id, quantity, ItemInstance.ORIGIN_FOUND)
	character.world.set_flag(taken_flag())
	if event_id != &"":
		StoryService.notify(character, event_id)
	return ""


func interact(hud: GameHud) -> void:
	var error := take()
	var definition := character.database.get_item(item_id) if character != null else null
	if error == "" and definition != null and hud.bridge != null:
		hud.bridge.item_received.emit(item_id, quantity, null)   # Loot & Progress Feedback 1.0: the loot feed's row
		return
	hud.notify(error if error != "" else "Recovered: %s" % (definition.display_name if definition != null else label))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var wood := Color(0.6, 0.45, 0.26)
	draw_rect(Rect2(-8, -12, 16, 13), wood)
	draw_rect(Rect2(-8, -12, 16, 13), wood.darkened(0.45), false, 1.0)
	draw_line(Vector2(-8, -6), Vector2(8, -6), wood.darkened(0.35), 1.0)
	if player_inside:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_rect(Rect2(-10, -14, 20, 17), Color(1, 0.9, 0.5, 0.4 + 0.4 * pulse), false, 1.0)
	WorldText.draw(self, Vector2(-WorldText.width(label, 6) * 0.5, -16), label, 6, Color(1, 0.9, 0.7), 2, Color.BLACK)
