class_name UiWindow
extends PanelContainer
## Base for all RPG windows (inventory, class station, building, options and later
## crafting/vendor menus): title, scrollable body, close button.
##
## Sizing rule (docs/DISPLAY_AND_UI_STANDARD.md): the window takes its content's
## preferred size, but never more than the visible UI canvas minus SCREEN_MARGIN
## on every side; overflowing content scrolls. The window is re-fitted and
## re-centered whenever its content, the window size or the UI scale changes, so
## it can never be cut off at any resolution or UI scale.

## Content root for subclasses.
var body: VBoxContainer

var _outer: VBoxContainer
var _title: Label
var _scroll: ScrollContainer
var _close: Button
var _fit_queued: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme_type_variation = &"WindowPanel"
	_outer = VBoxContainer.new()
	add_child(_outer)
	_title = UiTheme.heading()
	_title.visible = false
	_outer.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_close = Button.new()
	_close.text = "Close [Esc]"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.pressed.connect(hide)
	_outer.add_child(_close)
	body.minimum_size_changed.connect(queue_fit)
	visibility_changed.connect(queue_fit)


func _enter_tree() -> void:
	if not get_viewport().size_changed.is_connected(queue_fit):
		get_viewport().size_changed.connect(queue_fit)
	queue_fit()


func set_title(text: String) -> void:
	_title.text = text
	_title.visible = text != ""


func set_close_text(text: String) -> void:
	_close.text = text


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
	return padding + Vector2(0, rows)
