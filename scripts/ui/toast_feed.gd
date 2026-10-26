class_name ToastFeed
extends VBoxContainer
## Short-lived notification lines (level ups, unlocks, save results ...).

const LIFETIME := 3.0
const MAX_LINES := 5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END


func push(text: String, color: Color = UiTheme.COLOR_TEXT) -> void:
	var line := UiTheme.label(text, color)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override(&"font_outline_color", Color.BLACK)
	line.add_theme_constant_override(&"outline_size", 3)
	line.set_meta(&"age", 0.0)
	add_child(line)
	while get_child_count() > MAX_LINES:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func _process(delta: float) -> void:
	for line: Label in get_children():
		var age: float = line.get_meta(&"age") + delta
		line.set_meta(&"age", age)
		line.modulate.a = clampf((LIFETIME - age) / 0.5, 0.0, 1.0)
		if age >= LIFETIME:
			line.queue_free()
