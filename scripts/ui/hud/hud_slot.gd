class_name HudSlot
extends Control
## One square slot of the combat bar (UI Layout Lock 1.0; Combat HUD UX 2.0, docs/COMBAT_HUD_UX_2_0.md): the
## icon (skill art, else a procedural glyph), the key in the top-left corner, the cooldown as a darkening that
## runs down from the top with its seconds - no permanent text ("Empty", "None", "8 Mana" are gone; name,
## costs and reasons are in the hover tooltip). An empty slot is a quiet frame with its key. A skill the
## resource cannot pay is dimmed with a thin bar of the resource it has towards the cost. The quick-use slots
## show a bottle (hud/flask, hud/potion) whose liquid level is `fill` - the charges or the stack, never a number;
## an empty bottle is dark. Pure presentation: the bars set every value.

enum Glyph { EMPTY, SKILL, FLASK, POTION }

const SIZE := UiTheme.HUD_SLOT_SIZE
## Bottle art position in the slot (40 x 48, a little low: the key sits top left).
const BOTTLE_AT := Vector2(12, 10)

var key: String = ""
var glyph: Glyph = Glyph.EMPTY
var glyph_color: Color = UiTheme.TEXT_MUTED
## Letter drawn in a skill glyph (first letter of the skill's name).
var letter: String = ""
## Optional icon art (UiSkin: skills/<id>); drawn instead of the skill glyph.
var icon: Texture2D
## 0 = ready, 1 = the whole cooldown is still ahead.
var cooldown_ratio: float = 0.0
## False: drawn dimmed (the tooltip says why).
var usable: bool = true
## Bottles: share of the liquid 0..1 (0 = empty bottle).
var fill: float = 0.0
## Skills the resource cannot pay: share of the cost the pool holds (< 0 = no cost bar), in `cost_color`.
var cost_ratio: float = -1.0
var cost_color: Color = UiTheme.RESONANCE

var _key_label: Label
var _status: Label


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP   # tooltips; a click here never reaches the player
	_key_label = UiTheme.styled("", &"CaptionLabel")
	_key_label.position = Vector2(5, 1)
	_key_label.add_theme_color_override(&"font_color", UiTheme.BRONZE)
	_key_label.add_theme_constant_override(&"outline_size", 4)
	_key_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key_label)
	_status = UiTheme.styled("", &"CaptionLabel")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	_status.position = Vector2(2, SIZE.y - 21)
	_status.size = Vector2(SIZE.x - 4, 18)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_constant_override(&"outline_size", 4)
	_status.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_status)


## Transient word over the slot - only the running cooldown ("2.1s"); "" = nothing. Bottles keep it in the
## top-right corner, so it never covers the liquid.
func set_status(text: String, color: Color = UiTheme.WARNING) -> void:
	_status.text = text
	_status.add_theme_color_override(&"font_color", color)
	var corner := glyph == Glyph.FLASK or glyph == Glyph.POTION
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if corner else HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(2, 1) if corner else Vector2(2, SIZE.y - 21)
	_status.size = Vector2(SIZE.x - 7, 18) if corner else Vector2(SIZE.x - 4, 18)


func status_text() -> String:
	return _status.text


func _process(_delta: float) -> void:
	_key_label.text = key
	_key_label.add_theme_color_override(&"font_color", UiTheme.BRONZE if glyph != Glyph.EMPTY else UiTheme.TEXT_MUTED)
	queue_redraw()


