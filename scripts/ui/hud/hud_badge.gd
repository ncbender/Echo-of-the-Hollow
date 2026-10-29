class_name HudBadge
extends Control
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): a small framed badge in the EXP row beside the combat bar -
## the active class's level under the health vessel ("Lv 12"; class, trial and progress in the tooltip) and the
## class pressure under the resource vessel ("x2", only while pressure stacks). Read-only over the bridge.

enum Kind { LEVEL, PRESSURE }

const SIZE := Vector2(HudVessel.SIZE.x, UiTheme.XP_BAR_SIZE.y)
const FONT_SIZE := 12

var kind: Kind = Kind.LEVEL
var bridge: PlayerProgressionBridge
var text: String = ""
var _frame: StyleBox


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP   # tooltip; never a click into the playfield
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.55)
	track.border_color = Color(UiTheme.BRONZE_DARK, 0.9)
	track.set_border_width_all(UiTheme.BORDER_THIN)
	_frame = UiSkin.stylebox(&"bar/frame", track)   # the EXP bar's frame: one row, one look


func _process(_delta: float) -> void:
	var shown := ""
	var tip := ""
	if bridge != null and bridge.is_bound():
		var classes := bridge.character.classes
		if kind == Kind.LEVEL:
			var definition := classes.get_active_definition()
			if definition != null:
				var level := classes.get_level(classes.active_class_id)
				shown = "Lv %d" % level
				var progress: Array = HudXpBar.progress(classes)
				tip = "%s  ·  Level %d%s" % [definition.display_name, level, "  ·  Class trial" if classes.in_trial() else ""]
				tip += "\nMax level" if progress[1] == HudXpBar.MAX_TEXT else "\n%s to level %d" % [progress[1], level + 1]
		elif bridge.class_runtime != null and bridge.class_runtime.pressure > 0:
			shown = "x%d" % bridge.class_runtime.pressure
			tip = "Pressure x%d: consecutive hits raise your resource gain." % bridge.class_runtime.pressure
	visible = shown != ""
	tooltip_text = tip
	if shown != text:
		text = shown
		queue_redraw()


func _make_custom_tooltip(for_text: String) -> Object:
	return UiTheme.tooltip(for_text) if for_text != "" else null


func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var font := UiTheme.body_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var colour := UiTheme.PARCHMENT
	if kind == Kind.PRESSURE and bridge != null and bridge.resource_pool != null:
		colour = bridge.resource_pool.definition.color.lerp(UiTheme.PARCHMENT, 0.35)
	var baseline := Vector2(roundf((size.x - width) * 0.5), roundf((size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)
