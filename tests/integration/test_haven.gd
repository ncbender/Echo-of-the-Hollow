extends TestCase
## Haven & hybrid restoration: six fixed ruins (no free plots), atomic
## restoration (check all -> consume once -> world variant -> services ->
## milestone save), "A Fire Rekindled" with the cart supplies, the optional Old
## Storehouse, "Restoration unavailable for now.", Mara and Edrin with their
## lines, the north gate, Haven being safe, existing functions reachable.

const DIR := "user://test_saves/haven"
const PROFILE := DIR + "/slot_1.save.json"

var db: GameDatabase
var session: SessionState
var character: Character
var map: GameMap
var _previous_character: Character
var _previous_path: String


func before_each() -> void:
	db = GameDatabase.get_default()
	session = SessionState.find(get_tree())
	_previous_character = session.character
	_previous_path = session.save_path
	session.save_path = PROFILE
	session.saves.reset()
	character = CharacterFactory.create_new(db)
	session.set_character(character)


func after_each() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.saves.reset()
	for path in SaveSlots.all_paths(PROFILE):
		for suffix: String in ["", SaveSystem.BACKUP_SUFFIX, SaveSystem.TEMP_SUFFIX]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	session.save_path = _previous_path
	session.set_character(_previous_character)


## Story state: Mara brought the player to Haven with both crates.
func _arrive() -> void:
	for event: StringName in [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
			&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
			&"talk:mara_road_end", &"enter:home_base"]:
		StoryService.notify(character, event)
	character.inventory.add_item(&"supply_crate", 2)


func _open_haven() -> GameMap:
	character.world.map_id = &"home_base"
	session.travel(&"home_base", &"from_road", false)
	for i in 240:
		await get_tree().process_frame
		var current := get_tree().current_scene as GameMap
		if current != null and current.map_id == &"home_base" and current.is_node_ready() and not session.is_traveling():
			map = current
			await get_tree().physics_frame
			return current
	fail("Haven not loaded")
	return null


func _talk(npc: StoryNpc) -> PackedStringArray:
	var lines: PackedStringArray = []
	npc.interact(map.hud)
	var guard := 0
	while map.hud.dialogue_panel.visible and guard < 20:
		lines.append(map.hud.dialogue_panel.current_text())
		map.hud.dialogue_panel.advance()
		guard += 1
	return lines


func test_ruin_data() -> void:
	check_eq(db.ruins.size(), 10, "six original buildings + four Artisan Quarter workshops")
	var names: Array = []
	for ruin_id: StringName in [&"old_smithy", &"old_storehouse", &"fallen_barracks", &"common_hall", &"trading_house", &"forgotten_study"]:
		var ruin: RuinDefinition = db.ruins.get(ruin_id)
		if check(ruin != null, "ruin %s" % ruin_id):
			names.append(ruin.display_name)
	check_eq(names, ["The Old Smithy", "The Old Storehouse", "The Fallen Barracks", "The Common Hall", "The Trading House",
		"The Forgotten Study"], "English ruin names")
	var restorable: Array = db.ruins.values().filter(func(r: RuinDefinition) -> bool: return r.restorable)
	check_eq(restorable.size(), 6, "the smithy, the storehouse and the four Artisan Quarter workshops can be restored")
	check(RestorationService.validate_data(db).is_empty(), "ruin data valid")
	var workshops: Dictionary = {}
	for ruin: RuinDefinition in db.ruins.values():
		if ruin.profession_id != &"":
			workshops[ruin.id] = ruin.profession_id
	check_eq(workshops, {&"old_smithy": &"blacksmithing", &"tanners_lodge": &"leatherworking", &"weavers_house": &"tailoring",
		&"woodwrights_workshop": &"woodworking", &"alchemists_cottage": &"alchemy"}, "workstations only in the five workshops")


