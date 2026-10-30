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
## UI Visual Consistency 1.0 (docs/UI_VISUAL_CONSISTENCY_1_0.md): the neutral surfaces follow the
## Dark Classic anchors of the UI art (Charcoal #191B20, Slate #30343B, Steel #777C83, Parchment
## #C7BDAA, Old Gold #B39A70) - no green cast. Bronze accents and semantic colours are unchanged.
const BG := Color("16181c")               # deepest surface (HUD panels, tooltips), below Charcoal
const PANEL := Color("23262c")            # between Charcoal and Slate
const PANEL_ELEVATED := Color("30343b")   # Slate
const PANEL_INSET := Color("191b20")      # Charcoal
const BRONZE := Color("c5ad85")
const BRONZE_DIM := Color("7d6c52")
const BRONZE_DARK := Color("4a4134")
const TEXT_PRIMARY := Color("e9ddc5")
const TEXT_SECONDARY := Color("b3aea4")   # neutral warm grey (was a green grey)
const TEXT_MUTED := Color("85827b")
const RESONANCE := Color("78b8c5")
const RESONANCE_DIM := Color("4d7a83")
const SUCCESS := Color("9cbf7e")
const WARNING := Color("d9b46a")
const DANGER := Color("d27461")
const HEALTH := Color("b4493f")
const POISE := Color("c9a95c")
const PARCHMENT := Color("eadcb8")
## EXP fill: dim bronze, so the parchment percentage stays readable on top of it.
const XP := BRONZE_DIM

# --- Legacy aliases (kept so older call sites stay valid) ----------------------
const COLOR_TEXT := TEXT_PRIMARY
const COLOR_DIM := TEXT_SECONDARY
const COLOR_ACCENT := RESONANCE
const COLOR_WARN := WARNING
const COLOR_ERROR := DANGER
const COLOR_PROMPT := PARCHMENT
const COLOR_PANEL := Color(PANEL, 0.94)
## Modal windows: opaque so HUD/debug text never shows through.
const COLOR_WINDOW := Color(Color("1d1f24"), 0.99)
const COLOR_BORDER := BRONZE_DARK
const COLOR_BUTTON := Color("2e3238")
const COLOR_BUTTON_HOVER := Color("383c44")      # = button/hover art fill
const COLOR_BUTTON_PRESSED := Color("3b372f")    # warm: pressed / selected leans to bronze
const COLOR_BUTTON_DISABLED := Color("1f2125")
const COLOR_FOCUS := Color(RESONANCE, 0.95)

# --- Interaction states (UI Window Foundation 1.0) -------------------------------
## One meaning per colour, in every component: hover = dim bronze border, selected /
## active = bronze border (+ elevated fill), keyboard focus = resonance outline,
## disabled = dark fill + muted text, locked = disabled + a lock mark (never colour alone).
const STATE_HOVER_BORDER := BRONZE_DIM
const STATE_SELECTED_BORDER := BRONZE
const STATE_SELECTED_FILL := PANEL_ELEVATED
const STATE_DISABLED_TEXT := Color(TEXT_MUTED, 0.75)
const STATE_LOCKED_BORDER := Color(BRONZE_DARK, 0.5)

# --- Map (minimap, area map; glyph colours until the map art exists) -----------
const MAP_EXIT := Color(0.65, 0.5, 1.0)
const MAP_WAYSTONE := RESONANCE
const MAP_WAYSTONE_SILENT := TEXT_MUTED
const MAP_REST := Color(1.0, 0.55, 0.15)
const MAP_NPC := SUCCESS
const MAP_LANDMARK := BRONZE
const MAP_GOAL := WARNING
const MAP_PLAYER := RESONANCE

