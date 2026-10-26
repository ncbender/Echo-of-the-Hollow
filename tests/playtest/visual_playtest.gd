extends SceneTree
## Scripted visual playtest in the real arena (NOT headless).
## Plays a fixed input sequence through Player.feed_input(), saves screenshots and
## an event log to tests/output/. Run:
##   godot --path . --fixed-fps 60 -s res://tests/playtest/visual_playtest.gd [-- --weapon=1 --enemy]

const ARENA := "res://scenes/arena/test_arena.tscn"
const OUTPUT := "res://tests/output"

var arena: Node2D
var player: Player
var f := InputFrame.new()
var log_lines: PackedStringArray = []
var shot_index: int = 0
var prefix: String = "sword"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	arena = load(ARENA).instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.get_node("Player")
	player.feed_input(f)
	_connect_logging()
	await _ticks(10)

	var weapon_slot := _arg_int("--weapon", 0)
	if weapon_slot > 0:
		f.weapon_slot = weapon_slot
		await _ticks(2)
		prefix = String(player.combat.weapon.id)
	if "--polish" in OS.get_cmdline_user_args():
		await _polish_sequence()
	elif "--enemy" in OS.get_cmdline_user_args():
		await _enemy_sequence()
	else:
		await _combat_sequence()

	_log("final: player=%s state=%d" % [player.global_position, player.combat.state])
	for dummy in arena.get_node("Dummies").get_children():
		_log("final: %s hp=%.0f/%.0f hits=%d" % [dummy.name, dummy.health.health, dummy.health.max_health, dummy.hits_taken])
	var file := FileAccess.open(OUTPUT.path_join("%s_playtest_log.txt" % prefix), FileAccess.WRITE)
	file.store_string("\n".join(log_lines))
	file.close()
	quit(0)


func _combat_sequence() -> void:
	var dummy_a: Node2D = arena.get_node("Dummies/DummyA")
	# 1) Walk diagonally towards dummy A while aiming at it.
	f.move = Vector2(1, -0.2).normalized()
	await _ticks_aim(dummy_a, 12)
	f.move = Vector2.ZERO
	await _ticks_aim(dummy_a, 4)
	await _shot("01_idle_aim")

	# 2) L-L-L
	for i in 3:
		f.light_pressed = true
		await _until_phase(CombatComponent.Phase.ACTIVE, dummy_a)
		await _ticks_aim(dummy_a, 2)
		await _shot("02_light_%d_active" % (i + 1))
		await _until_phase(CombatComponent.Phase.RECOVERY, dummy_a)
		await _ticks_aim(dummy_a, 6 if i < 2 else 30)

	# 3) L then fully charged H (L-H thrust)
	f.light_pressed = true
	await _until_phase(CombatComponent.Phase.RECOVERY, dummy_a)
	f.heavy_pressed = true
	f.heavy_held = true
	await _ticks_aim(dummy_a, 20)
	await _shot("03_charging_empowered")
	await _ticks_aim(dummy_a, 26)
	await _shot("04_charging_full")
	f.heavy_held = false
	f.heavy_released = true
	await _until_phase(CombatComponent.Phase.ACTIVE, dummy_a)
	await _ticks_aim(dummy_a, 2)
	await _shot("05_lh_thrust_active")
	await _until_idle(dummy_a)

	# 4) Dash away: the dash follows the facing (mouse), WASD is ignored (Combat Polish 0.2).
	f.aim_direction = (player.global_position - dummy_a.global_position).normalized()
	f.move = Vector2.DOWN
	f.dash_pressed = true
	await _ticks(4)
	f.move = Vector2.ZERO
	await _shot("06_dash_iframes")
	await _ticks_aim(dummy_a, 40)

	# 5) Walk back and do L-L-H (crush) for a poise break
	f.move = (dummy_a.global_position - player.global_position).normalized()
	while player.global_position.distance_to(dummy_a.global_position) > 26.0:
		await _ticks_aim(dummy_a, 1)
	f.move = Vector2.ZERO
	for i in 2:
		f.light_pressed = true
		await _until_phase(CombatComponent.Phase.RECOVERY, dummy_a)
		await _ticks_aim(dummy_a, 2)
	f.heavy_pressed = true
	f.heavy_held = true
	await _ticks_aim(dummy_a, 2)
	f.heavy_held = false
	f.heavy_released = true
	await _until_phase(CombatComponent.Phase.ACTIVE, dummy_a)
	await _ticks_aim(dummy_a, 3)
	await _shot("07_llh_crush_active")
	await _ticks_aim(dummy_a, 12)
	await _shot("08_after_crush")
	await _until_idle(dummy_a)


