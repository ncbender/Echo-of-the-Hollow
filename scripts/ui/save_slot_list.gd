class_name SaveSlotList
extends RefCounted
## The save slot list shared by the title screen and the pause menu: the five
## manual slots and - when loading - the three rotating autosaves, in two
## clearly separated sections with a MANUAL / AUTOSAVE badge on every card.
## Each card shows place, class and level, play time and date; damaged files
## are marked and can never be loaded. Rows are HBoxContainers named Slot<n> /
## Autosave<n> with an "Action" button (stable for tests and playtests).

const WIDTH := 680


## `on_action(path: String, slot: int, info: Dictionary)`; slot = manual slot
## number (1..5) or -n for autosave n.
static func build(container: Container, save_path: String, saving: bool, on_action: Callable) -> void:
	container.add_child(UiTheme.section("Manual saves"))
	for slot in range(1, SaveSlots.MANUAL_SLOTS + 1):
		container.add_child(_card("Slot %d" % slot, "MANUAL", SaveSlots.manual_path(save_path, slot), saving, slot, on_action))
	if saving:
		var note := UiTheme.wrapped("Autosaves are written on their own every 5 minutes of play and at important moments; they rotate through three slots.", UiTheme.TEXT_MUTED, WIDTH)
		note.theme_type_variation = &"SmallLabel"
		container.add_child(note)
		return
	container.add_child(UiTheme.section("Autosaves"))
	for slot in range(1, SaveSlots.AUTO_SLOTS + 1):
		container.add_child(_card("Autosave %d" % slot, "AUTOSAVE", SaveSlots.auto_path(save_path, slot), false, -slot, on_action))


static func _card(label: String, badge: String, path: String, saving: bool, slot: int, on_action: Callable) -> Control:
	var info := SaveSystem.read_info(path)
	var card := UiTheme.card(&"CardPanel" if info.valid else &"InsetPanel")
	card.custom_minimum_size = Vector2(WIDTH, 0)
	var row := HBoxContainer.new()
	row.name = label.replace(" ", "")
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	var badge_label := UiTheme.styled(badge, &"CaptionLabel")
	badge_label.add_theme_color_override(&"font_color", UiTheme.BRONZE if badge == "MANUAL" else UiTheme.RESONANCE)
	badge_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(badge_label)
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override(&"separation", 0)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiTheme.styled(label, &"SubheadingLabel")
	text_box.add_child(title)
	var detail := UiTheme.styled("Empty", &"SmallLabel")
	if info.valid:
		detail.text = describe(info)
		if info.error != "":
			detail.text += "  ·  %s" % info.error
	elif info.exists:
		detail.text = "Damaged - this save cannot be loaded."
		detail.add_theme_color_override(&"font_color", UiTheme.DANGER)
	else:
		detail.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	text_box.add_child(detail)
	row.add_child(text_box)
	var button := UiTheme.button("", &"PrimaryButton" if (saving or info.valid) else &"")
	button.name = "Action"
	if saving:
		button.text = "Overwrite" if info.exists else "Save here"
	else:
		button.text = "Load"
		button.disabled = not info.valid
	button.pressed.connect(func() -> void: on_action.call(path, slot, info))
	row.add_child(button)
	(card.get_node("Box") as VBoxContainer).add_child(row)
	return card


## "Haven  ·  Warrior Lv 12  ·  1:05:12 played  ·  2026-10-26 14:03".
static func describe(info: Dictionary) -> String:
	var meta: Dictionary = info.meta
	var seconds := int(meta.get("play_time", 0))
	var played := "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	var when := Time.get_datetime_string_from_unix_time(int(info.saved_at) + _utc_offset(), true)
	var who := "%s Lv %d" % [meta.get("class", "?"), int(meta.get("level", 1))]
	return "%s  ·  %s  ·  %s played  ·  %s" % [meta.get("location", "?"), who, played, when.left(16)]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
