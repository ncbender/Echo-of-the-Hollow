class_name UiTheme
extends RefCounted
## "The Forgotten Chronicle" - the shared UI design system (docs/UI_DESIGN_SYSTEM.md,
## docs/DISPLAY_AND_UI_STANDARD.md).
##
## Matte dark-green panels, weathered bronze frames, parchment text and a sparse
## resonance-cyan accent. Every colour, size and style lives here: scenes use the
## semantic tokens and type variations, never their own hex values.
##
## All sizes are design pixels of the 1920x1080 reference canvas. The canvas_items
## stretch maps them to any window (4K = 2x) and the player's UI scale is
## Window.content_scale_factor - so nothing here is ever multiplied by a scale,
## and text is always rasterized at its final size (crisp, never magnified).

# --- Palette (semantic tokens) -------------------------------------------------
const BG := Color("171c1a")
const PANEL := Color("252e28")
const PANEL_ELEVATED := Color("303a33")
const PANEL_INSET := Color("1c2320")
const BRONZE := Color("c5ad85")
const BRONZE_DIM := Color("7d6c52")
const BRONZE_DARK := Color("4a4134")
const TEXT_PRIMARY := Color("e9ddc5")
const TEXT_SECONDARY := Color("afb9ad")
const TEXT_MUTED := Color("7f877e")
const RESONANCE := Color("78b8c5")
const RESONANCE_DIM := Color("4d7a83")
const SUCCESS := Color("9cbf7e")
const WARNING := Color("d9b46a")
const DANGER := Color("d27461")
const HEALTH := Color("b4493f")
const POISE := Color("c9a95c")
const PARCHMENT := Color("eadcb8")

# --- Legacy aliases (kept so older call sites stay valid) ----------------------
const COLOR_TEXT := TEXT_PRIMARY
const COLOR_DIM := TEXT_SECONDARY
const COLOR_ACCENT := RESONANCE
const COLOR_WARN := WARNING
const COLOR_ERROR := DANGER
const COLOR_PROMPT := PARCHMENT
const COLOR_PANEL := Color(0.145, 0.18, 0.157, 0.94)
## Modal windows: opaque so HUD/debug text never shows through.
const COLOR_WINDOW := Color(0.145, 0.18, 0.157, 0.99)
const COLOR_BORDER := BRONZE_DARK
const COLOR_BUTTON := Color("2c3630")
const COLOR_BUTTON_HOVER := Color("37443b")
const COLOR_BUTTON_PRESSED := Color("3d3a2c")
const COLOR_BUTTON_DISABLED := Color("1f2622")
const COLOR_FOCUS := Color(RESONANCE, 0.95)

# --- Typography (design px) ----------------------------------------------------
const FONT_CAPTION := 14
const FONT_SMALL := 15
const FONT_BODY := 18
const FONT_SUBHEADING := 20
const FONT_HEADING := 22
const FONT_TITLE := 28
const FONT_DISPLAY := 60

# --- Layout (design px) --------------------------------------------------------
## Distance of HUD elements and windows from the canvas edge.
const SCREEN_MARGIN := 16
## Inner padding of panels and windows.
const PANEL_PADDING := 14
## Gap between elements in containers.
const GAP := 8
const BORDER := 2
const CORNER := 3
## Right HUD column (class info, quest tracker).
const HUD_COLUMN_WIDTH := 340
## Width for wrapped text blocks in windows.
const TEXT_WIDTH := 520
## Width of the toast feed / interaction prompt at the bottom.
const FEED_WIDTH := 900
const BAR_HEIGHT := 8
const BAR_HEIGHT_SMALL := 6
const SLOT_SIZE := Vector2(150, 40)
const SLOT_GAP := 4
const TOOLTIP_MAX_WIDTH := 440
## Windows never get smaller than this (unless the canvas itself is smaller).
const WINDOW_MIN_SIZE := Vector2(320, 160)
## Short UI transitions (seconds); disabled by "Reduce Motion".
const TRANSITION := 0.12