# --- Typography (design px) ----------------------------------------------------
## UI Font Integration 1.0 (docs/UI_FONT_INTEGRATION_1_0.md): IBM Plex Mono Regular for all text,
## Silkscreen (an 8-px grid font) for headings, window titles and display text only.
const BODY_FONT_PATH := "res://assets/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf"
const DISPLAY_FONT_PATH := "res://assets/fonts/silkscreen/Silkscreen-Regular.ttf"
## Body sizes (IBM Plex Mono matches the former sans optically at the same sizes).
const FONT_CAPTION := 14
const FONT_SMALL := 15
const FONT_BODY := 18
const FONT_SUBHEADING := 20
## Menu UX Polish 1.0 (docs/MENU_UX_POLISH_1_0.md): the compact text hierarchy of the dense menu pages (Skills,
## Quests, Professions, Journal details) - entry title / running text / metadata. Own type variations
## (MenuHeadingLabel = Silkscreen FONT_SECTION, MenuTitleLabel, MenuTextLabel, MenuMetaLabel), so the global
## sizes above and every other window stay as they are.
const FONT_MENU_TITLE := 18
const FONT_MENU_TEXT := 15
const FONT_MENU_META := 14
## Silkscreen sizes on its 8-px grid (cap height 15 / 20 / 40 px: above the body text).
const FONT_SECTION := 16
const FONT_HEADING := 24
const FONT_TITLE := 32
const FONT_DISPLAY := 64

# --- Layout (design px) --------------------------------------------------------
## Distance of HUD elements and windows from the canvas edge.
const SCREEN_MARGIN := 16
## Inner padding of panels and windows.
const PANEL_PADDING := 14
## Gap between elements in containers.
const GAP := 8
const BORDER := 2
## Thin rules (inner frames, slot borders) and the thick active-slot frame.
const BORDER_THIN := 1
const BORDER_THICK := 3
const CORNER := 3
## Inner padding of item / skill slots (the icon sits this far inside the frame).
const SLOT_PADDING := 5
## Item icon (inventory, bags) and the HUD combat/quick-use slot.
const ICON_SIZE := Vector2(40, 40)
const HUD_SLOT_SIZE := Vector2(64, 64)
## Combat HUD UX 2.0: the menu bar button (was 40): the 32 x 32 icon art 1:1 with a 1 px state frame around it.
const MENU_ICON_SIZE := Vector2(34, 34)
## HUD EXP Bar 1.0: as wide as the combat bar (2 x 64 + 6, 18, 4 x 64 + 3 x 6), 6 px below it.
const XP_BAR_SIZE := Vector2(426, 14)
const XP_BAR_GAP := 6
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
## Skill Icons Pixel Art 1.0: the skill art's size, drawn 1:1 in the combat bar and the class station.
const SKILL_ICON_SIZE := Vector2(40, 40)
## Main Window Layout Lock 1.0 (docs/MAIN_WINDOW_LAYOUT_LOCK_1_0.md): the one outer size of the seven main
## menus (Inventory / Character, Skills & Talents, Professions, Journal, Map, Options). 1120 = the widest
## frame the 150 % canvas (1280) still takes beside the book registers (1280 - 2 x 16 - 116 = 1132), so the
## width is the same at every UI scale; 760 high at 75-125 %, the 150 % canvas clamps every main window
## alike (688). Each menu lays out its own inside; long parts scroll in their own areas.
const MAIN_WINDOW_SIZE := Vector2(1120, 760)
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
static var _body_font: Font
static var _display_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## The one text font (IBM Plex Mono Regular, OFL 1.1): smooth rendering as designed
## (greyscale antialiasing, light hinting) on whole pixels - subpixel glyph positions lose
## strokes of small text under the Nearest canvas filter at 75 % UI scale ("+0.5%" read as
## "+9.5%"). Every label, button, tooltip, HUD and world text uses it - also draw code
## (draw_string) and Godot's own popups (ThemeDB fallback).
static func body_font() -> Font:
	if _body_font == null:
		var font := load(BODY_FONT_PATH) as FontFile
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.hinting = TextServer.HINTING_LIGHT
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
		if ThemeDB.fallback_font != font:
			font.fallbacks = [ThemeDB.fallback_font]   # Godot's built-in face for glyphs Plex lacks
		_body_font = font
	return _body_font


