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


func refresh() -> void:
	super.refresh()
	var definition := ruin()
	var title := definition.display_name if definition != null else String(ruin_id)
	if not is_restored():
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
	if not is_restored():
		hud.open_restoration(self)
	elif built_building() != null:
		super.interact(hud)


## Restores the ruin (all checks inside RestorationService). On success the
## world changes at once and the ruin's closing dialogue is played.
func restore(hud: GameHud) -> String:
	var owner_character := character()
	var error := RestorationService.restore(owner_character, ruin())
	if error != "":
		return error
	refresh()
	hud.notify("%s has been restored." % ruin().display_name)
	if ruin().completion_dialogue != null:
		hud.open_dialogue(ruin().completion_dialogue)
	return ""


func _draw() -> void:
	var definition := ruin()
	var size := definition.footprint if definition != null else Vector2(60, 40)
	var title := definition.display_name if definition != null else String(ruin_id)
	if is_restored():
		if built_building() == null:
			draw_rect(Rect2(-size * 0.5, size), Color(0.5, 0.45, 0.35, 0.35))
			WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -size.y * 0.5 - 6), title, 7, Color(1.0, 0.92, 0.75), 2, Color.BLACK)
		return
	# ruin: broken wall stumps, a fallen beam, rubble
	var rect := Rect2(-size * 0.5, size)
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
	var color := Color(0.95, 0.85, 0.6, 0.95 if player_inside else 0.75)
	WorldText.draw(self, Vector2(-WorldText.width(title, 7) * 0.5, -size.y * 0.5 - 6), title, 7, color, 2, Color.BLACK)