func test_a_fire_rekindled_is_atomic() -> void:
	var smithy: RuinDefinition = db.ruins[&"old_smithy"]
	check_eq(RestorationService.restore_error(character, smithy), RestorationService.UNAVAILABLE, "not before Haven")
	_arrive()
	character.inventory.remove_quantity(&"supply_crate", 1)
	var before := character.inventory.to_array()
	check(RestorationService.restore(character, smithy).begins_with("Missing: Supply Crate 1/2"), "one crate is not enough")
	check_eq(character.inventory.to_array(), before, "nothing consumed by a refused restoration")
	check_eq(RestorationService.stage(character, &"old_smithy"), &"ruined", "still ruined")
	character.inventory.add_item(&"supply_crate", 1)
	StoryService.notify(character, &"talk:mara_welcome")
	check_eq(RestorationService.restore(character, smithy), "", "restored")
	check_eq(character.inventory.count(&"supply_crate"), 0, "exactly the two crates consumed")
	check_eq(RestorationService.stage(character, &"old_smithy"), &"restored", "stage restored")
	check(character.world.has_flag(&"prologue.smithy_restored"), "story flag")
	check(StoryService.at_step(character, &"shelter_among_the_trees", 3), "quest moved on")
	check(RestorationService.restore(character, smithy).contains("already restored"), "never twice")


func test_storehouse_is_optional_and_others_unavailable() -> void:
	_arrive()
	var store: RuinDefinition = db.ruins[&"old_storehouse"]
	check_eq(RestorationService.restore_error(character, store), RestorationService.UNAVAILABLE, "after the smithy only")
	RestorationService.restore(character, db.ruins[&"old_smithy"])
	check(RestorationService.restore_error(character, store).begins_with("Missing"), "now it shows its costs")
	character.inventory.add_item(&"timber", 4)
	character.inventory.add_item(&"stone", 2)
	var capacity := character.inventory.capacity
	check_eq(RestorationService.restore(character, store), "", "storehouse restored")
	check_eq(character.inventory.capacity, capacity + 10, "+10 inventory slots")
	for ruin_id: StringName in [&"fallen_barracks", &"common_hall", &"trading_house", &"forgotten_study"]:
		character.inventory.add_item(&"timber", 10)
		check_eq(RestorationService.restore_error(character, db.ruins[ruin_id]), "Restoration unavailable for now.", "%s unavailable" % ruin_id)


func test_haven_restoration_flow_in_the_map() -> void:
	_arrive()
	if await _open_haven() == null:
		return
	var mara := map.get_node("Mara") as StoryNpc
	var edrin := map.get_node("Edrin") as StoryNpc
	check(mara.visible and edrin.visible, "Mara and Edrin in Haven")
	check_eq(_talk(mara)[0], "Welcome to Haven. Don't let the name fool you. We work hard to keep it true.", "Mara's welcome")
	check(StoryService.at_step(character, &"shelter_among_the_trees", 2), "now the smithy")
	var smithy := map.get_node("Ruins/OldSmithy") as RuinSite
	smithy.interact(map.hud)
	check(map.hud.restoration_panel.visible, "restoration window")
	var hall := map.get_node("Ruins/CommonHall") as RuinSite
	map.hud.close_windows()
	map.hud.restoration_panel.open(character, hall)
	check(map.hud.restoration_panel.find_child("Restore", true, false) == null, "no Restore button for an unavailable ruin")
	check(_texts(map.hud.restoration_panel).has("Restoration unavailable for now."), "unavailable text shown")
	map.hud.restoration_panel.open(character, smithy)
	check_eq(map.hud.restoration_panel.restore(), "", "restored from the window")
	var lines: PackedStringArray = []
	while map.hud.dialogue_panel.visible:
		lines.append(map.hud.dialogue_panel.current_text())
		map.hud.dialogue_panel.advance()
	check_eq(lines, PackedStringArray(["This place isn't dead. Just buried under years of neglect.", "Think we can bring it back?",
		"One stone at a time."]), "A Fire Rekindled dialogue")
	check(smithy.built_building() != null and smithy.get_child_count() >= 2, "the world shows the smithy")
	smithy.interact(map.hud)
	check(map.hud.crafting_panel.visible, "the forge works (Resonance Forge)")
	map.hud.close_windows()
	await get_tree().process_frame
	await get_tree().process_frame
	var latest := SaveSlots.latest(PROFILE)
	var saved := SaveSystem.load_from(latest.get("path", ""), db)
	check(saved.ok() and RestorationService.is_restored(saved.character, &"old_smithy"), "milestone save holds the restoration")
	var gate := map.get_node("NorthGate") as StoryConditional
	check(gate.visible, "north gate barred")
	var intro := _talk(edrin)
	check_eq(intro, PackedStringArray(["Mara says you came in from the southern road. Then you've seen what walks out there.",
		"Those things weren't normal.", "No. And they weren't always like that.", "They've barely reached Haven, Edrin.",
		"And the thing in those woods gets closer every night.",
		"North of this gate lies an old shrine, the Whispering Stone. If you mean to stand against what is coming, go and listen to it."]),
		"Edrin's introduction (with Mara)")
	check(StoryService.at_step(character, &"the_whispering_stone", 0), "on to the Whispering Stone")
	await get_tree().process_frame
	check(not gate.visible, "north gate open")
	check_eq(_talk(mara), PackedStringArray(["Haven wasn't always this quiet. Most of these houses had families in them once.",
		"What happened?", "Depends who you ask. Maybe one day we'll have the luxury of finding out."]), "Mara about Haven's past")
	check(map.get_node_or_null("ClassStation") is ClassStation, "class station (training, presets, respec) still in Haven")


