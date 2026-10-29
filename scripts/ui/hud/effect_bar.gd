class_name EffectBar
extends HBoxContainer
## General HUD effect row (Consumables 1.0: the special potion buff; later other
## buffs and debuffs). Every active effect has its own square icon: the effect
## stays recognisable, the remaining duration runs down clockwise from 12
## o'clock as a ring, the rest is dimmed, and the time is written below
## (m:ss). An expired effect disappears; a new potion buff replaces the old
## icon because there is only one potion buff. Display only: it reads the
## remaining time from the rules (ConsumableService.active_effects) and never
## changes a timer.
## Combat HUD UX 2.0: also the class buffs of the ClassRuntime (Battle Cry ...) - formerly a text line in the
## removed PlayerFrame; their full duration is the remaining time when first seen (display only). Every icon
## names its effect in a tooltip.

var bridge: PlayerProgressionBridge

var _icons: Dictionary = {}   # effect id -> EffectIcon
var _buff_totals: Dictionary = {}   # class buff key -> duration when first seen


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)


func _process(_delta: float) -> void:
	var effects: Array[Dictionary] = []
	if bridge != null and bridge.is_bound():
		effects = ConsumableService.active_effects(bridge.character)
		effects.append_array(class_buffs())
	refresh(effects)


## Running class buffs as effects (kind "buff"): name from the key ("buff:battle_cry" -> "Battle Cry").
func class_buffs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var runtime := bridge.class_runtime if bridge != null else null
	if runtime == null:
		return result
	var running := {}
	for key: StringName in runtime.buffs:
		var left := runtime.buff_left(key)
		if left <= 0.0:
			continue
		running[key] = true
		if left > _buff_totals.get(key, 0.0):
			_buff_totals[key] = left   # a refreshed buff starts a new full ring
		result.append({"id": key, "name": String(key).trim_prefix("buff:").capitalize(), "color": UiTheme.BRONZE,
			"left": left, "total": _buff_totals[key], "kind": "buff"})
	for key: StringName in _buff_totals.keys():
		if not running.has(key):
			_buff_totals.erase(key)
	return result


## Shows exactly `effects` ([{"id", "name", "color", "left", "total"}]).
func refresh(effects: Array[Dictionary]) -> void:
	var seen := {}
	for effect: Dictionary in effects:
		var id: StringName = effect.id
		seen[id] = true
		var icon: EffectIcon = _icons.get(id)
		if icon == null:
			icon = EffectIcon.new()
			icon.name = "Effect_%s" % id
			add_child(icon)
			_icons[id] = icon
		icon.show_effect(effect)
	for id: StringName in _icons.keys():
		if not seen.has(id):
			(_icons[id] as Node).queue_free()
			_icons.erase(id)
	visible = not _icons.is_empty()


## One effect: square icon with the clockwise ring and the time below.
class EffectIcon:
	extends VBoxContainer

	const EDGE := 44.0

	var effect_name: String = ""
	var kind: String = ""
	var color: Color = Color.WHITE
	var left: float = 0.0
	var total: float = 1.0
	var _square: Control
	var _time: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS   # the tooltip names the effect
		add_theme_constant_override(&"separation", 1)
		_square = Control.new()
		_square.name = "Icon"
		_square.custom_minimum_size = Vector2(EDGE, EDGE)
		_square.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_square.draw.connect(_draw_square)
		add_child(_square)
		_time = UiTheme.styled("", &"CaptionLabel")
		_time.name = "Time"
		_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_time)

	func show_effect(effect: Dictionary) -> void:
		effect_name = str(effect.get("name", ""))
		kind = str(effect.get("kind", ""))
		tooltip_text = effect_name
		color = effect.get("color", Color.WHITE)
		left = maxf(0.0, float(effect.get("left", 0.0)))
		total = maxf(0.001, float(effect.get("total", 1.0)))
		_time.text = time_text(left)
		_square.queue_redraw()

	## Share of the duration still left (1 = just started, 0 = expired).
	func fraction() -> float:
		return clampf(left / total, 0.0, 1.0)

	static func time_text(seconds: float) -> String:
		var whole := ceili(seconds)
		return "%d:%02d" % [whole / 60, whole % 60]

	func _draw_square() -> void:
		var rect := Rect2(Vector2.ZERO, _square.size)
		var center := rect.get_center()
		_square.draw_rect(rect, UiTheme.PANEL_INSET)
		_square.draw_rect(rect, Color(UiTheme.BRONZE_DARK, 0.9), false, 1.0)
		if kind == "buff":   # a class buff: a bronze diamond
			_square.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -12), center + Vector2(11, 0), center + Vector2(0, 12), center + Vector2(-11, 0)]), color)
		else:   # the potion: a round flask in the effect's colour
			_square.draw_circle(center + Vector2(0, 4), 10.0, color)
			_square.draw_rect(Rect2(center + Vector2(-3, -12), Vector2(6, 8)), color.darkened(0.2))
			_square.draw_rect(Rect2(center + Vector2(-4, -14), Vector2(8, 3)), UiTheme.PARCHMENT)
		# elapsed part dimmed, remaining part as a ring: clockwise from 12 o'clock
		var start := -PI * 0.5
		var end := start + TAU * fraction()
		var radius := minf(rect.size.x, rect.size.y) * 0.5 - 3.0
		if fraction() < 1.0:
			var shade := PackedVector2Array([center])
			var steps := 32
			for step in steps + 1:
				shade.append(center + Vector2.from_angle(lerpf(end, start + TAU, float(step) / steps)) * (radius + 3.0))
			_square.draw_colored_polygon(shade, Color(0, 0, 0, 0.5))
		if fraction() > 0.0:
			_square.draw_arc(center, radius, start, end, 48, UiTheme.PARCHMENT, 3.0, true)
