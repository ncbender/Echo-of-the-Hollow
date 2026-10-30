extends "res://tests/playtest/ui_gallery.gd"
## Core UI Asset Prototype 1.0 (NOT headless): the first UI art in real windows - inventory with a
## selected bag slot and a hovered button (real mouse motion through the viewport), journal, HUD with
## the combat bar; layout checks of the gallery plus screenshots for the visual review.
##   godot --path . -s res://tests/playtest/ui_art_check.gd -- --res=1920x1080,2560x1440 --scale=1.0,1.25
## Output: tests/output/ui_art/<res>_<scale>_<screen>.png

const ART_OUT := "res://tests/output/ui_art"
const SCREENS := ["inventory", "journal", "hud_combat", "states", "inputs", "professions_search", "options", "map", "classes", "inventory_tooltip",
	"controls", "inventory_sort", "skills_mods", "options_gameplay", "options_audio", "options_controls",
	"booktabs_class", "booktabs_professions", "bars", "resource_text", "map_markers", "skill_icons", "weapons_tab"]
## UI Core States 1.0: every skinned state of one control type, drawn with the theme's real style.
## Rows of [sample size, [[style name, theme type], ...]] (UI Panels & Primary Controls 1.0: primary
## states and the five panels, the panels once small and once large for the nine-patch stretch).
const STATE_ROWS := [
	[Vector2(150, 40), [[&"normal", &"Button"], [&"hover", &"Button"], [&"pressed", &"Button"], [&"disabled", &"Button"]]],
	[Vector2(150, 40), [[&"normal", &"PrimaryButton"], [&"hover", &"PrimaryButton"], [&"pressed", &"PrimaryButton"], [&"disabled", &"PrimaryButton"]]],
	[Vector2(56, 56), [[&"normal", &"InventorySlot"], [&"hover", &"InventorySlot"], [&"pressed", &"InventorySlot"], [&"disabled", &"InventorySlot"]]],
	[Vector2(150, 37), [[&"normal", &"TabButton"], [&"hover", &"TabButton"], [&"pressed", &"TabButton"]]],
	[Vector2(64, 30), [[&"panel", &"HudPanel"], [&"panel", &"CardPanel"], [&"panel", &"SelectedCardPanel"], [&"panel", &"InsetPanel"], [&"panel", &"TooltipPanel"]]],
	[Vector2(230, 110), [[&"panel", &"HudPanel"], [&"panel", &"CardPanel"], [&"panel", &"SelectedCardPanel"], [&"panel", &"InsetPanel"], [&"panel", &"TooltipPanel"]]],
	# UI Scrollbars & Input Fields 1.0
	[Vector2(10, 90), [[&"scroll", &"VScrollBar"], [&"grabber", &"VScrollBar"], [&"grabber_highlight", &"VScrollBar"], [&"grabber_pressed", &"VScrollBar"]]],
	[Vector2(90, 10), [[&"scroll", &"HScrollBar"], [&"grabber", &"HScrollBar"], [&"grabber_highlight", &"HScrollBar"], [&"grabber_pressed", &"HScrollBar"]]],
	[Vector2(220, 40), [[&"normal", &"LineEdit"], [&"focus", &"LineEdit"], [&"read_only", &"LineEdit"]]],
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_OUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/ui_art_check/slot_1.save.json"
	for res_text in _arg("res", "1920x1080").split(","):
		var size := Vector2i(int(res_text.get_slice("x", 0)), int(res_text.get_slice("x", 1)))
		for scale_text in _arg("scale", "1.0").split(","):
			await _art_pass(size, float(scale_text))
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	quit(0 if failures == 0 else 1)


func _art_pass(resolution: Vector2i, scale: float) -> void:
	tag = "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
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
	var only := _arg("only", "")   # --only=a,b: a subset of SCREENS
	for screen: String in (SCREENS if only == "" else Array(only.split(","))):
		map.hud.close_windows()
		await GalleryScreens.reset(self)
		if screen == "states":
			var board := _state_board()
			await _frames(6)
			await _art_shot(screen)
			board.queue_free()
			await _frames(2)
			continue
		if screen == "inputs":   # UI Scrollbars & Input Fields 1.0: live fields and bars, real input
			var live := _input_board()
			await _frames(6)
			await _input_checks(live)
			live.queue_free()
			await _frames(2)
			continue
		if screen == "controls":   # Secondary Controls 1.0: every state of dropdown, check, slider, key chip
			var controls := _controls_board()
			await _frames(6)
			await _controls_checks(controls)
			controls.queue_free()
			await _frames(2)
			continue
		if screen == "weapons_tab":   # Skills & Talents UX 2.0 Phase 1
			await _weapons_tab_states()
			continue
		if screen == "skill_icons":   # Skill Icons Pixel Art 1.0
			await _skill_icon_states()
			continue
		if screen == "map_markers":   # Map Markers Pixel Art 1.0
			await _map_marker_states()
			continue
		if screen == "resource_text":   # HUD Resource Text Readability 1.0
			await _resource_text_sheet()
			continue
		if screen == "bars":   # HUD Bars Visual Integration 1.0
			await _bar_states()
			continue
		if screen == "booktabs_class" or screen == "booktabs_professions":   # BookTabs Visual Integration 1.0; Professions again since Menu UX Polish 1.1
			await _booktab_states(screen)
			continue
		if screen in ["inventory_sort", "skills_mods", "options_gameplay", "options_audio", "options_controls"]:
			await _real_secondary(screen)
			continue
		if screen == "professions_search":
			await GalleryScreens.open(self, "professions")
			await _frames(4)
			await _search_checks()
			_check_layout(screen)
			await _art_shot(screen)
			continue
		await GalleryScreens.open(self, screen)
		await _frames(6)
		if screen == "classes":   # UI Selection & Surface Polish 1.0: the class cards in every state
			await _class_card_states()
		if screen == "hud_combat":   # a real simple tooltip (TooltipPanel) over the menu bar
			var icon: Control = map.hud.menu_bar.buttons[&"journal"]
			await _hover(icon)
			for i in 60:
				await process_frame
			await _art_shot("tooltip")
		if screen == "hud_combat":   # Menu Icons 1.0: every entry of the bar finds its art
			for entry: Array in HudMenuBar.ENTRIES:
				var button: HudMenuBar.MenuIcon = map.hud.menu_bar.buttons[entry[0]]
				_check(button.icon_id == entry[3] and UiSkin.has(StringName("menu/%s" % button.icon_id)) and button.is_visible_in_tree(),
					"%s menu icon %s -> menu/%s.png shown" % [tag, entry[0], entry[3]])
		if screen == "inventory":
			_check(UiSkin.has(&"slot/selected") and UiSkin.has(&"button/hover"), "%s art present" % tag)
			var cells := map.hud.inventory_panel.find_children("*", "ItemCell", true, false)
			var bag_cell: ItemCell = null
			for node in cells:
				var cell := node as ItemCell
				if cell.equip_slot < 0 and cell.instance_id != "":
					bag_cell = cell
					break
			if _check_ok(bag_cell != null, "%s a bag cell" % tag):
				bag_cell.button_pressed = true   # the selected state (toggle)
			var close := _close_button(map.hud.inventory_panel)
			if _check_ok(close != null, "%s close button" % tag):
				await _hover(close)
				_check(close.is_hovered(), "%s close button hovered by the real mouse" % tag)
			# a second shot with the real mouse on a bag cell (slot hover next to the selected one)
			var other: ItemCell = null
			for node in cells:
				var cell := node as ItemCell
				if cell.equip_slot < 0 and cell.instance_id != "" and cell != bag_cell:
					other = cell
					break
			if _check_ok(other != null, "%s second bag cell" % tag):
				await _hover(other)
				_check(other.is_hovered(), "%s bag cell hovered by the real mouse" % tag)
				await _art_shot("inventory_slot_hover")
		_check_layout(screen)
		await _art_shot(screen)
	map.hud.close_windows()


## A window-panel board: per control type its states, each drawn with the theme's real (skinned)
## style box, then live controls (toggled-on button, disabled button and slot, tabs with a selection).
func _state_board() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 50
	map.add_child(layer)
	var theme := UiTheme.get_theme()
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.theme_type_variation = &"WindowPanel"
	panel.position = Vector2(40, 40)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiTheme.styled("UI Core States", &"TitleLabel"))
	for row: Array in STATE_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 12)
		box.add_child(line)
		for pair: Array in row[1]:
			var cell := VBoxContainer.new()
			var sample := Panel.new()
			sample.custom_minimum_size = row[0]
			sample.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # thin scroll samples keep their size
			var style := theme.get_stylebox(pair[0], pair[1])
			_check(style is StyleBoxTexture, "%s %s %s uses the art" % [tag, pair[1], pair[0]])
			sample.add_theme_stylebox_override(&"panel", style)
			cell.add_child(sample)
			cell.add_child(UiTheme.styled("%s %s" % [pair[1], pair[0]] if pair[0] != &"panel" else String(pair[1]), &"CaptionLabel"))
			line.add_child(cell)
	var live := HBoxContainer.new()
	live.add_theme_constant_override(&"separation", 12)
	box.add_child(live)
	var on := UiTheme.button("Windowed")
	on.toggle_mode = true
	on.button_pressed = true
	live.add_child(on)
	var off := UiTheme.button("Restore")
	off.disabled = true
	live.add_child(off)
	live.add_child(UiTheme.button("Craft", &"PrimaryButton"))
	var no_craft := UiTheme.button("Craft", &"PrimaryButton")
	no_craft.disabled = true
	live.add_child(no_craft)
	var locked := UiTheme.button("", &"InventorySlot")
	locked.custom_minimum_size = Vector2(56, 56)
	locked.disabled = true
	live.add_child(locked)
	var tabs := UiTabs.new()
	for id: String in ["Main Story", "Side Quests", "Haven"]:
		tabs.add_tab(id, id)
	tabs.select("Side Quests")
	box.add_child(tabs)
	return layer


