class_name UiTabs
extends HBoxContainer
## Row of tab buttons ("TabButton" style): one is selected at a time.
## Buttons are named "Tab<Id>" (stable for tests); `tab_selected` reports the id.

signal tab_selected(id: String)

var current: String = ""

var _group := ButtonGroup.new()


func _init() -> void:
	add_theme_constant_override(&"separation", 2)


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
	for child in get_children():
		var button := child as Button
		if button != null:
			button.set_pressed_no_signal(button.name == "Tab%s" % id.validate_node_name())
	if emit:
		tab_selected.emit(id)


func tab_button(id: String) -> Button:
	return get_node_or_null("Tab%s" % id.validate_node_name()) as Button


func _on_pressed(id: String) -> void:
	select(id)
	tab_selected.emit(id)