## Heading face (Silkscreen Regular, OFL 1.1): a pixel font on an 8-px grid, so no
## antialiasing, no hinting, whole-pixel positions. Only titles, headings, display text
## and the short skill letters; never body text or numbers in tables.
static func display_font() -> Font:
	if _display_font == null:
		var font := load(DISPLAY_FONT_PATH) as FontFile
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
		font.fallbacks = [body_font()]   # Silkscreen covers Latin only
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
	theme.default_font = body_font()
	theme.default_font_size = FONT_BODY
	# Godot's own popups (tooltips) and controls outside a themed tree use the same face.
	ThemeDB.fallback_font = body_font()

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
	for entry: Array in [[&"MenuTitleLabel", FONT_MENU_TITLE, TEXT_PRIMARY], [&"MenuTextLabel", FONT_MENU_TEXT, TEXT_PRIMARY],
			[&"MenuMetaLabel", FONT_MENU_META, TEXT_SECONDARY]]:
		theme.set_type_variation(entry[0], &"Label")
		theme.set_font_size(&"font_size", entry[0], entry[1])
		theme.set_color(&"font_color", entry[0], entry[2])
		theme.set_constant(&"line_spacing", entry[0], 1)
	theme.set_type_variation(&"MenuHeadingLabel", &"Label")   # the heading of a menu detail (Silkscreen, 8-px grid)
	theme.set_font(&"font", &"MenuHeadingLabel", display_font())
	theme.set_font_size(&"font_size", &"MenuHeadingLabel", FONT_SECTION)
	theme.set_color(&"font_color", &"MenuHeadingLabel", BRONZE)

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
	# clickable card (class cards): toggle pressed = selected (bronze border)
	theme.set_type_variation(&"CardButton", &"Button")
	_button_styles(theme, &"CardButton", 12, 10, PANEL, BRONZE_DARK)
	_button_fonts(theme, &"CardButton", TEXT_PRIMARY)
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
	# UI Scrollbars & Input Fields 1.0: a 2 px caret survives the 0.75 UI scale; read-only text dims
	theme.set_constant(&"caret_width", &"LineEdit", 2)
	theme.set_color(&"font_uneditable_color", &"LineEdit", TEXT_MUTED)
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
	_apply_skin(theme)
	return theme


