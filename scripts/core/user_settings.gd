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
## UI Scaling Standard 1.1: the selectable scales. 150 % is the maximum; older
## settings files with a larger (e.g. 200 %) or an old 80 % value are mapped to the
## nearest allowed one on load (the UI itself still copes with any factor).
const UI_SCALES: Array[float] = [0.75, 1.0, 1.25, 1.5]
const MAX_UI_SCALE := 1.5
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_WINDOW_MODE := WindowMode.WINDOWED
## Default windowed size: this share of the usable screen, 16:9.
const WINDOW_SCREEN_SHARE := 0.8
const SECTION := "display"
const AUDIO_SECTION := "audio"
const DEFAULT_SFX_VOLUME := 0.8
const GAMEPLAY_SECTION := "gameplay"

## Where save() writes; empty = in-memory only (tests, scripted playtests).
var path: String = ""
var ui_scale: float = DEFAULT_UI_SCALE
var window_mode: WindowMode = DEFAULT_WINDOW_MODE
## Combat/effects volume 0..1 (CombatAudio, "SFX" bus).
var sfx_volume: float = DEFAULT_SFX_VOLUME
## Autosave every 5 minutes of active play (milestones are always saved).
var periodic_autosave: bool = true
## HUD hint "Saving... / Progress saved / Save failed".
var show_save_indicator: bool = true
## Accessibility: no UI fades/slides (UiTheme.motion_enabled).
var reduce_motion: bool = false


## Loads `file_path`; missing or invalid entries fall back to the defaults.
static func load_from(file_path: String) -> UserSettings:
	var settings := UserSettings.new()
	settings.path = file_path
	var config := ConfigFile.new()
	if config.load(file_path) != OK:
		return settings
	var scale: Variant = config.get_value(SECTION, "ui_scale", DEFAULT_UI_SCALE)
	if scale is float or scale is int:
		settings.ui_scale = nearest_ui_scale(float(scale))   # 200 % -> 150 %, 80 % -> 75 %
	var mode: Variant = config.get_value(SECTION, "window_mode", DEFAULT_WINDOW_MODE)
	if mode is int and mode in WindowMode.values():
		settings.window_mode = mode
	var volume: Variant = config.get_value(AUDIO_SECTION, "sfx_volume", DEFAULT_SFX_VOLUME)
	if volume is float or volume is int:
		settings.sfx_volume = clampf(float(volume), 0.0, 1.0)
	settings.periodic_autosave = bool(config.get_value(GAMEPLAY_SECTION, "periodic_autosave", true))
	settings.show_save_indicator = bool(config.get_value(GAMEPLAY_SECTION, "show_save_indicator", true))
	settings.reduce_motion = bool(config.get_value(SECTION, "reduce_motion", false))
	return settings


## The allowed scale closest to `value`, never above MAX_UI_SCALE (saved values
## from older versions). Non-positive values give the default.
static func nearest_ui_scale(value: float) -> float:
	if value <= 0.0 or is_nan(value):
		return DEFAULT_UI_SCALE
	var best := DEFAULT_UI_SCALE
	for allowed in UI_SCALES:
		if absf(allowed - minf(value, MAX_UI_SCALE)) < absf(best - minf(value, MAX_UI_SCALE)):
			best = allowed
	return best


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
	config.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	config.set_value(GAMEPLAY_SECTION, "periodic_autosave", periodic_autosave)
	config.set_value(GAMEPLAY_SECTION, "show_save_indicator", show_save_indicator)
	config.set_value(SECTION, "reduce_motion", reduce_motion)
	return config.save(path)


## Only the values in UI_SCALES are accepted. Returns false for anything else.
func set_ui_scale(value: float) -> bool:
	if not is_valid_ui_scale(value):
		return false
	if not is_equal_approx(ui_scale, value):
		ui_scale = _snap(value)
		changed.emit()
	return true


func set_sfx_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if not is_equal_approx(value, sfx_volume):
		sfx_volume = value
		changed.emit()


func set_periodic_autosave(enabled: bool) -> void:
	if enabled != periodic_autosave:
		periodic_autosave = enabled
		changed.emit()


func set_show_save_indicator(enabled: bool) -> void:
	if enabled != show_save_indicator:
		show_save_indicator = enabled
		changed.emit()


func set_reduce_motion(enabled: bool) -> void:
	if enabled != reduce_motion:
		reduce_motion = enabled
		changed.emit()


func set_window_mode(mode: WindowMode) -> void:
	if mode != window_mode:
		window_mode = mode
		changed.emit()


func toggle_fullscreen() -> void:
	set_window_mode(WindowMode.WINDOWED if window_mode == WindowMode.FULLSCREEN else WindowMode.FULLSCREEN)


func reset_to_defaults() -> void:
	if is_equal_approx(ui_scale, DEFAULT_UI_SCALE) and window_mode == DEFAULT_WINDOW_MODE \
			and is_equal_approx(sfx_volume, DEFAULT_SFX_VOLUME):
		return
	ui_scale = DEFAULT_UI_SCALE
	window_mode = DEFAULT_WINDOW_MODE
	sfx_volume = DEFAULT_SFX_VOLUME
	changed.emit()


func apply_to(window: Window) -> void:
	window.content_scale_factor = ui_scale
	CombatAudio.set_volume(sfx_volume)
	UiTheme.motion_enabled = not reduce_motion
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
