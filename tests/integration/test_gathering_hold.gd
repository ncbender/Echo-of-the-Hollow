extends GameplayTestCase
## Gathering 1.1 control on the real player: G held = consecutive steps on the
## same target; release, movement, dash, attack, skill, HP damage, stun,
## knockback, death, a blocking menu and leaving the range interrupt at once
## (the partial step gives nothing, completed steps stay); a fully blocked hit
## without HP damage does not; exhaustion ends the action and a held G never
## starts the next one (a new press is needed).


class FakeTarget:
	extends RefCounted
	var seconds := 0.75
	var steps := 3
	var done := 0
	var inside := true

	func step_seconds() -> float:
		return seconds

	func in_range(_player: Node) -> bool:
		return inside

	func complete_step() -> Dictionary:
		done += 1
		return {"error": "", "exhausted": done >= steps}


var stops: Array[StringName] = []


func before_each() -> void:
	super.before_each()
	stops.clear()


func _spawn() -> FakeTarget:
	spawn_player()
	player.gather_stopped.connect(func(reason: StringName) -> void: stops.append(reason))
	var target := FakeTarget.new()
	check(player.begin_gather(target), "gathering starts")
	return target


func held() -> InputFrame:
	var f := frame()
	f.interact_held = true
	return f


func test_held_g_works_step_by_step_until_exhausted() -> void:
	var target := _spawn()
	await tick(held(), seconds_to_ticks(0.75) - 1)
	check_eq(target.done, 0, "no step before 0.75 s")
	await tick(held())
	check_eq(target.done, 1, "first step after 0.75 s")
	await tick(held(), seconds_to_ticks(1.5))
	check_eq(target.done, 3, "three consecutive steps while G is held")
	check_eq(stops, [Player.GATHER_EXHAUSTED] as Array[StringName], "exhaustion ends the action")
	await tick(held(), 120)
	check_eq(target.done, 3, "a held G never continues on (or moves to) another resource")
	check(not player.is_gathering(), "idle")


func test_release_interrupts_and_a_new_press_resumes() -> void:
	var target := _spawn()
	await tick(held(), seconds_to_ticks(0.75) + seconds_to_ticks(0.5))
	check_eq(target.done, 1, "one step done")
	await tick(frame())
	check_eq(stops, [Player.GATHER_RELEASED] as Array[StringName], "release interrupts at once")
	await tick(held(), 60)
	check_eq(target.done, 1, "holding again without a new press does nothing; the partial step gave nothing")
	check(player.begin_gather(target), "a new press starts again")
	await tick(held(), seconds_to_ticks(0.75) - 1)
	check_eq(target.done, 1, "the step restarts from zero (no carried partial time)")
	await tick(held())
	check_eq(target.done, 2, "completed steps stay: the next one is step 2")


func test_every_interruption() -> void:
	var cases := {
		Player.GATHER_MOVED: func(f: InputFrame) -> void: f.move = Vector2.RIGHT,
		Player.GATHER_DASH: func(f: InputFrame) -> void: f.dash_pressed = true,
		Player.GATHER_ATTACK: func(f: InputFrame) -> void: f.light_pressed = true,
		Player.GATHER_SKILL: func(f: InputFrame) -> void: f.ability_slot = 0,
	}
	for reason: StringName in cases:
		stops.clear()
		var target := _spawn()
		await tick(held(), 20)
		var f := held()
		(cases[reason] as Callable).call(f)
		await tick(f)
		check_eq(stops, [reason] as Array[StringName], "%s interrupts" % reason)
		await tick(held(), 60)
		check_eq(target.done, 0, "%s: the partial step gave nothing" % reason)
		player.queue_free()
		await get_tree().physics_frame
	# range, menu, damage, stun, knockback, death
	stops.clear()
	var target := _spawn()
	await tick(held(), 10)
	target.inside = false
	await tick(held())
	check_eq(stops.back(), Player.GATHER_RANGE, "leaving the range interrupts")
	player.begin_gather(target)
	target.inside = true
	player.input_blocker = func() -> bool: return true
	player.apply_input_block(held())
	check_eq(stops.back(), Player.GATHER_MENU, "a blocking menu interrupts")
	player.input_blocker = Callable()
	player.apply_input_block(held())
	for entry: Array in [[1.0, Vector2.ZERO, HitReaction.Type.NONE, Player.GATHER_DAMAGE],
			[0.0, Vector2.ZERO, HitReaction.Type.STUN, Player.GATHER_STUN],
			[0.0, Vector2(20, 0), HitReaction.Type.NONE, Player.GATHER_KNOCKBACK]]:
		check(player.begin_gather(target) or player.is_gathering(), "gathering again")
		await tick(held(), 2)
		var hit := HitData.new()
		hit.damage = entry[0]
		hit.knockback = entry[1]
		hit.reaction = entry[2]
		player.hurtbox.receive_hit(hit)
		check_eq(stops.back(), entry[3], "%s interrupts" % entry[3])
		await tick(frame(), 90)   # reactions and knockback fade
		player.reaction.step(10.0)
	player.begin_gather(target)
	player.health.apply_hit(_lethal())
	check_eq(stops.back(), Player.GATHER_DEATH, "death interrupts")
	check_eq(target.done, 0, "no step from any interrupted attempt")


func _lethal() -> HitData:
	var hit := HitData.new()
	hit.damage = 100000.0
	return hit


