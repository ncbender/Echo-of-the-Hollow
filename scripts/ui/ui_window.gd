class_name UiWindow
extends PanelContainer
## Base for all windows (inventory, class station, forge, journal, menus ...):
## framed panel with title, scrollable body and close button
## ("The Forgotten Chronicle": bronze frame with corner brackets).
##
## Sizing rule (docs/DISPLAY_AND_UI_STANDARD.md): the window takes its content's
## preferred size, but never more than the visible UI canvas minus SCREEN_MARGIN
## on every side; overflowing content scrolls. The window is re-fitted and
## re-centered whenever its content, the window size or the UI scale changes, so
## it can never be cut off at any resolution or UI scale.
## Opening fades in briefly (off with Reduce Motion) and gives keyboard focus to
## the first button, so every window can be used without the mouse.

## Content root for subclasses.
var body: VBoxContainer
## Fixed area under the scrolling body for the window's primary action (e.g.
## Craft): never scrolled away. Hidden until a subclass shows it.
var footer: VBoxContainer
## Give keyboard focus to the first enabled button when the window opens.
var auto_focus: bool = true
## Tabbed windows (UI Window Foundation 1.0): while open, the window keeps the largest size
## any of its pages needed - switching tabs never makes it jump; it shrinks again on reopen.
var keep_size_while_open: bool = false
## UI Usability & Haven Crafting 1.0: the outer size (design px) of a tabbed window - its geometry stays
## the same on every tab / page / category; more content scrolls inside, less leaves free room. A 0
## component keeps that axis content-sized (the width of fixed-column windows). Never more than the
## canvas allows (responsive), and the scrollbar width is always reserved, so it never moves the frame.
var stable_size := Vector2.ZERO
## Main Window Layout Lock 1.0: one of the seven main menus - outer size UiTheme.MAIN_WINDOW_SIZE (clamped
## like every other main window), the book-register room always reserved and the same centred rect for all
## of them (with or without registers). The body fills the window; inner areas scroll on their own.
var main_window: bool = false:
	set(value):
		main_window = value
		if body != null:
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL if value else Control.SIZE_FILL
		if _close != null:
			_close.visible = not value   # Playtest Corrections 1.0: main menus close by Esc, their key and their icon
		_update_title_rule()
		queue_fit()
var _held_size := Vector2.ZERO

