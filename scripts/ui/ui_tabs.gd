class_name UiTabs
extends HFlowContainer
## Row of tab buttons ("TabButton" style): one is selected at a time. Wraps
## onto a second row when the window is narrow (high UI scale).
## Buttons are named "Tab<Id>" (stable for tests); `tab_selected` reports the id.

signal tab_selected(id: String)

var current: String = ""

var _group := ButtonGroup.new()


func _init() -> void:
	add_theme_constant_override(&"h_separation", 2)
	add_theme_constant_override(&"v_separation", 2)


## Adds a tab; `text` is the visible (English) label.
func add_tab(id: String, text: String, tooltip: String = "") -> Button:
	var button := UiTheme.button(text, &"TabButton")
	button.name = "Tab%s" % id.validate_node_name()
	button.toggle_mode = true
	button.button_group = _group
	button.tooltip_text = tooltip
	button.pressed.connect(_on_pressed.bind(id))
	add_child(button)
	return button


func select(id: String, emit: bool = false) -> void:
	current = id
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for child in get_children():
		var button := child as Button
		if button != null:
			var chosen := button.name == "Tab%s" % id.validate_node_name()
			button.set_pressed_no_signal(chosen)
			if chosen and focus != null and focus != button and focus.get_parent() == self:
				button.grab_focus()   # the focus frame follows the shown page (never on another tab)
	if emit:
		tab_selected.emit(id)


func tab_button(id: String) -> Button:
	return get_node_or_null("Tab%s" % id.validate_node_name()) as Button


func _on_pressed(id: String) -> void:
	select(id)
	tab_selected.emit(id)