## Optional art (UiSkin, docs/UI_ASSET_CATALOG_1_0.md): [stylebox, theme type, asset id].
## Each style above stays the fallback; an existing PNG replaces it as a nine-patch.
const SKINNED := [
	[&"panel", &"WindowPanel", &"window/panel"], [&"panel", &"HudPanel", &"panel/hud"],
	[&"panel", &"CardPanel", &"panel/card"], [&"panel", &"SelectedCardPanel", &"panel/card_selected"],
	[&"panel", &"InsetPanel", &"panel/inset"], [&"panel", &"TooltipPanel", &"tooltip/panel"],
	[&"normal", &"Button", &"button/normal"], [&"hover", &"Button", &"button/hover"],
	[&"pressed", &"Button", &"button/pressed"], [&"hover_pressed", &"Button", &"button/pressed"],
	[&"disabled", &"Button", &"button/disabled"],
	[&"normal", &"PrimaryButton", &"button/primary_normal"], [&"hover", &"PrimaryButton", &"button/primary_hover"],
	[&"pressed", &"PrimaryButton", &"button/primary_pressed"], [&"hover_pressed", &"PrimaryButton", &"button/primary_pressed"],
	[&"disabled", &"PrimaryButton", &"button/primary_disabled"],   # UI Panels & Primary Controls 1.0
	[&"normal", &"TabButton", &"tab/normal"], [&"hover", &"TabButton", &"tab/hover"],
	[&"pressed", &"TabButton", &"tab/selected"], [&"hover_pressed", &"TabButton", &"tab/selected"],
	[&"normal", &"InventorySlot", &"slot/normal"], [&"hover", &"InventorySlot", &"slot/hover"],
	[&"pressed", &"InventorySlot", &"slot/selected"], [&"hover_pressed", &"InventorySlot", &"slot/selected"],
	[&"disabled", &"InventorySlot", &"slot/disabled"],
	# UI Selection & Surface Polish 1.0: clickable cards speak the card language of Journal and class choice
	# (selected = panel/card_selected, gold); hover / disabled tint the card art (no extra PNGs). Keyboard
	# focus stays the separate resonance outline (focus style untouched), so selected + focus show both.
	[&"normal", &"CardButton", &"panel/card"], [&"hover", &"CardButton", &"panel/card", CARD_HOVER_TINT],
	[&"pressed", &"CardButton", &"panel/card_selected"],
	[&"hover_pressed", &"CardButton", &"panel/card_selected", CARD_HOVER_TINT],
	[&"disabled", &"CardButton", &"panel/card", CARD_DISABLED_TINT],
	# UI Scrollbars & Input Fields 1.0: one grabber image for both bars; hover / drag lift it by tint
	[&"grabber", &"VScrollBar", &"scroll/grabber"], [&"grabber_highlight", &"VScrollBar", &"scroll/grabber", GRABBER_HOVER_TINT],
	[&"grabber_pressed", &"VScrollBar", &"scroll/grabber", GRABBER_PRESSED_TINT], [&"scroll", &"VScrollBar", &"scroll/track"],
	[&"grabber", &"HScrollBar", &"scroll/grabber"], [&"grabber_highlight", &"HScrollBar", &"scroll/grabber", GRABBER_HOVER_TINT],
	[&"grabber_pressed", &"HScrollBar", &"scroll/grabber", GRABBER_PRESSED_TINT], [&"scroll", &"HScrollBar", &"scroll/track"],
	# input fields: focus = resonance rim (keyboard focus, never gold), read-only = the sunk well
	[&"normal", &"LineEdit", &"input/normal"], [&"focus", &"LineEdit", &"input/focus"],
	[&"read_only", &"LineEdit", &"input/disabled"],
	# Secondary Controls 1.0 (docs/UI_SECONDARY_CONTROLS_1_0.md): dropdowns are buttons - the closed
	# OptionButton uses the button art (open = pressed, bronze); its list is a card. Check toggles keep
	# the button frame for hover, but "on" is shown only by the gold mark (pressed = the normal frame).
	# Slider: the scroll groove as rail, a gold fill. Key hints: a small key cap in the slot language.
	[&"normal", &"OptionButton", &"button/normal"], [&"hover", &"OptionButton", &"button/hover"],
	[&"pressed", &"OptionButton", &"button/pressed"], [&"disabled", &"OptionButton", &"button/disabled"],
	[&"normal_mirrored", &"OptionButton", &"button/normal"], [&"hover_mirrored", &"OptionButton", &"button/hover"],
	[&"pressed_mirrored", &"OptionButton", &"button/pressed"], [&"disabled_mirrored", &"OptionButton", &"button/disabled"],
	[&"panel", &"PopupMenu", &"panel/card"],
	[&"normal", &"CheckButton", &"button/normal"], [&"hover", &"CheckButton", &"button/hover"],
	[&"pressed", &"CheckButton", &"button/normal"], [&"hover_pressed", &"CheckButton", &"button/hover"],
	[&"disabled", &"CheckButton", &"button/disabled"],
	[&"normal", &"CheckBox", &"button/normal"], [&"hover", &"CheckBox", &"button/hover"],
	[&"pressed", &"CheckBox", &"button/normal"], [&"hover_pressed", &"CheckBox", &"button/hover"],
	[&"disabled", &"CheckBox", &"button/disabled"],
	[&"slider", &"HSlider", &"scroll/track"], [&"grabber_area", &"HSlider", &"slider/fill"],
	[&"grabber_area_highlight", &"HSlider", &"slider/fill", GRABBER_HOVER_TINT],
	[&"panel", &"KeyChip", &"chip/key"],
	# HUD Bars Visual Integration 1.0: every ProgressBar's frame + groove (the fill is UiTheme.fill_box)
	[&"background", &"ProgressBar", &"bar/frame"],
]


