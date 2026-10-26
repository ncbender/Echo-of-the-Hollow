extends GameplayTestCase
## Player hit reactions: FLINCH / INTERRUPT / KNOCKBACK / STUN, iFrames, resistance, hyper armor.

const GRUNT_SCENE: PackedScene = preload("res://scenes/enemies/grunt.tscn")


## knockback is a distance in px (KnockbackMotion); -3 px matches the old -60 speed value.
func _hit(type: HitReaction.Type, damage: float = 1.0, knockback: Vector2 = Vector2(-3, 0)) -> HitData:
	var hit := HitData.new()
	hit.damage = damage
	hit.knockback = knockback
	hit.reaction = type
	return hit


func _start_light() -> InputFrame:
	var f := frame(Vector2.ZERO, Vector2.RIGHT)
	await tick(light(f))
	return f


func test_flinch_does_not_interrupt() -> void:
	spawn_player()
	await _start_light()
	player.hurtbox.receive_hit(_hit(HitReaction.Type.FLINCH))
	check_eq(player.combat.state, CombatComponent.State.ATTACKING, "light attack continues")
	check_eq(player.reaction.current, HitReaction.Type.FLINCH, "flinch registered")
	check(not player.reaction.blocks_actions(), "flinch blocks nothing")


func test_interrupt_cancels_and_locks_attacks_briefly() -> void:
	spawn_player()
	var cancelled: Array[StringName] = []
	player.combat.attack_cancelled.connect(func(_a: AttackDefinition, reason: StringName) -> void: cancelled.append(reason))
	await _start_light()
	player.hurtbox.receive_hit(_hit(HitReaction.Type.INTERRUPT))
	check_eq(player.combat.state, CombatComponent.State.IDLE, "attack interrupted")
	check_eq(cancelled, [&"hit_reaction"] as Array[StringName], "cancel reason")
	var f := frame(Vector2.RIGHT, Vector2.RIGHT)
	await tick(light(f))
	check_eq(player.combat.state, CombatComponent.State.IDLE, "no attack during lockout")
	await tick(f, 5)
	check(player.velocity.x > 100.0, "movement allowed during interrupt lockout")
	await tick(f, seconds_to_ticks(player.reaction.config.interrupt_lockout))
	await tick(light(f))
	check_eq(player.combat.state, CombatComponent.State.ATTACKING, "attacks possible again")


func test_knockback_blocks_movement_and_pushes_harder() -> void:
	spawn_player()
	await wait_physics(1)
	player.hurtbox.receive_hit(_hit(HitReaction.Type.FLINCH))
	await tick(frame(), 30)
	var flinch_push := absf(player.global_position.x)
	player.global_position = Vector2.ZERO
	player.hurtbox.receive_hit(_hit(HitReaction.Type.KNOCKBACK))
	check(player.reaction.blocks_movement(), "knockback locks movement")
	await tick(frame(Vector2.RIGHT), 15)   # pressing against the push has no effect while locked
	await tick(frame(), 15)
	check(absf(player.global_position.x) > flinch_push, "knockback pushes further than flinch (%.1f vs %.1f)" % [absf(player.global_position.x), flinch_push])
	check(not player.reaction.is_reacting(), "knockback reaction ended")


func test_knockback_stops_dash_after_iframes() -> void:
	spawn_player()
	await wait_physics(1)
	await tick(dash_press(frame(Vector2.RIGHT)))
	await tick(frame(Vector2.RIGHT), 12)   # past the 180 ms iFrames
	check(player.dash.is_dashing(), "still dashing")
	player.hurtbox.receive_hit(_hit(HitReaction.Type.KNOCKBACK))
	check(not player.dash.is_dashing(), "knockback ended the dash")