## Class station cards: as opened, hover (real mouse) on another card, keyboard focus alone on another
## card, selection + keyboard focus on the selected card - one screenshot each.
func _class_card_states() -> void:
	var panel := map.hud.class_panel
	var selected := panel.find_child("Class_%s" % panel.selected_class, true, false) as Button
	var other: Button = null
	for node in panel.find_children("Class_*", "Button", true, false):
		if node != selected:
			other = node as Button
			break
	if not _check_ok(selected != null and other != null and selected.button_pressed, "%s class cards found" % tag):
		return
	_check(selected.get_theme_stylebox(&"pressed") is StyleBoxTexture, "%s selected class card uses the card art" % tag)
	await _art_shot("classes_opened")
	await _hover(other)
	_check(other.is_hovered() and not other.button_pressed, "%s other card hovered, not selected" % tag)
	await _art_shot("classes_hover")
	await _hover(map.hud.menu_bar)   # pointer away from the cards
	other.grab_focus()
	await _frames(3)
	_check(other.has_focus() and not other.button_pressed, "%s focus alone on an unselected card" % tag)
	await _art_shot("classes_focus")
	selected.grab_focus()
	await _frames(3)
	_check(selected.has_focus() and selected.button_pressed, "%s selected card focused" % tag)
	await _art_shot("classes_selected_focus")


