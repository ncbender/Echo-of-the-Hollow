class_name TalentLayout
extends RefCounted
## Sizes of the talent tree (Skills & Talents UX 2.0 Phase 2): ONE tree at a time, one row per tier
## (TalentRules.TIERS), TalentRules.COLUMNS card nodes per row. A node card is a fixed-height strip - icon
## tile left, the whole name (up to two lines) and "rank state" right - so the room left over goes into the
## gaps between the tiers, where the upgrade lines run. Below the smallest gap the tree area scrolls on its
## own (never the window).

const TIERS := TalentRules.TIERS
const SCALE_WIDTH := 70.0
const COLUMN_GAP := 12.0
const MIN_ROW_GAP := 14.0
const MAX_ROW_GAP := 56.0
const CARD_HEIGHT := 72.0
const CARD_PADDING := 4.0
## Skill art (40 x 40) 1:1 with a 1 px frame around it.
const TILE := 42.0
const NAME_LINES := 2
const NAME_LINE := 19.0
const RANK_HEIGHT := 16.0
const MIN_COLUMN := 140.0
const MAX_COLUMN := 240.0   # Menu UX Polish 1.0: the tree takes the whole width (no detail column)

var column_width: float = 150.0
var row_height: float = CARD_HEIGHT
## Room between two tier rows: the upgrade lines run here.
var row_gap: float = MIN_ROW_GAP


## Layout for `room` (width and height left for the tier scale and the tree).
static func pick(room: Vector2) -> TalentLayout:
	var result := TalentLayout.new()
	var columns := TalentRules.COLUMNS
	result.column_width = floorf(clampf((room.x - SCALE_WIDTH - COLUMN_GAP * (columns - 1)) / columns, MIN_COLUMN, MAX_COLUMN))
	result.row_gap = floorf(clampf((room.y - TIERS * CARD_HEIGHT) / (TIERS - 1), MIN_ROW_GAP, MAX_ROW_GAP))
	return result


func tree_width() -> float:
	return TalentRules.COLUMNS * column_width + (TalentRules.COLUMNS - 1) * COLUMN_GAP


func height() -> float:
	return TIERS * row_height + (TIERS - 1) * row_gap


func row_top(tier: int) -> float:
	return (tier - 1) * (row_height + row_gap)


## Left edge of a node card in `column` (fractional columns centre a lone node).
func column_left(column: float) -> float:
	return column * (column_width + COLUMN_GAP)


## Size of one node card: a column wide, a row high.
func card_size() -> Vector2:
	return Vector2(column_width, row_height)


## Size of the whole tree row: tier scale + tree.
func content_size() -> Vector2:
	return Vector2(SCALE_WIDTH + tree_width(), height())
