extends TestCase
## Map Markers Pixel Art 1.0 (docs/MAP_MARKERS_PIXEL_ART_1_0.md): every marker kind MapMarkers produces (and
## the player) has its 16 x 16 art, awake and silent waystones keep their own art, the art is drawn 1:1 on
## whole pixels inside the picture, the player arrow turns in 90 degree steps. Which markers exist and where
## (explored spots only) stays MapMarkers' job - test_map_fog.


func test_every_marker_kind_has_its_art() -> void:
	for kind: StringName in [MapMarkers.EXIT, MapMarkers.WAYSTONE, MapMarkers.REST, MapMarkers.NPC, MapMarkers.LANDMARK, MapMarkers.QUEST]:
		var art := UiSkin.texture(StringName("map/%s" % kind))
		check(art != null and art.get_size() == Vector2(MapPainter.MARKER_SIZE, MapPainter.MARKER_SIZE), "map/%s: 16 x 16" % kind)
	for extra: StringName in [&"map/waystone_silent", &"map/player"]:
		var art := UiSkin.texture(extra)
		check(art != null and art.get_size() == Vector2(16, 16), "%s: 16 x 16" % extra)
	check(UiSkin.texture(&"map/waystone") != UiSkin.texture(&"map/waystone_silent"), "awake and silent waystones differ")


func test_markers_are_drawn_one_to_one_inside_the_picture() -> void:
	var area := Vector2(120, 80)
	for spot: Vector2 in [Vector2(40.4, 30.6), Vector2(0, 0), Vector2(119.7, 79.9)]:
		var rect := MapPainter.marker_rect(spot, area)
		check(rect.size == Vector2(16, 16), "drawn 1:1 (%s)" % rect.size)
		check(rect.position == rect.position.round(), "on whole pixels (%s)" % rect.position)
		check(Rect2(Vector2.ZERO, area).encloses(rect), "inside the picture at %s (%s)" % [spot, rect])
	check(MapPainter.marker_rect(Vector2(40.4, 30.6), area).get_center() == Vector2(40, 31), "centred on the rounded spot")


func test_player_arrow_turns_in_right_angles() -> void:
	for facing: Vector2 in [Vector2.UP, Vector2(1, -0.2), Vector2(-0.3, 1), Vector2(-1, -1.2)]:
		var angle := snappedf(facing.normalized().angle() + PI * 0.5, PI * 0.5)
		check(is_equal_approx(fposmod(angle, PI * 0.5), 0.0) or is_equal_approx(fposmod(angle, PI * 0.5), PI * 0.5), "%s -> a right angle" % facing)