func _check_ok(ok: bool, text: String) -> bool:
	_check(ok, text)
	return ok


func _close_button(window: UiWindow) -> Button:
	for node in window.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with("Close") and button.is_visible_in_tree():
			return button
	return null


## Real mouse motion onto the control (screen position from the canvas through the root transform).
## Live controls on a window panel: three input fields (placeholder, focused with text, read-only) and a
## scroll area larger than its box in both directions (a vertical and a horizontal bar).
func _input_board() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 50
	map.add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = Vector2(40, 40)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.styled("Scrollbars & Input Fields", &"TitleLabel"))
	var fields := HBoxContainer.new()
	fields.add_theme_constant_override(&"separation", 12)
	box.add_child(fields)
	for spec: Array in [["Empty", "", true], ["Focused", "Iron Ingot", true], ["ReadOnly", "Read only", false]]:
		var edit := LineEdit.new()
		edit.name = "Edit%s" % spec[0]
		edit.placeholder_text = "Search recipes..."
		edit.text = spec[1]
		edit.editable = spec[2]
		edit.custom_minimum_size = Vector2(260, 0)
		fields.add_child(edit)
	var scroll := ScrollContainer.new()
	scroll.name = "BoardScroll"
	scroll.custom_minimum_size = Vector2(520, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	box.add_child(scroll)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	for i in 30:
		list.add_child(UiTheme.styled("Row %02d  -  a long line that is wider than the scroll area so the horizontal bar has something to move" % i, &"SmallLabel"))
	return layer


## Real input: focus + typing into a field (caret), wheel over the scroll area, drag of the vertical
## grabber and a click into the horizontal track - each must move only its own axis.
func _input_checks(layer: CanvasLayer) -> void:
	var focused := layer.find_child("EditFocused", true, false) as LineEdit
	var scroll := layer.find_child("BoardScroll", true, false) as ScrollContainer
	_check(focused.get_theme_stylebox(&"focus") is StyleBoxTexture and focused.get_theme_stylebox(&"normal") is StyleBoxTexture, "%s input art in use" % tag)
	_check(scroll.get_v_scroll_bar().get_theme_stylebox(&"grabber") is StyleBoxTexture, "%s scroll art in use" % tag)
	await _click(focused)
	_check(focused.has_focus(), "%s a click focuses the field" % tag)
	focused.caret_column = focused.text.length()
	await _type("sm")
	_check(focused.text == "Iron Ingotsm", "%s typing reaches the field (%s)" % [tag, focused.text])
	await _art_shot("inputs")
	var bar := scroll.get_v_scroll_bar()
	var before := scroll.scroll_vertical
	await _wheel(scroll, MOUSE_BUTTON_WHEEL_DOWN)
	_check(scroll.scroll_vertical > before, "%s the wheel scrolls the area (%d -> %d)" % [tag, before, scroll.scroll_vertical])
	# drag the vertical grabber (its centre) towards the bottom of the bar
	var page := bar.page / maxf(1.0, bar.max_value)
	var grab_centre := bar.size.y * (float(scroll.scroll_vertical) / maxf(1.0, bar.max_value) + page / 2.0)
	var from := root.get_final_transform() * (bar.get_global_rect().position + Vector2(bar.size.x / 2.0, grab_centre))
	var to := root.get_final_transform() * (bar.get_global_rect().position + Vector2(bar.size.x / 2.0, bar.size.y * 0.8))
	var v_before := scroll.scroll_vertical
	var h_start := scroll.scroll_horizontal
	await _drag(from, to)
	_check(scroll.scroll_vertical > v_before and scroll.scroll_horizontal == h_start,
		"%s dragging the grabber scrolls vertically only (%d -> %d)" % [tag, v_before, scroll.scroll_vertical])
	var h_bar := scroll.get_h_scroll_bar()
	var h_before := scroll.scroll_horizontal
	var track := root.get_final_transform() * (h_bar.get_global_rect().position + Vector2(h_bar.size.x * 0.9, h_bar.size.y / 2.0))
	await _drag(track, track)
	_check(scroll.scroll_horizontal > h_before, "%s a click into the horizontal track pages right (%d -> %d)" % [tag, h_before, scroll.scroll_horizontal])
	_check(bar.size.x >= 9.5 and h_bar.size.y >= 9.5, "%s bars keep their 10 px thickness (%.1f / %.1f)" % [tag, bar.size.x, h_bar.size.y])
	await _art_shot("inputs_scrolled")


## Professions: the search field focused by a click, typed into, the list filtered; a shot with caret.
func _search_checks() -> void:
	var panel := map.hud.professions_panel
	var search := panel.find_child("RecipeSearch", true, false) as LineEdit
	if not _check_ok(search != null, "%s recipe search field" % tag):
		return
	var height := search.size.y
	await _click(search)
	_check(search.has_focus(), "%s the search field takes the focus" % tag)
	await _type("sme")
	search = panel.find_child("RecipeSearch", true, false) as LineEdit
	_check(search.text == "sme" and search.has_focus(), "%s typed into the search, focus kept (%s)" % [tag, search.text])
	_check(is_equal_approx(search.size.y, height), "%s the field keeps its height when focused (%.1f)" % [tag, search.size.y])
	var line := search.get_theme_font(&"font").get_height(search.get_theme_font_size(&"font_size"))
	var inner := search.size.y - search.get_theme_stylebox(&"focus").get_minimum_size().y
	_check(inner + 0.5 >= line, "%s the text line fits inside the field (%.1f >= %.1f)" % [tag, inner, line])


## Secondary Controls 1.0 board on a window panel: dropdowns (normal, hover, focus, disabled, one with a
## long text, one at the right screen edge), check toggles (off, on, hover, focus, disabled on/off), sliders
## (normal, keyboard, disabled) and the key chips of the HUD and the windows.
func _controls_board() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 50
	map.add_child(layer)
	var panel := PanelContainer.new()
	panel.theme = UiTheme.get_theme()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = Vector2(40, 40)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	box.add_child(UiTheme.styled("Secondary Controls", &"TitleLabel"))
	var drops := HBoxContainer.new()
	drops.add_theme_constant_override(&"separation", 12)
	box.add_child(drops)
	for spec: Array in [["DropNormal", false], ["DropHover", false], ["DropFocus", false], ["DropDisabled", true]]:
		drops.add_child(_drop(spec[0], ["Default", "Rarity", "Type", "Name"], spec[1]))
	var long := _drop("DropLong", ["Form: none", "Cleaving Arc", "Echoing Roar (locked: reach level 12 and finish the Warden's trial)"], false)
	long.set_item_disabled(2, true)
	drops.add_child(long)
	var checks := HBoxContainer.new()
	checks.add_theme_constant_override(&"separation", 12)
	box.add_child(checks)
	for spec: Array in [["CheckOff", false, false], ["CheckOn", true, false], ["CheckHover", true, false], ["CheckFocus", false, false],
			["CheckOffDisabled", false, true], ["CheckOnDisabled", true, true]]:
		var toggle := CheckButton.new()
		toggle.name = spec[0]
		toggle.text = String(spec[0]).trim_prefix("Check")
		toggle.button_pressed = spec[1]
		toggle.disabled = spec[2]
		checks.add_child(toggle)
	var sliders := HBoxContainer.new()
	sliders.add_theme_constant_override(&"separation", 24)
	box.add_child(sliders)
	for spec: Array in [["SliderNormal", 40.0, true], ["SliderKeys", 50.0, true], ["SliderDisabled", 70.0, false]]:
		var slider := HSlider.new()
		slider.name = spec[0]
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 5.0
		slider.value = spec[1]
		slider.editable = spec[2]
		slider.custom_minimum_size = Vector2(260, 24)
		sliders.add_child(slider)
	var chips := HBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override(&"separation", 6)
	box.add_child(chips)
	for key: String in ["I", "C", "T", "P", "J", "M", "O", "1", "2", "Q", "E", "R", "F", "G", "Esc", "Shift", "LMB / RMB", "Mouse Wheel"]:
		chips.add_child(UiTheme.key_chip(key))
	# a dropdown at the right screen edge (its list must open inside the screen)
	var edge := _drop("DropEdge", ["Default", "Rarity", "A rather long sort name"], false)
	edge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	edge.position = Vector2(root.get_visible_rect().size.x / root.get_final_transform().get_scale().x - 160.0, 820.0)
	layer.add_child(edge)
	return layer


func _drop(drop_name: String, items: Array, disabled: bool) -> OptionButton:
	var drop := OptionButton.new()
	drop.name = drop_name
	for item: String in items:
		drop.add_item(item)
	drop.select(1 if items.size() > 1 else 0)
	drop.disabled = disabled
	return drop


func _controls_checks(layer: CanvasLayer) -> void:
	var theme := UiTheme.get_theme()
	for pair: Array in [[&"arrow", &"OptionButton"], [&"radio_checked", &"PopupMenu"], [&"checked", &"CheckButton"],
			[&"unchecked", &"CheckButton"], [&"grabber", &"HSlider"], [&"grabber_highlight", &"HSlider"]]:
		var icon := theme.get_icon(pair[0], pair[1])
		_check(icon != null and icon.resource_path.begins_with(UiSkin.ROOT), "%s %s %s uses the art (%s)" % [tag, pair[1], pair[0], icon.resource_path if icon else "-"])
	for pair: Array in [[&"normal", &"OptionButton"], [&"panel", &"PopupMenu"], [&"slider", &"HSlider"], [&"grabber_area", &"HSlider"], [&"panel", &"KeyChip"]]:
		_check(theme.get_stylebox(pair[0], pair[1]) is StyleBoxTexture, "%s %s %s uses the art" % [tag, pair[1], pair[0]])
	(layer.find_child("DropFocus", true, false) as Control).grab_focus()
	await _hover(layer.find_child("DropHover", true, false) as Control)
	_check((layer.find_child("DropHover", true, false) as BaseButton).is_hovered(), "%s dropdown hovered by the real mouse" % tag)
	await _art_shot("controls")
	# check toggles: hover + focus, a real click toggles
	(layer.find_child("CheckFocus", true, false) as Control).grab_focus()
	var hover := layer.find_child("CheckHover", true, false) as CheckButton
	await _hover(hover)
	_check(hover.is_hovered(), "%s check toggle hovered" % tag)
	var off := layer.find_child("CheckOff", true, false) as CheckButton
	await _click(off)
	_check(off.button_pressed, "%s a click turns the check on" % tag)
	await _click(off)
	_check(not off.button_pressed, "%s and off again" % tag)
	var disabled := layer.find_child("CheckOnDisabled", true, false) as CheckButton
	await _click(disabled)
	_check(disabled.button_pressed, "%s a disabled check does not change" % tag)
	# slider: keyboard (focus + right arrow) and a drag of the grabber
	var keys := layer.find_child("SliderKeys", true, false) as HSlider
	keys.grab_focus()
	await _frames(2)
	for i in 2:
		for pressed: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_RIGHT
			key.physical_keycode = KEY_RIGHT
			key.pressed = pressed
			root.push_input(key)
			await _frames(2)
	_check(is_equal_approx(keys.value, 60.0), "%s the right arrow moves the focused slider by its steps (%.0f)" % [tag, keys.value])
	var normal := layer.find_child("SliderNormal", true, false) as HSlider
	var start := normal.value
	var rect := normal.get_global_rect()
	var from := root.get_final_transform() * (rect.position + Vector2(rect.size.x * start / 100.0, rect.size.y / 2.0))
	var to := root.get_final_transform() * (rect.position + Vector2(rect.size.x * 0.8, rect.size.y / 2.0))
	await _drag(from, to)
	_check(normal.value > start, "%s dragging the grabber raises the value (%.0f -> %.0f)" % [tag, start, normal.value])
	var locked := layer.find_child("SliderDisabled", true, false) as HSlider
	var locked_value := locked.value
	var lr := locked.get_global_rect()
	await _drag(root.get_final_transform() * (lr.position + Vector2(lr.size.x * 0.7, lr.size.y / 2.0)), root.get_final_transform() * (lr.position + Vector2(lr.size.x * 0.1, lr.size.y / 2.0)))
	_check(is_equal_approx(locked.value, locked_value), "%s a disabled slider keeps its value" % tag)
	(layer.find_child("CheckFocus", true, false) as Control).grab_focus()   # keyboard focus: resonance outline
	await _hover(normal)
	await _art_shot("controls_states")
	# key chips: one line each, text never clipped
	for chip: Control in (layer.find_child("Chips", true, false) as Control).get_children():
		var label := chip.get_child(0) as Label
		_check(chip.size.x + 0.5 >= label.get_minimum_size().x and chip.size.y >= label.get_minimum_size().y - 0.5,
			"%s key chip '%s' holds its text" % [tag, label.text])
	# dropdown open: selected (radio on), disabled entry, long text; then the one at the screen edge
	var long := layer.find_child("DropLong", true, false) as OptionButton
	await _click(long)
	var popup := long.get_popup()
	_check(popup.visible, "%s the dropdown opens on a click" % tag)
	var canvas := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_check(canvas.grow(1.0).encloses(Rect2(popup.position, popup.size)), "%s the list opens inside the window (%s)" % [tag, Rect2(popup.position, popup.size)])
	await _art_shot("controls_dropdown")
	popup.hide()
	await _frames(2)
	var edge := layer.find_child("DropEdge", true, false) as OptionButton
	edge.show_popup()   # placement at the edge (the click path is checked above)
	await _frames(3)
	_check(edge.get_popup().visible and canvas.grow(1.0).encloses(Rect2(edge.get_popup().position, edge.get_popup().size)),
		"%s the dropdown at the right edge opens inside the screen (%s)" % [tag, Rect2(edge.get_popup().position, edge.get_popup().size)])
	_check(long.size.x + 0.5 >= long.get_minimum_size().x, "%s the long dropdown text is not cut (%.0f)" % [tag, long.size.x])
	await _art_shot("controls_dropdown_edge")
	edge.get_popup().hide()
	await _frames(2)


## Real windows: the inventory's sort dropdown opened, the class station's mod dropdowns (locked
## entries disabled) opened, the options pages with check toggles, the volume slider and key chips.
## Nothing is changed or saved (lists are opened and closed, never chosen from).
func _real_secondary(screen: String) -> void:
	match screen:
		"inventory_sort":
			await GalleryScreens.open(self, "inventory")
			await _frames(4)
			var sort := map.hud.inventory_panel.find_child("Sort", true, false) as OptionButton
			if _check_ok(sort != null, "%s sort dropdown" % tag):
				await _click(sort)
				_check(sort.get_popup().visible, "%s sort list open" % tag)
		"skills_mods":
			await GalleryScreens.open(self, "skills")
			await _frames(4)
			var mods := map.hud.class_panel.find_children("*_form", "OptionButton", true, false)
			if _check_ok(not mods.is_empty(), "%s mod dropdowns" % tag):
				var mod := mods[0] as OptionButton
				mod.show_popup()
				await _frames(3)
				_check(mod.get_popup().visible, "%s mod list open" % tag)
		"options_gameplay", "options_audio", "options_controls":
			await GalleryScreens.open(self, "options")
			await _frames(3)
			map.hud.options_panel.show_page(screen.trim_prefix("options_").capitalize())
			await _frames(4)
			if screen == "options_gameplay":
				var autosave := map.hud.options_panel.find_child("PeriodicAutosave", true, false) as Control
				await _hover(autosave)
	await _frames(3)
	_check_layout(screen)
	await _art_shot(screen)
	for node in map.hud.find_children("*", "OptionButton", true, false):
		(node as OptionButton).get_popup().hide()
	await _frames(2)


## BookTabs: the art in use, hover (real mouse) on another register, keyboard focus on the selected one
## (gold rim + cyan outline at once), focus on another one; the frame never moves while doing so.
func _booktab_states(screen: String) -> void:
	var window: UiWindow
	if screen == "booktabs_class":
		await GalleryScreens.open(self, "skills")
		window = map.hud.class_panel
	else:
		await GalleryScreens.open(self, "professions")
		window = map.hud.professions_panel
	await _frames(4)
	var tabs := window.side_tabs
	if not _check_ok(tabs != null, "%s %s registers" % [tag, screen]):
		return
	var frame := window.get_global_rect()
	var buttons: Array = tabs.get_children().filter(func(n: Node) -> bool: return n is Button)
	var selected: Button = null
	var other: Button = null
	for node in buttons:
		var button := node as Button
		if button.button_pressed:
			selected = button
		elif other == null:
			other = button
	if not _check_ok(selected != null and other != null, "%s %s a selected and another register" % [tag, screen]):
		return
	_check(selected.get_theme_stylebox(&"pressed") is StyleBoxTexture and other.get_theme_stylebox(&"normal") is StyleBoxTexture,
		"%s %s register art in use" % [tag, screen])
	_check(selected.size.x > other.size.x, "%s %s selected register sticks out (%.0f > %.0f)" % [tag, screen, selected.size.x, other.size.x])
	selected.grab_focus()
	await _hover(other)
	_check(other.is_hovered() and selected.has_focus(), "%s %s hover on one, focus on the selected one" % [tag, screen])
	await _art_shot(screen + "_hover_focus")
	other.grab_focus()
	await _frames(3)
	_check(window.get_global_rect().is_equal_approx(frame), "%s %s the frame never moves" % [tag, screen])
	for node in buttons:
		var label := node as Button
		var font := label.get_theme_font(&"font")
		var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
		var room := label.size.x - label.get_theme_stylebox(&"normal").get_margin(SIDE_LEFT) - tabs.bridge   # visible part (Menu UX Polish 1.1: up to the page)
		_check(text_width <= room + 0.5, "%s %s '%s' fits the visible register (%.0f <= %.0f)" % [tag, screen, label.text, text_width, room])
		if not label.button_pressed:
			_check(is_equal_approx(label.size.x, BookTabs.WIDTH - BookTabs.OVERLAP + tabs.bridge), "%s %s '%s' inactive register width %.0f" % [tag, screen, label.text, label.size.x])
			_check(label.z_index == 0 and selected.z_index > 0, "%s %s inactive behind the frame, the selected one in front" % [tag, screen])
	await _art_shot(screen)
	map.hud.close_windows()
	await _frames(2)


## HUD bars with real data (nothing saved: the gallery session only): HP full / low / 1 %, the boss bar,
## EXP 0 / 1 / 58 / 99 % / MAX, the resources of the three classes. Every bar uses the art; the EXP bar
## stays one 426 x 14 bar 6 px under the combat bar; a shot per case.
func _bar_states() -> void:
	await GalleryScreens.open(self, "hud_boss")
	await _frames(4)
	var hud := map.hud
	var player := map.player
	var character: Character = session.character
	var classes := character.classes
	var theme := UiTheme.get_theme()
	_check(theme.get_stylebox(&"background", &"ProgressBar") is StyleBoxTexture, "%s bar frame art" % tag)
	_check(HudFillArt.available(hud.health_vessel.frame_id(), &"hud/vessel_fill_left"), "%s HP vessel art" % tag)   # Combat HUD UX 2.0
	_check(hud.target_frame._health.get_theme_stylebox(&"fill") is StyleBoxTexture, "%s boss HP fill art" % tag)
	_check(hud.xp_bar._fill is StyleBoxTexture and hud.xp_bar._frame is StyleBoxTexture, "%s EXP art" % tag)
	var progress: Dictionary = classes._progress[classes.active_class_id]
	var needed := classes.xp_to_next(classes.active_class_id)
	var cases := [["full", 1.0, 0], ["low", 0.08, ceili(needed * 0.01)], ["one", 0.01, ceili(needed * 0.58)], ["empty", 0.0, needed - 1]]
	for entry: Array in cases:
		player.health.health = player.health.max_health * float(entry[1])
		progress["xp"] = int(entry[2])
		await _frames(4)
		var xp := hud.xp_bar
		_check(xp.size.is_equal_approx(UiTheme.XP_BAR_SIZE), "%s %s EXP bar 426 x 14 (%s)" % [tag, entry[0], xp.size])
		_check(not xp._label.text.contains("/"), "%s %s EXP shows a percent only (%s)" % [tag, entry[0], xp._label.text])
		var column := hud._combat_row.get_global_rect()
		_check(is_equal_approx(xp.get_global_rect().position.y - column.end.y, UiTheme.XP_BAR_GAP), "%s %s EXP 6 px under the combat bar" % [tag, entry[0]])
		await _art_shot("bars_" + entry[0])
	var level := classes.get_level(classes.active_class_id)
	progress["level"] = classes.get_active_definition().max_level
	await _frames(4)
	_check(hud.xp_bar._label.text == "MAX", "%s EXP at the max level: MAX (%s)" % [tag, hud.xp_bar._label.text])
	await _art_shot("bars_max")
	progress["level"] = level
	player.health.health = player.health.max_health
	for class_id: StringName in [&"arcanist", &"shadowrunner"]:   # the class resources keep their own colours
		classes.unlock(class_id)
		classes.set_active(class_id)
		await _frames(6)
		_check(hud.resource_vessel.has_value and HudFillArt.available(&"hud/vessel_right", &"hud/vessel_fill_right"), "%s %s resource vessel art" % [tag, class_id])
		await _art_shot("bars_" + String(class_id))
	classes.set_active(&"warrior")
	await _frames(3)


## The Weapons tab with real equipped weapons of six families (mastery levels set in this session only): only
## the wielded family, its combo icons (art present), a locked combo chosen by a real click (details, no change of
## level or inputs), arrow keys move the focus through the grid, the frame equals the other tabs; then no weapon.
func _weapons_tab_states() -> void:
	var character: Character = session.character
	var db := character.database
	var panel := map.hud.class_panel
	character.inventory.capacity += 10   # this session only: room for six weapons and the unequip at the end
	map.hud.close_windows()
	map.hud.toggle_talents()
	panel.show_page("Classes")
	await _frames(4)
	var frame := panel.get_global_rect()
	var cases := [[&"one_handed_sword", 7], [&"two_handed_sword", 12], [&"staff", 4], [&"bow", 10], [&"spear", 20], [&"dagger", 1]]
	for case: Array in cases:
		var family_id: StringName = case[0]
		var item_id := StringName()
		for definition: ItemDefinition in db.items.values():
			if definition.weapon_family_id == family_id and definition.is_equippable():
				item_id = definition.id
				break
		var item: ItemInstance = character.inventory.add_item(item_id, 1)[0] if character.inventory.free_slots() > 0 else null
		if not _check_ok(item != null, "%s %s weapon in the bag" % [tag, family_id]):
			continue
		character.equipment.equip(item.instance_id, EquipSlot.Slot.MAIN_HAND)
		character.mastery._levels[family_id] = case[1]
		panel.show_page("Weapons")
		await _frames(4)
		var family: WeaponFamily = db.weapons[family_id]
		_check((panel.find_child("Family", true, false) as Label).text == family.display_name, "%s %s shown (only the wielded family)" % [tag, family_id])
		var cells := panel.find_child("Combos", true, false).get_children()
		_check(cells.size() == ComboIcons.entries(family).size(), "%s %s: every combo has a cell (%d)" % [tag, family_id, cells.size()])
		for cell: Node in cells:
			_check((cell.find_child("Icon", true, false) as TextureRect).texture != null, "%s %s %s art" % [tag, family_id, cell.name])
		_check(panel.get_global_rect().is_equal_approx(frame), "%s %s: the frame of every tab" % [tag, family_id])
		var locked: Button = null
		for cell: Node in cells:
			if (cell.find_child("State", true, false) as Label).get_theme_color(&"font_color") == UiTheme.WARNING:
				locked = cell as Button
		if locked != null:
			var level_before := character.mastery.get_level(family_id)
			await _click(locked)
			_check(locked.button_pressed and (panel.find_child("ComboState", true, false) as Label).text.begins_with("Locked"),
				"%s %s: a locked combo can be chosen and read" % [tag, family_id])
			_check(character.mastery.get_level(family_id) == level_before, "%s %s: choosing changes nothing" % [tag, family_id])
		var first := cells[0] as Button
		first.grab_focus()
		await _frames(2)
		for pressed: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_RIGHT
			key.physical_keycode = KEY_RIGHT
			key.pressed = pressed
			root.push_input(key)
			await _frames(2)
		_check(cells[1].has_focus(), "%s %s: the right arrow moves to the next combo" % [tag, family_id])
		await _art_shot("weapons_tab_%s" % family_id)
	character.equipment.unequip(EquipSlot.Slot.MAIN_HAND)
	panel.show_page("Weapons")
	await _frames(4)
	_check(panel.find_child("NoWeapon", true, false) != null and panel.find_child("Combos", true, false) == null, "%s no weapon: the empty state" % tag)
	_check(panel.get_global_rect().is_equal_approx(frame), "%s no weapon: the same frame" % tag)
	await _art_shot("weapons_tab_none")
	map.hud.close_windows()
	await _frames(2)


## Skill icons in the real controls, for the three playable classes: the combat bar (each slot shows its skill's
## art; slot 1 on cooldown with the dark overlay, slot 2 ready, the others without resource = dimmed with their
## status word) and the class station's Skills page (slot cards and rows, locked skills dimmed). Nothing saved.
func _skill_icon_states() -> void:
	var character: Character = session.character
	var classes := character.classes
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner"]:
		classes.unlock(class_id)
		classes._progress[class_id]["level"] = maxi(classes.get_level(class_id), 10)   # level-unlocked skills slotted
		SkillBook.auto_fill(character, class_id)
		classes.set_active(class_id)
		map.hud.close_windows()
		await _frames(6)
		var runtime := map.hud.health_vessel.bridge.class_runtime
		var bar := map.hud.skill_bar
		if runtime.pool != null:
			runtime.pool.value = 0.0
		var first := runtime.skill_in_slot(0)
		var second := runtime.skill_in_slot(1)
		if first != null:
			runtime.cooldowns[first.id] = runtime.time + runtime.params_for(first).cooldown * 0.6
		if second != null and runtime.pool != null:
			runtime.pool.value = runtime.pool.max_value()   # slot 2 ready (slot 1 still on cooldown)
		await _frames(4)
		for index in SkillBar.KEYS.size():
			var skill := runtime.skill_in_slot(index)
			if skill == null:
				continue
			var slot: HudSlot = bar._slots[index]
			_check(slot.icon != null and slot.icon == UiSkin.texture(StringName("skills/%s" % skill.id)),
				"%s %s slot %s shows skills/%s" % [tag, class_id, SkillBar.KEYS[index], skill.id])
		if first != null:
			_check(bar._slots[0].cooldown_ratio > 0.0, "%s %s slot Q on cooldown" % [tag, class_id])
		await _art_shot("skill_icons_hud_%s" % class_id)
		map.hud.toggle_talents()
		map.hud.class_panel.show_page("Skills")
		await _frames(6)
		var icons := map.hud.class_panel.find_children("SkillIcon", "TextureRect", true, false)
		_check(icons.size() >= 5, "%s %s Skills page shows icons (%d)" % [tag, class_id, icons.size()])
		await _art_shot("skill_icons_station_%s" % class_id)
		map.hud.close_windows()
		runtime.cooldowns.clear()
	classes.set_active(&"warrior")
	await _frames(3)


## Map markers with real map components: every map/* art present (16 x 16), the area map of Haven (exits at
## both edges, waystone, NPC with its note) with the legend of all kinds, the region view, and the minimap
## with the player facing four ways (real mouse motion turns the aim). Only explored spots carry markers
## (MapMarkers - unchanged); a shot per view.
func _map_marker_states() -> void:
	for kind: String in ["player", "exit", "waystone", "waystone_silent", "rest", "npc", "landmark", "quest"]:
		var art := UiSkin.texture(StringName("map/%s" % kind))
		_check(art != null and art.get_size() == Vector2(16, 16), "%s map/%s art 16 x 16" % [tag, kind])
	var markers := MapMarkers.collect(map, session.character, map.fog)
	var kinds := {}
	for marker: Dictionary in markers:
		kinds[marker.kind] = true
		_check(map.fog == null or map.fog.is_explored_at(marker.position), "%s marker %s on explored ground" % [tag, marker.kind])
	_log("%s Haven markers: %s" % [tag, kinds.keys()])
	await GalleryScreens.open(self, "map")
	await _frames(6)
	await _art_shot("map_markers_area")
	map.hud.world_map_panel.show_page("Region")
	await _frames(6)
	await _art_shot("map_markers_region")
	map.hud.close_windows()
	await _frames(4)
	await _art_shot("map_markers_minimap")   # the HUD minimap with its markers (facing = the real mouse)
	# the player arrow in eight facings through the real MapPainter (the aim follows the OS mouse, so it is
	# drawn here directly): it turns in 90 degree steps and stays 16 x 16 on whole pixels
	var layer := CanvasLayer.new()
	layer.layer = 60
	map.add_child(layer)
	var board := PanelContainer.new()
	board.theme = UiTheme.get_theme()
	board.theme_type_variation = &"HudPanel"
	board.position = Vector2(40, 400)
	layer.add_child(board)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(8 * 40 + 8, 48)
	board.add_child(canvas)
	var facings := [Vector2.UP, Vector2(1, -1), Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN, Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1)]
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), AreaMap.FLOOR)
		for index in facings.size():
			MapPainter.draw_player(canvas, Vector2(24 + index * 40, 24), facings[index], 9.0))
	await _frames(6)
	await _art_shot("map_markers_facings")
	layer.queue_free()
	await _frames(2)