func test_fully_blocked_hit_does_not_interrupt() -> void:
	var target := _spawn()
	await tick(held(), 10)
	var hit := HitData.new()
	hit.damage = 0.0   # e.g. parried: no HP damage, no knockback, no reaction
	player.hurtbox.receive_hit(hit)
	check(player.is_gathering(), "no HP damage: gathering goes on")
	await tick(held(), seconds_to_ticks(0.75))
	check_eq(target.done, 1, "and the step completes")


func test_only_from_neutral() -> void:
	spawn_player()
	var target := FakeTarget.new()
	await tick(light(frame()))
	check(not player.begin_gather(target), "not during an attack")
	await tick(frame(), 60)
	await tick(dash_press(frame()))
	check(not player.begin_gather(target), "not during a dash")
	await tick(frame(), 30)
	check(player.begin_gather(target), "from neutral")
	check(not player.begin_gather(FakeTarget.new()), "never two at once")



## A real ResourceNode with the session character: hold G through all steps,
## interrupt midway, resume with a new press; materials and XP arrive per step.
func test_real_node_with_held_g() -> void:
	var session := SessionState.find(get_tree())
	var previous := session.character
	var character := CharacterFactory.create_new(GameDatabase.get_default())
	session.set_character(character)
	var definition: ResourceNodeDefinition = GameDatabase.get_default().resource_nodes[&"oak_tree"]
	var node := ResourceNode.new()
	node.definition = definition
	node.node_id = &"test_oak"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	node.add_child(shape)
	add_child(node)
	spawn_player()
	player.gather_stopped.connect(func(reason: StringName) -> void: stops.append(reason))
	await wait_physics(3)
	check(node.player_inside, "player stands at the tree")
	var start_timber := character.inventory.count(&"timber")
	node.interact(null)
	check(player.is_gathering(), "G press starts woodcutting")
	var step_ticks := seconds_to_ticks(0.75)
	await tick(held(), step_ticks)
	check_eq(ResourceGathering.steps_done(character.world, &"", &"test_oak"), 1, "one chop done")
	check(character.inventory.count(&"timber") >= start_timber + 1, "the first chop already gives timber")
	await tick(held(), 20)
	await tick(frame())   # released mid-chop
	check_eq(stops.back(), Player.GATHER_RELEASED, "released")
	check_eq(ResourceGathering.steps_done(character.world, &"", &"test_oak"), 1, "the half chop gave nothing")
	node.interact(null)
	await tick(held(), step_ticks * definition.steps)
	check_eq(stops.back(), Player.GATHER_EXHAUSTED, "the tree is felled")
	check_eq(character.inventory.count(&"timber") - start_timber, definition.yield_quantity, "all timber of the budget, once")
	check(not node.is_available(), "exhausted")
	node.interact(null)
	check(not player.is_gathering(), "an exhausted node does not start again")
	node.queue_free()
	session.set_character(previous)



## Final integration: keys 1 / 2 interrupt gathering and the drink then starts
## under its own rules; Shift interrupts and the defense reacts normally;
## gathering never runs together with a drink or a block / parry.
func test_drink_keys_interrupt_and_the_drink_starts() -> void:
	for key in [0, 1]:
		stops.clear()
		var target := _spawn()
		var asked: Array[int] = []
		player.consumable_handler = func(kind: int) -> bool:
			asked.append(kind)
			player.begin_use(1.1, 0.45, Callable())   # stands in for the bridge (the real rules are not touched)
			return true
		await tick(held(), 20)
		var press := held()
		if key == 0:
			press.flask_pressed = true
		else:
			press.potion_pressed = true
		await tick(press)
		check_eq(stops, [Player.GATHER_DRINK] as Array[StringName], "key %d interrupts gathering" % (key + 1))
		check_eq(asked, [key] as Array[int], "key %d: the drink is asked for in the same tick" % (key + 1))
		check(player.is_using() and not player.is_gathering(), "drinking, not gathering")
		check(not player.begin_gather(target), "no gathering while drinking")
		check_eq(target.done, 0, "the partial step gave nothing")
		player.queue_free()
		await get_tree().physics_frame


func test_shift_interrupts_and_the_defense_reacts() -> void:
	var target := _spawn()
	await tick(held(), 20)
	var shift := held()
	shift.defend_pressed = true
	shift.defend_held = true
	await tick(shift)
	check_eq(stops, [Player.GATHER_DEFEND] as Array[StringName], "Shift interrupts gathering")
	check(player.defense.is_defending(), "the parry window opened in the same tick")
	check(not player.begin_gather(target), "no gathering while blocking or parrying")
	var guard := held()
	guard.defend_held = true
	await tick(guard, 30)
	check(not player.is_gathering() and target.done == 0, "holding G and Shift never gathers")


## Holding G must not repeat single interactions: a held key only sends echo
## events, and the map reacts to non-echo presses only (GameMap._unhandled_input).
func test_held_g_sends_no_repeated_interaction() -> void:
	GameHud.ensure_input_actions()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_G
	press.pressed = true
	check(press.is_action_pressed(&"interact"), "the first G press is an interaction")
	var echo := press.duplicate() as InputEventKey
	echo.echo = true
	check(not echo.is_action_pressed(&"interact"), "auto-repeat while G is held is no new interaction")
