class_name UserSettings
extends RefCounted
## Player preferences that belong to the installation, not to a character save:
## UI scale and window mode (docs/DISPLAY_AND_UI_STANDARD.md).
##
## UI scale is applied as Window.content_scale_factor on top of the canvas_items
## stretch (1920x1080 design). The stretch already maps the design to any window
## size (4K = 2x), so the factor is purely the player's preference - no double
## scaling. The game camera divides its zoom by the same factor (GameCamera), so
## the visible world never changes with the UI scale.

signal changed

enum WindowMode { WINDOWED, FULLSCREEN }

const DEFAULT_PATH := "user://settings.cfg"
const UI_SCALES: Array[float] = [0.8, 1.0, 1.25, 1.5, 2.0]
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_WINDOW_MODE := WindowMode.WINDOWED
## Default windowed size: this share of the usable screen, 16:9.
const WINDOW_SCREEN_SHARE := 0.8
const SECTION := "display"

## Where save() writes; empty = in-memory only (tests, scripted playtests).
var path: String = ""
var ui_scale: float = DEFAULT_UI_SCALE
var window_mode: WindowMode = DEFAULT_WINDOW_MODE


## Loads `file_path`; missing or invalid entries fall back to the defaults.
static func load_from(file_path: String) -> UserSettings:
	var settings := UserSettings.new()
	settings.path = file_path
	var config := ConfigFile.new()
	if config.load(file_path) != OK:
		return settings
	var scale: Variant = config.get_value(SECTION, "ui_scale", DEFAULT_UI_SCALE)
	if (scale is float or scale is int) and is_valid_ui_scale(float(scale)):
		settings.ui_scale = _snap(float(scale))
	var mode: Variant = config.get_value(SECTION, "window_mode", DEFAULT_WINDOW_MODE)
	if mode is int and mode in WindowMode.values():
		settings.window_mode = mode
	return settings


static func is_valid_ui_scale(value: float) -> bool:
	for allowed in UI_SCALES:
		if is_equal_approx(allowed, value):
			return true
	return false


static func _snap(value: float) -> float:
	for allowed in UI_SCALES:
		if is_equal_approx(allowed, value):
			return allowed
	return DEFAULT_UI_SCALE


func save() -> Error:
	if path == "":
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var config := ConfigFile.new()
	config.set_value(SECTION, "ui_scale", ui_scale)
	config.set_value(SECTION, "window_mode", window_mode)
	return config.save(path)


## Only the values in UI_SCALES are accepted. Returns false for anything else.
func set_ui_scale(value: float) -> bool:
	if not is_valid_ui_scale(value):
		return false
	if not is_equal_approx(ui_scale, value):
		ui_scale = _snap(value)
		changed.emit()
	return true


func set_window_mode(mode: WindowMode) -> void:
	if mode != window_mode:
		window_mode = mode
		changed.emit()


func toggle_fullscreen() -> void:
	set_window_mode(WindowMode.WINDOWED if window_mode == WindowMode.FULLSCREEN else WindowMode.FULLSCREEN)


func reset_to_defaults() -> void:
	if is_equal_approx(ui_scale, DEFAULT_UI_SCALE) and window_mode == DEFAULT_WINDOW_MODE:
		return
	ui_scale = DEFAULT_UI_SCALE
	window_mode = DEFAULT_WINDOW_MODE
	changed.emit()


func apply_to(window: Window) -> void:
	window.content_scale_factor = ui_scale
	var fullscreen := window_mode == WindowMode.FULLSCREEN
	if fullscreen and window.mode != Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
	elif not fullscreen and window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
		fit_window_to_screen(window)


## Windowed default: largest 16:9 size within WINDOW_SCREEN_SHARE of the usable
## screen area, centered (physical pixels, so 4K screens get a large window).
static func fit_window_to_screen(window: Window) -> void:
	if window.mode != Window.MODE_WINDOWED or DisplayServer.get_name() == "headless":
		return
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var width := mini(int(usable.size.x * WINDOW_SCREEN_SHARE), int(usable.size.y * WINDOW_SCREEN_SHARE * 16.0 / 9.0))
	var size := Vector2i(width, int(width * 9.0 / 16.0))
	window.size = size
	window.position = usable.position + (usable.size - size) / 2