func test_stun_blocks_everything_then_recovers() -> void:
	spawn_player()
	await wait_physics(1)
	player.hurtbox.receive_hit(_hit(HitReaction.Type.STUN, 1.0, Vector2.ZERO))
	var f := frame(Vector2.RIGHT)
	await tick(light(f))
	await tick(dash_press(f))
	check_eq(player.combat.state, CombatComponent.State.IDLE, "no attack while stunned")
	check(not player.dash.is_dashing(), "no dash while stunned")
	check(player.velocity.length() < 1.0, "no movement while stunned")
	await tick(f, seconds_to_ticks(player.reaction.config.stun_duration))
	check(not player.reaction.is_reacting(), "stun over")
	await tick(f, 5)
	check(player.velocity.x > 100.0, "moves again after stun")


func test_dash_iframes_prevent_reaction() -> void:
	spawn_player()
	await wait_physics(1)
	await tick(dash_press(frame(Vector2.RIGHT)))
	check(not player.hurtbox.receive_hit(_hit(HitReaction.Type.STUN)), "hit rejected during iFrames")
	check_eq(player.reaction.current, HitReaction.Type.NONE, "no reaction during iFrames")
	check(player.dash.is_dashing(), "dash continues")


func test_resistance_reduces_reactions() -> void:
	spawn_player()
	player.reaction.bonus_resistance = HitReaction.Type.INTERRUPT
	await _start_light()
	player.hurtbox.receive_hit(_hit(HitReaction.Type.INTERRUPT))
	check_eq(player.combat.state, CombatComponent.State.ATTACKING, "resisted interrupt")
	check_eq(player.reaction.current, HitReaction.Type.FLINCH, "reduced to flinch")
	player.hurtbox.receive_hit(_hit(HitReaction.Type.KNOCKBACK))
	check_eq(player.combat.state, CombatComponent.State.IDLE, "stronger reaction still interrupts")


func test_hyper_armor_phase_prevents_interrupt() -> void:
	var combat := new_combat()
	var armored: AttackDefinition = SWORD.get_attack(&"sword_light_1").duplicate()
	armored.uninterruptible_phases = AttackDefinition.CANCEL_STARTUP
	combat._start_attack(armored, Vector2.RIGHT, 0)
	var component := HitReactionComponent.new()
	add_child(component)
	check_eq(component.apply(_hit(HitReaction.Type.INTERRUPT), combat, null), HitReaction.Type.FLINCH, "armored startup -> flinch")
	check_eq(combat.state, CombatComponent.State.ATTACKING, "attack keeps running")


func test_weaker_reaction_does_not_replace_stronger() -> void:
	var component := HitReactionComponent.new()
	add_child(component)
	component.apply(_hit(HitReaction.Type.STUN), null, null)
	component.apply(_hit(HitReaction.Type.FLINCH), null, null)
	check_eq(component.current, HitReaction.Type.STUN, "stun kept")
	check_near(component.time_left, component.config.stun_duration, 0.001, "stun duration kept")


func test_grunt_third_attack_is_knockback_slam() -> void:
	spawn_player()
	var enemy: Enemy = GRUNT_SCENE.instantiate()
	enemy.position = Vector2(26, 0)
	enemy.target = player
	add_child(enemy)
	var started: Array[StringName] = []
	enemy.combat.attack_started.connect(func(a: AttackDefinition, _t: int) -> void: started.append(a.id))
	var reactions: Array[HitReaction.Type] = []
	player.reaction.reaction_started.connect(func(t: HitReaction.Type, _d: float) -> void: reactions.append(t))
	player.health.max_health = 1000.0
	player.health.reset()
	var guard := 0
	while started.size() < 3 and guard < 600:
		guard += 1
		await tick(frame())
	await tick(frame(), 60)
	check_eq(started, [&"grunt_swipe", &"grunt_swipe", &"grunt_slam"] as Array[StringName], "swipe, swipe, slam")
	check(HitReaction.Type.FLINCH in reactions, "swipe flinches")
	check(HitReaction.Type.KNOCKBACK in reactions, "slam knocks back")
