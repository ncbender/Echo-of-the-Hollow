class_name RuinSite
extends BuildPlot
## A ruin of Haven at a fixed place (no free building). Ruined: rubble and
## the restoration window. Restored: the building of the ruin's definition
## appears (BuildPlot shows it) and works as before - the Old Smithy opens the
## Resonance Forge and its recipes, the Old Storehouse adds inventory slots,
## the Fallen Barracks bring back the training yard. A ruin with stash access
## (Old Storehouse) opens the Haven stash in every stage.

@export var ruin_id: StringName

var _character: Character


func _ready() -> void:
	super._ready()
	_character = character()
	if _character != null:
		_character.world.restoration_changed.connect(_on_restoration_changed)


func _exit_tree() -> void:
	if _character != null and _character.world.restoration_changed.is_connected(_on_restoration_changed):
		_character.world.restoration_changed.disconnect(_on_restoration_changed)


func ruin() -> RuinDefinition:
	return GameDatabase.get_default().ruins.get(ruin_id)


func is_restored() -> bool:
	var owner_character := character()
	return owner_character != null and RestorationService.is_restored(owner_character, ruin_id)


## The building a restored ruin provides (the BuildPlot machinery shows it).
func built_building() -> BuildingDefinition:
	var owner_character := character()
	return RestorationService.building(owner_character, ruin_id) if owner_character != null else null


## An Artisan Quarter workshop: a profession workstation without a building of
## its own. Its bench comes first in every stage; restoring is offered there.
func is_workshop() -> bool:
	var definition := ruin()
	return definition != null and definition.profession_id != &"" and definition.building_id == &""


func stage() -> StringName:
	var owner_character := character()
	return RestorationService.stage(owner_character, ruin_id) if owner_character != null else RestorationService.RUINED


func refresh() -> void:
	super.refresh()
	var definition := ruin()
	var title := definition.display_name if definition != null else String(ruin_id)
	if is_workshop():
		prompt = "Work at %s" % title
	elif not is_restored():
		prompt = "Inspect %s" % title
	elif built_building() != null:
		prompt = "Use %s" % title
	else:
		prompt = title
	queue_redraw()


func _on_restoration_changed(changed: StringName, _stage: StringName) -> void:
	if changed == ruin_id:
		refresh()


func interact(hud: GameHud) -> void:
	var definition := ruin()
	if definition != null and definition.stash_access:
		hud.open_stash(self)   # the stash works in every stage; restoring is offered there
		return
	if is_workshop():
		hud.open_professions(ruin_id, self)   # Artisan Quarter workshop: the bench works in every stage
		return
	if not is_restored():
		hud.open_restoration(self)
	elif built_building() != null:
		super.interact(hud)


## Restores the ruin (all checks inside RestorationService). On success the
## world changes at once and the ruin's closing dialogue is played.
func restore(hud: GameHud) -> String:
	return advance(hud, RestorationService.RESTORED)


## Advances the ruin to `target` - exactly its next stage (a stale or repeated
## request is refused by RestorationService and changes nothing).
func advance(hud: GameHud, target: StringName) -> String:
	var owner_character := character()
	var error := RestorationService.advance(owner_character, ruin(), target)
	if error != "":
		return error
	refresh()
	var done := "revitalized" if target == RestorationService.REVITALIZED else "restored"
	hud.notify("%s has been %s." % [ruin().display_name, done])
	if target == RestorationService.RESTORED and ruin().completion_dialogue != null:
		hud.open_dialogue(ruin().completion_dialogue)
	return ""


func _draw() -> void:
	var definition := ruin()
	var size := definition.footprint if definition != null else Vector2(60, 40)
	var title := definition.display_name if definition != null else String(ruin_id)
	var rect := Rect2(-size * 0.5, size)
	var color := Color(0.95, 0.85, 0.6, 0.95 if player_inside else 0.75)
	if is_workshop():
		_draw_workshop(definition, rect, title, color)
		return
	if is_restored():
		if built_building() == null:
			draw_rect(rect, Color(0.5, 0.45, 0.35, 0.35))
			WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -size.y * 0.5 - 6), title, 7, Color(1.0, 0.92, 0.75), 2, Color.BLACK)
		return
	_draw_rubble(rect)
	WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -size.y * 0.5 - 6), title, 7, color, 2, Color.BLACK)
	if definition != null and definition.profession_id != &"":
		_draw_workstation(definition, rect)


## Ruin: broken wall stumps, a fallen beam, rubble.
func _draw_rubble(rect: Rect2) -> void:
	var size := rect.size
	var stone := Color(0.36, 0.33, 0.3)
	draw_rect(rect, Color(0.22, 0.2, 0.17, 0.6))
	draw_rect(Rect2(rect.position, Vector2(size.x, 5)), stone)
	draw_rect(Rect2(rect.position, Vector2(5, size.y * 0.7)), stone)
	draw_rect(Rect2(rect.position + Vector2(size.x - 5, size.y * 0.3), Vector2(5, size.y * 0.7)), stone.darkened(0.15))
	draw_rect(Rect2(rect.position + Vector2(size.x * 0.55, size.y - 5), Vector2(size.x * 0.45, 5)), stone.darkened(0.1))
	draw_line(rect.position + Vector2(8, 10), rect.position + Vector2(size.x - 12, size.y - 8), Color(0.35, 0.25, 0.16), 3.0)
	for i in 5:
		var at := rect.position + Vector2(10 + (i * 37) % int(size.x - 16), 12 + (i * 23) % int(size.y - 16))
		draw_circle(at, 2.5, stone.lightened(0.1))


