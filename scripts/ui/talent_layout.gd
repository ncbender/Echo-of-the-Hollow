class_name TalentLayout
extends RefCounted
## Sizes of the talent page (Talent UI Polish 1.2), picked from the room the
## window has left: one row per tier, the same rows in every tree and in the
## TalentTierScale. "Normal" = nodes with their short name below; "compact" =
## icon nodes only (names in the tooltip) when the room is too low (150 % UI
## scale). Below the compact minimum the tree area scrolls (200 %).

const TIERS := 7
const HEADER := 46.0
const NAME_HEIGHT := 18.0
const SCALE_WIDTH := 56.0
const TREE_GAP := 20.0
const MIN_TREE_WIDTH := 250.0
const COMPACT_MIN_TREE_WIDTH := 190.0
const MAX_TREE_WIDTH := 560.0
const NORMAL_MIN_ROW := 78.0
const NORMAL_MAX_ROW := 118.0
const COMPACT_MIN_ROW := 50.0

var compact: bool = false
var tree_width: float = 300.0
var row_height: float = NORMAL_MIN_ROW
var node_size: float = 48.0


## Layout for `room` (width and height left for the tree row) and `trees` trees.
static func pick(room: Vector2, trees: int) -> TalentLayout:
	var result := TalentLayout.new()
	var count := maxi(1, trees)
	# whole pixels: a fractional sum would make the row a hair wider than the room
	result.tree_width = floorf(clampf((room.x - SCALE_WIDTH - TREE_GAP * count) / count, MIN_TREE_WIDTH, MAX_TREE_WIDTH))
	var row := floorf((room.y - HEADER) / TIERS)
	if row >= NORMAL_MIN_ROW:
		result.compact = false
		result.row_height = minf(row, NORMAL_MAX_ROW)
		result.node_size = clampf(result.row_height - NAME_HEIGHT - 16.0, 46.0, 64.0)
	else:
		result.compact = true
		result.row_height = maxf(row, COMPACT_MIN_ROW)
		result.node_size = clampf(result.row_height - 12.0, 38.0, 48.0)
		result.tree_width = floorf(clampf((room.x - SCALE_WIDTH - TREE_GAP * count) / count, COMPACT_MIN_TREE_WIDTH, MAX_TREE_WIDTH))
	return result


func height() -> float:
	return HEADER + TIERS * row_height


func row_top(tier: int) -> float:
	return HEADER + (tier - 1) * row_height


## Vertical node centre in its row (room for the name below in normal mode).
func node_center_y(tier: int) -> float:
	var block := node_size + (0.0 if compact else NAME_HEIGHT + 2.0)
	return row_top(tier) + (row_height - block) * 0.5 + node_size * 0.5


func name_width() -> float:
	return tree_width * 0.46


## Size of the whole tree row: tier scale + trees + gaps.
func content_size(trees: int) -> Vector2:
	return Vector2(SCALE_WIDTH + trees * tree_width + trees * TREE_GAP, height())
