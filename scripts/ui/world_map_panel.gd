class_name WorldMapPanel
extends UiWindow
## The map window (M): two views (Map & Fog of War 1.0; Map UX 2.0, docs/MAP_UX_2_0.md).
##   Area (default)  the current map at a readable whole-pixel scale: explored geometry under the fog, the
##                   player, explored exits, waystones, resting places, NPCs, landmarks and known quest goals
##                   (MapMarkers) - the same picture and fog as the minimap. It opens centred on the player.
##   Region          a schematic network of the places you know in the Hollow Outskirts (MapDefinition.map_cell
##                   and .neighbors): compact place nodes, "you are here", the waystone state at each place you
##                   may know of; an unknown neighbour is a nameless "?", never its name. A click selects a place
##                   (details below: state, waystone, the journey); travelling is only the explicit button and
##                   only from an awake waystone you stand at (WaystoneService rules, unchanged).
## Both views: drag with the left mouse button (a small threshold tells a click from a drag), arrow keys, a
## compact "centre" button; the picture never leaves big empty margins. Nothing here changes the world. Like every
## window it blocks the player's input; the world keeps running (no pause).

const PAGES := ["Area", "Region"]
## Region network: one cell per MapDefinition.map_cell, a compact node in it.
const CELL := Vector2(206, 104)
const NODE := Vector2(168, 52)
const MARGIN := Vector2(28, 28)
## Area scale (view px per world px): the whole map when it fits at up to 1.0, never below this (readable) - in
## steps of 1/8, so one map pixel (AreaMap.PIXEL = 8 world px) is always a whole number of screen pixels.
const AREA_MIN_SCALE := 0.5
const AREA_MAX_SCALE := 1.0

var character: Character
var page: String = "Area"

var _tabs: UiTabs
var _area_page: VBoxContainer
var _area: AreaMapView
var _area_title: Label
var _region_page: VBoxContainer
var _graph: MapGraph
var _detail: PanelContainer


func _ready() -> void:
	main_window = true   # Main Window Layout Lock 1.0: the map takes the room the shared frame leaves
	set_title("Hollow Outskirts")
	set_close_text("Close [M / Esc]")
	_tabs = UiTabs.new()
	for id: String in PAGES:
		_tabs.add_tab(id, id)
	_tabs.tab_selected.connect(show_page)
	body.add_child(_tabs)
	# Area: one slim toolbar (map name, the marker symbols with tooltips, help, centre) and the map
	_area_page = VBoxContainer.new()
	_area_page.name = "AreaPage"
	_area_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area_page.add_theme_constant_override(&"separation", UiTheme.GAP)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", UiTheme.GAP)
	_area_title = UiTheme.styled("", &"SubheadingLabel")
	_area_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_area_title)
	bar.add_child(_area_legend())
	bar.add_child(HelpButton.make("\n".join([
		"# Map",
		"Drag with the left mouse button or use the arrow keys to look around.",
		"The centre button brings you back to yourself.",
		"# Symbols",
		"Arrow: you, pointing where you face.",
		"Diamond: an exit. Tall stone: an awake waystone; grey: a silent one.",
		"Flame: a resting place. Figure: a person.",
		"Small square: a landmark. Ring: your current goal.",
		"Dim ground: explored. Dark: not yet explored."]), "AreaHelp"))
	var centre := _centre_button("CenterOnPlayer", "Center on player")
	centre.pressed.connect(func() -> void: _area.center_on_player())
	bar.add_child(centre)
	_area_page.add_child(bar)
	_area = AreaMapView.new()
	_area.name = "AreaMap"
	_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.custom_minimum_size = Vector2(240, 160)
	_area_page.add_child(_area)
	body.add_child(_area_page)
	# Region: toolbar, the network, the details of the chosen place
	_region_page = VBoxContainer.new()
	_region_page.name = "RegionPage"
	_region_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_region_page.add_theme_constant_override(&"separation", UiTheme.GAP)
	var region_bar := HBoxContainer.new()
	region_bar.add_theme_constant_override(&"separation", UiTheme.GAP)
	var caption := UiTheme.styled("Places you have found  ·  schematic, not to scale", &"SmallLabel")
	caption.add_theme_color_override(&"font_color", UiTheme.TEXT_SECONDARY)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	region_bar.add_child(caption)
	region_bar.add_child(HelpButton.make("\n".join([
		"# Region",
		"Each box is a place you have visited; lines are the paths between them.",
		"Arrow in a box: you are here. Gold frame: the place you chose.",
		"Tall stone: an awake waystone; grey: a silent one.",
		"?: a path you have not walked yet.",
		"Click a place (or use the arrow keys) to see it below. You travel only from an awake waystone you stand at."]), "RegionHelp"))
	var region_centre := _centre_button("CenterOnPlace", "Center on your place")
	region_centre.pressed.connect(func() -> void: _graph.center_on_here())
	region_bar.add_child(region_centre)
	_region_page.add_child(region_bar)
	_graph = MapGraph.new()
	_graph.name = "RegionMap"
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.custom_minimum_size = Vector2(240, 160)
	_graph.selected.connect(func(_id: StringName) -> void: _show_place())
	_region_page.add_child(_graph)
	_detail = UiTheme.card(&"InsetPanel")
	_detail.name = "PlaceDetail"
	_region_page.add_child(_detail)
	body.add_child(_region_page)


