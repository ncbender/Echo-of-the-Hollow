class_name MasteryPanel
extends PanelContainer
## Small always-visible weapon mastery window for the currently used family.

var bridge: PlayerProgressionBridge

var _title: Label
var _level: Label
var _bar: ProgressBar
var _next: Label
var _techniques: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(172, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	add_child(box)
	_title = UiTheme.label("", UiTheme.COLOR_ACCENT)
	_level = UiTheme.label()
	_bar = UiTheme.bar()
	_next = UiTheme.label("", UiTheme.COLOR_DIM)
	_techniques = UiTheme.label("", UiTheme.COLOR_DIM)
	_techniques.autowrap_mode = TextServer.AUTOWRAP_WORD
	for child: Control in [_title, _level, _bar, _next, _techniques]:
		box.add_child(child)


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()
	if visible:
		refresh()


func refresh() -> void:
	var family_id := bridge.current_family_id()
	var mastery := bridge.character.mastery
	var family: WeaponFamily = bridge.character.database.weapons.get(family_id)
	_title.text = "Mastery: %s" % (family.display_name if family != null else String(family_id))
	var level := mastery.get_level(family_id)
	var needed := mastery.xp_to_next(family_id)
	if mastery.is_max_level(family_id):
		_level.text = "Level %d (max)" % level
		_bar.max_value = 1
		_bar.value = 1
	else:
		_level.text = "Level %d   %d / %d XP" % [level, mastery.get_xp(family_id), needed]
		_bar.max_value = needed
		_bar.value = mastery.get_xp(family_id)
	var next := mastery.next_unlock(family_id)
	_next.text = "Next: %s (Lv %d)" % [next.display_name, next.level] if next != null else "Next: -"
	var names: PackedStringArray = []
	for unlock in mastery.unlocked_techniques(family_id):
		names.append(unlock.display_name)
	_techniques.text = "Techniques: %s" % (", ".join(names) if not names.is_empty() else "base combos")
