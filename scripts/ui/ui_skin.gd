class_name UiSkin
extends RefCounted
## Optional UI art (UI Window Foundation 1.0, docs/UI_ASSET_CATALOG_1_0.md): every UI asset
## has a stable id = its path below ROOT without ".png" ("window/panel", "menu/inventory",
## "map/waystone"). If the file exists it is used; if not, the component keeps its
## procedural placeholder (StyleBoxFlat, drawn glyph). No asset is ever required - a missing
## file is the normal case until the pixel art is produced, so it never warns.
##
## Frames and panels are nine-patches: PATCH holds the border width (texture px) that
## stays unscaled - one number for all sides, or a Vector4i (left, top, right, bottom) where the
## sides differ (bar/fill: no side borders, so it can be drawn at any width); content padding is
## taken over from the procedural style, so swapping in art never moves any layout. Icons are
## drawn into the component's existing rect.

const ROOT := "res://assets/ui/"
## Nine-patch borders (texture px) of the frame assets; ids not listed are plain images.
const PATCH := {
	&"window/panel": 12, &"window/header_rule": 0, &"panel/hud": 6, &"panel/card": 6, &"panel/card_selected": 6,
	&"panel/inset": 4, &"tooltip/panel": 6,
	&"button/normal": 4, &"button/hover": 4, &"button/pressed": 4, &"button/disabled": 4,
	&"button/primary_normal": 4, &"button/primary_hover": 4, &"button/primary_pressed": 4, &"button/primary_disabled": 4,
	&"tab/normal": 4, &"tab/hover": 4, &"tab/selected": 4,
	&"slot/normal": 4, &"slot/hover": 4, &"slot/selected": 4, &"slot/disabled": 4,
	&"hud/slot_frame": 4, &"hud/slot_frame_disabled": 4, &"hud/minimap_frame": 6,
	&"scroll/grabber": 3, &"scroll/track": 3,
	&"input/normal": 4, &"input/focus": 4, &"input/disabled": 4,
	&"slider/fill": 3, &"chip/key": 3,
	&"booktab/normal": 4, &"booktab/hover": 4, &"booktab/selected": 4,   # BookTabs Visual Integration 1.0   # Secondary Controls 1.0 (icons: dropdown/*, check/*, slider/grabber*)
	&"bar/frame": 1, &"bar/fill": Vector4i(0, 1, 0, 1),   # HUD Bars Visual Integration 1.0 (EXP bar too)
	&"window/page": 6,   # Menu UX Polish 1.0 (window/backdrop is a plain tile)
}

static var _cache := {}


## The texture of `id`, or null when no file exists yet (cached either way).
static func texture(id: StringName) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path := ROOT + String(id) + ".png"
	var found: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_cache[id] = found
	return found


static func has(id: StringName) -> bool:
	return texture(id) != null


## `fallback` unless the asset `id` exists: then a nine-patch StyleBoxTexture with the
## fallback's content margins (same layout, new look).
static func stylebox(id: StringName, fallback: StyleBox) -> StyleBox:
	var art := texture(id)
	if art == null:
		return fallback
	var box := StyleBoxTexture.new()
	box.texture = art
	var patch: Variant = PATCH.get(id, 0)
	if patch is Vector4i:
		box.texture_margin_left = patch.x
		box.texture_margin_top = patch.y
		box.texture_margin_right = patch.z
		box.texture_margin_bottom = patch.w
	else:
		box.set_texture_margin_all(float(patch))
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, fallback.get_content_margin(side))
	return box


## Drops the cache (tests that add or remove files; the theme is built once per run).
static func clear_cache() -> void:
	_cache.clear()
