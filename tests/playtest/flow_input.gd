class_name PlaytestFlowInput
extends RefCounted
## Combat Flow 1.5 input for scripted playtests that feed one shared InputFrame:
## presses a path ("LLH"; bows "LP") on `player`, each input as soon as the
## running step accepts it, then waits until the chain is over.


static func press_path(tree: SceneTree, player: Player, f: InputFrame, path: String) -> void:
	for index in path.length():
		var guard := 0
		while index > 0 and (player.combat.chain.length() != index or player.combat.attack_clock() < player.combat.accept_from()) and guard < 120:
			if not player.combat.is_busy():
				break
			await tree.physics_frame
			guard += 1
		match path[index]:
			"L":
				f.light_pressed = true
			"H":
				f.heavy_pressed = true
			"P":
				f.light_pressed = true
				f.heavy_held = true
		for i in 2:   # held through the tick that consumes the press
			await tree.physics_frame
		f.heavy_held = false
	var wait := 0
	while player.combat.is_busy() and wait < 240:
		await tree.physics_frame
		wait += 1
