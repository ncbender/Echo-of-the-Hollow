class_name AreaMinimap
extends Control
## The minimap in the top-right MinimapFrame (Map & Fog of War 1.0): north up, VIEW_WORLD
## world px around the player, clamped to the map's bounds - at an edge the view stops and
## the player arrow moves off the centre instead. Draws the map picture (AreaMap), the fog
## (MapFog: unexplored dark, explored dimmed, the near range lit as a ring), the explored
## markers (MapMarkers) and the player arrow in its facing (Player.aim_direction).
## Reads only; markers are collected a few times per second, the pictures never per frame.

const VIEW_WORLD := 1024.0
const MARKER_REFRESH := 0.25

var map: GameMap
var _markers: Array[Dictionary] = []
var _since_markers: float = 999.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func bind(target: GameMap) -> void:
	map = target
	_markers.clear()
	_since_markers = 999.0


func is_bound() -> bool:
	return map != null and is_instance_valid(map) and map.area_map != null


## World rectangle shown now: VIEW_WORLD around `centre`, kept inside `bounds` (a map smaller
## than the view is centred).
static func view_rect(bounds: Rect2, centre: Vector2, view: Vector2) -> Rect2:
	var origin := centre - view * 0.5
	for axis in 2:
		if bounds.size[axis] <= view[axis]:
			origin[axis] = bounds.get_center()[axis] - view[axis] * 0.5
		else:
			origin[axis] = clampf(origin[axis], bounds.position[axis], bounds.end[axis] - view[axis])
	return Rect2(origin, view)


func current_view() -> Rect2:
	var view := Vector2(VIEW_WORLD, VIEW_WORLD * size.y / maxf(size.x, 1.0))
	return view_rect(map.area_map.bounds, map.player.global_position, view)


## Control position of a world point in the current view.
func world_to_minimap(world: Vector2) -> Vector2:
	var view := current_view()
	return (world - view.position) * (size.x / view.size.x)


func _process(delta: float) -> void:
	if not is_bound():
		return
	_since_markers += delta
	if _since_markers >= MARKER_REFRESH:
		_since_markers = 0.0
		_markers = MapMarkers.collect(map, map.session.get_character() if map.session != null else null, map.fog)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), AreaMap.VOID)
	if not is_bound():
		return
	var view := current_view()
	var zoom_factor := size.x / view.size.x
	MapPainter.draw_area(self, map.area_map, map.fog, view, zoom_factor)
	if map.fog != null:   # the near range: explored around the player right now
		draw_arc(world_to_minimap(map.player.global_position), MapFog.RADIUS * MapFog.CELL * zoom_factor, 0.0, TAU, 32,
			Color(UiTheme.PARCHMENT, 0.18), 1.0)
	for marker in _markers:
		MapPainter.draw_marker(self, marker, (marker.position - view.position) * zoom_factor, false)
	MapPainter.draw_player(self, (map.player.global_position - view.position) * zoom_factor, map.player.aim_direction, 7.0)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BRONZE_DARK, false, 1.0)
