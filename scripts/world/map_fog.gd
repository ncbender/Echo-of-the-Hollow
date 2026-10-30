class_name MapFog
extends RefCounted
## Fog of war of one map (Map & Fog of War 1.0, docs/MAP_AND_FOG_OF_WAR_1_0.md): a grid of
## CELL world px, one bit per cell (explored or not), stored in the character's WorldState as
## map state "fog" = "v1:<w>x<h>:<base64>" - no save schema change (Save v15).
## Cells are explored only by the player's real movement: from the player's cell a
## breadth-first search walks at most RADIUS cells (Euclidean) through passable cells. A step
## between two cells is blocked when the straight line between their centres crosses a wall,
## a closed barrier or void (AreaMap.is_solid); the blocked cell itself is still explored -
## it is the wall the player sees - but the search never continues behind it. So a room
## behind a wall stays dark although it lies inside the radius. This is NOT a line-of-sight
## test: around a corner the search follows the free cells up to the radius.

const CELL := 32.0
## Search radius in cells (6 = 192 world px: the near half of the 512 x 288 view at zoom 3.75).
const RADIUS := 6
const FORMAT := "v1"
const STATE_KEY := "fog"
const DARK := Color(0.02, 0.022, 0.03, 1.0)
const DIM := Color(0.0, 0.0, 0.0, 0.32)

static var _base64 := RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$")

var bounds: Rect2
var width: int = 0
var height: int = 0
var bits := PackedByteArray()
## Small image (one pixel per cell) drawn over the map picture; updated per explored cell.
var image: Image
var texture: ImageTexture
## Why a stored state was discarded on load ("" = loaded or new).
var load_warning: String = ""


func _init(map_bounds: Rect2 = Rect2()) -> void:
	if map_bounds.has_area():
		setup(map_bounds)


func setup(map_bounds: Rect2) -> void:
	bounds = map_bounds
	width = maxi(1, ceili(bounds.size.x / CELL))
	height = maxi(1, ceili(bounds.size.y / CELL))
	bits = PackedByteArray()
	bits.resize(ceili(width * height / 8.0))
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(DARK)
	texture = ImageTexture.create_from_image(image)


func cell_of(world: Vector2) -> Vector2i:
	return Vector2i(((world - bounds.position) / CELL).floor())


func cell_centre(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_explored(cell: Vector2i) -> bool:
	if not in_grid(cell):
		return false
	var index := cell.y * width + cell.x
	return bits[index >> 3] & (1 << (index & 7)) != 0


func is_explored_at(world: Vector2) -> bool:
	return is_explored(cell_of(world))


func explored_count() -> int:
	var count := 0
	for index in width * height:
		if bits[index >> 3] & (1 << (index & 7)) != 0:
			count += 1
	return count


func _mark(cell: Vector2i) -> bool:
	if not in_grid(cell) or is_explored(cell):
		return false
	var index := cell.y * width + cell.x
	bits[index >> 3] = bits[index >> 3] | (1 << (index & 7))
	image.set_pixelv(cell, DIM)
	return true


## Explores the cells around `world` (see the class comment). Returns the number of newly
## explored cells; the texture is updated only when something changed.
func reveal(world: Vector2, area: AreaMap) -> int:
	var start := cell_of(world)
	if not in_grid(start):
		return 0
	var added := 1 if _mark(start) else 0
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next := cell + step
			if seen.has(next) or not in_grid(next) or Vector2(next - start).length() > RADIUS:
				continue
			seen[next] = true
			if _mark(next):
				added += 1
			if area == null or _passable(cell, next, area):
				queue.append(next)
	if added > 0:
		texture.update(image)
	return added


## Straight line between the two cell centres free of walls (four samples, 8 px apart).
func _passable(from: Vector2i, to: Vector2i, area: AreaMap) -> bool:
	var a := cell_centre(from)
	var b := cell_centre(to)
	for k in range(1, 5):
		if area.is_solid(a.lerp(b, k / 4.0)):
			return false
	return true


# --- persistence ----------------------------------------------------------------------------------

func encode() -> String:
	return "%s:%dx%d:%s" % [FORMAT, width, height, Marshalls.raw_to_base64(bits)]


## Loads a stored state of this map. A missing state starts dark; a malformed one or one of
## another grid size (the map was rebuilt) is discarded with `load_warning` - never applied
## half, never a crash. Returns true if a state was applied.
func decode(stored: Variant) -> bool:
	load_warning = ""
	if stored == null or str(stored) == "":
		return false
	var parts := str(stored).split(":", true, 2)
	if parts.size() != 3 or parts[0] != FORMAT:
		load_warning = "fog: unknown format, map starts unexplored"
		return false
	var size := parts[1].split("x")
	if size.size() != 2 or not size[0].is_valid_int() or not size[1].is_valid_int() \
			or int(size[0]) != width or int(size[1]) != height:
		load_warning = "fog: grid %s does not fit this map (%dx%d), map starts unexplored" % [parts[1], width, height]
		return false
	if parts[2].length() % 4 != 0 or not _base64.search(parts[2]):
		load_warning = "fog: damaged data, map starts unexplored"
		return false
	var data := Marshalls.base64_to_raw(parts[2])
	if data.size() != bits.size():
		load_warning = "fog: damaged data, map starts unexplored"
		return false
	bits = data
	for y in height:
		for x in width:
			image.set_pixel(x, y, DIM if is_explored(Vector2i(x, y)) else DARK)
	texture.update(image)
	return true


## Loads this map's state from the character's world (missing / invalid: unexplored).
## Returns true if a stored state was applied.
func load_from(world: WorldState, map_id: StringName) -> bool:
	var applied := decode(world.get_map_value(map_id, STATE_KEY, null))
	if not applied and load_warning != "":
		push_warning(load_warning)
	return applied


func store_in(world: WorldState, map_id: StringName) -> void:
	world.set_map_value(map_id, STATE_KEY, encode())
