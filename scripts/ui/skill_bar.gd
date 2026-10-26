class_name SkillBar
extends HBoxContainer
## HUD row of the four skill slots (Q/E/R/F): skill name, resource cost and the
## remaining cooldown. Pure presentation; reads the bridge's ClassRuntime.

const KEYS := ["Q", "E", "R", "F"]
const SLOT_SIZE := Vector2(150, 54)

var bridge: PlayerProgressionBridge

var _slots: Array[PanelContainer] = []
var _names: Array[Label] = []
var _infos: Array[Label] = []
var _bars: Array[ProgressBar] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	for index in KEYS.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 2)
		panel.add_child(box)
		var name_label := UiTheme.label("", UiTheme.COLOR_TEXT)
		name_label.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		name_label.clip_text = true
		var info := UiTheme.label("", UiTheme.COLOR_DIM)
		info.add_theme_font_size_override(&"font_size", UiTheme.FONT_SMALL)
		var bar := UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL)
		box.add_child(name_label)
		box.add_child(info)
		box.add_child(bar)
		add_child(panel)
		_slots.append(panel)
		_names.append(name_label)
		_infos.append(info)
		_bars.append(bar)


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()
	if visible:
		refresh()


func refresh() -> void:
	var runtime := bridge.class_runtime
	for index in KEYS.size():
		var skill := runtime.skill_in_slot(index)
		if skill == null:
			_names[index].text = "[%s] -" % KEYS[index]
			_infos[index].text = ""
			_bars[index].value = 0.0
			_slots[index].modulate = Color(1, 1, 1, 0.5)
			continue
		var params := runtime.params_for(skill)
		var left := runtime.cooldown_left(skill.id)
		var pool := runtime.pool
		var affordable := params.cost <= 0.0 or (pool != null and pool.value + 0.0001 >= params.cost)
		_names[index].text = "[%s] %s" % [KEYS[index], skill.display_name]
		_names[index].add_theme_color_override(&"font_color", skill.color.lightened(0.3))
		var cost := "%d %s" % [roundi(params.cost), pool.definition.display_name if pool != null else ""] if params.cost > 0.0 else "free"
		_infos[index].text = "%s%s" % [cost, "   %.1fs" % left if left > 0.0 else ""]
		_bars[index].max_value = maxf(params.cooldown, 0.01)
		_bars[index].value = params.cooldown - left
		_slots[index].modulate = Color.WHITE if affordable and left <= 0.0 else Color(1, 1, 1, 0.55)
