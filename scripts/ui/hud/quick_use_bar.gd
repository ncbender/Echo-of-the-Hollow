class_name QuickUseBar
extends HBoxContainer
## HUD quick use above the player frame: key 1 Hearth Flask (charges left of
## maximum, heal per charge) and key 2 the slotted special potion (name, count,
## shared cooldown). A slot that cannot be used says why in words. Pure
## presentation over Character.consumables (ConsumableService) - never drives
## a timer.

const SLOT_SIZE := Vector2(197, 58)

var bridge: PlayerProgressionBridge

var _flask_name: Label
var _flask_info: Label
var _potion_name: Label
var _potion_info: Label
var _potion_bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	var flask := _slot("1", "FlaskSlot")
	_flask_name = flask[0]
	_flask_info = flask[1]
	var potion := _slot("2", "PotionSlot")
	_potion_name = potion[0]
	_potion_info = potion[1]
	_potion_bar = UiTheme.bar(UiTheme.BAR_HEIGHT_SMALL, UiTheme.RESONANCE)
	(potion[2] as VBoxContainer).add_child(_potion_bar)


func _slot(key: String, slot_name: String) -> Array:
	var panel := PanelContainer.new()
	panel.name = slot_name
	panel.theme_type_variation = &"HudPanel"
	panel.custom_minimum_size = SLOT_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 6)
	head.add_child(UiTheme.key_chip(key))
	var title := UiTheme.styled("", &"SmallLabel")
	title.name = "Name"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	box.add_child(head)
	var info := UiTheme.styled("", &"CaptionLabel")
	info.name = "Info"
	box.add_child(info)
	add_child(panel)
	return [title, info, box]


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()
	if visible:
		refresh()


func refresh() -> void:
	var character := bridge.character
	var state := character.consumables
	var full := ConsumableService.max_charges(character)
	_flask_name.text = "Hearth Flask"
	_flask_name.add_theme_color_override(&"font_color", UiTheme.PARCHMENT if state.charges > 0 else UiTheme.TEXT_MUTED)
	_flask_info.text = ("%d / %d  ·  heals %d%%" % [state.charges, full, roundi(ConsumableService.heal_share(character) * 100.0)]) \
		if state.charges > 0 else "Empty - rest by a fire"
	var definition := character.database.get_item(state.potion_slot) if state.potion_slot != &"" else null
	if definition == null:
		_potion_name.text = "No potion"
		_potion_name.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
		_potion_info.text = "Right-click a potion in your bag"
		_potion_bar.value = 0.0
		return
	var count := character.inventory.count(state.potion_slot)
	_potion_name.text = definition.display_name
	_potion_name.add_theme_color_override(&"font_color", definition.potion_effect.color.lightened(0.3) if count > 0 else UiTheme.TEXT_MUTED)
	if state.cooldown_left > 0.0:
		_potion_info.text = "x%d  ·  Cooldown %ds" % [count, ceili(state.cooldown_left)]
	else:
		_potion_info.text = "x%d" % count if count > 0 else "None left"
	var cooldown := character.database.rules.potion_cooldown
	_potion_bar.value = 100.0 * (1.0 - state.cooldown_left / cooldown) if cooldown > 0.0 else 100.0