var _outer: VBoxContainer
## Title row: the window title and, right of it, optional header controls (set_title_tabs).
var _title_row: HBoxContainer
var _title: Label
var _title_rule: HSeparator
var _scroll: ScrollContainer
var _close: Button
var _fit_queued: bool = false
## Optional page registers outside the left edge (BookTabs); see set_side_tabs.
var side_tabs: BookTabs
## Distance of the first register from the window top (below the title).
const SIDE_TABS_TOP := 72.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = &"WindowPanel"
	_outer = VBoxContainer.new()
	add_child(_outer)
	_title_row = HBoxContainer.new()
	_title_row.name = "TitleRow"
	_title_row.visible = false
	_title_row.add_theme_constant_override(&"separation", UiTheme.GAP * 4)
	_outer.add_child(_title_row)
	_title = UiTheme.styled("", &"TitleLabel")
	_title.visible = false
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_row.add_child(_title)
	_title_rule = HSeparator.new()
	_title_rule.visible = false
	_title_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outer.add_child(_title_rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	footer = VBoxContainer.new()
	footer.name = "Footer"
	footer.visible = false
	_outer.add_child(footer)
	_close = Button.new()
	_close.name = "Close"
	_close.text = "Close [Esc]"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(hide)
	_outer.add_child(_close)
	_scroll.item_rect_changed.connect(queue_redraw)   # the main-menu page follows the body (Menu UX Polish 1.0)
	footer.item_rect_changed.connect(queue_redraw)
	footer.visibility_changed.connect(queue_redraw)
	body.minimum_size_changed.connect(queue_fit)
	footer.minimum_size_changed.connect(queue_fit)
	footer.visibility_changed.connect(queue_fit)
	visibility_changed.connect(queue_fit)
	visibility_changed.connect(_on_opened)


func _enter_tree() -> void:
	if not get_viewport().size_changed.is_connected(queue_fit):
		get_viewport().size_changed.connect(queue_fit)
	queue_fit()


func set_title(text: String) -> void:
	_title.text = text
	_title.visible = text != ""
	_title_row.visible = text != ""
	_update_title_rule()


## Menu UX Polish 1.0: page tabs in the title row, right of the title ("Professions   Crafting | Gathering |
## Salvage") - a window's own horizontal pages instead of book registers or a tab row under the title.
func set_title_tabs(tabs: Control) -> void:
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title_row.add_child(tabs)


func set_close_text(text: String) -> void:
	_close.text = text


func close_button() -> Button:
	return _close


func _on_opened() -> void:
	if not visible:
		_held_size = Vector2.ZERO
	if not visible or not is_inside_tree():
		return
	UiTheme.fade_in(self)
	if auto_focus:
		_focus_first.call_deferred()


## Keyboard focus on the first enabled button of the body (else the close button). A selected
## choice in that group (a pressed toggle, e.g. the current UI scale) takes it instead, so the
## focus frame never marks a second, unselected option (UI Window Foundation 1.0).
func _focus_first() -> void:
	if not visible or not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		return
	var first_tab: BaseButton = null
	for node in body.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button.is_visible_in_tree() or button.disabled or button.focus_mode == Control.FOCUS_NONE or button is HelpButton:
			continue   # a help "?" opens on focus: never the window's automatic first focus (Menu UX Polish 1.1)
		if button.theme_type_variation != &"TabButton" and button.toggle_mode and button.button_group != null 				and not button.button_pressed and button.button_group.get_pressed_button() != null 				and button.button_group.get_pressed_button().is_visible_in_tree():
			button = button.button_group.get_pressed_button()
		if button.theme_type_variation == &"TabButton":
			if first_tab == null and button.button_pressed:
				first_tab = button   # the selected tab, if nothing else takes focus
			continue
		button.grab_focus()
		return
	if first_tab != null:
		first_tab.grab_focus()
	elif _close.is_visible_in_tree():
		_close.grab_focus()


## Preferred size of the body content; subclasses with flow layouts override it.
func preferred_body_size() -> Vector2:
	return body.get_combined_minimum_size()


## Largest size the window may take (visible canvas minus margins).
func max_window_size() -> Vector2:
	var limit := get_viewport_rect().size - Vector2.ONE * (2.0 * UiTheme.SCREEN_MARGIN)
	limit.x -= _register_room()   # the registers stay on screen too
	if main_window:
		limit = limit.min(UiTheme.MAIN_WINDOW_SIZE)
	return limit


## Room left of the window for the book registers: always reserved by a main window, so all seven share
## one rect whether they have registers or not.
func _register_room() -> float:
	if main_window:
		return BookTabs.WIDTH + BookTabs.ACTIVE_EXTRA - BookTabs.OVERLAP
	return side_tabs.reserved_width() if side_tabs != null else 0.0


## The body's room in this window (design px): for a main window its fixed inner size, else the most the
## canvas allows. Layouts that fill the window (talent trees, maps) size themselves from it.
func body_room() -> Vector2:
	return (max_window_size() - _chrome_size()).max(Vector2.ZERO)


func queue_fit() -> void:
	if _fit_queued or not is_inside_tree():
		return
	_fit_queued = true
	_fit.call_deferred()


## Applies the sizing rule now (also used by tests).
func fit() -> void:
	if not visible or not is_inside_tree():
		return
	var limit := max_window_size()
	var chrome := _chrome_size()
	var available := (limit - chrome).max(Vector2.ZERO)
	var want := preferred_body_size()
	var scroll_size := want.min(available)
	if want.y > available.y:   # vertical scrollbar takes width
		var bar := _scroll.get_v_scroll_bar().get_combined_minimum_size().x
		scroll_size.x = minf(want.x + bar, available.x)
	if keep_size_while_open:
		scroll_size = scroll_size.max(_held_size).min(available)
		_held_size = scroll_size
	if main_window:
		scroll_size = available   # the one main frame (max_window_size is the clamped MAIN_WINDOW_SIZE)
	elif stable_size != Vector2.ZERO:
		var bar := _scroll.get_v_scroll_bar().get_combined_minimum_size().x
		var target := (stable_size - chrome).max(Vector2.ZERO)
		if stable_size.x <= 0.0:
			target.x = want.x + bar
		if stable_size.y <= 0.0:
			target.y = want.y
		scroll_size = target.min(available)
	var min_body := (UiTheme.WINDOW_MIN_SIZE - chrome).max(Vector2.ZERO).min(available)
	_scroll.custom_minimum_size = scroll_size.max(min_body).floor()
	reset_size()
	size = size.min(limit)
	var reserved := _register_room()
	position = Vector2((get_viewport_rect().size.x - size.x + reserved) * 0.5, (get_viewport_rect().size.y - size.y) * 0.5).floor()
	_place_side_tabs()


## Back to the top of the scrolling body (a new tab / page / category starts at its beginning).
func reset_scroll() -> void:
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0


func _fit() -> void:
	_fit_queued = false
	fit()


func _chrome_size() -> Vector2:
	var padding := get_theme_stylebox(&"panel").get_minimum_size()
	var gap := float(_outer.get_theme_constant(&"separation"))
	# Playtest Corrections 1.0: a hidden close button takes no row in a main menu (its room goes to the content);
	# other windows keep their layout as it was
	var rows := 0.0 if main_window and not _close.visible else _close.get_combined_minimum_size().y + gap
	if footer.visible:
		rows += footer.get_combined_minimum_size().y + gap
	if _title.text != "":
		rows += _title_row.get_combined_minimum_size().y + gap
		if _title_rule.visible:
			rows += _title_rule.get_combined_minimum_size().y + gap
	return padding + Vector2(0, rows)


## Bronze corner brackets on top of the panel frame (part of the placeholder frame: a
## window/panel asset brings its own corners).
func _draw() -> void:
	if UiSkin.has(&"window/panel"):
		UiTheme.draw_hard_shadow(self)   # the art brings its corners, not its shadow
		if main_window:
			_draw_main_ground()
		return
	var length := 14.0
	var inset := 4.0
	var color := UiTheme.BRONZE
	var rect := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x <= rect.position.x + 0.1 else -1.0
		var sy := 1.0 if corner.y <= rect.position.y + 0.1 else -1.0
		draw_line(corner, corner + Vector2(length * sx, 0), color, 2.0)
		draw_line(corner, corner + Vector2(0, length * sy), color, 2.0)
		draw_rect(Rect2(corner + Vector2(3 * sx - 1.5, 3 * sy - 1.5), Vector2(3, 3)), Color(UiTheme.BRONZE, 0.7))


## Puts `tabs` outside the left edge of the window (book registers). They are a
## top-level child: not laid out by the panel, but shown/hidden with it.
func set_side_tabs(tabs: BookTabs) -> void:
	side_tabs = tabs
	tabs.top_level = true
	add_child(tabs)
	queue_fit()


func _place_side_tabs() -> void:
	if side_tabs == null:
		return
	var bridge := tab_bridge()
	if not is_equal_approx(side_tabs.bridge, bridge):
		side_tabs.bridge = bridge
	side_tabs.reset_size()
	side_tabs.global_position = global_position + Vector2(-side_tabs.size.x + bridge, SIDE_TABS_TOP)


## Menu UX Polish 1.1: how far the registers reach into the window - up to the page (the selected one joins it),
## without the page art the usual overlap under the frame.
func tab_bridge() -> float:
	if not draws_page():
		return BookTabs.OVERLAP
	return maxf(BookTabs.OVERLAP, get_theme_stylebox(&"panel").get_margin(SIDE_LEFT) - PAGE_MARGIN)


# --- Menu UX Polish 1.0: ground and page of the seven main menus ----------------------------------------
## Inner edge of the window/panel frame (its slate mat ends here, in texture = design px).
const FRAME_INSET := 9.0
## The page reaches this far around the body (and the footer): its engraved line sits in the panel padding.
const PAGE_MARGIN := 6.0
static var _page_style: StyleBox


## True when this window draws the page (a main menu with the window/page art); the page's engraved top
## line then replaces the title rule.
func draws_page() -> bool:
	return main_window and UiSkin.has(&"window/panel") and UiSkin.has(&"window/page")


func _update_title_rule() -> void:
	if _title_rule != null:
		_title_rule.visible = _title.text != "" and not draws_page()


## The page rect in local px: the body's scroll area and a shown footer, PAGE_MARGIN around them.
func page_rect() -> Rect2:
	var rect := Rect2(_scroll.global_position - global_position, _scroll.size)
	if footer.visible:
		rect = rect.merge(Rect2(footer.global_position - global_position, footer.size))
	return rect.grow(PAGE_MARGIN)


## The grain (window/backdrop, tiled 1:1 inside the frame) under the calm engraved page (window/page) that
## carries the content - text never sits on the grain. Optional art: without a file nothing is drawn.
func _draw_main_ground() -> void:
	var ground := UiSkin.texture(&"window/backdrop")
	if ground != null:
		draw_texture_rect(ground, Rect2(Vector2.ONE * FRAME_INSET, size - Vector2.ONE * FRAME_INSET * 2.0), true)
	if draws_page():
		if _page_style == null:
			_page_style = UiSkin.stylebox(&"window/page", StyleBoxEmpty.new())
		draw_style_box(_page_style, page_rect())
