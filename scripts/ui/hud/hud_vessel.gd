class_name HudVessel
extends Control
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): one of the two vessels beside the combat bar - health on
## the left (dark red), the active class's real resource on the right (its own colour, ClassResourceDefinition).
## A tall, angular well filled from the bottom to the current share, the current value as a number inside;
## name and maximum in the tooltip, no permanent "HP" / "Mana" label. A class without a resource (Basic
## Adventurer) shows the empty, dimmed vessel and says so in the tooltip - never a stand-in resource.
## Read-only view of the player's HealthComponent and the bridge's ClassResourcePool, every frame (damage,
## healing, spending, regeneration, class switch and loading all show without extra wiring).

enum Kind { HEALTH, RESOURCE }

const SIZE := Vector2(52, 66)
const FONT_SIZE := 14
## Health fill: dark red (UiTheme.HEALTH, a step darker).
const HEALTH_FILL := Color("9c3a32")

var kind: Kind = Kind.HEALTH
var bridge: PlayerProgressionBridge
## Shown share 0..1, number and colour; `has_value` false = no resource for this class.
var ratio: float = 0.0
var value_text: String = ""
var color: Color = HEALTH_FILL
var has_value: bool = false


func _init() -> void:
	custom_minimum_size = SIZE
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP   # tooltip; a click here never reaches the playfield


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound() and is_instance_valid(bridge.player)
	if visible:
		refresh()


func refresh() -> void:
	if kind == Kind.HEALTH:
		var health := bridge.player.health
		var maximum := maxf(1.0, health.max_health)
		_show(true, clampf(health.health / maximum, 0.0, 1.0), str(ceili(health.health)), HEALTH_FILL,
			"Health  %d / %d" % [ceili(health.health), roundi(health.max_health)])
		return
	var pool := bridge.resource_pool
	if pool == null:
		var definition := bridge.character.classes.get_active_definition()
		_show(false, 0.0, "", UiTheme.TEXT_MUTED, "%s uses no class resource." % (definition.display_name if definition != null else "This class"))
		return
	var limit := maxf(1.0, pool.max_value())
	var tip := "%s  %d / %d" % [pool.definition.display_name, roundi(pool.value), roundi(pool.max_value())]
	if bridge.class_runtime != null and bridge.class_runtime.pressure > 0:
		tip += "\nPressure x%d" % bridge.class_runtime.pressure
	_show(true, clampf(pool.value / limit, 0.0, 1.0), str(roundi(pool.value)), pool.definition.color, tip)


func _show(value: bool, share: float, text: String, fill: Color, tip: String) -> void:
	if value != has_value or not is_equal_approx(share, ratio) or text != value_text or fill != color:
		has_value = value
		ratio = share
		value_text = text
		color = fill
		queue_redraw()
	tooltip_text = tip


func _make_custom_tooltip(for_text: String) -> Object:
	return UiTheme.tooltip(for_text) if for_text != "" else null


func frame_id() -> StringName:
	return &"hud/vessel_left" if kind == Kind.HEALTH else &"hud/vessel_right"


func _draw() -> void:
	var mask := &"hud/vessel_fill_left" if kind == Kind.HEALTH else &"hud/vessel_fill_right"
	if HudFillArt.available(frame_id(), mask):
		HudFillArt.draw(self, Vector2.ZERO, frame_id(), mask, ratio if has_value else 0.0, color, 2, not has_value)
	else:   # procedural fallback: a framed well filled from the bottom
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, UiTheme.PANEL_INSET)
		if has_value and ratio > 0.0:
			var height := maxf(2.0, roundf((size.y - 4.0) * ratio))
			draw_rect(Rect2(Vector2(2, size.y - 2.0 - height), Vector2(size.x - 4.0, height)), color)
		draw_rect(rect, UiTheme.BRONZE_DARK if has_value else UiTheme.PANEL_ELEVATED, false, 2.0)
	if has_value and value_text != "":
		HudFillArt.draw_number(self, size * 0.5, value_text, FONT_SIZE)
