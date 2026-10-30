class_name BuildPlot
extends Interactable
## A predefined build plot in the home base. Empty: shows the foundation and
## opens the build menu. Built: shows the building scene and opens its menu.
## The built state lives in the character's WorldState (persistent, saved).

@export var plot_id: StringName

var _building_node: Node
var _session: SessionState


func _ready() -> void:
	super()
	_session = SessionState.find(get_tree())
	refresh()


func definition() -> BuildingPlotDefinition:
	return GameDatabase.get_default().plots.get(plot_id)


func character() -> Character:
	return _session.get_character() if _session != null else null


func built_building() -> BuildingDefinition:
	var owner_character := character()
	if owner_character == null:
		return null
	return owner_character.database.buildings.get(BaseBuilder.plot_state(owner_character, plot_id))


## Syncs the visuals with the saved state (call after building).
func refresh() -> void:
	var building := built_building()
	if building != null and _building_node == null and building.scene != null:
		_building_node = building.scene.instantiate()
		add_child(_building_node)
	var plot := definition()
	prompt = "Use %s" % building.display_name if building != null \
		else "Build on %s" % (plot.display_name if plot != null else String(plot_id))
	queue_redraw()


func interact(hud: GameHud) -> void:
	var building := built_building()
	if building != null and building.crafting_station:
		hud.open_crafting_panel(self)
	else:
		hud.open_build_panel(self)


func _draw() -> void:
	if built_building() != null:
		return
	var rect := Rect2(-32, -22, 64, 44)
	draw_rect(rect, Color(0.6, 0.55, 0.4, 0.12))
	var color := Color(0.9, 0.8, 0.5, 0.75 if player_inside else 0.4)
	var x := rect.position.x
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(minf(x + 5, rect.end.x), rect.position.y), color, 1.0)
		draw_line(Vector2(x, rect.end.y), Vector2(minf(x + 5, rect.end.x), rect.end.y), color, 1.0)
		x += 9.0
	var y := rect.position.y
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, minf(y + 5, rect.end.y)), color, 1.0)
		draw_line(Vector2(rect.end.x, y), Vector2(rect.end.x, minf(y + 5, rect.end.y)), color, 1.0)
		y += 9.0
	var plot := definition()
	var text := plot.display_name if plot != null else String(plot_id)
	var font := UiTheme.body_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
	WorldText.draw(self, Vector2(-width * 0.5, 3), text, 7, color, 2, Color.BLACK)
