class_name ToastFeed
extends VBoxContainer
## Short-lived notifications above the skill bar (level ups, unlocks, quest and
## save results ...): one compact HUD panel per message with a colour accent,
## centred, wrapped at MAX_WIDTH. The same message again while it is shown
## refreshes it with a counter ("x2") instead of stacking copies. Fades out.

const LIFETIME := 3.5
const FADE := 0.5
const MAX_LINES := 4
const MAX_WIDTH := 560.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 4)


func push(text: String, color: Color = UiTheme.TEXT_PRIMARY) -> void:
	for row: Control in get_children():
		if row.get_meta(&"text", "") == text and not row.is_queued_for_deletion():
			var count: int = row.get_meta(&"count", 1) + 1
			row.set_meta(&"count", count)
			row.set_meta(&"age", 0.0)
			(row.find_child("Text", true, false) as Label).text = "%s  x%d" % [text, count]
			return
	var row := PanelContainer.new()
	row.theme_type_variation = &"HudPanel"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.set_meta(&"text", text)
	row.set_meta(&"age", 0.0)
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var accent := ColorRect.new()
	accent.color = color
	accent.custom_minimum_size = Vector2(4, 0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(accent)
	var label := UiTheme.label(text, color.lerp(UiTheme.TEXT_PRIMARY, 0.35))
	label.name = "Text"
	label.add_theme_font_size_override(&"font_size", UiTheme.FONT_BODY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if label.get_minimum_size().x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	box.add_child(label)
	add_child(row)
	while get_child_count() > MAX_LINES:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


## Texts currently shown, oldest first (tests, debugging).
func texts() -> PackedStringArray:
	var result: PackedStringArray = []
	for row: Control in get_children():
		var label := row.find_child("Text", true, false) as Label
		if label != null:
			result.append(label.text)
	return result


func _process(delta: float) -> void:
	for row: Control in get_children():
		var age: float = row.get_meta(&"age") + delta
		row.set_meta(&"age", age)
		row.modulate.a = clampf((LIFETIME - age) / FADE, 0.0, 1.0)
		if age >= LIFETIME:
			remove_child(row)
			row.queue_free()
