class_name HudDashMeter
extends Control
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): the dash charges as small segments under the hero - one per
## real charge (DashConfig.max_charges), the recharging one filling up. Hidden while every charge is ready,
## back at once when a dash is spent; no "Dash" label. Below the segments a short defense word only while it
## matters (the counter window, the parry cooldown) - the permanent "Shift: <guard>" text is gone.
## A HUD control placed every frame from the player's canvas position (follows movement, camera and scene
## changes), clamped inside the canvas so it stays readable at the screen edges. Read-only: no dash rule here.

## Distance below the player's origin in world px: under the shadow (≈ 10) and the aim marker (18).
const BELOW_WORLD := 22.0
const SEGMENT := Vector2(14, 4)
const SEGMENT_GAP := 3.0
const FONT_SIZE := 12

var bridge: PlayerProgressionBridge
var charges: int = 0
var max_charges: int = 0
var recharge: float = 0.0
## Short defense word under the segments ("" = none).
var defense_word: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = false
	visible = false


func _process(_delta: float) -> void:
	var player := bridge.player if bridge != null and bridge.is_bound() else null
	if player == null or not is_instance_valid(player) or not player.is_inside_tree() or player.health.is_dead():
		visible = false
		return
	charges = player.dash.charges
	max_charges = player.dash.config.max_charges
	recharge = player.dash.get_recharge_progress()
	defense_word = defense_text(player.defense)
	visible = charges < max_charges or defense_word != ""
	if not visible:
		return
	var width := maxf(segments_width(), UiTheme.body_font().get_string_size(defense_word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	size = Vector2(ceilf(width), SEGMENT.y + 2.0 + (16.0 if defense_word != "" else 0.0))
	var foot := player.get_global_transform_with_canvas() * Vector2(0, BELOW_WORLD)
	var canvas := (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	var margin := float(UiTheme.SCREEN_MARGIN)
	position = Vector2(clampf(foot.x - size.x * 0.5, margin, maxf(margin, canvas.x - margin - size.x)),
		clampf(foot.y, margin, maxf(margin, canvas.y - margin - size.y))).round()
	queue_redraw()


func segments_width() -> float:
	return max_charges * SEGMENT.x + maxi(0, max_charges - 1) * SEGMENT_GAP


## The defense state in a short word while it matters: the counter window, the parry cooldown; "" otherwise.
static func defense_text(defense: DefenseComponent) -> String:
	if defense == null:
		return ""
	if defense.counter_left > 0.0:
		return "Counter!"
	if defense.state == DefenseComponent.State.IDLE and defense.cooldown_left > 0.0 and defense.profile() != null:
		return "Parry %.1fs" % defense.cooldown_left
	return ""


func _draw() -> void:
	if charges < max_charges:
		var left := roundf((size.x - segments_width()) * 0.5)
		for index in max_charges:
			var rect := Rect2(Vector2(left + index * (SEGMENT.x + SEGMENT_GAP), 1), SEGMENT)
			draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.85))   # ink outline, readable on any ground
			draw_rect(rect, UiTheme.PANEL_INSET)
			if index < charges:
				draw_rect(rect, UiTheme.RESONANCE)
			elif index == charges and recharge > 0.0:
				draw_rect(Rect2(rect.position, Vector2(floorf(rect.size.x * recharge), rect.size.y)), UiTheme.RESONANCE_DIM)
	if defense_word != "":
		var font := UiTheme.body_font()
		var width := font.get_string_size(defense_word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at := Vector2(roundf((size.x - width) * 0.5), SEGMENT.y + 2.0 + font.get_ascent(FONT_SIZE))
		var colour := UiTheme.RESONANCE if defense_word == "Counter!" else UiTheme.TEXT_SECONDARY
		draw_string_outline(font, at, defense_word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0, 0, 0, 0.9))
		draw_string(font, at, defense_word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)