## Secondary Controls 1.0: optional icon art, [icon name, theme type, asset id] - drawn 1:1 in design px
## (the sizes are the default theme's slots). A missing file keeps Godot's default icon.
const SKINNED_ICONS := [
	[&"arrow", &"OptionButton", &"dropdown/arrow"],
	[&"radio_checked", &"PopupMenu", &"dropdown/radio_on"], [&"radio_checked_disabled", &"PopupMenu", &"dropdown/radio_on"],
	[&"radio_unchecked", &"PopupMenu", &"dropdown/radio_off"], [&"radio_unchecked_disabled", &"PopupMenu", &"dropdown/radio_off_disabled"],
	[&"checked", &"PopupMenu", &"check/on"], [&"checked_disabled", &"PopupMenu", &"check/on_disabled"],
	[&"unchecked", &"PopupMenu", &"check/off"], [&"unchecked_disabled", &"PopupMenu", &"check/off_disabled"],
	[&"checked", &"CheckBox", &"check/on"], [&"checked_disabled", &"CheckBox", &"check/on_disabled"],
	[&"unchecked", &"CheckBox", &"check/off"], [&"unchecked_disabled", &"CheckBox", &"check/off_disabled"],
	[&"checked", &"CheckButton", &"check/on"], [&"checked_disabled", &"CheckButton", &"check/on_disabled"],
	[&"unchecked", &"CheckButton", &"check/off"], [&"unchecked_disabled", &"CheckButton", &"check/off_disabled"],
	[&"checked_mirrored", &"CheckButton", &"check/on"], [&"checked_disabled_mirrored", &"CheckButton", &"check/on_disabled"],
	[&"unchecked_mirrored", &"CheckButton", &"check/off"], [&"unchecked_disabled_mirrored", &"CheckButton", &"check/off_disabled"],
	[&"grabber", &"HSlider", &"slider/grabber"], [&"grabber_highlight", &"HSlider", &"slider/grabber_hover"],
	[&"grabber_disabled", &"HSlider", &"slider/grabber_disabled"],
]


## UI Selection & Surface Polish 1.0: StyleBoxTexture has no shadow (the procedural StyleBoxFlat had
## shadow_size 10 / 6), so skinned window panels draw a hard pixel shadow themselves: two strips just
## outside their own rect (right and below, light from the top left), nothing over the panel, no size,
## margin, anchor or input change. Only while the window/panel art is in use (no double shadow).
const SHADOW_OFFSET := 4.0
const SHADOW_COLOR := Color(0, 0, 0, 0.45)


static func draw_hard_shadow(item: Control) -> void:
	if not UiSkin.has(&"window/panel"):
		return
	var size := item.size
	item.draw_rect(Rect2(Vector2(size.x, SHADOW_OFFSET), Vector2(SHADOW_OFFSET, size.y)), SHADOW_COLOR)
	item.draw_rect(Rect2(Vector2(SHADOW_OFFSET, size.y), Vector2(size.x - SHADOW_OFFSET, SHADOW_OFFSET)), SHADOW_COLOR)


## Optional 4th SKINNED value: a modulate for state variants without their own art (only applied to art,
## never to the procedural fallback). Hover lifts the surface a little, disabled sinks it.
const CARD_HOVER_TINT := Color(1.16, 1.16, 1.16)
const CARD_DISABLED_TINT := Color(0.6, 0.6, 0.6)
const GRABBER_HOVER_TINT := Color(1.18, 1.18, 1.18)
const GRABBER_PRESSED_TINT := Color(1.32, 1.3, 1.26)


