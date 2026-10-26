class_name ItemSlotButton
extends Button
## Inventory / equipment slot. Uses the "InventorySlot" theme variation and a
## wrapping, width-limited tooltip (UiTheme.tooltip) for item details.


func _init() -> void:
	theme_type_variation = &"InventorySlot"
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "":
		return null   # empty slot: no tooltip box
	return UiTheme.tooltip(for_text)