func _enemy_sequence() -> void:
	arena.call(&"spawn_enemy", player.global_position + Vector2(90, 0))
	await _ticks(1)
	var enemy: Node2D = arena.get_node("Enemies").get_child(0)
	await _ticks_aim(enemy, 30)
	await _shot("e01_enemy_approach")
	var telegraph_seen := false
	for i in 120:
		if enemy.get(&"state") == 1 and not telegraph_seen:   # TELEGRAPH
			telegraph_seen = true
			await _shot("e02_enemy_telegraph")
			f.dash_pressed = true
			f.move = Vector2.RIGHT   # ignored: the dash follows the aim
			f.aim_direction = Vector2.LEFT
			await _ticks(2)   # resume happens before the player tick: keep LEFT for one full tick
		await _ticks_aim(enemy, 1)
		f.move = Vector2.ZERO
	await _shot("e03_after_dodge")
	# Fight back until the enemy dies.
	var guard := 0
	while is_instance_valid(enemy) and not enemy.get(&"health").is_dead() and guard < 1200:
		guard += 1
		var to_enemy := enemy.global_position - player.global_position
		f.move = to_enemy.normalized() if to_enemy.length() > 24.0 else Vector2.ZERO
		if player.combat.state == CombatComponent.State.IDLE and to_enemy.length() < 34.0:
			f.light_pressed = true
		await _ticks_aim(enemy, 1)
	f.move = Vector2.ZERO
	await _ticks(4)
	await _shot("e04_enemy_defeated")
	_log("enemy defeated: %s after %d ticks" % [not is_instance_valid(enemy) or enemy.get(&"health").is_dead(), guard])


## Combat Polish 0.2: lunge/knockback vectors (F1 debug on), weapon knockback
## profiles against a standard grunt, dash towards the mouse, then a real fight.
func _polish_sequence() -> void:
	prefix = "polish"
	DebugView.show_hitboxes = true
	var enemy: Enemy = arena.call(&"spawn_enemy", player.global_position + Vector2(40, 0))
	var active_config := enemy.config
	var normal_health := enemy.health.max_health
	enemy.health.set_max_health(5000.0)   # survives the measuring phase
	enemy.config = enemy.config.duplicate()
	enemy.config.attack_range = 0.0
	enemy.config.move_speed = 0.0
	await _ticks_aim(enemy, 10)
	# 1) sword L1: lunge vector (green) during startup, knockback vector (red) after the hit
	f.light_pressed = true
	await _ticks_aim(enemy, 3)
	await _shot("p01_sword_l1_lunge")
	await _until_phase(CombatComponent.Phase.ACTIVE, enemy)
	await _ticks_aim(enemy, 3)
	await _shot("p02_sword_l1_knockback")
	await _until_idle(enemy)
	await _ticks_aim(enemy, 30)
	_log_knockback(enemy, "sword light")
	# 2) sword L-L-L without walking
	for i in 3:
		f.light_pressed = true
		await _until_phase(CombatComponent.Phase.RECOVERY, enemy)
		await _ticks_aim(enemy, 2)
	await _until_idle(enemy)
	await _ticks_aim(enemy, 30)
	_log_knockback(enemy, "sword L3")
	# 3) sword heavy tap
	await _walk_to(enemy, 26.0)
	f.heavy_pressed = true
	await _until_phase(CombatComponent.Phase.ACTIVE, enemy)
	await _ticks_aim(enemy, 4)
	await _shot("p03_sword_heavy_knockback")
	await _until_idle(enemy)
	await _ticks_aim(enemy, 30)
	_log_knockback(enemy, "sword heavy")
	# 4) greatsword light and heavy
	f.weapon_slot = 1
	await _ticks(2)
	await _walk_to(enemy, 34.0)
	f.light_pressed = true
	await _until_idle(enemy)
	await _ticks_aim(enemy, 30)
	_log_knockback(enemy, "greatsword light")
	await _walk_to(enemy, 34.0)
	f.heavy_pressed = true
	await _until_phase(CombatComponent.Phase.ACTIVE, enemy)
	await _ticks_aim(enemy, 4)
	await _shot("p04_greatsword_heavy_knockback")
	await _until_idle(enemy)
	await _ticks_aim(enemy, 30)
	_log_knockback(enemy, "greatsword heavy")
	# 5) dash: WASD left, mouse right -> dash right
	f.move = Vector2.LEFT
	f.aim_direction = Vector2.RIGHT
	f.dash_pressed = true
	await _ticks(4)
	await _shot("p05_dash_wasd_left_mouse_right")
	f.move = Vector2.ZERO
	await _ticks(30)
	# 6) normal fight against the active grunt with the greatsword, then the sword
	enemy.config = active_config
	enemy.health.set_max_health(normal_health)
	f.weapon_slot = 0
	var guard := 0
	while is_instance_valid(enemy) and not enemy.health.is_dead() and guard < 1500:
		guard += 1
		var to_enemy := enemy.global_position - player.global_position
		f.move = to_enemy.normalized() if to_enemy.length() > 24.0 else Vector2.ZERO
		if player.combat.state != CombatComponent.State.CHARGING and to_enemy.length() < 34.0:
			f.light_pressed = true
		player.health.heal(1000.0)
		if guard == 120:
			await _shot("p06_fight")
		await _ticks_aim(enemy, 1)
	f.move = Vector2.ZERO
	_log("polish fight: enemy defeated=%s after %d ticks" % [not is_instance_valid(enemy) or enemy.health.is_dead(), guard])


