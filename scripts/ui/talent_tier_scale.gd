class_name TalentTierScale
extends Control
## Tier scale left of the shown talent tree (Skills & Talents UX 2.0 Phase 2): per tier row "Tier n", the
## points it needs in the lower tiers of the tree, and whether it is open for the build ("Open" / "a/b").
## Same rows as the TalentTreeView (TalentLayout).

var rules: TalentRules
var layout: TalentLayout
## Points the build has in the lower tiers of the shown tree, per tier 1..TIERS.
var spent_below: Array[int] = []


func setup(talent_rules: TalentRules) -> void:
	rules = talent_rules
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "A tier opens once enough points are spent in the lower tiers of this tree; every talent of an open tier can be chosen."
	apply(TalentLayout.new())


func apply(target: TalentLayout) -> void:
	layout = target
	custom_minimum_size = Vector2(TalentLayout.SCALE_WIDTH, layout.height())
	size = custom_minimum_size
	queue_redraw()


## Points of `talents` below every tier of `tree`.
func set_progress(talents: Dictionary, tree: TalentTreeDefinition) -> void:
	spent_below.clear()
	for tier in range(1, TalentLayout.TIERS + 1):
		spent_below.append(TalentService.points_in_tree(talents, tree, tier))
	queue_redraw()


## "Open" or "a/b" (points below / needed) for `tier`.
func progress_text(tier: int) -> String:
	var needed := rules.tier_requirement(tier)
	var spent: int = spent_below[tier - 1] if tier - 1 < spent_below.size() else 0
	return "Open" if spent >= needed else "%d/%d" % [spent, needed]


func _draw() -> void:
	if layout == null or rules == null:
		return
	var font := get_theme_font(&"font", &"Label")
	for tier in range(1, TalentLayout.TIERS + 1):
		var top := layout.row_top(tier)
		var needed := rules.tier_requirement(tier)
		var open := tier - 1 < spent_below.size() and spent_below[tier - 1] >= needed
		draw_string(font, Vector2(0, top + 18), "Tier %d" % tier, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.BRONZE)
		draw_string(font, Vector2(0, top + 36), "%d pts" % needed, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, UiTheme.TEXT_SECONDARY)
		draw_string(font, Vector2(0, top + 54), progress_text(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, UiTheme.SUCCESS if open else UiTheme.WARNING)
		draw_line(Vector2(size.x - 6, top + 4), Vector2(size.x - 6, top + layout.row_height - 4), Color(UiTheme.BRONZE_DARK, 0.8), 1.0)
