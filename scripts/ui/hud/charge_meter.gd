class_name ChargeMeter
extends PanelContainer
## Heavy attack charge above the skill bar, only while RMB is held: the tier
## reached in words and a segmented bar (one segment per tier). Reads the
## player's CombatComponent; the world ring at the character stays as well.

var bridge: PlayerProgressionBridge

var _label: Label
var _segments: Segments


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", UiTheme.GAP)
	add_child(box)
	_label = UiTheme.styled("", &"SmallLabel")
	_label.add_theme_color_override(&"font_color", UiTheme.PARCHMENT)
	_label.custom_minimum_size = Vector2(150, 0)
	box.add_child(_label)
	_segments = Segments.new()
	box.add_child(_segments)
	visible = false


func _process(_delta: float) -> void:
	var player := bridge.player if bridge != null and bridge.is_bound() else null
	var combat := player.combat if player != null and is_instance_valid(player) else null
	visible = combat != null and combat.state == CombatComponent.State.CHARGING and combat.charging_attack != null \
		and combat.charging_attack.charge_profile != null
	if not visible:
		return
	var profile := combat.charging_attack.charge_profile
	var tier := combat.get_charge_tier_preview()
	var full: float = profile.tier_thresholds[profile.tier_thresholds.size() - 1] if not profile.tier_thresholds.is_empty() else 1.0
	_label.text = "Heavy: %s" % profile.tier_name(tier)
	_segments.tiers = profile.max_tier() + 1
	_segments.tier = tier
	_segments.progress = clampf(combat.charge_time / full, 0.0, 1.0)
	_segments.queue_redraw()


class Segments:
	extends Control

	var tiers: int = 3
	var tier: int = 0
	var progress: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(180, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gap := 4.0
		var width := (size.x - gap * (tiers - 1)) / maxf(1.0, tiers)
		for index in tiers:
			var rect := Rect2(Vector2(index * (width + gap), 2), Vector2(width, size.y - 4))
			draw_rect(rect, UiTheme.PANEL_INSET)
			if index <= tier:
				draw_rect(rect, UiTheme.BRONZE if index < tiers - 1 else UiTheme.WARNING)
			draw_rect(rect, UiTheme.BRONZE_DIM, false, 1.0)
		draw_rect(Rect2(Vector2(0, size.y - 2), Vector2(size.x * progress, 2)), UiTheme.PARCHMENT)
