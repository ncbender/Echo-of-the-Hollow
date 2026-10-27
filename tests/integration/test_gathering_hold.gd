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
	var drink := held()
	drink.flask_pressed = true
	await tick(drink)
	check(not player.is_using(), "no drink while gathering")
