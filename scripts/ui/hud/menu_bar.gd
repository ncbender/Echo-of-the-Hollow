class_name HudMenuBar
extends PanelContainer
## The one icon menu bar of the HUD, bottom left (UI Layout Lock 1.0; Combat HUD UX 2.0: 34 px buttons, 2 px
## apart, 4 px padding - the 32 px art 1:1, a quiet state frame only): seven icon buttons
## for the existing windows, no permanent text. Hover shows the name and the current key
## (OptionsPanel.binding_text, so a rebound key is shown as it is); an icon is lit while
## its window is open. A click runs exactly the same toggle as the key (GameHud.open_menu).
## Buttons take no keyboard focus (G / Enter / Space stay with the game) and stop the
## mouse, so a click here never reaches the player. Icon art: assets/ui/menu/<icon>.png (UiSkin);
## the drawn glyphs stay the fallback.

signal menu_pressed(id: StringName)

## id, English name, input action, icon art (assets/ui/menu/<icon>.png) - in this order on the bar.
const ENTRIES := [
	[&"inventory", "Inventory", &"ui_inventory", &"inventory"], [&"character", "Character", &"ui_character", &"character"],
	[&"talents", "Skills & Talents", &"ui_talents", &"skills"], [&"professions", "Professions", &"ui_professions", &"professions"],
	[&"journal", "Journal", &"ui_journal", &"journal"], [&"map", "Map", &"ui_map", &"map"], [&"settings", "Settings", &"ui_options", &"settings"]]
const ICON_SIZE := UiTheme.MENU_ICON_SIZE
const GAP := 2
## Combat HUD UX 2.0: inner padding of the bar (the HudPanel default is 10).
const PADDING := 4

var buttons: Dictionary = {}   # id -> MenuIcon


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := (UiTheme.get_theme().get_stylebox(&"panel", &"HudPanel")).duplicate() as StyleBox
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_content_margin(side, PADDING)
	add_theme_stylebox_override(&"panel", panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", GAP)
	add_child(row)
	for entry: Array in ENTRIES:
		var icon := MenuIcon.new()
		icon.name = "Menu_%s" % entry[0]
		icon.id = entry[0]
		icon.action = entry[2]
		icon.title = entry[1]
		icon.icon_id = entry[3]
		icon.pressed.connect(menu_pressed.emit.bind(entry[0]))
		row.add_child(icon)
		buttons[entry[0]] = icon


## Lights the icon of the open view (&"" = none).
func set_active(id: StringName) -> void:
	for key: StringName in buttons:
		(buttons[key] as MenuIcon).active = key == id


class MenuIcon:
	extends Button

	var id: StringName
	var action: StringName
	var title: String
	## Asset name of the optional icon art (Menu Icons 1.0: the talents view uses menu/skills).
	var icon_id: StringName
	var active: bool = false

	func _init() -> void:
		custom_minimum_size = HudMenuBar.ICON_SIZE
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		flat = true

	func _process(_delta: float) -> void:
		tooltip_text = "%s  [%s]" % [title, OptionsPanel.binding_text(action)]
		queue_redraw()

	func _make_custom_tooltip(for_text: String) -> Object:
		return UiTheme.tooltip(for_text)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var hover := is_hovered()
		draw_rect(rect, UiTheme.PANEL_ELEVATED if active or hover else Color(UiTheme.PANEL_INSET, 0.6))
		draw_rect(rect, UiTheme.BRONZE if active else (UiTheme.BRONZE_DIM if hover else Color(UiTheme.BRONZE_DARK, 0.7)), false, 1.0)
		var c := size * 0.5
		var ink := UiTheme.PARCHMENT if active or hover else UiTheme.BRONZE
		var art := UiSkin.texture(StringName("menu/%s" % icon_id))   # optional 32 x 32 icon; the frame stays
		if art != null:
			draw_texture_rect(art, Rect2(c - Vector2(16, 16), Vector2(32, 32)), false, Color.WHITE if active or hover else Color(0.85, 0.85, 0.85))
			return
		match id:
			&"inventory":   # a bag
				draw_rect(Rect2(c + Vector2(-9, -4), Vector2(18, 15)), ink, false, 2.0)
				draw_arc(c + Vector2(0, -4), 6.0, PI, TAU, 10, ink, 2.0)
			&"character":   # head and shoulders
				draw_circle(c + Vector2(0, -6), 5.0, ink)
				draw_arc(c + Vector2(0, 12), 10.0, PI, TAU, 14, ink, 3.0)
			&"talents":   # a branching tree
				draw_line(c + Vector2(0, 11), c + Vector2(0, -2), ink, 2.0)
				draw_line(c + Vector2(0, -2), c + Vector2(-8, -9), ink, 2.0)
				draw_line(c + Vector2(0, -2), c + Vector2(8, -9), ink, 2.0)
				for at: Vector2 in [Vector2(-8, -9), Vector2(8, -9), Vector2(0, 11)]:
					draw_circle(c + at, 3.0, ink)
			&"professions":   # a hammer
				draw_line(c + Vector2(-7, 10), c + Vector2(5, -2), ink, 3.0)
				draw_rect(Rect2(c + Vector2(0, -12), Vector2(12, 7)), ink)
			&"journal":   # a book
				draw_rect(Rect2(c + Vector2(-9, -11), Vector2(18, 22)), ink, false, 2.0)
				draw_line(c + Vector2(-5, -11), c + Vector2(-5, 11), ink, 2.0)
				draw_line(c + Vector2(-1, -4), c + Vector2(6, -4), ink, 1.0)
				draw_line(c + Vector2(-1, 1), c + Vector2(6, 1), ink, 1.0)
			&"map":   # a folded map
				draw_polyline(PackedVector2Array([c + Vector2(-11, -8), c + Vector2(-4, -11), c + Vector2(4, -8), c + Vector2(11, -11),
					c + Vector2(11, 8), c + Vector2(4, 11), c + Vector2(-4, 8), c + Vector2(-11, 11), c + Vector2(-11, -8)]), ink, 2.0)
				draw_line(c + Vector2(-4, -11), c + Vector2(-4, 8), ink, 1.0)
				draw_line(c + Vector2(4, -8), c + Vector2(4, 11), ink, 1.0)
			&"settings":   # a cog
				draw_arc(c, 7.0, 0.0, TAU, 20, ink, 3.0)
				for k in 8:
					var dir := Vector2.from_angle(TAU * k / 8.0)
					draw_line(c + dir * 8.0, c + dir * 12.0, ink, 3.0)
