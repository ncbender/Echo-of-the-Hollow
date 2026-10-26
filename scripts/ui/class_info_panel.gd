class_name ClassInfoPanel
extends PanelContainer
## Active class, class level/XP, class resource and key stats.

var bridge: PlayerProgressionBridge

var _title: Label
var _bar: ProgressBar
var _resource_label: Label
var _resource_bar: ProgressBar
var _stats: Label
var _fill_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UiTheme.HUD_COLUMN_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	add_child(box)
	_title = UiTheme.label("", UiTheme.COLOR_ACCENT)
	_bar = UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL)
	_resource_label = UiTheme.label("", UiTheme.COLOR_DIM)
	_resource_bar = UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL)
	_stats = UiTheme.label("", UiTheme.COLOR_DIM)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD
	for child: Control in [_title, _bar, _resource_label, _resource_bar, _stats]:
		box.add_child(child)


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()
	if visible:
		refresh()


func refresh() -> void:
	var classes := bridge.character.classes
	var definition := classes.get_active_definition()
	var class_id := classes.active_class_id
	_title.text = "%s  Lv %d   %d/%d XP" % [definition.display_name if definition else "-", classes.get_level(class_id),
		classes.get_xp(class_id), classes.xp_to_next(class_id)]
	_bar.max_value = maxi(1, classes.xp_to_next(class_id))
	_bar.value = classes.get_xp(class_id)
	var pool := bridge.resource_pool
	_resource_label.visible = pool != null
	_resource_bar.visible = pool != null
	if pool != null:
		_resource_label.text = "%s %d / %d" % [pool.definition.display_name, roundi(pool.value), roundi(pool.max_value())]
		_resource_bar.max_value = pool.max_value()
		_resource_bar.value = pool.value
		_resource_bar.add_theme_stylebox_override(&"fill", _fill(pool.definition.color))
	var stats := bridge.character.get_stats()
	_stats.text = "HP %d  Armor %d\nDmg %+d%%  Crit %d%%  Poise %+d%%" % [
		roundi(stats[Stats.MAX_HEALTH]), roundi(stats[Stats.ARMOR]), roundi(stats[Stats.PHYSICAL_DAMAGE]),
		roundi(stats[Stats.CRIT_CHANCE]), roundi(stats[Stats.POISE_DAMAGE])]


func _fill(color: Color) -> StyleBoxFlat:
	if not _fill_cache.has(color):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		_fill_cache[color] = box
	return _fill_cache[color]
