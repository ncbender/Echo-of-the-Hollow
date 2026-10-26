class_name TalentTierScale
extends Control
## Shared tier scale left of the talent trees: "T1" ... "T7" with the points
## each tier needs in the lower tiers, on the same rows as every tree
## (TalentLayout), so one label serves all three columns.

var rules: TalentRules
var layout: TalentLayout


func setup(talent_rules: TalentRules) -> void:
	rules = talent_rules
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Tiers: a tier opens once enough points are spent in the lower tiers of the same tree."
	apply(TalentLayout.new())


func apply(target: TalentLayout) -> void:
	layout = target
	custom_minimum_size = Vector2(TalentLayout.SCALE_WIDTH, layout.height())
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if layout == null or rules == null:
		return
	var font := get_theme_font(&"font", &"Label")
	for tier in range(1, TalentLayout.TIERS + 1):
		var y := layout.node_center_y(tier)
		var tier_text := "T%d" % tier
		draw_string(font, Vector2(4, y - 2), tier_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.BRONZE)
		draw_string(font, Vector2(4, y + 15), "%d pts" % rules.tier_requirement(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_CAPTION, UiTheme.TEXT_MUTED)
		draw_line(Vector2(size.x - 8, layout.row_top(tier) + 6), Vector2(size.x - 8, layout.row_top(tier) + layout.row_height - 6), Color(UiTheme.BRONZE_DARK, 0.8), 1.0)
