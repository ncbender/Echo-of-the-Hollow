class_name PlayerFrame
extends PanelContainer
## Bottom-left HUD frame: class and level, health (bar + numbers), class
## resource, the dash charges with their recharge, the defense state (Shift) in
## words, active skill buffs and weapon mastery. Read-only view of the bridge,
## the player's components and the class runtime - no gameplay values here.

const WIDTH := 400

var bridge: PlayerProgressionBridge

var _title: Label
var _health: ProgressBar
var _health_text: Label
var _resource: ProgressBar
var _resource_text: Label
var _dash: DashPips
var _defense: Label
var _buffs: Label
var _mastery: Label


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	add_child(box)
	_title = UiTheme.styled("", &"SmallLabel")
	_title.add_theme_color_override(&"font_color", UiTheme.BRONZE)
	box.add_child(_title)
	var health_row := _bar_with_text(18, UiTheme.HEALTH)
	_health = health_row.get_child(0) as ProgressBar
	_health_text = health_row.get_child(1) as Label
	box.add_child(health_row)
	var resource_row := _bar_with_text(12, UiTheme.RESONANCE)
	_resource = resource_row.get_child(0) as ProgressBar
	_resource_text = resource_row.get_child(1) as Label
	box.add_child(resource_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	row.add_child(UiTheme.styled("Dash", &"CaptionLabel"))
	_dash = DashPips.new()
	row.add_child(_dash)
	_defense = UiTheme.styled("", &"SmallLabel")
	_defense.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defense.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_defense)
	box.add_child(row)
	_buffs = UiTheme.styled("", &"SmallLabel")
	_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buffs.custom_minimum_size = Vector2(WIDTH - 24, 0)
	box.add_child(_buffs)
	_mastery = UiTheme.styled("", &"CaptionLabel")
	box.add_child(_mastery)


## A bar with its value written on top (never colour-only).
func _bar_with_text(height: float, color: Color) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, height)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := UiTheme.bar(height, color)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(bar)
	var text := UiTheme.styled("", &"CaptionLabel")
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override(&"font_color", UiTheme.PARCHMENT)
	text.add_theme_constant_override(&"outline_size", 4)
	text.add_theme_font_size_override(&"font_size", 13 if height < 16 else UiTheme.FONT_CAPTION)
	stack.add_child(text)
	return stack


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound() and is_instance_valid(bridge.player)
	if visible:
		refresh()


func refresh() -> void:
	var player := bridge.player
	var character := bridge.character
	var classes := character.classes
	var definition := classes.get_active_definition()
	_title.text = "%s  ·  Level %d%s" % [definition.display_name if definition else "-", classes.get_level(classes.active_class_id),
		"  ·  Class trial" if classes.in_trial() else ""]
	_health.max_value = maxf(1.0, player.health.max_health)
	_health.value = player.health.health
	_health_text.text = "%d / %d" % [ceili(player.health.health), roundi(player.health.max_health)]
	var pool := bridge.resource_pool
	_resource.get_parent().visible = pool != null
	if pool != null:
		_resource.max_value = maxf(1.0, pool.max_value())
		_resource.value = pool.value
		_resource.add_theme_stylebox_override(&"fill", UiTheme.fill_box(pool.definition.color))
		_resource_text.text = "%s %d / %d%s" % [pool.definition.display_name, roundi(pool.value), roundi(pool.max_value()),
			"  ·  Pressure x%d" % bridge.class_runtime.pressure if bridge.class_runtime.pressure > 0 else ""]
	_dash.charges = player.dash.charges
	_dash.max_charges = player.dash.config.max_charges
	_dash.recharge = player.dash.get_recharge_progress()
	_dash.queue_redraw()
	_defense.text = defense_text(player.defense)
	_defense.add_theme_color_override(&"font_color", UiTheme.RESONANCE if player.defense.counter_left > 0.0 or player.defense.state != DefenseComponent.State.IDLE else UiTheme.TEXT_SECONDARY)
	var buffs: PackedStringArray = []
	for key: StringName in bridge.class_runtime.buffs:
		var left := bridge.class_runtime.buff_left(key)
		if left > 0.0:
			buffs.append("%s %ds" % [String(key).trim_prefix("buff:").capitalize(), ceili(left)])
	_buffs.text = "Active: %s" % ", ".join(buffs) if not buffs.is_empty() else ""
	_buffs.visible = not buffs.is_empty()
	var family_id := bridge.current_family_id()
	var family: WeaponFamily = character.database.weapons.get(family_id)
	_mastery.text = "%s mastery  ·  Level %d" % [family.display_name if family != null else String(family_id), character.mastery.get_level(family_id)]


## The Shift defense in words (state, counter window, cooldown).
static func defense_text(defense: DefenseComponent) -> String:
	if defense == null:
		return ""
	if defense.counter_left > 0.0:
		return "COUNTER - strike now!"
	match defense.state:
		DefenseComponent.State.PARRY:
			return "Parry window"
		DefenseComponent.State.BLOCK:
			return "Blocking"
		DefenseComponent.State.RECOVERY:
			return "Recovering"
	var guard := defense.profile()
	if guard == null:
		return ""
	return "Shift: %s" % guard.display_name if defense.cooldown_left <= 0.0 else "Parry ready in %.1fs" % defense.cooldown_left


## Dash charges as pips; the next charge fills up while it recharges.
class DashPips:
	extends Control

	var charges: int = 0
	var max_charges: int = 2
	var recharge: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(70, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var width := 28.0
		for index in max_charges:
			var rect := Rect2(Vector2(index * (width + 6), 2), Vector2(width, 10))
			draw_rect(rect, UiTheme.PANEL_INSET)
			if index < charges:
				draw_rect(rect, UiTheme.RESONANCE)
			elif index == charges:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x * recharge, rect.size.y)), UiTheme.RESONANCE_DIM)
			draw_rect(rect, UiTheme.BRONZE_DIM, false, 1.0)
