class_name ItemIcon
extends Control
## Provisional procedural item icon (no art assets yet): a frame whose border
## pattern shows the rarity (colour AND pips, never colour alone) and a simple
## glyph for the item kind (blade, armour, ring, potion, ore ...). Replace with
## sprite icons later by setting `texture` - the frame stays.

const SIZE := Vector2(40, 40)
const K = ItemDefinition.SlotKind

var definition: ItemDefinition
## Optional sprite icon; drawn instead of the glyph when set.
var texture: Texture2D
var quantity: int = 1
var equipped: bool = false
## Item Integrity marks (drawn in the top right corner).
var favorite: bool = false
var locked: bool = false
## Rarity of the shown instance (Loot Foundation 1.0); RARITY_FROM_DEFINITION = the definition's.
var rarity: int = ItemInstance.RARITY_FROM_DEFINITION


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(item_definition: ItemDefinition, amount: int = 1, is_equipped: bool = false) -> ItemIcon:
	definition = item_definition
	quantity = amount
	equipped = is_equipped
	queue_redraw()
	return self


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, UiTheme.PANEL_INSET)
	if definition == null:
		draw_rect(rect, Color(UiTheme.BRONZE_DARK, 0.6), false, 1.0)
		return
	var shown := definition.rarity if rarity == ItemInstance.RARITY_FROM_DEFINITION else rarity as ItemDefinition.Rarity
	var color := UiTheme.rarity_color(shown)
	draw_rect(rect, Color(color, 0.85), false, 2.0)
	# rarity pips along the bottom edge
	for index in UiTheme.rarity_pips(shown):
		draw_rect(Rect2(Vector2(4 + index * 6, size.y - 6), Vector2(4, 3)), color)
	var center := size * 0.5 + Vector2(0, -2)
	var s := minf(size.x, size.y) / 40.0
	if texture != null:
		draw_texture_rect(texture, rect.grow(-5), false)
	else:
		_draw_glyph(center, s, color.lerp(UiTheme.PARCHMENT, 0.4))
	if quantity > 1:
		var text := str(quantity)
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION).x
		draw_string_outline(ThemeDB.fallback_font, Vector2(size.x - width - 3, size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(size.x - width - 3, size.y - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, UiTheme.PARCHMENT)
	if equipped:
		draw_rect(Rect2(Vector2(2, 2), Vector2(9, 9)), UiTheme.RESONANCE_DIM)
		draw_string(ThemeDB.fallback_font, Vector2(3, 10), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.PARCHMENT)
	if favorite:   # a bronze diamond
		var at := Vector2(size.x - 7, 7)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0)]), UiTheme.BRONZE)
	if locked:   # a small padlock
		var at := Vector2(size.x - (17 if favorite else 7), 8)
		draw_arc(at + Vector2(0, -2), 2.5, PI, TAU, 8, UiTheme.PARCHMENT, 1.5)
		draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 6)), UiTheme.PARCHMENT)


func _draw_glyph(c: Vector2, s: float, color: Color) -> void:
	match definition.slot_kind:
		K.ONE_HAND_WEAPON, K.TWO_HAND_WEAPON:
			var length := 13.0 if definition.slot_kind == K.ONE_HAND_WEAPON else 16.0
			draw_line(c + Vector2(-length, length) * s * 0.7, c + Vector2(length, -length) * s * 0.7, color, 3.0 * s)
			draw_line(c + Vector2(-9, 3) * s, c + Vector2(-3, 9) * s, color.darkened(0.2), 3.0 * s)
		K.SHIELD, K.OFF_HAND:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -10) * s, c + Vector2(9, -10) * s, c + Vector2(9, 1) * s, c + Vector2(0, 11) * s, c + Vector2(-9, 1) * s]), color.darkened(0.15))
		K.HEAD:
			draw_arc(c + Vector2(0, 3) * s, 10.0 * s, PI, TAU, 12, color, 3.0 * s)
			draw_line(c + Vector2(-11, 3) * s, c + Vector2(11, 3) * s, color, 3.0 * s)
		K.CHEST, K.SHOULDERS, K.BACK:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -8) * s, c + Vector2(-4, -11) * s, c + Vector2(4, -11) * s, c + Vector2(11, -8) * s, c + Vector2(8, 11) * s, c + Vector2(-8, 11) * s]), color.darkened(0.15))
		K.HANDS, K.WRISTS:
			draw_rect(Rect2(c + Vector2(-7, -6) * s, Vector2(14, 15) * s), color.darkened(0.15))
			for f in 3:
				draw_rect(Rect2(c + Vector2(-7 + f * 5, -11) * s, Vector2(3.5, 6) * s), color)
		K.BELT:
			draw_rect(Rect2(c + Vector2(-12, -3) * s, Vector2(24, 6) * s), color.darkened(0.15))
			draw_rect(Rect2(c + Vector2(-3, -4) * s, Vector2(6, 8) * s), color, false, 2.0)
		K.LEGS, K.FEET:
			draw_rect(Rect2(c + Vector2(-8, -10) * s, Vector2(6, 18) * s), color.darkened(0.15))
			draw_rect(Rect2(c + Vector2(2, -10) * s, Vector2(6, 18) * s), color.darkened(0.15))
		K.RING:
			draw_arc(c, 8.0 * s, 0.0, TAU, 20, color, 3.0 * s)
			draw_circle(c + Vector2(0, -8) * s, 3.0 * s, UiTheme.RESONANCE)
		K.NECK, K.TRINKET:
			draw_arc(c + Vector2(0, -4) * s, 9.0 * s, 0.2, PI - 0.2, 12, color, 2.0 * s)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2) * s, c + Vector2(5, 7) * s, c + Vector2(0, 12) * s, c + Vector2(-5, 7) * s]), UiTheme.RESONANCE)
		_:
			_draw_category_glyph(c, s, color)


func _draw_category_glyph(c: Vector2, s: float, color: Color) -> void:
	match definition.category:
		ItemDefinition.Category.CONSUMABLE:
			draw_circle(c + Vector2(0, 3) * s, 8.0 * s, Color("a84a42"))
			draw_rect(Rect2(c + Vector2(-3, -10) * s, Vector2(6, 6) * s), color)
		ItemDefinition.Category.QUEST:
			draw_rect(Rect2(c + Vector2(-10, -8) * s, Vector2(20, 16) * s), Color("8a6a40"))
			draw_rect(Rect2(c + Vector2(-10, -8) * s, Vector2(20, 16) * s), color, false, 2.0)
			draw_line(c + Vector2(-10, -2) * s, c + Vector2(10, -2) * s, color, 2.0)
		_:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 4) * s, c + Vector2(-4, -8) * s, c + Vector2(6, -9) * s, c + Vector2(10, 3) * s, c + Vector2(3, 10) * s]), color.darkened(0.2))
			draw_line(c + Vector2(-4, -8) * s, c + Vector2(3, 10) * s, Color(color.lightened(0.3), 0.6), 1.0)