func open(target_character: Character, start_page: String = "Area") -> void:
	character = target_character
	_graph.bind(character)
	var map := get_tree().current_scene as GameMap if is_inside_tree() else null
	_area.bind(map, character)
	var map_def: MapDefinition = character.database.maps.get(map.map_id) if map != null else null
	_area_title.text = map_def.display_name if map_def != null else ""
	page = ""
	show()
	_area.follow_layout()   # every opening starts at the player (once the layout is valid)
	_graph.follow_layout()
	show_page(start_page if start_page in PAGES else "Area")


func show_page(id: String) -> void:
	if id != page:
		reset_scroll()
	page = id
	_tabs.select(id)
	_area_page.visible = id == "Area"
	_region_page.visible = id == "Region"
	if id == "Region":
		_graph.follow_layout()   # the current place in view
		_show_place()
	queue_fit()


## A compact icon button (the player arrow art, else "o") with its tooltip; keyboard reachable.
func _centre_button(button_name: String, tip: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(30, 30)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art := UiSkin.texture(&"map/player")
	if art != null:
		button.icon = art
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = "o"
	return button


## The marker symbols in one slim row - each as drawn on the map, its word in the tooltip (the help "?" has them
## all for keyboard users). Shapes differ, never only colours.
func _area_legend() -> Control:
	var row := HBoxContainer.new()
	row.name = "AreaLegend"
	row.add_theme_constant_override(&"separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for entry: Array in [["player", "You"], [MapMarkers.EXIT, "Exit"], [MapMarkers.WAYSTONE, "Awake waystone"],
			["silent", "Silent waystone"], [MapMarkers.REST, "Resting place"], [MapMarkers.NPC, "Person"],
			[MapMarkers.LANDMARK, "Landmark"], [MapMarkers.QUEST, "Current goal"], ["explored", "Explored"], ["dark", "Not yet explored"]]:
		var swatch := LegendSwatch.new()
		swatch.kind = StringName(entry[0])
		swatch.tooltip_text = entry[1]
		row.add_child(swatch)
	return row


## Details of the chosen place: its name, whether you are there, its waystone (only as far as you may know it) and
## the journey - the Travel button only when you stand at an awake waystone, else the concrete reason.
func _show_place() -> void:
	var box := _detail.get_node("Box") as VBoxContainer
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if character == null:
		return
	var place_id := _graph.selected_id
	var map_def: MapDefinition = character.database.maps.get(place_id)
	if map_def == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 2)
	box.add_child(row)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var title := UiTheme.styled(map_def.display_name, &"MenuTitleLabel")
	title.name = "PlaceName"
	texts.add_child(title)
	var here := place_id == character.world.here()
	var waystone := place_waystone(character, place_id)
	var awake := waystone != null and waystone.available and WaystoneService.is_active(character, waystone.id)
	var facts: PackedStringArray = ["You are here" if here else "Visited"]
	if waystone != null:
		facts.append("%s: %s" % [waystone.display_name, "awake" if awake else "silent"])
	var state := UiTheme.styled("  ·  ".join(facts), &"MenuMetaLabel")
	state.name = "PlaceState"
	state.add_theme_color_override(&"font_color", UiTheme.RESONANCE if here else UiTheme.TEXT_SECONDARY)
	texts.add_child(state)
	if not awake or here:
		return   # no journey to a place without an awake waystone, nor to where you are
	var from := standing_waystone()
	var reason := "Travel starts at an awake waystone." if from == null else \
		WaystoneService.travel_error(character, from.waystone_id, waystone.id, from.enemies_near())
	if reason != "":
		var why := UiTheme.styled(reason, &"MenuMetaLabel")
		why.name = "TravelReason"
		why.add_theme_color_override(&"font_color", UiTheme.WARNING)
		why.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(why)
	var button := UiTheme.button("Travel", &"PrimaryButton", travel_to_selected)
	button.name = "Travel"
	button.disabled = reason != ""
	button.tooltip_text = reason if reason != "" else "Free travel to %s." % waystone.display_name
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 140
	row.add_child(button)


