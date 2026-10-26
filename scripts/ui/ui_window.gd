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
## Give keyboard focus to the first enabled button when the window opens.
var auto_focus: bool = true

var _outer: VBoxContainer
var _title: Label
var _title_rule: HSeparator
var _scroll: ScrollContainer
var _close: Button
var _fit_queued: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = &"WindowPanel"
	_outer = VBoxContainer.new()
	add_child(_outer)
	_title = UiTheme.styled("", &"TitleLabel")
	_title.visible = false
	_outer.add_child(_title)
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
	_close = Button.new()
	_close.name = "Close"
	_close.text = "Close [Esc]"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(hide)
	_outer.add_child(_close)
	body.minimum_size_changed.connect(queue_fit)
	visibility_changed.connect(queue_fit)
	visibility_changed.connect(_on_opened)


func _enter_tree() -> void:
	if not get_viewport().size_changed.is_connected(queue_fit):
		get_viewport().size_changed.connect(queue_fit)
	queue_fit()


func set_title(text: String) -> void:
	_title.text = text
	_title.visible = text != ""
	_title_rule.visible = text != ""


func set_close_text(text: String) -> void:
	_close.text = text


func close_button() -> Button:
	return _close


func _on_opened() -> void:
	if not visible or not is_inside_tree():
		return
	UiTheme.fade_in(self)
	if auto_focus:
		_focus_first.call_deferred()


## Keyboard focus on the first enabled button of the body (else the close button).
func _focus_first() -> void:
	if not visible or not is_inside_tree():
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		return
	var first_tab: BaseButton = null
	for node in body.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button.is_visible_in_tree() or button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		if button.theme_type_variation == &"TabButton":
			if first_tab == null and button.button_pressed:
				first_tab = button   # the selected tab, if nothing else takes focus
			continue
		button.grab_focus()
		return
	if first_tab != null:
		first_tab.grab_focus()
	else:
		_close.grab_focus()


## Preferred size of the body content; subclasses with flow layouts override it.
func preferred_body_size() -> Vector2:
	return body.get_combined_minimum_size()


## Largest size the window may take (visible canvas minus margins).
func max_window_size() -> Vector2:
	return get_viewport_rect().size - Vector2.ONE * (2.0 * UiTheme.SCREEN_MARGIN)


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
	var min_body := (UiTheme.WINDOW_MIN_SIZE - chrome).max(Vector2.ZERO).min(available)
	_scroll.custom_minimum_size = scroll_size.max(min_body).floor()
	reset_size()
	size = size.min(limit)
	position = ((get_viewport_rect().size - size) * 0.5).floor()


func _fit() -> void:
	_fit_queued = false
	fit()


func _chrome_size() -> Vector2:
	var padding := get_theme_stylebox(&"panel").get_minimum_size()
	var gap := float(_outer.get_theme_constant(&"separation"))
	var rows := _close.get_combined_minimum_size().y + gap
	if _title.text != "":
		rows += _title.get_combined_minimum_size().y + gap
		rows += _title_rule.get_combined_minimum_size().y + gap
	return padding + Vector2(0, rows)


## Bronze corner brackets on top of the panel frame.
func _draw() -> void:
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
