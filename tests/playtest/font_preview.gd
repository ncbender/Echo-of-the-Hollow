extends "res://tests/playtest/ui_gallery.gd"
## UI Font Comparison 1.0 (NOT headless, preview only): the real gallery screens and two specimen
## pages with candidate fonts. The font is swapped only inside this process (theme default font,
## heading types, ThemeDB fallback) - no project file, UiTheme constant or setting changes.
## Fonts: assets/fonts/candidates/<font>/ (OFL 1.1, licence files beside them, .gdignore).
##   godot --path . -s res://tests/playtest/font_preview.gd -- --fonts=current,pixelify,silkscreen,press
##       [--res=1920x1080,2560x1440] [--scale=1.0,1.25] [--only=specimen_text,specimen_ui,inventory_tooltip,...]
## Output: tests/output/font_preview/<font>_<res>_<scale>_<screen>.png (+ native crops of the specimens)

const FONT_OUT := "res://tests/output/font_preview"
const CANDIDATES := "res://assets/fonts/candidates/"
const FILES := {
	"pixelify": "pixelify_sans/PixelifySans-wght.ttf",
	"silkscreen": "silkscreen/Silkscreen-Regular.ttf",
	"press": "press_start_2p/PressStart2P-Regular.ttf",
	# Body Font Final Selection 1.1
	"gohu": "gohufont/gohufont-uni-14.bdf",
	"plex": "ibm_plex_mono/IBMPlexMono-Regular.ttf",
}
## Vector fonts keep their intended smooth rendering (antialiasing, light hinting).
const VECTOR := ["plex"]
const LABELS := {"current": "Current (Godot default + serif headings)", "pixelify": "A  Pixelify Sans", "silkscreen": "B  Silkscreen",
	"press": "C  Press Start 2P", "mix": "Pixelify body + Silkscreen headings", "gohu": "GohuFont 14", "plex": "IBM Plex Mono", "plexz": "IBM Plex Mono (zero)"}
const BdfFont := preload("res://tests/playtest/bdf_font.gd")
## Body Font Final Selection 1.1: real examples with the critical glyphs (5/S 2/Z 8/B 0/O 1/I/l B/G [ ]/( )).
const CRITICAL := ["Level 56   5/5   2/2   18%   68%   99%", "+25% attack speed  ·  +0.9 Crit Chance %", "Berserker  ·  Rootbound Sentinel",
	"The First Signs  ·  What the Roots Keep", "Inventory  ·  Skills & Talents  ·  Close [J / Esc]", "Iron Ingot x2  ·  Rage 80 / 100  ·  3/5",
	"5S 2Z 8B 0O 1Il BG [] () 6G 9g"]
const EXP_VALUES_2 := ["0%", "18%", "58%", "68%", "99%", "MAX"]

static var _loaded: Dictionary = {}
const SCREENS := ["specimen_text", "specimen_ui", "inventory_tooltip", "journal", "journal_side", "skills", "talents_full",
	"professions", "map", "options", "hud_combat"]
const SIZES := [14, 15, 18, 20, 22, 28, 16, 24]
const QUEST_TEXT := "Mara's cart lies broken on the Old Road. Recover the supply crates before the hollow creatures scatter them - the second wave will not wait."
const EXP_VALUES := ["0%", "18%", "68%", "99%", "MAX"]