## Rarity presentation: name, colour and a shape index for ItemIcon frames, so
## rarity is never told by colour alone.
const RARITY := {
	ItemDefinition.Rarity.NORMAL: {"name": "Common", "color": Color("cfc8b6"), "pips": 0},
	ItemDefinition.Rarity.MAGIC: {"name": "Magic", "color": Color("7fa7d8"), "pips": 1},
	ItemDefinition.Rarity.RARE: {"name": "Rare", "color": Color("e1c35a"), "pips": 2},
	ItemDefinition.Rarity.EPIC: {"name": "Epic", "color": Color("b48ad6"), "pips": 3},
	ItemDefinition.Rarity.LEGENDARY: {"name": "Legendary", "color": Color("e3934a"), "pips": 4},
	ItemDefinition.Rarity.UNIQUE: {"name": "Unique", "color": Color("d6b47a"), "pips": 4},
	ItemDefinition.Rarity.SET: {"name": "Set", "color": Color("7fbf8a"), "pips": 3},
}

## Short UI transitions (window fade). Set from UserSettings.reduce_motion.
static var motion_enabled: bool = true

static var _theme: Theme
static var _display_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Serif display face for titles and headings (system font with fallbacks; the
## built-in sans is used where none of them exists). Provisional until a
## licensed game font is chosen.
static func display_font() -> Font:
	if _display_font == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
		font.font_weight = 600
		font.fallbacks = [ThemeDB.fallback_font]
		_display_font = font
	return _display_font


static func rarity_name(rarity: int) -> String:
	return RARITY.get(rarity, RARITY[ItemDefinition.Rarity.NORMAL]).name


static func rarity_color(rarity: int) -> Color:
	return RARITY.get(rarity, RARITY[ItemDefinition.Rarity.NORMAL]).color


static func rarity_pips(rarity: int) -> int:
	return RARITY.get(rarity, RARITY[ItemDefinition.Rarity.NORMAL]).pips


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY

	# panels
	theme.set_stylebox(&"panel", &"PanelContainer", _box(COLOR_PANEL, BRONZE_DARK, PANEL_PADDING))
	theme.set_stylebox(&"panel", &"Panel", _box(COLOR_PANEL, BRONZE_DARK, PANEL_PADDING))
	theme.set_type_variation(&"WindowPanel", &"PanelContainer")
	var window := _box(COLOR_WINDOW, BRONZE_DIM, PANEL_PADDING + 4)
	window.shadow_color = Color(0, 0, 0, 0.55)
	window.shadow_size = 10
	theme.set_stylebox(&"panel", &"WindowPanel", window)
	theme.set_type_variation(&"HudPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"HudPanel", _box(Color(BG, 0.78), Color(BRONZE_DARK, 0.9), 10))
	theme.set_type_variation(&"CardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CardPanel", _box(PANEL_ELEVATED, BRONZE_DARK, 12))
	theme.set_type_variation(&"SelectedCardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SelectedCardPanel", _box(PANEL_ELEVATED, RESONANCE_DIM, 12))
	theme.set_type_variation(&"InsetPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"InsetPanel", _box(PANEL_INSET, Color(BRONZE_DARK, 0.6), 10))
	theme.set_type_variation(&"KeyChip", &"PanelContainer")
	var chip := _box(PANEL_ELEVATED, BRONZE_DIM, 0)
	chip.content_margin_left = 6
	chip.content_margin_right = 6
	chip.content_margin_top = 1
	chip.content_margin_bottom = 1
	theme.set_stylebox(&"panel", &"KeyChip", chip)

	# labels
	theme.set_color(&"font_color", &"Label", TEXT_PRIMARY)
	theme.set_color(&"font_outline_color", &"Label", Color.BLACK)
	theme.set_constant(&"line_spacing", &"Label", 2)
	theme.set_type_variation(&"HeaderLabel", &"Label")
	theme.set_font(&"font", &"HeaderLabel", display_font())
	theme.set_font_size(&"font_size", &"HeaderLabel", FONT_HEADING)
	theme.set_color(&"font_color", &"HeaderLabel", BRONZE)
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_font(&"font", &"TitleLabel", display_font())
	theme.set_font_size(&"font_size", &"TitleLabel", FONT_TITLE)
	theme.set_color(&"font_color", &"TitleLabel", BRONZE)
	theme.set_type_variation(&"DisplayLabel", &"Label")
	theme.set_font(&"font", &"DisplayLabel", display_font())
	theme.set_font_size(&"font_size", &"DisplayLabel", FONT_DISPLAY)
	theme.set_color(&"font_color", &"DisplayLabel", BRONZE)
	theme.set_type_variation(&"SubheadingLabel", &"Label")
	theme.set_font_size(&"font_size", &"SubheadingLabel", FONT_SUBHEADING)
	theme.set_color(&"font_color", &"SubheadingLabel", TEXT_PRIMARY)
	theme.set_type_variation(&"SmallLabel", &"Label")
	theme.set_font_size(&"font_size", &"SmallLabel", FONT_SMALL)
	theme.set_color(&"font_color", &"SmallLabel", TEXT_SECONDARY)
	theme.set_type_variation(&"CaptionLabel", &"Label")
	theme.set_font_size(&"font_size", &"CaptionLabel", FONT_CAPTION)
	theme.set_color(&"font_color", &"CaptionLabel", TEXT_MUTED)

	# containers
	for type: StringName in [&"VBoxContainer", &"HBoxContainer"]:
		theme.set_constant(&"separation", type, GAP)
	theme.set_constant(&"h_separation", &"GridContainer", SLOT_GAP)
	theme.set_constant(&"v_separation", &"GridContainer", SLOT_GAP)
	theme.set_constant(&"h_separation", &"HFlowContainer", GAP * 2)
	theme.set_constant(&"v_separation", &"HFlowContainer", GAP * 2)
	var rule := StyleBoxLine.new()
	rule.color = Color(BRONZE_DARK, 0.9)
	rule.thickness = 1
	theme.set_stylebox(&"separator", &"HSeparator", rule)
	theme.set_constant(&"separation", &"HSeparator", 6)

	# buttons
	_button_styles(theme, &"Button", 12, 6, COLOR_BUTTON, BRONZE_DARK)
	_button_fonts(theme, &"Button", TEXT_PRIMARY)
	theme.set_type_variation(&"PrimaryButton", &"Button")
	_button_styles(theme, &"PrimaryButton", 16, 8, Color("3d3a2c"), BRONZE)
	_button_fonts(theme, &"PrimaryButton", PARCHMENT)
	theme.set_type_variation(&"DangerButton", &"Button")
	_button_styles(theme, &"DangerButton", 12, 6, Color("3a2622"), Color("8a4b3f"))
	_button_fonts(theme, &"DangerButton", Color("f0c8bc"))
	theme.set_type_variation(&"TabButton", &"Button")
	_tab_styles(theme)
	_button_fonts(theme, &"TabButton", TEXT_SECONDARY)
	theme.set_color(&"font_pressed_color", &"TabButton", BRONZE)
	theme.set_color(&"font_hover_pressed_color", &"TabButton", BRONZE)
	theme.set_type_variation(&"InventorySlot", &"Button")
	_button_styles(theme, &"InventorySlot", 8, 4, PANEL_INSET, Color(BRONZE_DARK, 0.8))
	_button_fonts(theme, &"InventorySlot", TEXT_PRIMARY)
	theme.set_font_size(&"font_size", &"InventorySlot", FONT_SMALL)
	theme.set_type_variation(&"FlatButton", &"Button")
	_button_styles(theme, &"FlatButton", 8, 4, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	_button_fonts(theme, &"FlatButton", TEXT_SECONDARY)
	for type: StringName in [&"OptionButton", &"CheckButton", &"CheckBox", &"MenuButton"]:
		_button_styles(theme, type, 12, 6, COLOR_BUTTON, BRONZE_DARK)
		_button_fonts(theme, type, TEXT_PRIMARY)

	# inputs
	var edit := _box(PANEL_INSET, BRONZE_DARK, 8)
	var edit_focus := _box(PANEL_INSET, RESONANCE_DIM, 8)
	theme.set_stylebox(&"normal", &"LineEdit", edit)
	theme.set_stylebox(&"focus", &"LineEdit", edit_focus)
	theme.set_stylebox(&"read_only", &"LineEdit", _box(COLOR_BUTTON_DISABLED, BRONZE_DARK, 8))
	theme.set_color(&"font_color", &"LineEdit", TEXT_PRIMARY)
	theme.set_color(&"font_placeholder_color", &"LineEdit", TEXT_MUTED)
	theme.set_color(&"caret_color", &"LineEdit", RESONANCE)
	var popup := _box(PANEL_ELEVATED, BRONZE_DIM, 6)
	theme.set_stylebox(&"panel", &"PopupMenu", popup)
	theme.set_stylebox(&"hover", &"PopupMenu", _box(COLOR_BUTTON_HOVER, COLOR_BUTTON_HOVER, 4))
	theme.set_color(&"font_color", &"PopupMenu", TEXT_PRIMARY)
	theme.set_color(&"font_hover_color", &"PopupMenu", PARCHMENT)
	theme.set_color(&"font_disabled_color", &"PopupMenu", TEXT_MUTED)
	var slider := StyleBoxFlat.new()
	slider.bg_color = PANEL_INSET
	slider.border_color = BRONZE_DARK
	slider.set_border_width_all(1)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	var slider_fill := slider.duplicate() as StyleBoxFlat
	slider_fill.bg_color = RESONANCE_DIM
	theme.set_stylebox(&"slider", &"HSlider", slider)
	theme.set_stylebox(&"grabber_area", &"HSlider", slider_fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", slider_fill)

	# bars
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.55)
	bar_bg.border_color = Color(BRONZE_DARK, 0.8)
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = RESONANCE
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)

	# tooltip
	var tooltip := _box(Color(BG, 0.98), BRONZE_DIM, 12)
	tooltip.shadow_color = Color(0, 0, 0, 0.5)
	tooltip.shadow_size = 6
	theme.set_stylebox(&"panel", &"TooltipPanel", tooltip)
	theme.set_color(&"font_color", &"TooltipLabel", TEXT_PRIMARY)
	theme.set_font_size(&"font_size", &"TooltipLabel", FONT_BODY)

	# scroll bars
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = BRONZE_DARK
	grabber.set_corner_radius_all(CORNER)
	grabber.set_content_margin_all(5)
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0, 0, 0, 0.3)
	scroll_bg.set_content_margin_all(5)
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", type, scroll_bg)
		theme.set_stylebox(&"grabber", type, grabber)
		var highlight := grabber.duplicate() as StyleBoxFlat
		highlight.bg_color = BRONZE_DIM
		theme.set_stylebox(&"grabber_highlight", type, highlight)
		theme.set_stylebox(&"grabber_pressed", type, highlight)
	return theme


static func _box(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(padding)
	return box


static func _button_styles(theme: Theme, type: StringName, pad_x: int, pad_y: int, fill: Color, border: Color) -> void:
	var normal := _box(fill, border, 0)
	normal.set_border_width_all(1)
	normal.content_margin_left = pad_x
	normal.content_margin_right = pad_x
	normal.content_margin_top = pad_y
	normal.content_margin_bottom = pad_y
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.1) if fill.a > 0.0 else Color(COLOR_BUTTON_HOVER, 0.6)
	hover.border_color = BRONZE_DIM
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = COLOR_BUTTON_PRESSED
	pressed.border_color = BRONZE   # selected = bronze, keyboard focus = resonance outline
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = COLOR_BUTTON_DISABLED if fill.a > 0.0 else Color(0, 0, 0, 0)
	disabled.border_color = Color(BRONZE_DARK, 0.5)
	# Focus is drawn on top of the current state: a clear outline for keyboard/gamepad.
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = COLOR_FOCUS
	focus.set_border_width_all(BORDER)
	focus.set_corner_radius_all(CORNER)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, pressed)
	theme.set_stylebox(&"disabled", type, disabled)
	theme.set_stylebox(&"focus", type, focus)


static func _button_fonts(theme: Theme, type: StringName, color: Color) -> void:
	theme.set_color(&"font_color", type, color)
	theme.set_color(&"font_hover_color", type, PARCHMENT)
	theme.set_color(&"font_focus_color", type, PARCHMENT)
	theme.set_color(&"font_pressed_color", type, PARCHMENT)
	theme.set_color(&"font_hover_pressed_color", type, PARCHMENT)
	theme.set_color(&"font_disabled_color", type, Color(TEXT_MUTED, 0.75))


## Tabs: flat until selected; the selected tab gets a bronze underline.
static func _tab_styles(theme: Theme) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(BRONZE_DARK, 0.7)
	normal.border_width_bottom = 2
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(PANEL_ELEVATED, 0.6)
	hover.border_color = BRONZE_DIM
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(PANEL_ELEVATED, 0.9)
	pressed.border_color = BRONZE
	pressed.border_width_bottom = 3
	var disabled := normal.duplicate() as StyleBoxFlat
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = COLOR_FOCUS
	focus.set_border_width_all(BORDER)
	theme.set_stylebox(&"normal", &"TabButton", normal)
	theme.set_stylebox(&"hover", &"TabButton", hover)
	theme.set_stylebox(&"pressed", &"TabButton", pressed)
	theme.set_stylebox(&"hover_pressed", &"TabButton", pressed)
	theme.set_stylebox(&"disabled", &"TabButton", disabled)
	theme.set_stylebox(&"focus", &"TabButton", focus)


# --- Factories (shared components) ------------------------------------------------

static func label(text: String = "", color: Color = COLOR_TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override(&"font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func heading(text: String = "") -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"HeaderLabel"
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Label with one of the type variations (TitleLabel, SubheadingLabel, SmallLabel,
## CaptionLabel ...).
static func styled(text: String, variation: StringName) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = variation
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## Label that wraps at `width` design px.
static func wrapped(text: String, color: Color = COLOR_TEXT, width: float = TEXT_WIDTH) -> Label:
	var result := label(text, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(width, 0)
	return result


## Section heading: bronze caption with a thin rule to its right.
static func section(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Section_%s" % text.validate_node_name()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := styled(text.to_upper(), &"CaptionLabel")
	title.add_theme_color_override(&"font_color", BRONZE)
	row.add_child(title)
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	return row


## Small framed key hint ("G", "Esc", "Q").
static func key_chip(key: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"KeyChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := styled(key, &"SmallLabel")
	text.add_theme_color_override(&"font_color", PARCHMENT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(text)
	return chip


## Panel with a variation (CardPanel, InsetPanel, HudPanel ...) and a VBox inside;
## returns the panel, the box is its only child.
static func card(variation: StringName = &"CardPanel") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	var box := VBoxContainer.new()
	box.name = "Box"
	panel.add_child(box)
	return panel


## "Name ........ value" row for stat lists.
static func stat_row(name_text: String, value_text: String, value_color: Color = TEXT_PRIMARY) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := label(name_text, TEXT_SECONDARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := label(value_text, value_color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


## Button with a type variation (PrimaryButton, DangerButton, TabButton ...).
static func button(text: String, variation: StringName = &"", action: Callable = Callable()) -> Button:
	var result := Button.new()
	result.text = text
	if variation != &"":
		result.theme_type_variation = variation
	if action.is_valid():
		result.pressed.connect(action)
	return result


static func bar(height: float = BAR_HEIGHT, fill: Color = Color(0, 0, 0, 0)) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.custom_minimum_size = Vector2(0, height)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fill.a > 0.0:
		result.add_theme_stylebox_override(&"fill", fill_box(fill))
	return result


static var _fills: Dictionary = {}


## Shared fill style per colour (bars that change colour do not allocate).
static func fill_box(color: Color) -> StyleBoxFlat:
	if not _fills.has(color):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		_fills[color] = box
	return _fills[color]


## Wrapping tooltip content (Control._make_custom_tooltip). Width-limited, so long
## item texts never run off the screen; Godot keeps the popup inside the viewport.
static func tooltip(text: String) -> Control:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"TooltipLabel"
	var font_size := get_theme().get_font_size(&"font_size", &"TooltipLabel")
	var natural := ThemeDB.fallback_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(minf(natural + 2.0, TOOLTIP_MAX_WIDTH), 0)
	return result


## Fades `control` in (TRANSITION seconds) unless motion is reduced.
static func fade_in(control: CanvasItem) -> void:
	if not motion_enabled or not control.is_inside_tree():
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "modulate:a", 1.0, TRANSITION)