func _make_custom_tooltip(for_text: String) -> Object:
	return UiTheme.tooltip(for_text) if for_text != "" else null


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var quiet := glyph == Glyph.EMPTY   # an empty slot: the frame only, a step darker
	var frame := UiSkin.texture(&"hud/slot_frame" if usable and not quiet else &"hud/slot_frame_disabled")
	var frame_tint := Color.WHITE
	if frame == null and (quiet or not usable):   # no disabled art yet: the slot frame, dimmed (one look per bar)
		frame = UiSkin.texture(&"hud/slot_frame")
		frame_tint = Color(0.6, 0.6, 0.6)
	if frame != null:
		draw_texture_rect(frame, rect, false, Color(frame_tint, 0.7) if quiet else frame_tint)
	else:
		draw_rect(rect, UiTheme.COLOR_PANEL)
		draw_rect(rect, UiTheme.BRONZE_DARK if usable and not quiet else UiTheme.PANEL_ELEVATED, false, 2.0)
	if glyph == Glyph.FLASK or glyph == Glyph.POTION:
		_draw_cooldown()   # behind the bottle: the liquid stays readable during the cooldown
		_draw_bottle()
		return
	var centre := Vector2(size.x * 0.5, size.y * 0.5 - 4.0)
	var tint := glyph_color if usable else glyph_color.darkened(0.45)
	if icon != null and glyph == Glyph.SKILL:
		draw_texture_rect(icon, Rect2(centre - Vector2(20, 20), Vector2(40, 40)), false, Color.WHITE if usable else Color(0.5, 0.5, 0.5))
	elif glyph == Glyph.SKILL:
		draw_circle(centre, 15.0, Color(tint, 0.25))
		draw_arc(centre, 15.0, 0.0, TAU, 28, tint, 2.0)
		var font := UiTheme.display_font()
		var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_HEADING)
		draw_string(font, centre + Vector2(-text_size.x * 0.5, text_size.y * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_HEADING, tint)
	_draw_cost()
	_draw_cooldown()


## The bottle with its liquid: art when present, else a drawn bottle with the same fill rule.
func _draw_bottle() -> void:
	var round_body := glyph == Glyph.POTION
	var frame_id := &"hud/potion" if round_body else &"hud/flask"
	var mask_id := &"hud/potion_fill" if round_body else &"hud/flask_fill"
	var liquid := glyph_color if usable else glyph_color.darkened(0.35)
	if HudFillArt.available(frame_id, mask_id):
		HudFillArt.draw(self, BOTTLE_AT, frame_id, mask_id, fill, liquid, 3, fill <= 0.0)
		return
	var body := Rect2(BOTTLE_AT + Vector2(6, 14), Vector2(28, 32))
	draw_rect(Rect2(BOTTLE_AT + Vector2(15, 4), Vector2(10, 10)), UiTheme.TEXT_MUTED)
	draw_rect(body, UiTheme.PANEL_INSET)
	if fill > 0.0:
		var height := maxf(3.0, roundf(body.size.y * fill))
		draw_rect(Rect2(body.position + Vector2(0, body.size.y - height), Vector2(body.size.x, height)), liquid)
	draw_rect(body, UiTheme.TEXT_SECONDARY if fill > 0.0 else UiTheme.TEXT_MUTED, false, 2.0)


## A skill the pool cannot pay: a thin bar at the bottom - how much of the cost is there, in the resource colour.
func _draw_cost() -> void:
	if cost_ratio < 0.0:
		return
	var bar := Rect2(Vector2(8, size.y - 10), Vector2(size.x - 16, 4))
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.85))
	draw_rect(bar, UiTheme.PANEL_INSET)
	draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * clampf(cost_ratio, 0.0, 1.0)), bar.size.y)), cost_color)


func _draw_cooldown() -> void:
	if cooldown_ratio <= 0.0:
		return
	var rect := Rect2(Vector2(2, 2), Vector2(size.x - 4, (size.y - 4) * clampf(cooldown_ratio, 0.0, 1.0)))
	var art := UiSkin.texture(&"hud/cooldown")   # optional dark overlay, cut to the remaining part
	if art != null:
		draw_texture_rect_region(art, rect, Rect2(Vector2.ZERO, Vector2(art.get_size().x, art.get_size().y * clampf(cooldown_ratio, 0.0, 1.0))))
	else:
		draw_rect(rect, Color(0, 0, 0, 0.55))