var font_id: String = "current"
var _default_body: Font
var _default_heading: Font
var _overlay: CanvasLayer


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FONT_OUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/font_preview/slot_1.save.json"
	_default_body = ThemeDB.fallback_font
	_default_heading = UiTheme.display_font()
	_log("default body font: %s / heading: %s" % [_default_body.get_font_name(), _default_heading.get_font_name()])
	for id: String in _arg("fonts", "current,pixelify,silkscreen,press").split(","):
		_apply_font(id)
		for res_text in _arg("res", "1920x1080").split(","):
			var size := Vector2i(int(res_text.get_slice("x", 0)), int(res_text.get_slice("x", 1)))
			for scale_text in _arg("scale", "1.0").split(","):
				await _pass(size, float(scale_text))
	_apply_font("current")
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(FONT_OUT.path_join("font_preview_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0)


## Pixel fonts: no antialiasing, no hinting, whole-pixel positions (the project's Nearest look).
static func load_font(id: String) -> Font:
	if _loaded.has(id):
		return _loaded[id]
	if id == "ui":   # the integrated UI body font (UI Font Integration 1.0, imported resource)
		return UiTheme.body_font()
	if id == "plexz":   # IBM Plex Mono with its OpenType "zero" feature (marked zero)
		var variation := FontVariation.new()
		variation.base_font = load_font("plex")
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("zero"): 1}
		_loaded[id] = variation
		return variation
	var path: String = CANDIDATES + FILES[id]
	var font: FontFile
	if path.ends_with(".bdf"):
		font = BdfFont.load_bdf(path)
	else:
		font = FontFile.new()
		if font.load_dynamic_font(path) != OK:
			push_error("font %s missing" % id)
			return null
		if id in VECTOR:
			font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			font.hinting = TextServer.HINTING_LIGHT
		else:
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.generate_mipmaps = false
	_loaded[id] = font
	return font


## "<body>" (heading = body), "<body>+<heading>" (e.g. gohu+silkscreen), "current", "mix".
func _fonts_for(id: String) -> Array[Font]:
	match id:
		"current":
			return [_default_body, _default_heading]
		"mix":
			return [load_font("pixelify"), load_font("silkscreen")]
	if id.contains("+"):
		return [load_font(id.get_slice("+", 0)), load_font(id.get_slice("+", 1))]
	var font := load_font(id)
	return [font, font]


static func label_for(id: String) -> String:
	if id.contains("+"):
		return "%s + %s" % [LABELS.get(id.get_slice("+", 0), id), LABELS.get(id.get_slice("+", 1), "")]
	return LABELS.get(id, id)


## Process-local swap: the theme default, the three heading types, the fallback (draw code).
func _apply_font(id: String) -> void:
	font_id = id
	var fonts := _fonts_for(id)
	var theme := UiTheme.get_theme()
	ThemeDB.fallback_font = fonts[0]
	theme.default_font = null if id == "current" else fonts[0]
	for type: StringName in [&"HeaderLabel", &"TitleLabel", &"DisplayLabel"]:
		theme.set_font(&"font", type, fonts[1])
	UiTheme._display_font = fonts[1]
	_log("font %s: body %s, heading %s" % [id, fonts[0].get_font_name(), fonts[1].get_font_name()])
	for size: int in [14, 18]:
		_log("  %d px: height %.1f, sentence width %.0f" % [size, fonts[0].get_height(size),
			fonts[0].get_string_size(QUEST_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x])


func _rich_character() -> Character:
	var character := super._rich_character()
	for quest_id: StringName in [&"the_lost_hunter", &"what_the_roots_keep"]:
		StoryService.start(character, quest_id)
	return character


func _pass(resolution: Vector2i, scale: float) -> void:
	tag = "%s_%dp_%d" % [font_id, resolution.y, roundi(scale * 100.0)]
	root.mode = Window.MODE_WINDOWED
	root.borderless = resolution.x >= DisplayServer.screen_get_size().x
	root.size = resolution
	root.position = DisplayServer.screen_get_position()
	session.settings.set_ui_scale(scale)
	session.settings.set_reduce_motion(true)
	await _frames(8)
	session.set_character(_rich_character())
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	await _await_map()
	_log("%s: window %s, canvas %s" % [tag, root.size, map.hud.get_viewport().get_visible_rect().size])
	var only := _arg("only", "")
	for screen: String in (SCREENS if only == "" else Array(only.split(","))):
		map.hud.close_windows()
		await GalleryScreens.reset(self)
		if screen.begins_with("specimen"):
			_specimen(screen)
			await _frames(6)
			await _shot(screen)
			_crop_columns(screen)
			_overlay.queue_free()
			_overlay = null
			await _frames(2)
			continue
		var label: String = await GalleryScreens.open(self, "journal" if screen == "journal_side" else screen)
		if label == "":
			continue
		if screen == "journal_side":
			map.hud.journal_panel.show_page("Side Quests")
		await _frames(6)
		_check_layout(screen)
		_log_windows(screen)
		await _shot(screen)
		if _overlay != null:
			_overlay.queue_free()
			_overlay = null
	map.hud.close_windows()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := FONT_OUT.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _log_windows(screen: String) -> void:
	for node in map.hud.find_children("*", "UiWindow", true, false):
		var window := node as UiWindow
		if window.is_visible_in_tree():
			_log("  %s %s: %s size %s" % [tag, screen, window.name, window.size.round()])
	for node in map.hud.find_children("*", "ItemTooltip", true, false):
		if (node as Control).is_visible_in_tree():
			_log("  %s %s: ItemTooltip size %s" % [tag, screen, (node as Control).size.round()])


# --- specimens: all fonts side by side, identical texts, sizes and widths -----------------------

func _specimen(page: String) -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	map.add_child(_overlay)
	var back := ColorRect.new()
	back.color = UiTheme.BG
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.theme = UiTheme.get_theme()
	_overlay.add_child(back)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_top = 12
	row.offset_right = -12
	row.offset_bottom = -12
	row.add_theme_constant_override(&"separation", 10)
	back.add_child(row)
	for id: String in _arg("columns", "current,pixelify,silkscreen,press").split(","):
		var column := PanelContainer.new()
		column.name = "Column_%s" % id
		column.theme_type_variation = &"HudPanel"
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.clip_contents = true
		column.theme = _column_theme(id)
		row.add_child(column)
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 6)
		column.add_child(box)
		box.add_child(UiTheme.heading(label_for(id)))
		match page:
			"specimen_text":
				_text_rows(box)
			"specimen_critical":
				_critical_rows(box)
			"specimen_exp":
				_exp_rows(box)
			_:
				_ui_rows(box)


func _column_theme(id: String) -> Theme:
	var fonts := _fonts_for(id)
	var theme := Theme.new()
	theme.default_font = fonts[0]
	theme.default_font_size = UiTheme.FONT_BODY
	for type: StringName in [&"HeaderLabel", &"TitleLabel", &"DisplayLabel"]:
		theme.set_font(&"font", type, fonts[1])
	return theme


func _sized(text: String, size: int, color: Color = UiTheme.TEXT_PRIMARY, wrap: bool = false, clip: bool = true) -> Label:
	var label := UiTheme.label(text, color)
	label.add_theme_font_size_override(&"font_size", size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 10
	elif clip:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
	return label


func _text_rows(box: VBoxContainer) -> void:
	for size: int in SIZES:
		box.add_child(_sized("%d  The Whispering Stone 1Il 0Oo" % size, size, UiTheme.TEXT_PRIMARY if size != 16 and size != 24 else UiTheme.RESONANCE))
	for size: int in [14, 18, 24]:
		box.add_child(_sized("%d  0123456789  5S 2Z 8B 6G Il1 O0" % size, size, UiTheme.WARNING))
	box.add_child(_sized("1 I l | 0 O o | 5 S | 8 B | rn m", UiTheme.FONT_BODY, UiTheme.PARCHMENT))
	box.add_child(_sized("0%  18%  68%  99%  MAX  ·  12 / 140  ·  2.1s", UiTheme.FONT_BODY, UiTheme.PARCHMENT))
	box.add_child(_sized("Parry ready in 2.1s. \"Embers\" (3/5)! Why? - Close [J / Esc]", UiTheme.FONT_SMALL))
	box.add_child(_sized(QUEST_TEXT, UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY, true))
	box.add_child(_sized("+12% Physical Damage  ·  Requires Level 4  ·  Iron Ingot x2", UiTheme.FONT_SMALL, UiTheme.SUCCESS, true))
	box.add_child(_sized("You · Exit · Waystone · Silent waystone · Resting place · Person · Landmark · Current goal", UiTheme.FONT_CAPTION, UiTheme.TEXT_SECONDARY, true))


func _ui_rows(box: VBoxContainer) -> void:
	var tabs := UiTabs.new()
	for id: String in ["Main Story", "Side Quests", "Class Quests", "Completed", "Haven"]:
		tabs.add_tab(id, id)
	tabs.select("Side Quests")
	box.add_child(tabs)
	var buttons := HFlowContainer.new()
	buttons.add_child(UiTheme.button("Craft", &"PrimaryButton"))
	buttons.add_child(UiTheme.button("Close [J / Esc]"))
	var off := UiTheme.button("Restore")
	off.disabled = true
	buttons.add_child(off)
	box.add_child(buttons)
	var slot := UiTheme.button("Tan Hide   ·   Leatherworking 1", &"InventorySlot")
	slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot.clip_text = true
	box.add_child(slot)
	var tracker := PanelContainer.new()
	tracker.theme_type_variation = &"HudPanel"
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override(&"separation", 2)
	lines.add_child(_sized("THE FIRST SIGNS", UiTheme.FONT_SMALL, UiTheme.BRONZE))
	lines.add_child(_sized("Examine the Split Watchstone  0/1", UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY, true))
	lines.add_child(_sized("The Lost Hunter: Follow the tracks  1/2", UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY))
	lines.add_child(_sized("+1 more (J)", UiTheme.FONT_CAPTION, UiTheme.TEXT_MUTED))
	tracker.add_child(lines)
	box.add_child(tracker)
	var status := HBoxContainer.new()
	for word: String in ["Q", "No Rage", "2.1s", "Empty", "2/2"]:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"InsetPanel"
		chip.add_child(_sized(word, UiTheme.FONT_CAPTION, UiTheme.BRONZE if word == "Q" else UiTheme.TEXT_SECONDARY, false, false))
		status.add_child(chip)
	box.add_child(status)
	for value: String in EXP_VALUES:
		box.add_child(_exp_bar(value, 426.0))
	box.add_child(_sized("UI Scale   75 %   100 %   125 %   150 %", UiTheme.FONT_BODY))
	box.add_child(_sized("Reduce motion  ·  Periodic autosave  ·  Show save indicator", UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY, true))


## Body Font Final Selection 1.1: headings in the heading font (16 / 24, the Silkscreen grid), then the
## critical real examples at the small and the body size, a long tooltip, a quest text, a recipe row.
func _critical_rows(box: VBoxContainer) -> void:
	var heading_font := box.get_theme_font(&"font", &"HeaderLabel")
	for entry: Array in [["Skills & Talents", 24], ["The First Signs  ·  Rootbound Sentinel", 16]]:
		var title := _sized(entry[0], entry[1], UiTheme.BRONZE)
		title.add_theme_font_override(&"font", heading_font)
		box.add_child(title)
	for size: int in [UiTheme.FONT_SMALL, UiTheme.FONT_BODY]:
		box.add_child(_sized("- %d px -" % size, UiTheme.FONT_CAPTION, UiTheme.TEXT_MUTED))
		for line: String in CRITICAL:
			box.add_child(_sized(line, size, UiTheme.PARCHMENT if line.begins_with("5S") else UiTheme.TEXT_PRIMARY))
	box.add_child(_sized("Capstone - unlocks Unbound Fury: 10 s of +25% attack speed, +20% damage, +2 life on hit; rage does not decay. Requires 30 points in lower tiers of Berserker (30 / 30).",
		UiTheme.FONT_BODY, UiTheme.TEXT_PRIMARY, true))
	box.add_child(_sized(QUEST_TEXT, UiTheme.FONT_BODY, UiTheme.TEXT_SECONDARY, true))
	box.add_child(_sized("Tan Hide  ·  Raw Hide x2, Flax Fiber x1  ·  Leatherworking 1  ·  Uses 1/1", UiTheme.FONT_SMALL, UiTheme.SUCCESS, true))


## The EXP percentage at the real 14 px height (caption 13, as HudXpBar) and at 18 px (16 px text).
func _exp_rows(box: VBoxContainer) -> void:
	var width := minf(426.0, root.get_visible_rect().size.x / 4.0 - 40.0)
	for entry: Array in [[14.0, 13], [18.0, 16]]:
		box.add_child(_sized("bar %d px, text %d px, width %d" % [entry[0], entry[1], width], UiTheme.FONT_CAPTION, UiTheme.TEXT_MUTED))
		for value: String in EXP_VALUES_2:
			box.add_child(_exp_bar(value, width, entry[0], entry[1]))


## Simulated EXP bar (specimen; the real one is HudXpBar): percentage centred inside, as the HUD (dim bronze fill).
func _exp_bar(value: String, width: float, height: float = 14.0, font_size: int = 13) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(width, height)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var bar := UiTheme.bar(height, UiTheme.XP)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.max_value = 100
	bar.value = 100.0 if value == "MAX" else float(value.trim_suffix("%"))
	stack.add_child(bar)
	var text := UiTheme.styled(value, &"CaptionLabel")
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override(&"font_color", UiTheme.PARCHMENT)
	text.add_theme_constant_override(&"outline_size", 4)
	text.add_theme_font_size_override(&"font_size", font_size)
	stack.add_child(text)
	return stack


## One simulated bar at its planned place: centred under the combat bar, in the 16 px bottom margin.
func _exp_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	map.add_child(_overlay)
	var holder := Control.new()
	holder.theme = UiTheme.get_theme()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	var left := map.hud.quick_use.get_global_rect()
	var right := map.hud.skill_bar.get_global_rect()
	var bar := _exp_bar("68%", right.end.x - left.position.x)
	holder.add_child(bar)
	bar.position = Vector2(left.position.x, maxf(left.end.y, right.end.y) + 1.0)
	bar.size = Vector2(right.end.x - left.position.x, 14)


## The specimen columns at native screen pixels (the screenshot is the full window).
func _crop_columns(page: String) -> void:
	var image := root.get_texture().get_image()
	var factor := float(root.size.x) / root.get_visible_rect().size.x
	for node in _overlay.find_children("Column_*", "PanelContainer", true, false):
		var column := node as Control
		var rect := Rect2(column.global_position * factor, column.size * factor)
		var crop := Rect2i(rect.position.round(), Vector2i(rect.size))
		crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if crop.has_area():
			image.get_region(crop).save_png(ProjectSettings.globalize_path(FONT_OUT.path_join("%s_%s_%s_crop.png" % [tag, page, column.name.trim_prefix("Column_")])))
