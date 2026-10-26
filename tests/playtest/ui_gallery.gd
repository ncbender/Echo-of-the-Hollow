extends SceneTree
## UI gallery (NOT headless): opens every player-facing screen with realistic
## data, takes a screenshot and checks the layout (on screen, inside the margin,
## nothing squeezed). Used for the visual review of the UI/UX redesign. Run:
##   godot --path . -s res://tests/playtest/ui_gallery.gd -- [--res=1920x1080] [--scale=1.0] [--only=a,b]
## Screenshots: tests/output/gallery/<res>_<scale>_<screen>.png

const OUTPUT := "res://tests/output/gallery"

var session: SessionState
var map: GameMap
var log_lines: PackedStringArray = []
var failures: int = 0
var checks: int = 0
var tag: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	session = SessionState.find(self)
	session.save_path = "user://test_saves/ui_gallery/slot_1.save.json"
	var resolutions := _arg("res", "1920x1080").split(",")
	var scales := _arg("scale", "1.0").split(",")
	for res_text in resolutions:
		var size := Vector2i(int(res_text.get_slice("x", 0)), int(res_text.get_slice("x", 1)))
		for scale_text in scales:
			await _pass(size, float(scale_text))
	_log("RESULT: %s (%d checks, %d failed)" % ["OK" if failures == 0 else "FAILED", checks, failures])
	var file := FileAccess.open(OUTPUT.path_join("gallery_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0 if failures == 0 else 1)


func _pass(resolution: Vector2i, scale: float) -> void:
	tag = "%dp_%d" % [resolution.y, roundi(scale * 100.0)]
	root.mode = Window.MODE_WINDOWED
	root.borderless = resolution.x >= DisplayServer.screen_get_size().x
	root.size = resolution
	root.position = DisplayServer.screen_get_position()
	session.settings.set_ui_scale(scale)
	session.settings.set_reduce_motion(true)   # deterministic screenshots (no fade in progress)
	await _frames(8)
	session.set_character(_rich_character())
	var only := _arg("only", "")
	var screens: Array = GalleryScreens.ALL if only == "" else Array(only.split(","))
	await _title_screen(screens)
	change_scene_to_file("res://scenes/maps/home_base.tscn")
	await _await_map()
	for screen: String in screens:
		if screen == "title":
			continue
		map.hud.close_windows()
		await _frames(3)
		var label: String = await GalleryScreens.open(self, screen)
		if label == "":
			continue
		await _frames(6)
		_check_layout(screen)
		await _shot(screen)
	map.hud.close_windows()


func _title_screen(screens: Array) -> void:
	if not "title" in screens:
		return
	change_scene_to_file(SessionState.TITLE_SCENE)
	await _frames(10)
	_check_controls(current_scene, "title")
	await _shot("title")


## A character with something in every system: items of all kinds, crafted
## affixes, a second class, talents, presets, quests, restored ruins.
func _rich_character() -> Character:
	var character := CharacterFactory.create_new(session.database)
	GameMap.give_crafting_kit(character)
	GameMap.give_debug_items(character)
	for event: StringName in [&"reach:road_signpost", &"encounter:road_ambush", &"reach:cart_site", &"encounter:cart_attack",
			&"talk:mara_cart", &"interact:supply_crate", &"interact:supply_crate", &"encounter:cart_second_wave",
			&"talk:mara_road_end", &"enter:home_base", &"talk:mara_welcome"]:
		StoryService.notify(character, event)
	character.world.set_restoration(&"old_smithy", &"restored")
	character.world.set_flag(&"haven.old_smithy.restored")
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	character.classes.add_xp(&"warrior", 60000)
	for node_id: StringName in [&"war_b_seething", &"war_b_seething", &"war_wb_hands"]:
		TalentService.learn(character, &"warrior", node_id)
	PresetService.save_preset(character, &"warrior", 0, "Rage Bruiser")
	QuestService.start(character, &"unlock_arcanist")
	_forge_example(character)
	return character


## A forged blade with several affixes, two essences and a socketed gem - made
## through the real CraftingService (seeded), nothing written by hand.
func _forge_example(character: Character) -> void:
	var blade: ItemInstance = character.inventory.items().filter(func(i: ItemInstance) -> bool: return i.definition_id == &"forged_blade")[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var steps: Array = [[CraftingOps.IMPRINT, &"material_id", &"storm_ore"], [CraftingOps.AUGMENT, &"", null], [CraftingOps.AUGMENT, &"", null],
		[CraftingOps.ESSENCE_INSERT, &"essence_id", &"storm_wolf"], [CraftingOps.ESSENCE_INSERT, &"essence_id", &"stone_golem"],
		[CraftingOps.SOCKET_OPEN, &"", null], [CraftingOps.SOCKET_INSERT, &"socketable_id", &"garnet"], [CraftingOps.QUALITY, &"", null]]
	for step: Array in steps:
		var request := CraftingRequest.make(step[0], blade)
		if step[1] != &"":
			request.set(step[1], step[2])
		if step[0] == CraftingOps.SOCKET_INSERT:
			request.slot_index = 0
		var result := CraftingService.execute(character, request, rng)
		_log("forge example %s: %s" % [step[0], result.message if result.ok else result.error])


# --- helpers used by GalleryScreens ------------------------------------------------

func frames(count: int) -> void:
	await _frames(count)


func _await_map() -> void:
	for i in 300:
		await process_frame
		var current := current_scene as GameMap
		if current != null and current.is_node_ready() and not session.is_traveling():
			map = current
			await _frames(10)
			return
	_check(false, "map loaded")


func _check_layout(label: String) -> void:
	var controls: Array[Node] = map.hud.find_children("*", "Control", true, false)
	_check_list(controls, label)
	# HUD elements never cover each other
	var hud := map.hud
	var parts: Array[Control] = [hud.player_frame, hud.skill_bar, hud.objectives, hud.target_frame, hud.loot_feed, hud.save_indicator]
	var overlaps: PackedStringArray = []
	for a in parts.size():
		for b in range(a + 1, parts.size()):
			if parts[a].is_visible_in_tree() and parts[b].is_visible_in_tree() \
					and parts[a].get_global_rect().grow(-1.0).intersects(parts[b].get_global_rect().grow(-1.0)):
				overlaps.append("%s %s x %s %s" % [parts[a].name, parts[a].get_global_rect(), parts[b].name, parts[b].get_global_rect()])
	_check(overlaps.is_empty(), "%s %s HUD without overlaps (%s)" % [tag, label, "; ".join(overlaps)])


func _check_controls(node: Node, label: String) -> void:
	_check_list(node.find_children("*", "Control", true, false), label)


func _check_list(controls: Array[Node], label: String) -> void:
	var view := root.get_visible_rect()
	var problems: PackedStringArray = []
	for node in controls:
		var control := node as Control
		if not control.is_visible_in_tree() or _inside_scroll(control):
			continue
		var rect := control.get_global_rect()
		if not view.grow(1.0).encloses(rect):
			problems.append("%s off screen %s" % [control.name, rect])
		if control is UiWindow and not view.grow(-UiTheme.SCREEN_MARGIN + 1.0).encloses(rect):
			problems.append("%s inside margin %s" % [control.name, rect])
		var minimum := control.get_combined_minimum_size()
		if control.size.x + 0.5 < minimum.x or control.size.y + 0.5 < minimum.y:
			problems.append("%s squeezed %s < %s" % [control.name, control.size, minimum])
	_check(problems.is_empty(), "%s %s layout (%s)" % [tag, label, "; ".join(problems.slice(0, 4))])


func _inside_scroll(control: Control) -> bool:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s_%s.png" % [tag, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	_log("%s %s" % ["CHECK OK  " if ok else "CHECK FAIL", text])


func _log(text: String) -> void:
	print(text)
	log_lines.append(text)


func _arg(key: String, default: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return default
