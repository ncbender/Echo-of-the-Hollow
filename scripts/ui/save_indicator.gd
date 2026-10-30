class_name SaveIndicator
extends PanelContainer
## Small HUD hint in the bottom-right corner: "Saving..." while a save is being
## written, "Progress saved" only AFTER a successful write, "Save failed" on an
## error. Calm: no blinking, fades out. Hidden by the option "Show Save
## Indicator" - except failures, which are always shown.

const SHOW_SUCCESS := 2.0
const SHOW_FAILURE := 5.0
## Slot height before the theme is known (GameHud measures the real one, slot_height).
const FALLBACK_HEIGHT := 46.0

var session: SessionState
var _label: Label
var _left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # also while the pause menu saves
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiTheme.label("Progress saved", UiTheme.COLOR_TEXT)   # one line from the start: a stable slot
	add_child(_label)
	visible = false
	session = SessionState.find(get_tree())
	if session != null and session.saves != null:
		session.saves.save_started.connect(_on_started)
		session.saves.save_finished.connect(_on_finished)


func _exit_tree() -> void:
	if session != null and session.saves != null:
		if session.saves.save_started.is_connected(_on_started):
			session.saves.save_started.disconnect(_on_started)
		if session.saves.save_finished.is_connected(_on_finished):
			session.saves.save_finished.disconnect(_on_finished)


func _enabled() -> bool:
	return session == null or session.settings == null or session.settings.show_save_indicator


func _on_started(_kind: SaveCoordinator.Kind) -> void:
	show_text("Saving...", UiTheme.COLOR_DIM, 10.0, _enabled())


func _on_finished(_id: int, ok: bool, _kind: SaveCoordinator.Kind, _message: String) -> void:
	if ok:
		show_text("Progress saved", UiTheme.COLOR_ACCENT, SHOW_SUCCESS, _enabled())
	else:
		show_text("Save failed", UiTheme.COLOR_ERROR, SHOW_FAILURE, true)


func show_text(text: String, color: Color, seconds: float, allowed: bool = true) -> void:
	if not allowed:
		return
	_label.text = text
	_label.add_theme_color_override(&"font_color", color)
	_left = seconds
	modulate.a = 1.0
	visible = true


## Height of the indicator's slot: its HUD panel around one line of text - the same for every
## message and whether it is shown or not (HUD Notification Collision Fix 1.0: the loot feed sits
## above this slot; a hard-coded 26 px let the 46 px panel grow up into the feed).
func slot_height() -> float:
	return maxf(get_combined_minimum_size().y, size.y) if is_inside_tree() else FALLBACK_HEIGHT


func text() -> String:
	return _label.text if visible else ""


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
	elif _left < 0.5:
		modulate.a = _left / 0.5