## The Travel button (UI and tests): the same journey as the waystone window. "" when it started.
func travel_to_selected() -> String:
	var waystone := place_waystone(character, _graph.selected_id)
	if waystone == null:
		return "No waystone there."
	var error := WaystonePanel.start_travel(get_tree(), character, standing_waystone(), waystone.id)
	if error != "":
		_show_place()
		return error
	hide()
	return ""


## The awake waystone the player stands at on this map (null when none) - the only place a journey starts.
func standing_waystone() -> Waystone:
	var map := get_tree().current_scene if is_inside_tree() else null
	if map == null:
		return null
	for node in map.find_children("*", "Waystone", true, false):
		var stone := node as Waystone
		if stone.player_inside and WaystoneService.is_active(character, stone.waystone_id):
			return stone
	return null


## Enemies may come near or leave while the window is open: the reason is checked twice a second and the
## details are rebuilt only when it changed (the keyboard focus stays where it is otherwise).
func _process(_delta: float) -> void:
	if not visible or page != "Region" or Engine.get_process_frames() % 30 != 0:
		return
	var travel := _detail.find_child("Travel", true, false) as Button
	if travel == null:
		return
	var waystone := place_waystone(character, _graph.selected_id)
	var from := standing_waystone()
	var reason := "Travel starts at an awake waystone." if from == null else 		WaystoneService.travel_error(character, from.waystone_id, waystone.id, from.enemies_near())
	if (reason != "") != travel.disabled or (reason != "" and travel.tooltip_text != reason):
		_show_place()


## Map ids drawn on the region map: visited (or current) and not developer-only.
static func known_maps(target: Character) -> Array[StringName]:
	var result: Array[StringName] = []
	for map_def: MapDefinition in target.database.maps.values():
		if not map_def.show_on_map:
			continue
		if map_def.id == target.world.here() or int(target.world.get_map_value(map_def.id, "visits", 0)) > 0:
			result.append(map_def.id)
	return result


## Waystones the player may know of: awake ones, and those standing on a place already
## visited. An undiscovered waystone is not listed at all - no name, no hint (no spoiler).
static func known_waystones(target: Character) -> Array[WaystoneDefinition]:
	var known := known_maps(target)
	var result: Array[WaystoneDefinition] = []
	for waystone in WaystoneService.all(target.database):
		var awake := waystone.available and WaystoneService.is_active(target, waystone.id)
		if awake or (waystone.map_id != &"" and waystone.map_id in known):
			result.append(waystone)
	return result


## The known waystone at `map_id` (known_waystones), null when none may be shown there.
static func place_waystone(target: Character, map_id: StringName) -> WaystoneDefinition:
	for waystone in known_waystones(target):
		if waystone.map_id == map_id:
			return waystone
	return null