static func _apply_skin(theme: Theme) -> void:
	for entry: Array in SKINNED:
		var fallback := theme.get_stylebox(entry[0], entry[1])
		var style := UiSkin.stylebox(entry[2], fallback)
		if entry.size() > 3 and style is StyleBoxTexture:
			(style as StyleBoxTexture).modulate_color = entry[3]
		theme.set_stylebox(entry[0], entry[1], style)
	for entry: Array in SKINNED_ICONS:
		var art := UiSkin.texture(entry[2])
		if art != null:
			theme.set_icon(entry[0], entry[1], art)


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


## Menu UX Polish 1.0: wrapped text of a dense menu page in one of the Menu*Label variations (default: running
## text, 15) - the colour override like `wrapped`.
static func menu_text(text: String, color: Color = COLOR_TEXT, width: float = TEXT_WIDTH, variation: StringName = &"MenuTextLabel") -> Label:
	var result := wrapped(text, color, width)
	result.theme_type_variation = variation
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


## Skill Icons Pixel Art 1.0: the skill's art (skills/<id>, 40 x 40) shown 1:1, dimmed for a locked skill;
## null without a file - callers then keep their text-only layout (the art is optional, never required).
static func skill_icon(skill_id: StringName, dimmed: bool = false) -> TextureRect:
	var art := UiSkin.texture(StringName("skills/%s" % skill_id))
	if art == null:
		return null
	var icon := TextureRect.new()
	icon.name = "SkillIcon"
	icon.texture = art
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = SKILL_ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dimmed:
		icon.modulate = Color(0.5, 0.5, 0.5)   # like the HUD slot of an unusable skill
	return icon


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
		# the bar/fill art needs room for its lit and shaded row inside the 1 px frame
		result.add_theme_stylebox_override(&"fill", fill_box(fill) if height >= BAR_ART_MIN_HEIGHT else _flat_fill(fill))
	return result


static var _fills: Dictionary = {}
static var _flat_fills: Dictionary = {}

## HUD Bars Visual Integration 1.0: bars this high or higher get the bar/fill art (5 = poise: 3 px of fill).
const BAR_ART_MIN_HEIGHT := 5.0
## bar/fill's body tone (0xD8 / 0xFF): the tint is scaled by its inverse, so the body shows the exact colour.
const BAR_FILL_BODY := 216.0 / 255.0


## Shared fill style per colour (bars that change colour do not allocate). With the bar/fill art: the neutral
## mask tinted with `color` (lit top row, shaded bottom row), drawn 1 px inside the bar/frame ring (`inset`,
## ProgressBar draws its fill over the whole bar) - no side borders, so 1 % stays 1 % and nothing is squeezed.
## Without the art: the flat colour as before.
static func fill_box(color: Color, inset: bool = true) -> StyleBox:
	var key := [color, inset]
	if not _fills.has(key):
		var style := UiSkin.stylebox(&"bar/fill", _flat_fill(color))
		if style is StyleBoxTexture:
			style = style.duplicate()
			var tint := style as StyleBoxTexture
			tint.modulate_color = Color(color.r / BAR_FILL_BODY, color.g / BAR_FILL_BODY, color.b / BAR_FILL_BODY, color.a)
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				tint.set_content_margin(side, 0)   # no minimum width: the fill is exactly proportional
				tint.set_expand_margin(side, -1.0 if inset else 0.0)
		_fills[key] = style
	return _fills[key]


static func _flat_fill(color: Color) -> StyleBoxFlat:
	if not _flat_fills.has(color):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		_flat_fills[color] = box
	return _flat_fills[color]


## Wrapping tooltip content (Control._make_custom_tooltip). Width-limited, so long
## item texts never run off the screen; Godot keeps the popup inside the viewport.
static func tooltip(text: String) -> Control:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"TooltipLabel"
	var font_size := get_theme().get_font_size(&"font_size", &"TooltipLabel")
	var natural := body_font().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
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