func _walk_to(target: Node2D, distance: float) -> void:
	for i in 120:
		var to := target.global_position - player.global_position
		if to.length() <= distance:
			break
		f.move = to.normalized()
		await _ticks_aim(target, 1)
	f.move = Vector2.ZERO
	await _ticks_aim(target, 2)


func _log_knockback(enemy: Enemy, label: String) -> void:
	var motion := enemy.knockback
	_log("knockback %s: dealt %.2f px (res %.2f) moved %.2f px" % [label, motion.last_offset.length(), enemy.config.knockback_resistance, motion.last_traveled])


func _connect_logging() -> void:
	var combat := player.combat
	combat.attack_started.connect(func(attack: AttackDefinition, tier: int) -> void:
		_log("attack_started %s tier=%d path=%s" % [attack.id, tier, combat.combo.path]))
	combat.attack_cancelled.connect(func(attack: AttackDefinition, reason: StringName) -> void:
		_log("attack_cancelled %s by %s" % [attack.id, reason]))
	combat.hit_landed.connect(func(hit: HitData) -> void:
		_log("hit %s -> %s dmg=%.1f poise=%.1f tier=%d hitstop=%.3f" % [hit.attack.id, hit.target.name, hit.damage, hit.poise_damage, hit.charge_tier, hit.hitstop]))
	combat.charge_tier_changed.connect(func(tier: int) -> void: _log("charge tier -> %d" % tier))
	player.dash.dash_started.connect(func(direction: Vector2) -> void:
		_log("dash %s charges=%d (aim %s, move %s)" % [direction, player.dash.charges, f.aim_direction, f.move]))
	for dummy in arena.get_node("Dummies").get_children():
		dummy.health.poise_broken.connect(func() -> void: _log("POISE BREAK %s" % dummy.name))


## Edge flags are cleared by Player after it consumed them; never clear them here,
## the coroutine resumes *before* the player processes the tick.
func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _ticks_aim(target: Node2D, count: int) -> void:
	for i in count:
		if is_instance_valid(target):
			f.aim_direction = (target.global_position - player.global_position).normalized()
		await physics_frame


func _until_phase(phase: CombatComponent.Phase, target: Node2D, limit: int = 90) -> void:
	for i in limit:
		await _ticks_aim(target, 1)
		if player.combat.state == CombatComponent.State.ATTACKING and player.combat.phase == phase:
			return
	_log("WARNING: phase %d not reached" % phase)


func _until_idle(target: Node2D, limit: int = 120) -> void:
	for i in limit:
		await _ticks_aim(target, 1)
		if player.combat.state == CombatComponent.State.IDLE:
			return


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	shot_index += 1
	var path := OUTPUT.path_join("%s_%s.png" % [prefix, label])
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_log("screenshot %s" % path.get_file())


func _log(text: String) -> void:
	var line := "[%5d] %s" % [Engine.get_physics_frames(), text]
	log_lines.append(line)
	print(line)


func _arg_int(name: String, fallback: int) -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.get_slice("=", 1).to_int()
	return fallback
