class_name HudXpBar
extends Control
## HUD EXP Bar 1.0 (docs/HUD_EXP_BAR_1_0.md): the one EXP bar, directly under the combat bar.
## Shows the progress inside the active class's current level as a whole percentage centred
## in the bar ("MAX" at the class's max level) - never absolute XP. Read-only view of
## CharacterClasses (active_class_id, get_level, get_xp, xp_to_next); no XP logic here.
## Art (HUD Bars Visual Integration 1.0): the shared bar/frame and the bar/fill tint mask in EXP bronze, like
## every other bar; without the files the procedural bar is drawn.

const SIZE := UiTheme.XP_BAR_SIZE
const MAX_TEXT := "MAX"

var bridge: PlayerProgressionBridge
## Shown share 0..1 and text ("" = no class to show: empty track, no text).
var ratio: float = 0.0
var text: String = ""

var _label: BarText
var _frame: StyleBox
var _fill: StyleBox


func _init() -> void:
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never a click target, never blocks input
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.55)
	track.border_color = Color(UiTheme.BRONZE_DARK, 0.9)
	track.set_border_width_all(UiTheme.BORDER_THIN)
	_frame = UiSkin.stylebox(&"bar/frame", track)
	_fill = UiTheme.fill_box(UiTheme.XP, false)   # drawn inside the frame below (whole pixels)
	_label = BarText.new()   # centred on the digits, fitted into the 14 px bar (UI Usability 1.0)
	_label.font_size = 13
	add_child(_label)


## [share 0..1, text] of the active class: whole percent, rounded down (never "100%" before
## the level-up), "MAX" at the max level, "" without a known class.
static func progress(classes: CharacterClasses) -> Array:
	var definition := classes.get_active_definition()
	if definition == null:
		return [0.0, ""]
	var class_id := classes.active_class_id
	if classes.get_level(class_id) >= definition.max_level:
		return [1.0, MAX_TEXT]
	var needed := classes.xp_to_next(class_id)
	if needed <= 0:
		return [1.0, MAX_TEXT]
	var share := clampf(float(classes.get_xp(class_id)) / float(needed), 0.0, 1.0)
	var percent := mini(floori(share * 100.0), 99)
	return [share, "%d%%" % percent]


func _process(_delta: float) -> void:
	var shown := [0.0, ""]
	if bridge != null and bridge.is_bound() and bridge.character != null:
		shown = progress(bridge.character.classes)
	if not is_equal_approx(shown[0], ratio) or shown[1] != text:
		ratio = shown[0]
		text = shown[1]
		_label.text = text
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_frame, rect)
	# whole design pixels inside the 1 px frame (pixel-art friendly, no half-filled columns)
	var inner := rect.grow(-UiTheme.BORDER_THIN)
	var width := floorf(inner.size.x * ratio)
	if width >= 1.0:
		draw_style_box(_fill, Rect2(inner.position, Vector2(width, inner.size.y)))