## Map UX 2.0: a clipped picture that is moved by dragging with the left mouse button (immediately, no inertia)
## or by the arrow keys, kept inside its content (a smaller content sits in the middle). A press that moves less
## than DRAG_THRESHOLD is a click (`_click`), a drag never clicks. `follow_layout` keeps the start view (player /
## current place centred) through every layout change until the player moves the picture.
class PanCanvas:
	extends Control

	const DRAG_THRESHOLD := 5.0
	const KEY_STEP := 64.0

	var pan := Vector2.ZERO
	var dragging: bool = false
	var _pressed: bool = false
	var _press_at := Vector2.ZERO
	var _press_offset := Vector2.ZERO
	var _following: bool = false

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(_on_resized)

	## Size of the whole picture in view px (subclasses).
	func content_size() -> Vector2:
		return Vector2.ZERO

	## The start point to centre on (content px; subclasses) - used while following the layout.
	func start_point() -> Vector2:
		return content_size() * 0.5

	func _click(_at: Vector2) -> void:
		pass

	## Keys other than panning (subclasses); true when handled.
	func _key(_event: InputEvent) -> bool:
		return false

	func follow_layout() -> void:
		_following = true
		_apply_follow.call_deferred()

	func _apply_follow() -> void:
		if _following and size.x > 1.0 and size.y > 1.0:
			center_on(start_point())

	func _on_resized() -> void:
		if _following:
			center_on(start_point())
		else:
			pan_to(pan)

	## Offset kept inside the content: per axis centred when the content is smaller, else no empty margin.
	func clamp_offset(wanted: Vector2) -> Vector2:
		var content := content_size()
		var result := Vector2.ZERO
		for axis in 2:
			if content[axis] <= size[axis]:
				result[axis] = (size[axis] - content[axis]) * 0.5
			else:
				result[axis] = clampf(wanted[axis], size[axis] - content[axis], 0.0)
		return result.round()

	func pan_to(wanted: Vector2) -> void:
		pan = clamp_offset(wanted)
		queue_redraw()

	func center_on(point: Vector2) -> void:
		pan_to(size * 0.5 - point)

	func _gui_input(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressed = true
				dragging = false
				_press_at = button.position
				_press_offset = pan
				grab_focus()
			elif _pressed:
				_pressed = false
				if not dragging:
					_click(button.position)
				dragging = false
				mouse_default_cursor_shape = Control.CURSOR_ARROW
			accept_event()
			return
		var motion := event as InputEventMouseMotion
		if motion != null and _pressed:
			if not dragging and motion.position.distance_to(_press_at) >= DRAG_THRESHOLD:
				dragging = true
				_following = false   # the player looks around now: no re-centring until the next opening
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			if dragging:
				pan_to(_press_offset + motion.position - _press_at)
			accept_event()
			return
		if _key(event):
			accept_event()
			return
		for pair: Array in [[&"ui_left", Vector2.RIGHT], [&"ui_right", Vector2.LEFT], [&"ui_up", Vector2.DOWN], [&"ui_down", Vector2.UP]]:
			if event.is_action_pressed(pair[0], true):
				_following = false
				pan_to(pan + pair[1] * KEY_STEP)
				accept_event()
				return

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and _pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_pressed = false
			dragging = false

	func _draw_focus_frame() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.COLOR_FOCUS if has_focus() else UiTheme.BRONZE_DARK, false, 2.0)


## The Area view: the current map at a whole-pixel scale, centred on the player when opened.
class AreaMapView:
	extends PanCanvas

	var map: GameMap
	var character: Character
	var _markers: Array[Dictionary] = []

	func bind(target: GameMap, target_character: Character) -> void:
		map = target
		character = target_character
		refresh_markers()

	func refresh_markers() -> void:
		_markers = MapMarkers.collect(map, character, map.fog) if is_bound() else ([] as Array[Dictionary])

	func is_bound() -> bool:
		return map != null and is_instance_valid(map) and map.area_map != null

	## View px per world px: the whole map when it fits (up to AREA_MAX_SCALE), never below AREA_MIN_SCALE, in
	## steps of 1/8 (one map pixel = a whole number of screen pixels).
	func scale_factor() -> float:
		if not is_bound() or size.x < 1.0:
			return AREA_MIN_SCALE
		var bounds := map.area_map.bounds
		var fit := minf(size.x / bounds.size.x, size.y / bounds.size.y)
		return clampf(floorf(fit * 8.0) / 8.0, AREA_MIN_SCALE, AREA_MAX_SCALE)

	func content_size() -> Vector2:
		return (map.area_map.bounds.size * scale_factor()).floor() if is_bound() else Vector2.ZERO

	func start_point() -> Vector2:
		return world_to_content(map.player.global_position) if is_bound() and map.player != null else content_size() * 0.5

	func center_on_player() -> void:
		center_on(start_point())

	func world_to_content(world: Vector2) -> Vector2:
		return (world - map.area_map.bounds.position) * scale_factor()

	## Where `world` is drawn in this control (content + pan).
	func world_to_view(world: Vector2) -> Vector2:
		return world_to_content(world) + pan

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			refresh_markers()
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), AreaMap.VOID)
		if not is_bound():
			draw_string(UiTheme.body_font(), Vector2(12, 28), "No map of this place.", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED)
			_draw_focus_frame()
			return
		var bounds := map.area_map.bounds
		var factor := scale_factor()
		var view := Rect2(bounds.position - pan / factor, size / factor)   # the world rectangle in this control
		MapPainter.draw_area(self, map.area_map, map.fog, view, factor)
		var shown := Rect2(Vector2.ZERO, size).grow(16.0)
		for marker in _markers:
			var at := world_to_view(marker.position)
			if shown.has_point(at):
				MapPainter.draw_marker(self, marker, at, marker.kind in [MapMarkers.LANDMARK, MapMarkers.EXIT, MapMarkers.WAYSTONE, MapMarkers.NPC])
		MapPainter.draw_player(self, world_to_view(map.player.global_position), map.player.aim_direction, 9.0)
		_draw_focus_frame()


