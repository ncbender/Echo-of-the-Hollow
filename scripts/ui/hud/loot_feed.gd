class_name LootFeed
extends VBoxContainer
## Bottom-right loot notifications: icon, name in rarity colour plus the rarity
## word, amount. Fed by PlayerProgressionBridge.item_received. Fades out.

const LIFETIME := 4.0
const MAX_ROWS := 5

var bridge: PlayerProgressionBridge


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 4)


func push(item_id: StringName, quantity: int) -> void:
	var definition := bridge.character.database.get_item(item_id) if bridge != null else null
	if definition == null:
		return
	var row := PanelContainer.new()
	row.theme_type_variation = &"HudPanel"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := HBoxContainer.new()
	row.add_child(box)
	var icon := ItemIcon.new().setup(definition, quantity)
	icon.custom_minimum_size = Vector2(30, 30)
	box.add_child(icon)
	var name_label := UiTheme.styled("%s%s" % [definition.display_name, "  x%d" % quantity if quantity > 1 else ""], &"SmallLabel")
	name_label.add_theme_color_override(&"font_color", UiTheme.rarity_color(definition.rarity))
	box.add_child(name_label)
	if definition.rarity != ItemDefinition.Rarity.NORMAL:
		box.add_child(UiTheme.styled(UiTheme.rarity_name(definition.rarity), &"CaptionLabel"))
	row.set_meta(&"age", 0.0)
	add_child(row)
	while get_child_count() > MAX_ROWS:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()


func rows() -> int:
	return get_child_count()


func _process(delta: float) -> void:
	for row: Control in get_children():
		var age: float = row.get_meta(&"age") + delta
		row.set_meta(&"age", age)
		row.modulate.a = clampf((LIFETIME - age) / 0.6, 0.0, 1.0)
		if age >= LIFETIME:
			row.queue_free()
