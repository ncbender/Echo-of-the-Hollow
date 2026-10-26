class_name SkillBar
extends HBoxContainer
## HUD row of the four skill slots (Q/E/R/F): key, skill name, resource cost and
## the remaining cooldown (bar + seconds). A slot that cannot be used says why
## in words ("Cooldown", "No Rage"), never only by dimming.
## Pure presentation; reads the bridge's ClassRuntime.

const KEYS := ["Q", "E", "R", "F"]
const SLOT_SIZE := Vector2(156, 76)

var bridge: PlayerProgressionBridge

var _slots: Array[PanelContainer] = []
var _names: Array[Label] = []
var _infos: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 6)
	for index in KEYS.size():
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"HudPanel"
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 2)
		panel.add_child(box)
		var head := HBoxContainer.new()
		head.add_theme_constant_override(&"separation", 6)
		head.add_child(UiTheme.key_chip(KEYS[index]))
		var name_label := UiTheme.styled("", &"SmallLabel")
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var info := UiTheme.styled("", &"CaptionLabel")
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.RESONANCE)
		box.add_child(head)
		box.add_child(info)
		box.add_child(bar)
		add_child(panel)
		_slots.append(panel)
		_names.append(name_label)
		_infos.append(info)
		_bars.append(bar)


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound() \
			and bridge.character.builds.get_build().slots.any(func(id: StringName) -> bool: return id != &"")
	if visible:
		refresh()


func refresh() -> void:
	var runtime := bridge.class_runtime
	for index in KEYS.size():
		var skill := runtime.skill_in_slot(index)
		if skill == null:
			_names[index].text = "Empty"
			_names[index].add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
			_infos[index].text = ""
			_bars[index].value = 0.0
			_slots[index].modulate = Color(1, 1, 1, 0.55)
			continue
		var params := runtime.params_for(skill)
		var left := runtime.cooldown_left(skill.id)
		var pool := runtime.pool
		var affordable := params.cost <= 0.0 or (pool != null and pool.value + 0.0001 >= params.cost)
		_names[index].text = skill.display_name
		_names[index].add_theme_color_override(&"font_color", skill.color.lightened(0.35))
		var cost := "%d %s" % [roundi(params.cost), pool.definition.display_name if pool != null else ""] if params.cost > 0.0 else "No cost"
		if left > 0.0:
			_infos[index].text = "Cooldown  %.1fs" % left
		elif not affordable:
			_infos[index].text = "Need %s" % cost
		else:
			_infos[index].text = cost
		_infos[index].add_theme_color_override(&"font_color", UiTheme.WARNING if left > 0.0 or not affordable else UiTheme.TEXT_SECONDARY)
		_bars[index].max_value = maxf(params.cooldown, 0.01)
		_bars[index].value = params.cooldown - left
		_slots[index].modulate = Color.WHITE if affordable and left <= 0.0 else Color(1, 1, 1, 0.7)