func test_haven_is_safe() -> void:
	_arrive()
	if await _open_haven() == null:
		return
	for i in 120:
		await get_tree().physics_frame
	check(map.find_children("*", "Enemy", true, false).is_empty(), "no enemies in Haven")
	check(map.find_children("*", "Encounter", true, false).is_empty(), "no encounters in Haven")


func test_restoration_survives_save_and_load() -> void:
	_arrive()
	RestorationService.restore(character, db.ruins[&"old_smithy"])
	character.inventory.add_item(&"timber", 4)
	character.inventory.add_item(&"stone", 2)
	RestorationService.restore(character, db.ruins[&"old_storehouse"])
	var path := DIR + "/restored.save.json"
	check_eq(SaveSystem.save_to(character, path), OK, "saved")
	var loaded := SaveSystem.load_from(path, db)
	for suffix: String in ["", SaveSystem.BACKUP_SUFFIX]:
		DirAccess.remove_absolute(path + suffix)
	check(loaded.ok(), "loaded")
	character = loaded.character
	session.set_character(character)
	check_eq(character.inventory.capacity, db.rules.inventory_capacity + 10, "capacity restored once")
	if await _open_haven() == null:
		return
	check((map.get_node("Ruins/OldStorehouse") as RuinSite).built_building() != null, "storehouse standing after loading")
	check(not (map.get_node("Ruins/CommonHall") as RuinSite).is_restored(), "others still ruined")


func test_v4_buildings_become_ruins_without_double_bonus() -> void:
	var errors: PackedStringArray = []
	var data: Dictionary = SaveMigrations.migrate({"world": {"buildings": {"plot_east": "storage", "plot_north": "training_ground"}},
		"prologue": {"stage": "completed"}}, 4, errors)
	var warnings: PackedStringArray = []
	var migrated := Character.from_dict(data, db, warnings)
	check(RestorationService.is_restored(migrated, &"old_storehouse") and RestorationService.is_restored(migrated, &"fallen_barracks"), "plots became ruins")
	check(migrated.world.buildings.is_empty(), "plot list emptied")
	check_eq(migrated.inventory.capacity, db.rules.inventory_capacity + 10, "storage bonus exactly once")
	check(RestorationService.building(migrated, &"fallen_barracks").id == &"training_ground", "training yard kept")


func _texts(node: Node) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in node.find_children("*", "Label", true, false):
		texts.append(label.text.strip_edges())
	return texts
