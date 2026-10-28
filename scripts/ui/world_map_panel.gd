class_name WorldMapPanel
extends UiWindow
## Region map (M): a schematic of the places you know in the Hollow Outskirts -
## not a terrain map. Visited places with their paths, "You are here", awake
## waystones and the region's planned waystones that are still undiscovered.
## Drawn from MapDefinition presentation data (cell, neighbors) and the
## character's WorldState; nothing here changes the world.

const CELL := Vector2(210, 120)
const NODE := Vector2(170, 56)

var character: Character

var _graph: MapGraph
var _legend: VBoxContainer


func _ready() -> void:
	set_title("Hollow Outskirts")
	set_close_text("Close [M / Esc]")
	body.add_child(UiTheme.styled("Places you have found. Travel between awake waystones at any waystone.", &"SmallLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP * 3)
	_graph = MapGraph.new()
	row.add_child(_graph)
	_legend = VBoxContainer.new()
	_legend.custom_minimum_size = Vector2(260, 0)
	row.add_child(_legend)
	body.add_child(row)


func open(target_character: Character) -> void:
	character = target_character
	_graph.character = character
	_graph.rebuild()
	_rebuild_legend()
	show()
	queue_fit()


## Map ids drawn on the map: visited (or current) and not developer-only.
static func known_maps(target: Character) -> Array[StringName]:
	var result: Array[StringName] = []
	for map_def: MapDefinition in target.database.maps.values():
		if not map_def.show_on_map:
			continue
		if map_def.id == target.world.here() or int(target.world.get_map_value(map_def.id, "visits", 0)) > 0:
			result.append(map_def.id)
	return result


func _rebuild_legend() -> void:
	for child in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()
	_legend.add_child(UiTheme.section("Waystones"))
	for waystone in WaystoneService.all(character.database):
		var awake := waystone.available and WaystoneService.is_active(character, waystone.id)
		var line := UiTheme.styled("%s  -  %s" % [waystone.display_name, "awake" if awake else "undiscovered"], &"SmallLabel")
		line.add_theme_color_override(&"font_color", UiTheme.RESONANCE if awake else UiTheme.TEXT_MUTED)
		_legend.add_child(line)
	_legend.add_child(UiTheme.section("Legend"))
	_legend.add_child(UiTheme.styled("[You are here]  your location", &"SmallLabel"))
	_legend.add_child(UiTheme.styled("(W)  awake waystone", &"SmallLabel"))
	_legend.add_child(UiTheme.styled("?  a path you have not walked yet", &"SmallLabel"))


class MapGraph:
	extends Control

	var character: Character
	var _origin := Vector2.ZERO
	var _known: Array[StringName] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func rebuild() -> void:
		_known = WorldMapPanel.known_maps(character)
		var min_cell := Vector2i(999, 999)
		var max_cell := Vector2i(-999, -999)
		for map_def: MapDefinition in character.database.maps.values():
			if map_def.show_on_map:
				min_cell = Vector2i(mini(min_cell.x, map_def.map_cell.x), mini(min_cell.y, map_def.map_cell.y))
				max_cell = Vector2i(maxi(max_cell.x, map_def.map_cell.x), maxi(max_cell.y, map_def.map_cell.y))
		_origin = -Vector2(min_cell) * CELL + Vector2(20, 20)
		custom_minimum_size = Vector2(max_cell - min_cell + Vector2i.ONE) * CELL + Vector2(40, 0)
		queue_redraw()

	func _center(map_def: MapDefinition) -> Vector2:
		return _origin + Vector2(map_def.map_cell) * CELL + NODE * 0.5

	func _draw() -> void:
		if character == null:
			return
		var db := character.database
		var font := ThemeDB.fallback_font
		# paths
		for map_id in _known:
			var map_def: MapDefinition = db.maps[map_id]
			for other_id in map_def.neighbors:
				var other: MapDefinition = db.maps.get(other_id)
				if other == null or not other.show_on_map:
					continue
				var known_other := other_id in _known
				draw_line(_center(map_def), _center(other), Color(UiTheme.BRONZE_DIM, 0.9 if known_other else 0.35), 2.0 if known_other else 1.0)
				if not known_other:
					var at := _center(other)
					draw_circle(at, 14, UiTheme.PANEL_INSET)
					draw_arc(at, 14, 0, TAU, 20, Color(UiTheme.BRONZE_DARK, 0.8), 1.0)
					draw_string(font, at + Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.FONT_BODY, UiTheme.TEXT_MUTED)
		# places
		for map_id in _known:
			var map_def: MapDefinition = db.maps[map_id]
			var rect := Rect2(_origin + Vector2(map_def.map_cell) * CELL, NODE)
			var here := map_id == character.world.here()
			draw_rect(rect, UiTheme.PANEL_ELEVATED if here else UiTheme.PANEL_INSET)
			draw_rect(rect, UiTheme.BRONZE if here else UiTheme.BRONZE_DARK, false, 2.0)
			draw_string(font, rect.position + Vector2(8, 22), map_def.display_name, HORIZONTAL_ALIGNMENT_LEFT, NODE.x - 16, UiTheme.FONT_SMALL, UiTheme.PARCHMENT)
			var caption := "[You are here]" if here else ""
			for waystone in WaystoneService.all(db):
				if waystone.map_id == map_id and waystone.available and WaystoneService.is_active(character, waystone.id):
					caption = (caption + "  (W)").strip_edges()
			if caption != "":
				draw_string(font, rect.position + Vector2(8, 44), caption, HORIZONTAL_ALIGNMENT_LEFT, NODE.x - 16, UiTheme.FONT_CAPTION,
					UiTheme.RESONANCE if here else UiTheme.TEXT_SECONDARY)