## One symbol of the Area legend, drawn with the same MapPainter as the map itself (word in the tooltip).
class LegendSwatch:
	extends Control

	var kind: StringName

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_PASS   # its tooltip names it
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var at := (size * 0.5).floor()
		match kind:
			&"player":
				MapPainter.draw_player(self, at, Vector2.UP, 8.0)
			&"explored":
				draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), AreaMap.ROAD)
				draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), MapFog.DIM)
			&"dark":
				draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), MapFog.DARK)
				draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), UiTheme.BRONZE_DARK, false, 1.0)
			&"silent":
				MapPainter.draw_marker(self, {"kind": MapMarkers.WAYSTONE, "label": "(silent)"}, at, false)
			&"quest":
				MapPainter.draw_marker(self, {"kind": MapMarkers.QUEST, "label": "", "quest": true}, at, false)
			_:
				MapPainter.draw_marker(self, {"kind": kind, "label": ""}, at, false)


## The Region view: a schematic network - one compact node per known place at its MapDefinition.map_cell, lines
## for the real neighbours, "?" for a neighbour not visited yet (never its name). Arrow = you are here; gold frame =
## the chosen place; the waystone symbol (awake / silent) right on the node, only where you may know it.
class MapGraph:
	extends PanCanvas

	signal selected(map_id: StringName)

	var character: Character
	var selected_id: StringName = &""
	var _known: Array[StringName] = []
	var _min_cell := Vector2i.ZERO
	var _max_cell := Vector2i.ZERO

	func bind(target: Character) -> void:
		character = target
		_known = WorldMapPanel.known_maps(character)
		# the layout spans every place of the region (as before): its size never tells what is still unknown
		_min_cell = Vector2i(999, 999)
		_max_cell = Vector2i(-999, -999)
		for map_def: MapDefinition in character.database.maps.values():
			if map_def.show_on_map:
				_min_cell = Vector2i(mini(_min_cell.x, map_def.map_cell.x), mini(_min_cell.y, map_def.map_cell.y))
				_max_cell = Vector2i(maxi(_max_cell.x, map_def.map_cell.x), maxi(_max_cell.y, map_def.map_cell.y))
		if not selected_id in _known:
			selected_id = character.world.here() if character.world.here() in _known else (_known[0] if not _known.is_empty() else &"")
		queue_redraw()

	func content_size() -> Vector2:
		if character == null:
			return Vector2.ZERO
		return Vector2(_max_cell - _min_cell + Vector2i.ONE) * CELL - (CELL - NODE) + MARGIN * 2.0

	func node_rect(map_id: StringName) -> Rect2:
		var map_def: MapDefinition = character.database.maps[map_id]
		return Rect2(MARGIN + Vector2(map_def.map_cell - _min_cell) * CELL, NODE)

	func start_point() -> Vector2:
		var here := character.world.here() if character != null else &""
		return node_rect(here).get_center() if here in _known else content_size() * 0.5

	func center_on_here() -> void:
		center_on(start_point())

	func known() -> Array[StringName]:
		return _known

	func select(map_id: StringName) -> void:
		if not map_id in _known:
			return
		selected_id = map_id
		var rect := node_rect(map_id)
		if not Rect2(Vector2.ZERO, size).encloses(Rect2(rect.position + pan, rect.size)):
			center_on(rect.get_center())   # keyboard choice off screen: bring it into view
		queue_redraw()
		selected.emit(map_id)

	func _click(at: Vector2) -> void:
		for map_id in _known:
			if node_rect(map_id).has_point(at - pan):
				select(map_id)
				return

	## Arrow keys choose the nearest known place in that direction (no other keys, no travel).
	func _key(event: InputEvent) -> bool:
		for pair: Array in [[&"ui_left", Vector2.LEFT], [&"ui_right", Vector2.RIGHT], [&"ui_up", Vector2.UP], [&"ui_down", Vector2.DOWN]]:
			if event.is_action_pressed(pair[0], true):
				var from := node_rect(selected_id).get_center() if selected_id in _known else start_point()
				var best := &""
				var best_distance := INF
				for map_id in _known:
					var to := node_rect(map_id).get_center() - from
					if map_id == selected_id or to.normalized().dot(pair[1]) < 0.5:
						continue
					if to.length() < best_distance:
						best_distance = to.length()
						best = map_id
				if best != &"":
					select(best)
				return true
		return false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL_INSET)
		if character == null:
			_draw_focus_frame()
			return
		var db := character.database
		var font := UiTheme.body_font()
		# paths first: the nodes are drawn over them, so no line runs through a name
		for map_id in _known:
			var map_def: MapDefinition = db.maps[map_id]
			for other_id in map_def.neighbors:
				var other: MapDefinition = db.maps.get(other_id)
				if other == null or not other.show_on_map:
					continue
				var known_other := other_id in _known
				var from := node_rect(map_id).get_center() + pan
				var to := node_rect(other_id).get_center() + pan
				draw_line(from, to, Color(UiTheme.BRONZE_DIM, 0.9 if known_other else 0.4), 2.0 if known_other else 1.0)
				if not known_other:   # a path not walked yet: a nameless "?"
					draw_circle(to, 13.0, UiTheme.PANEL)
					draw_arc(to, 13.0, 0.0, TAU, 20, Color(UiTheme.BRONZE_DARK, 0.9), 1.0)
					draw_string(font, to + Vector2(-4, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL, UiTheme.TEXT_SECONDARY)
		var here_id := character.world.here()
		for map_id in _known:
			var map_def: MapDefinition = db.maps[map_id]
			var rect := node_rect(map_id)
			rect.position += pan
			var here := map_id == here_id
			var chosen := map_id == selected_id
			draw_rect(rect, UiTheme.PANEL_ELEVATED if chosen or here else UiTheme.PANEL)
			draw_rect(rect.grow(-1.0), UiTheme.BRONZE if chosen else UiTheme.BRONZE_DARK, false, 2.0 if chosen else 1.0)
			var text_left := 8.0
			if here:   # you are here: the player arrow inside the node and a resonance line under it
				MapPainter.draw_player(self, rect.position + Vector2(16, rect.size.y * 0.5), Vector2.UP, 7.0)
				draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 4), Vector2(rect.size.x - 4, 2)), UiTheme.RESONANCE)
				text_left = 30.0
			var waystone := WorldMapPanel.place_waystone(character, map_id)
			var right := 8.0
			if waystone != null:
				var awake := waystone.available and WaystoneService.is_active(character, waystone.id)
				MapPainter.draw_marker(self, {"kind": MapMarkers.WAYSTONE, "label": "" if awake else "(silent)"},
					rect.position + Vector2(rect.size.x - 14, rect.size.y * 0.5), false)
				right = 26.0
			# the whole name, two lines when needed (never cut): centred vertically in the node
			var width := rect.size.x - text_left - right
			var lines := _wrap(font, map_def.display_name, width, UiTheme.FONT_SMALL)
			var line_height := font.get_height(UiTheme.FONT_SMALL)
			var top := rect.position.y + (rect.size.y - line_height * lines.size()) * 0.5 + font.get_ascent(UiTheme.FONT_SMALL)
			for index in lines.size():
				draw_string(font, Vector2(rect.position.x + text_left, top + index * line_height).round(), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
					UiTheme.FONT_SMALL, UiTheme.PARCHMENT if chosen or here else UiTheme.TEXT_PRIMARY)
		_draw_focus_frame()

	## `text` broken into lines of at most `width` px at word boundaries.
	static func _wrap(font: Font, text: String, width: float, font_size: int) -> PackedStringArray:
		var lines: PackedStringArray = []
		var line := ""
		for word in text.split(" "):
			var candidate := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				lines.append(line)
				line = word
			else:
				line = candidate
		if line != "":
			lines.append(line)
		return lines

	## True when every known place's name fits its node in at most two lines (tests).
	func names_fit() -> bool:
		var font := UiTheme.body_font()
		for map_id in _known:
			var map_def: MapDefinition = character.database.maps[map_id]
			var waystone := WorldMapPanel.place_waystone(character, map_id)
			var width := NODE.x - (30.0 if map_id == character.world.here() else 8.0) - (26.0 if waystone != null else 8.0)
			var lines := _wrap(font, map_def.display_name, width, UiTheme.FONT_SMALL)
			if lines.size() > 2:
				return false
			for line in lines:
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_SMALL).x > width + 0.5:
					return false
		return true