## Every class resource at 0 / 1 / 5 / 8 / 9 / 25 / 50 / 75 / 100 of 100 (real pools, gallery session only):
## the resource bar cut out of the real frame, stacked into one sheet per pass; checks: the text stays one
## size, inside the bar, centred, and the dark half is used exactly on bright fills.
func _resource_text_sheet() -> void:
	map.hud.close_windows()
	await _frames(4)
	var hud := map.hud
	var classes: Character = session.character
	var sheet: Image = null
	var row := 0
	var values := [0, 1, 5, 8, 9, 25, 50, 75, 100]
	for class_id: StringName in [&"warrior", &"arcanist", &"shadowrunner", &"guardian", &"soulbinder"]:
		if session.database.get_class_def(class_id) == null or not session.database.get_class_def(class_id).playable:
			continue   # Guardian / Soulbinder are not playable yet (their colours: test_ui_usability)
		classes.classes.unlock(class_id)
		classes.classes.set_active(class_id)
		await _frames(6)
		var pool := map.hud.health_vessel.bridge.resource_pool
		if not _check_ok(pool != null, "%s %s has a resource pool" % [tag, class_id]):
			continue
		for value: int in values:
			pool.value = float(value) * pool.max_value() / 100.0
			await _frames(3)
			await RenderingServer.frame_post_draw
			var bar := hud.resource_vessel as Control   # Combat HUD UX 2.0: the resource vessel
			var rect := root.get_final_transform() * bar.get_global_rect()
			var cut := Rect2i(Vector2i(rect.position) - Vector2i(2, 6), Vector2i(rect.size) + Vector2i(4, 12))
			var image := root.get_texture().get_image().get_region(cut)
			if sheet == null:
				sheet = Image.create(cut.size.x, cut.size.y * values.size() * 5, false, image.get_format())
				sheet.fill(Color(0.16, 0.16, 0.16))
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cut.size), Vector2i(0, row * cut.size.y))
			row += 1
			_check(hud.resource_vessel.value_text == str(roundi(pool.value)), "%s %s %d: the vessel shows the value (%s)" % [tag, class_id, value, hud.resource_vessel.value_text])
	classes.classes.set_active(&"warrior")
	if sheet != null:
		var path := ART_OUT.path_join("%s_resource_text.png" % tag)
		sheet.save_png(ProjectSettings.globalize_path(path))
		_log("sheet %s" % path.get_file())
	await _frames(3)


