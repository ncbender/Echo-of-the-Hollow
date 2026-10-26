extends Node2D
## Placeholder visuals for the melee enemy, including the attack telegraph.

const COLOR_BODY := Color("b5524a")
const COLOR_TELEGRAPH := Color(1.0, 0.45, 0.2)
const COLOR_TELEGRAPH_HEAVY := Color(1.0, 0.15, 0.15)
const COLOR_STAGGER := Color("9fc8ff")
## Unblockable attacks (AttackDefinition.defense_flags = 0): own colour PLUS shape
## cues (zigzag outline, "!!" marker) so they never rely on colour alone.
const COLOR_UNBLOCKABLE := Color(0.95, 0.35, 1.0)

@onready var enemy: Enemy = get_parent()
@onready var fx: HitReactionFx = $"../HitReactionFx"
var _warned_attack: int = -1


func _ready() -> void:
	# Poise break: impact + word, clearly stronger than a normal hit flash.
	($"../HealthComponent" as HealthComponent).poise_broken.connect(_on_poise_broken)   # parent not ready yet
	enemy.parried.connect(_on_parried)


func _on_poise_broken() -> void:
	CombatAudio.play(enemy, &"poise_break")
	var world := CombatFx.world_of(enemy)
	CombatFx.spawn(world, enemy.global_position + Vector2(0, -4), CombatFx.Style.STAR, COLOR_STAGGER, 20.0, 0.4)
	CombatFx.spawn(world, enemy.global_position, CombatFx.Style.RING, COLOR_STAGGER, 24.0, 0.35)
	var label := CombatFx.spawn(world, enemy.global_position, CombatFx.Style.TEXT, COLOR_STAGGER, 0.0, 0.6)
	label.text = "BREAK"


func _on_parried() -> void:
	CombatFx.spawn(CombatFx.world_of(enemy), enemy.global_position + Vector2(0, -4), CombatFx.Style.FLASH, Color(1, 1, 0.85), 9.0, 0.2)


func _process(_delta: float) -> void:
	queue_redraw()
	# Unblockable attacks also sound different (once per attack, at telegraph start).
	var combat := enemy.combat
	if combat.state == CombatComponent.State.ATTACKING and combat.current_attack.is_unblockable() \
			and combat.attack_instance != _warned_attack:
		_warned_attack = combat.attack_instance
		CombatAudio.play(enemy, &"unblockable_warn")


func _draw() -> void:
	var combat := enemy.combat
	var health := enemy.health
	var alpha := 1.0
	if enemy.state == Enemy.State.DEAD:
		alpha = clampf(1.0 - enemy.dead_time / enemy.config.despawn_delay, 0.0, 1.0)

	if enemy.state == Enemy.State.TELEGRAPH:
		_draw_telegraph(combat)

	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35 * alpha))
	draw_set_transform(Vector2.ZERO)

	var body := COLOR_BODY
	if enemy.state == Enemy.State.STAGGERED:
		body = body.lerp(COLOR_STAGGER, 0.6)
	elif enemy.state == Enemy.State.TELEGRAPH:
		body = body.lerp(COLOR_TELEGRAPH, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.04))
	body = body.lerp(Color.WHITE, fx.flash)
	body.a = alpha
	var o := fx.offset
	draw_circle(o + Vector2(0, -4), 8.0, body)
	var look := combat.attack_direction if combat.is_busy() else enemy.velocity.normalized()
	if look == Vector2.ZERO:
		look = Vector2.DOWN
	for side in [-1.0, 1.0]:
		draw_circle(o + Vector2(0, -5) + look * 4.0 + look.orthogonal() * 2.5 * side, 1.3, Color(1, 0.9, 0.6, alpha))

	if combat.state == CombatComponent.State.ATTACKING and combat.phase == CombatComponent.Phase.ACTIVE:
		var reach := combat.get_reach(combat.current_attack, 0)
		var half := deg_to_rad(combat.current_attack.arc_degrees) * 0.5
		var angle := combat.attack_direction.angle()
		draw_arc(Vector2.ZERO, reach * 0.9, angle - half, angle + half, 12, Color(1, 0.8, 0.6, 0.9), 3.0)

	if enemy.state != Enemy.State.DEAD:
		var width := 20.0
		var top := Vector2(-width * 0.5, -20)
		draw_rect(Rect2(top, Vector2(width, 2.5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(width * health.health / health.max_health, 2.5)), Color("d9534f"))
	if DebugView.show_hitboxes and enemy.knockback.is_active():
		DebugView.draw_vector(self, enemy.knockback.remaining(), DebugView.COLOR_KNOCKBACK)
	if enemy.state == Enemy.State.STAGGERED:
		WorldText.draw(self, Vector2(-2, -24), "!", 10, COLOR_STAGGER, 2, Color.BLACK)


func _draw_telegraph(combat: CombatComponent) -> void:
	var attack := combat.current_attack
	var color := COLOR_TELEGRAPH if attack.input_type == AttackDefinition.InputType.LIGHT else COLOR_TELEGRAPH_HEAVY
	if attack.is_unblockable():
		_draw_unblockable(combat)
		return
	var progress := combat.phase_progress()
	var reach := combat.get_reach(attack, 0)
	var half := deg_to_rad(attack.arc_degrees) * 0.5
	var angle := combat.attack_direction.angle()
	var outline := PackedVector2Array([Vector2.ZERO])
	var fill := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var a := angle - half + 2.0 * half * i / 12.0
		outline.append(Vector2.from_angle(a) * reach)
		fill.append(Vector2.from_angle(a) * reach * progress)
	draw_colored_polygon(fill, Color(color, 0.35))
	outline.append(Vector2.ZERO)
	draw_polyline(outline, Color(color, 0.8), 1.0 if color == COLOR_TELEGRAPH else 2.0)


func _draw_unblockable(combat: CombatComponent) -> void:
	var attack := combat.current_attack
	var progress := combat.phase_progress()
	var reach := combat.get_reach(attack, 0)
	var half := deg_to_rad(attack.arc_degrees) * 0.5
	var angle := combat.attack_direction.angle()
	var fill := PackedVector2Array([Vector2.ZERO])
	var zigzag := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		var a := angle - half + 2.0 * half * i / 16.0
		fill.append(Vector2.from_angle(a) * reach * progress)
		zigzag.append(Vector2.from_angle(a) * reach * (1.0 if i % 2 == 0 else 0.86))
	zigzag.append(Vector2.ZERO)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
	draw_colored_polygon(fill, Color(COLOR_UNBLOCKABLE, 0.3))
	draw_polyline(zigzag, Color(COLOR_UNBLOCKABLE, 0.6 + 0.4 * pulse), 2.0)
	WorldText.draw(self, Vector2(-6, -30), "!!", 11, Color(1.0, 0.9, 1.0), 3, Color(0.35, 0.0, 0.4))
