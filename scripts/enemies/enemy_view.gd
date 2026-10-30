class_name EnemyView
extends Node2D
## Placeholder visuals for the melee enemy, including the attack telegraph.

const COLOR_BODY := Color("b5524a")
const COLOR_TELEGRAPH := Color(1.0, 0.45, 0.2)
const COLOR_STAGGER := Color("9fc8ff")
## Braced windup (EnemyConfig.braced_poise_taken): a heavy stone-coloured ring.
const COLOR_BRACED := Color(0.85, 0.8, 0.62)
## Opening after a heavy attack (EnemyConfig.recovery_cue): dimmed body and "...".
const COLOR_EXPOSED := Color(0.5, 0.55, 0.5)

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

	if current_telegraph() >= 0:
		_draw_telegraph(combat)

	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35 * alpha))
	draw_set_transform(Vector2.ZERO)

	var body := enemy.config.body_color
	if enemy.state == Enemy.State.STAGGERED:
		body = body.lerp(COLOR_STAGGER, 0.6)
	elif enemy.state == Enemy.State.TELEGRAPH:   # a steady build-up with the startup, no blinking (Combat Telegraphs 1.0)
		body = body.lerp(COLOR_TELEGRAPH, 0.2 + 0.4 * combat.phase_progress())
	elif is_exposed():
		body = body.lerp(COLOR_EXPOSED, 0.55)
	body = body.lerp(Color.WHITE, fx.flash)
	body.a = alpha
	var o := fx.offset
	draw_circle(o + Vector2(0, -4), enemy.config.body_radius, body)
	if enemy.state != Enemy.State.DEAD and enemy.is_braced():
		draw_arc(o + Vector2(0, -4), enemy.config.body_radius + 3.0, 0.0, TAU, 28, COLOR_BRACED, 2.5)
	if is_exposed():
		WorldText.draw(self, Vector2(-6, -enemy.config.body_radius - 14.0), "...", 9, COLOR_EXPOSED.lightened(0.4), 2, Color.BLACK)
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


## Recovery of a heavy attack, shown only for enemies with EnemyConfig.recovery_cue.
func is_exposed() -> bool:
	var combat := enemy.combat
	return enemy.config.recovery_cue and enemy.state == Enemy.State.ATTACKING \
			and combat.phase == CombatComponent.Phase.RECOVERY \
			and combat.current_attack.input_type == AttackDefinition.InputType.HEAVY


## Combat Telegraphs 1.0 (docs/COMBAT_TELEGRAPHS_1_0.md): the windup (startup) of every enemy attack shows its area
## (cone in the attack direction, the fill growing with the startup; thin line = light, thick = heavy) and ONE symbol
## for how it can be defended - read from AttackDefinition.telegraph_kind(), the same reading DefenseComponent.resolve
## uses: PARRYABLE = bright cross spark, BLOCK_ONLY = angular amber shield, UNDEFENDABLE = red broken ring (and a
## jagged red cone edge). The symbol sits above the head, or below the body when the attack points up, so it never
## covers the area. Same timing for all three: it grows in over the first 15 % of the startup, holds steady, and
## brightens once from 70 % on - no blinking, no text. Drawn only in the TELEGRAPH state, so the active phase, a
## stagger, an interruption or death end it at once.
const COLOR_AREA := Color(1.0, 0.45, 0.2)
const COLOR_SPARK := Color("fff6d6")
const COLOR_SHIELD := Color("e0a43c")
const COLOR_BROKEN := Color("e23b2e")
const COLOR_INK := Color(0.05, 0.04, 0.03, 0.9)
## Symbol timing as shares of the startup.
const SYMBOL_GROW := 0.15
const SYMBOL_BRIGHT := 0.7


