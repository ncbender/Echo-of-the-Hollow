class_name StoryNpc
extends Interactable
## A named NPC standing in a map while `condition` holds (Mara at the cart, Mara
## in Haven, Edrin at the north gate). Interact (G): the NPC's current
## dialogue, otherwise a short idle line. A gold "!" marks a dialogue that moves
## the story on. Which NPC stands where is data (conditions), never code.

@export var npc_id: StringName
@export var condition: StoryCondition

var character: Character
var _bark: String = ""
var _bark_left: float = 0.0


func _ready() -> void:
	super._ready()
	var session := SessionState.find(get_tree())
	if session != null:
		character = session.get_character()
		character.world.flag_changed.connect(_on_flag_changed)
		character.quests.changed.connect(refresh_story)
	var npc := definition()
	prompt = "Talk to %s" % (npc.display_name if npc != null else String(npc_id))
	refresh_story()


func _exit_tree() -> void:
	if character != null:
		if character.world.flag_changed.is_connected(_on_flag_changed):
			character.world.flag_changed.disconnect(_on_flag_changed)
		if character.quests.changed.is_connected(refresh_story):
			character.quests.changed.disconnect(refresh_story)


func definition() -> NpcDefinition:
	return GameDatabase.get_default().npcs.get(npc_id)


func is_present() -> bool:
	return StoryCondition.check(condition, character)


## Shows or hides the NPC when flags or quests change.
func refresh_story() -> void:
	visible = is_present()


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	refresh_story()


func interact(hud: GameHud) -> void:
	var dialogue := DialogueService.pick(character, definition())
	if dialogue != null:
		hud.open_dialogue(dialogue)
		return
	var npc := definition()
	if npc != null and not npc.idle_lines.is_empty():
		say(npc.idle_lines[randi() % npc.idle_lines.size()])


## Speech bubble above the head (barks, idle lines).
func say(text: String, seconds: float = 3.0) -> void:
	_bark = text
	_bark_left = seconds


func current_bark() -> String:
	return _bark if _bark_left > 0.0 else ""


func _process(delta: float) -> void:
	_bark_left = maxf(0.0, _bark_left - delta)
	queue_redraw()


func _draw() -> void:
	var npc := definition()
	var color := npc.color if npc != null else Color(0.8, 0.7, 0.5)
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-5, -14, 10, 14), color.darkened(0.25))
	draw_circle(Vector2(0, -17), 4.5, Color(0.92, 0.78, 0.62))
	draw_rect(Rect2(-5, -22, 10, 3), color.darkened(0.45))
	var title := npc.display_name if npc != null else String(npc_id)
	WorldText.draw(self, Vector2(-WorldText.width(title, 6) * 0.5, -26), title, 6, color.lightened(0.35), 2, Color.BLACK)
	if character != null and npc != null and DialogueService.has_story_dialogue(character, npc):
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		WorldText.draw(self, Vector2(-2, -34), "!", 10, Color(1.0, 0.85, 0.3, pulse), 2, Color.BLACK)
	if _bark_left > 0.0:
		var alpha := clampf(_bark_left / 0.4, 0.0, 1.0)
		WorldText.draw(self, Vector2(-WorldText.width(_bark, 6) * 0.5, -44), _bark, 6, Color(1, 1, 0.92, alpha), 2, Color(0, 0, 0, alpha))