## An Artisan Quarter workshop in its stage. Ruined: rubble. Restored: closed
## walls, a plank floor, stacked stock. Revitalized: additionally lanterns, a
## tool rack, a banner in the profession's colour and a planter. The bench and
## its sign stand in every stage (same place: interaction never moves).
func _draw_workshop(definition: RuinDefinition, rect: Rect2, title: String, color: Color) -> void:
	var current := stage()
	var profession: ProfessionDefinition = GameDatabase.get_default().professions.get(definition.profession_id)
	var tint := profession.color if profession != null else Color(0.7, 0.6, 0.4)
	if current == RestorationService.RUINED:
		_draw_rubble(rect)
	else:
		_draw_repaired(rect, tint)
	if current == RestorationService.REVITALIZED:
		color = Color(1.0, 0.92, 0.72, 1.0 if player_inside else 0.9)
	WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -rect.size.y * 0.5 - 6), title, 7, color, 2, Color.BLACK)
	_draw_workstation(definition, rect)
	if current == RestorationService.REVITALIZED:
		_draw_revitalized(rect, tint)


func _draw_repaired(rect: Rect2, tint: Color) -> void:
	var size := rect.size
	var wall := Color(0.47, 0.4, 0.31)
	draw_rect(Rect2(rect.position + Vector2(2, 3), size), Color(0, 0, 0, 0.25))   # shadow
	draw_rect(rect, Color(0.34, 0.27, 0.19))   # plank floor
	var y := rect.position.y + 10.0
	while y < rect.end.y - 4.0:
		draw_line(Vector2(rect.position.x + 5, y), Vector2(rect.end.x - 5, y), Color(0.27, 0.21, 0.15), 1.0)
		y += 6.0
	draw_rect(Rect2(rect.position, Vector2(size.x, 8)), wall)   # back wall
	draw_rect(Rect2(rect.position, Vector2(size.x, 2)), wall.lightened(0.2))
	draw_rect(Rect2(rect.position, Vector2(5, size.y)), wall.darkened(0.1))   # side walls
	draw_rect(Rect2(rect.position + Vector2(size.x - 5, 0), Vector2(5, size.y)), wall.darkened(0.15))
	draw_rect(Rect2(rect.position + Vector2(0, size.y - 4), Vector2(size.x * 0.3, 4)), wall.darkened(0.05))   # front, open door
	draw_rect(Rect2(rect.position + Vector2(size.x * 0.7, size.y - 4), Vector2(size.x * 0.3, 4)), wall.darkened(0.05))
	for i in 2:   # stock stacked in the back corner
		var at := rect.position + Vector2(14 + i * 8, 10)
		draw_rect(Rect2(at, Vector2(7, 7)), tint.darkened(0.45))
		draw_rect(Rect2(at, Vector2(7, 7)), Color(0.2, 0.15, 0.1), false, 1.0)


func _draw_revitalized(rect: Rect2, tint: Color) -> void:
	var size := rect.size
	for x: float in [0.2, 0.8]:   # lanterns on the back wall
		var at := rect.position + Vector2(size.x * x, 6)
		draw_circle(at, 10.0, Color(1.0, 0.78, 0.4, 0.14))
		draw_circle(at, 5.0, Color(1.0, 0.8, 0.45, 0.22))
		draw_circle(at, 2.0, Color(1.0, 0.88, 0.6))
	for i in 4:   # tool rack
		var at := rect.position + Vector2(size.x - 22 + i * 4, 10)
		draw_line(at, at + Vector2(0, 7), tint.lightened(0.2), 1.5)
	var banner := Rect2(rect.position + Vector2(6, 12), Vector2(6, 11))   # banner in the trade's colour
	draw_rect(banner, tint)
	draw_rect(banner, tint.darkened(0.5), false, 1.0)
	for i in 3:   # planter by the door
		draw_circle(rect.position + Vector2(size.x * 0.3 - 6 + i * 3, size.y - 7), 2.0, Color(0.35, 0.6, 0.3))


## Workstation of a workshop ruin (usable in every stage) and its hanging sign
## with the profession's colour and name.
func _draw_workstation(definition: RuinDefinition, rect: Rect2) -> void:
	var profession: ProfessionDefinition = GameDatabase.get_default().professions.get(definition.profession_id)
	var tint := profession.color if profession != null else Color(0.7, 0.6, 0.4)
	var bench := Rect2(rect.position + Vector2(rect.size.x * 0.5 - 13, rect.size.y - 17), Vector2(26, 9))
	draw_rect(bench, Color(0.42, 0.3, 0.19))
	draw_rect(Rect2(bench.position, Vector2(bench.size.x, 2)), Color(0.55, 0.41, 0.26))
	draw_rect(Rect2(bench.position + Vector2(3, 9), Vector2(2, 5)), Color(0.3, 0.21, 0.13))
	draw_rect(Rect2(bench.position + Vector2(bench.size.x - 5, 9), Vector2(2, 5)), Color(0.3, 0.21, 0.13))
	draw_circle(bench.position + Vector2(bench.size.x * 0.5, -2), 3.0, tint)   # the tool of the trade
	# sign on a post at the right front corner
	var post := rect.position + Vector2(rect.size.x + 4, rect.size.y - 2)
	draw_line(post, post + Vector2(0, -22), Color(0.36, 0.26, 0.16), 2.0)
	var board := Rect2(post + Vector2(-9, -22), Vector2(18, 10))
	draw_rect(board, Color(0.5, 0.38, 0.24))
	draw_rect(Rect2(board.position + Vector2(2, 2), board.size - Vector2(4, 4)), tint.darkened(0.2))
	if profession != null:
		var label := profession.display_name
		WorldText.draw(self, Vector2(-WorldText.width(label, 6) * 0.5, -rect.size.y * 0.5 + 6), label, 6, tint.lightened(0.35), 2, Color.BLACK)
