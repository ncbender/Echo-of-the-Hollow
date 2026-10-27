extends SceneTree
## Gathering 1.1 visual check in an isolated scene (no map, no story): one node
## per gathering profession in three states (untouched, partly worked,
## exhausted) and the player mid-swing with the placeholder tool. Window run:
##   godot --path . --fixed-fps 60 -s res://tests/playtest/gathering_visual_check.gd
## Screenshots: tests/output/gathering/. Uses a fresh test character, never saves.

const OUTPUT := "res://tests/output/gathering"
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const NODES := [&"oak_tree", &"iron_vein", &"forest_rock", &"wild_flax", &"elk_remains"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var session := SessionState.find(self)
	var db := GameDatabase.get_default()
	var character := CharacterFactory.create_new(db)
	for profession_id: StringName in [&"woodcutting", &"mining", &"herbalism", &"skinning"]:
		while character.professions.level(profession_id) < 3:
			character.professions.add_xp(profession_id, 50)
	session.set_character(character)
	var stage := Node2D.new()
	root.add_child(stage)
	current_scene = stage
	var camera := Camera2D.new()
	camera.zoom = Vector2(4, 4)
	camera.position = Vector2(100, 40)
	stage.add_child(camera)
	var row := 0
	for node_id: StringName in NODES:
		for state in 3:   # 0 untouched, 1 partly worked, 2 exhausted
			var definition: ResourceNodeDefinition = db.resource_nodes[node_id]
			var node := ResourceNode.new()
			node.definition = definition
			node.node_id = StringName("%s_%d" % [node_id, state])
			node.position = Vector2(40 + state * 60, -10 + row * 26)
			stage.add_child(node)
			var steps := 0 if state == 0 else (maxi(1, definition.steps - 1) if state == 1 else definition.steps)
			if state == 1 and definition.steps == 1:
				steps = 0
			for i in steps:
				ResourceGathering.complete_step(character, &"", node.node_id, definition, Time.get_unix_time_from_system())
		row += 1
	var tree := ResourceNode.new()
	tree.definition = db.resource_nodes[&"oak_tree"]
	tree.node_id = &"swing_tree"
	tree.position = Vector2(-8, -14)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	tree.add_child(shape)   # gathering range
	stage.add_child(tree)
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector2(-22, -4)   # in front of the tree, drawn on top
	stage.add_child(player)
	player.use_external_input = true
	await physics_frame
	await physics_frame
	var f := InputFrame.new()
	f.interact_held = true
	player.feed_input(f)
	print("gathering started: %s" % player.begin_gather(tree))
	for i in 20:   # mid-swing (raise phase)
		await physics_frame
	await _shot("01_states_and_axe_raised")
	for i in 22:
		await physics_frame
	await _shot("02_axe_strike")
	print("still gathering: %s, steps done %d" % [player.is_gathering(), ResourceGathering.steps_done(character.world, &"", &"swing_tree")])
	for i in 400:   # chop on until the tree falls
		await physics_frame
		if not player.is_gathering():
			break
	for i in 15:   # mid-fall
		await physics_frame
	await _shot("03_tree_falling")
	for i in 40:
		await physics_frame
	await _shot("04_stump")
	quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := OUTPUT.path_join("%s.png" % label)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("screenshot %s" % path.get_file())
