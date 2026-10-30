class_name MapPainter
extends RefCounted
## Shared drawing of the minimap and the area map (Map & Fog of War 1.0): the map picture and
## its fog for a world rectangle, markers and the player arrow - reduced, flat, pixel-sharp
## glyphs. Pure drawing on a CanvasItem. Map Markers Pixel Art 1.0: the map/* art (16 x 16) is drawn
## 1:1 on whole pixels (never stretched); without the files the procedural glyphs below are drawn.

## Size of the marker art (design px) - drawn 1:1, centred on the spot.
const MARKER_SIZE := 16.0


## Draws the part of the map picture (and fog) inside `view` (world px) at `scale`.
static func draw_area(canvas: CanvasItem, area: AreaMap, fog: MapFog, view: Rect2, scale: float) -> void:
	var shown := view.intersection(area.bounds)
	if not shown.has_area():
		return
	var dest := Rect2((shown.position - view.position) * scale, shown.size * scale)
	var src := Rect2((shown.position - area.bounds.position) / AreaMap.PIXEL, shown.size / AreaMap.PIXEL)
	canvas.draw_texture_rect_region(area.texture, dest, src)
	if fog != null:
		var fog_src := Rect2((shown.position - fog.bounds.position) / MapFog.CELL, shown.size / MapFog.CELL)
		canvas.draw_texture_rect_region(fog.texture, dest, fog_src)


static func draw_player(canvas: CanvasItem, at: Vector2, facing: Vector2, radius: float) -> void:
	var dir := facing.normalized() if facing.length() > 0.01 else Vector2.UP
	var art := UiSkin.texture(&"map/player")   # optional arrow art pointing up, turned to the facing
	if art != null:
		# 1:1 (the radius only sizes the procedural arrow) and turned in 90 degree steps: any other angle
		# frays nearest-filtered pixel art (45 degrees too, checked at 75 %); four directions show the facing
		var angle := snappedf(dir.angle() + PI * 0.5, PI * 0.5)
		canvas.draw_set_transform(at.round(), angle)
		canvas.draw_texture_rect(art, Rect2(-Vector2.ONE * MARKER_SIZE * 0.5, Vector2.ONE * MARKER_SIZE), false)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var side := dir.orthogonal()
	var tip := at + dir * radius
	var points := PackedVector2Array([tip, at - dir * radius * 0.7 + side * radius * 0.7, at - dir * radius * 0.3,
		at - dir * radius * 0.7 - side * radius * 0.7])
	canvas.draw_colored_polygon(points, UiTheme.MAP_PLAYER)
	canvas.draw_polyline(points + PackedVector2Array([tip]), Color.BLACK, 1.0)


## Where the marker art goes for the spot `at` on a picture of `area` size: 1:1 (16 x 16), on whole pixels
## (texel 8, 8 = the spot), kept inside the picture (exits sit on its edge).
static func marker_rect(at: Vector2, area: Vector2) -> Rect2:
	var half := MARKER_SIZE * 0.5
	var spot := at.round().clamp(Vector2.ONE * half, (area - Vector2.ONE * half).max(Vector2.ONE * half))
	return Rect2(spot - Vector2.ONE * half, Vector2.ONE * MARKER_SIZE)


## One marker glyph at `at`; with `labelled` its name beside it (area map).
static func draw_marker(canvas: Control, marker: Dictionary, at: Vector2, labelled: bool) -> void:
	var quest: bool = marker.get("quest", false)
	var ink := UiTheme.MAP_GOAL if quest else UiTheme.PARCHMENT
	var silent: bool = marker.kind == MapMarkers.WAYSTONE and str(marker.label).ends_with("(silent)")
	var art := UiSkin.texture(StringName("map/%s%s" % [marker.kind, "_silent" if silent else ""]))   # optional 16 x 16 art
	if art != null:
		canvas.draw_texture_rect(art, marker_rect(at, canvas.size), false)
	else:
		_draw_glyph(canvas, marker, at, ink, quest)
	if quest and marker.kind != MapMarkers.QUEST:
		canvas.draw_arc(at, 8.0, 0.0, TAU, 14, UiTheme.MAP_GOAL, 1.0)
	_draw_label(canvas, marker, at, ink, labelled)


static func _draw_glyph(canvas: Control, marker: Dictionary, at: Vector2, ink: Color, quest: bool) -> void:
	match marker.kind:
		MapMarkers.EXIT:
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(5, 0), at + Vector2(0, 5), at + Vector2(-5, 0)]),
				UiTheme.MAP_EXIT if not quest else ink)
		MapMarkers.WAYSTONE:
			canvas.draw_rect(Rect2(at + Vector2(-3, -6), Vector2(6, 12)), UiTheme.MAP_WAYSTONE if not str(marker.label).ends_with("(silent)") else UiTheme.MAP_WAYSTONE_SILENT)
		MapMarkers.REST:
			canvas.draw_circle(at, 3.5, UiTheme.MAP_REST)
		MapMarkers.NPC:
			canvas.draw_circle(at, 4.0, UiTheme.MAP_NPC)
		MapMarkers.LANDMARK:
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), UiTheme.MAP_LANDMARK)
		_:
			canvas.draw_circle(at, 4.5, Color(ink, 0.35))
			canvas.draw_arc(at, 4.5, 0.0, TAU, 12, ink, 1.5)


static func _draw_label(canvas: Control, marker: Dictionary, at: Vector2, ink: Color, labelled: bool) -> void:
	var note := str(marker.get("note", ""))
	if note != "" or labelled:
		var font := canvas.get_theme_default_font()
		var text := note if not labelled else str(marker.label) + ("  " + note if note != "" else "")
		if text.strip_edges() != "":
			# right of the glyph; flipped left / kept inside at the picture's edges (never cut off)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION).x
			var pos := at + Vector2(8, 4)
			if pos.x + width > canvas.size.x - 2.0:
				pos.x = maxf(2.0, at.x - 8.0 - width)
			pos.y = clampf(pos.y, float(UiTheme.FONT_CAPTION), canvas.size.y - 4.0)
			canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, 3, Color.BLACK)
			canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, ink)