func _draw_telegraph(combat: CombatComponent) -> void:
	var attack := combat.current_attack
	var kind := attack.telegraph_kind()
	var progress := combat.phase_progress()
	var reach := combat.get_reach(attack, 0)
	var half := deg_to_rad(attack.arc_degrees) * 0.5
	var angle := combat.attack_direction.angle()
	var heavy := attack.input_type != AttackDefinition.InputType.LIGHT
	var area := COLOR_BROKEN if kind == AttackDefinition.Telegraph.UNDEFENDABLE else COLOR_AREA
	var fill := PackedVector2Array([Vector2.ZERO])
	var edge := PackedVector2Array([Vector2.ZERO])
	for i in 17:
		var a := angle - half + 2.0 * half * i / 16.0
		fill.append(Vector2.from_angle(a) * reach * progress)
		var jag := 0.86 if kind == AttackDefinition.Telegraph.UNDEFENDABLE and i % 2 == 1 else 1.0   # jagged edge
		edge.append(Vector2.from_angle(a) * reach * jag)
	edge.append(Vector2.ZERO)
	draw_colored_polygon(fill, Color(area, 0.3))
	draw_polyline(edge, Color(area, 0.8), 2.0 if heavy or kind == AttackDefinition.Telegraph.UNDEFENDABLE else 1.0)
	draw_telegraph_symbol(self, kind, symbol_anchor(combat.attack_direction), progress)


## The telegraph kind shown now (AttackDefinition.Telegraph), -1 when none: only during the startup of an attack.
func current_telegraph() -> int:
	var combat := enemy.combat
	if enemy.state != Enemy.State.TELEGRAPH or combat.current_attack == null:
		return -1
	return combat.current_attack.telegraph_kind()


## Above the head, or below the body - whichever lies further from the attack direction (the cone never covers it).
func symbol_anchor(direction: Vector2) -> Vector2:
	var above := Vector2(0, -enemy.config.body_radius - 22.0)
	var below := Vector2(0, 14)
	if direction == Vector2.ZERO:
		return above
	return above if absf(direction.angle_to(above)) >= absf(direction.angle_to(below)) else below


## The defense symbol at `at` (whole pixels, an ink outline under every stroke). `progress` = startup share.
static func draw_telegraph_symbol(canvas: CanvasItem, kind: AttackDefinition.Telegraph, at: Vector2, progress: float) -> void:
	var grow := clampf(progress / SYMBOL_GROW, 0.0, 1.0)
	var bright := 1.0 if progress >= SYMBOL_BRIGHT else 0.75
	var size := roundf(lerpf(3.0, 6.0, grow))
	at = at.round()
	match kind:
		AttackDefinition.Telegraph.PARRYABLE:   # cross spark: a "+" with short diagonal glints
			var color := Color(COLOR_SPARK, bright)
			for line: Array in [[Vector2(-size, 0), Vector2(size, 0)], [Vector2(0, -size), Vector2(0, size)]]:
				canvas.draw_line(at + line[0], at + line[1], COLOR_INK, 3.0)
			var glint := roundf(size * 0.5)
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				canvas.draw_rect(Rect2(at + corner * (glint + 1.0) - Vector2(1, 1), Vector2(2, 2)), COLOR_INK)
				canvas.draw_rect(Rect2(at + corner * (glint + 1.0) - Vector2(0.5, 0.5), Vector2(1, 1)), color)
			canvas.draw_line(at + Vector2(-size, 0), at + Vector2(size, 0), color, 1.0)
			canvas.draw_line(at + Vector2(0, -size), at + Vector2(0, size), color, 1.0)
		AttackDefinition.Telegraph.BLOCK_ONLY:   # angular shield: flat top, straight sides, a point below
			var w := size
			var shield := PackedVector2Array([at + Vector2(-w, -w), at + Vector2(w, -w), at + Vector2(w, roundf(w * 0.3)),
				at + Vector2(0, w + 1.0), at + Vector2(-w, roundf(w * 0.3)), at + Vector2(-w, -w)])
			canvas.draw_colored_polygon(shield, Color(COLOR_SHIELD.darkened(0.55), 0.9))
			canvas.draw_polyline(shield, COLOR_INK, 3.0)
			canvas.draw_polyline(shield, Color(COLOR_SHIELD, bright), 1.0)
		_:   # broken ring: four arcs with gaps
			var radius := size + 1.0
			for quarter in 4:
				var from := PI * 0.5 * quarter + 0.35
				var to := PI * 0.5 * (quarter + 1) - 0.35
				canvas.draw_arc(at, radius, from, to, 6, COLOR_INK, 3.0)
				canvas.draw_arc(at, radius, from, to, 6, Color(COLOR_BROKEN, bright), 1.0)
			canvas.draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Color(COLOR_BROKEN, bright))