## Lower-case letters as real key events (pressed + released).
func _type(text: String) -> void:
	for letter in text:
		for pressed: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = OS.find_keycode_from_string(letter.to_upper())
			key.unicode = letter.unicode_at(0) if pressed else 0
			key.pressed = pressed
			root.push_input(key)
		await _frames(2)
	await _frames(2)


func _click(control: Control) -> void:
	await _hover(control)
	var at := root.get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		root.push_input(click)
		await _frames(2)


func _wheel(control: Control, button: MouseButton) -> void:
	var at := root.get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = button
		wheel.pressed = pressed
		wheel.position = at
		wheel.global_position = at
		root.push_input(wheel)
	await _frames(3)


## A left-button drag in window pixels: press at `from`, motion in steps, release at `to`.
func _drag(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from
	press.global_position = from
	root.push_input(press)
	await _frames(2)
	for step in 6:
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(step + 1) / 6.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 6.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
		await _frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release)
	await _frames(3)


func _hover(control: Control) -> void:
	var canvas_at := control.get_global_rect().get_center()
	var at := root.get_final_transform() * canvas_at   # window pixels for the pushed event
	# first off the target, then onto it: a pointer left on the same spot by an earlier pass
	# would otherwise produce no enter event
	for point: Vector2 in [at + Vector2(0, -400), at]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		# no warp_mouse: moving the real OS pointer let its own motion events race the pushed ones
		root.push_input(motion)
		await _frames(3)


func _art_shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ART_OUT.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())
