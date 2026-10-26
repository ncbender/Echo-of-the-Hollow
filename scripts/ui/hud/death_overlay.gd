class_name DeathOverlay
extends Control
## Shown while the player is down: a calm darkening, "You have fallen" and the
## time until the player rises at the last resting place. Respawning is the
## Player's job (it never saves); this only shows it.

var bridge: PlayerProgressionBridge

var _title: Label
var _detail: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	_title = UiTheme.styled("You have fallen", &"DisplayLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override(&"font_color", UiTheme.DANGER.lightened(0.15))
	box.add_child(_title)
	_detail = UiTheme.styled("", &"SubheadingLabel")
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)
	visible = false


func _process(_delta: float) -> void:
	var player := bridge.player if bridge != null and bridge.is_bound() else null
	visible = player != null and is_instance_valid(player) and player.health.is_dead()
	if visible:
		_detail.text = "You rise again at the last resting place in %.1f s" % maxf(0.0, player.respawn_time_left())
