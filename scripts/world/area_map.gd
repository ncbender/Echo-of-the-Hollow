class_name AreaMap
extends RefCounted
## The simplified 2D picture of one map for the minimap and the area map (Map & Fog of War
## 1.0, docs/MAP_AND_FOG_OF_WAR_1_0.md). Built once from the scene's real geometry - every
## ArenaFloor area (floor, side paths, main road) and every visible WallBlock (forest, walls,
## story barriers) - into a small image, one pixel per PIXEL world px. Rebuilt only when a
## story flag changes (a barrier opened or closed), never per frame.
## World -> map: pixel = (world - bounds.position) / PIXEL.

const PIXEL := 8.0
const ARENA_FLOOR_SCRIPT := "res://scripts/arena/arena_floor.gd"
## Raster colours (also the classes read back by is_solid - keep every pair > 0.01 apart).
## UI Core States & Map Palette 1.0: FLOOR / WALL neutral to the UI's Charcoal / Slate (were green,
## #334036 / #171F1A), contrasts kept: floor : wall 1.56, wall : unexplored 1.19 (docs/UI_CORE_STATES_1_0.md).
const VOID := Color(0.04, 0.045, 0.05, 1.0)
const FLOOR := Color(0.225, 0.24, 0.265, 1.0)   # #393D44
const SIDE := Color(0.33, 0.3, 0.23, 1.0)
const ROAD := Color(0.47, 0.4, 0.29, 1.0)
const WALL := Color(0.105, 0.11, 0.127, 1.0)   # #1B1C20

## World rectangle the picture covers (camera_bounds, else the floors, else spawn_area).
var bounds: Rect2
var image: Image
var texture: ImageTexture
var width: int = 0
var height: int = 0


func _init(map: Node2D = null) -> void:
	if map != null:
		build(map)


## The world rectangle of `map`: its camera bounds (large maps), else the union of its
## floor areas (small maps), else its debug spawn area - never an empty map.
static func bounds_of(map: Node2D) -> Rect2:
	var camera: Variant = map.get(&"camera_bounds")
	if camera is Rect2 and (camera as Rect2).has_area():
		return camera
	var union := Rect2()
	for floor in floors_of(map):
		var rect := floor_rect(floor)
		union = rect if not union.has_area() else union.merge(rect)
	if union.has_area():
		return union.grow(16.0)
	var spawn: Variant = map.get(&"spawn_area")
	return (spawn as Rect2).grow(64.0) if spawn is Rect2 else Rect2(-320, -180, 640, 360)


static func floors_of(map: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for node in map.find_children("*", "Node2D", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path == ARENA_FLOOR_SCRIPT:
			result.append(node as Node2D)
	return result


## Global rectangle of an ArenaFloor's area (nested, translated nodes included).
static func floor_rect(floor: Node2D) -> Rect2:
	var area: Rect2 = floor.get(&"area")
	return floor.global_transform * area


## Global rectangle of a WallBlock (centred on its position).
static func wall_rect(wall: WallBlock) -> Rect2:
	return wall.global_transform * Rect2(-wall.size * 0.5, wall.size)


## (Re)draws the picture from the scene as it is now. Floors first, then side paths and the
## main road on top, then every wall that is visible (an open story barrier is hidden, so it
## disappears from the map too).
func build(map: Node2D) -> void:
	bounds = bounds_of(map)
	width = maxi(1, ceili(bounds.size.x / PIXEL))
	height = maxi(1, ceili(bounds.size.y / PIXEL))
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(VOID)
	var floors := floors_of(map)
	for layer in [FLOOR, SIDE, ROAD]:
		for floor in floors:
			if shown(floor, map) and _floor_class(floor) == layer:
				image.fill_rect(_to_px(floor_rect(floor)), layer)
	for node in map.find_children("*", "WallBlock", true, false):
		var wall := node as WallBlock
		if shown(wall, map):
			image.fill_rect(_to_px(wall_rect(wall)), WALL)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.set_image(image)


## Visible within the map (the map root itself may be hidden while a travel fades in).
static func shown(node: Node, map: Node) -> bool:
	while node != null and node != map:
		var item := node as CanvasItem
		if item != null and not item.visible:
			return false
		node = node.get_parent()
	return true


static func _floor_class(floor: Node) -> Color:
	var parent := String(floor.get_parent().name)
	var name := String(floor.name)
	if parent == "MainRoad" or name.begins_with("Road") or name.begins_with("Path") or name == "Aisle":
		return ROAD
	if parent == "SidePaths" or name.begins_with("Side"):
		return SIDE
	return FLOOR


func _to_px(rect: Rect2) -> Rect2i:
	var from := ((rect.position - bounds.position) / PIXEL).floor()
	var to := ((rect.end - bounds.position) / PIXEL).ceil()
	return Rect2i(Vector2i(from), Vector2i(to - from)).intersection(Rect2i(0, 0, width, height))


## Map-picture pixel of a world position (may lie outside the picture).
func to_pixel(world: Vector2) -> Vector2:
	return (world - bounds.position) / PIXEL


## True where the player cannot stand: a wall, a closed barrier or outside every floor.
func is_solid(world: Vector2) -> bool:
	var px := Vector2i(to_pixel(world).floor())
	if px.x < 0 or px.y < 0 or px.x >= width or px.y >= height:
		return true
	var colour := image.get_pixelv(px)   # the image stores RGBA8: compare with a tolerance
	return _near(colour, WALL) or _near(colour, VOID)


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
