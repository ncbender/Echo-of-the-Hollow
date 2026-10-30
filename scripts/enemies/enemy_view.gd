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
	_cue_layer = Node2D.new()
	_cue_layer.name = "ParryCueLayer"
	_cue_layer.z_index = 20   # the parry cue above the enemy, the hero and the area
	_cue_layer.draw.connect(_draw_cue)
	add_child(_cue_layer)


func _on_poise_broken() -> void:
	CombatAudio.play(enemy, &"poise_break")
	var world := CombatFx.world_of(enemy)
	CombatFx.spawn(world, enemy.global_position + Vector2(0, -4), CombatFx.Style.STAR, COLOR_STAGGER, 20.0, 0.4)
	CombatFx.spawn(world, enemy.global_position, CombatFx.Style.RING, COLOR_STAGGER, 24.0, 0.35)
	var label := CombatFx.spawn(world, enemy.global_position, CombatFx.Style.TEXT, COLOR_STAGGER, 0.0, 0.6)
	label.text = "BREAK"


func _on_parried() -> void:
	CombatFx.spawn(CombatFx.world_of(enemy), enemy.global_position + Vector2(0, -4), CombatFx.Style.FLASH, Color(1, 1, 0.85), 9.0, 0.2)


func _process(delta: float) -> void:
	queue_redraw()
	if _cue_age >= 0.0:
		_cue_age += delta
		if _cue_age >= CUE_FLASH:
			_cue_age = -1.0
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
	if _cue_layer != null:
		_cue_layer.queue_redraw()


## Recovery of a heavy attack, shown only for enemies with EnemyConfig.recovery_cue.
func is_exposed() -> bool:
	var combat := enemy.combat
	return enemy.config.recovery_cue and enemy.state == Enemy.State.ATTACKING \
			and combat.phase == CombatComponent.Phase.RECOVERY \
			and combat.current_attack.input_type == AttackDefinition.InputType.HEAVY


## Combat Telegraphs 1.0 / Parry Timing Cue 1.0 (docs/PARRY_TIMING_CUE_1_0.md): the windup (startup) of every enemy
## attack shows its area - cone in the attack direction, the fill growing with the startup; thin line = light, thick =
## heavy; an attack that can be neither parried nor safely blocked (AttackDefinition.telegraph_kind UNDEFENDABLE) in
## red with a jagged edge. No defense symbols any more (the cross / shield / ring of Combat Telegraphs 1.0 were not read
## as intended): an elite's or boss's parryable attack instead shows ONE short bright cross flash at its attack side at
## the moment to press Shift (ParryCue: the hit minus reaction + half the parry window). Drawn only in TELEGRAPH, so the
## active phase, a stagger, an interruption or death end the area at once; the flash is cancelled the same way.
const COLOR_AREA := Color(1.0, 0.45, 0.2)
const COLOR_BROKEN := Color("e23b2e")
const COLOR_INK := Color(0.05, 0.04, 0.03, 0.9)
const COLOR_CUE := Color("fffbe8")
const COLOR_CUE_GLOW := Color("ffd76a")
## Length of the cue flash (seconds, real time): short, over before the hit.
const CUE_FLASH := 0.16

## The parry cue: the attack instance it was shown for (one per attack), how long the flash has run (-1 = none),
## where (attack side, in the view), and how many cues this view showed (tests).
signal parry_cue(attack_instance: int)
var cue_instance: int = -1
var cue_count: int = 0
var _cue_age: float = -1.0
## The flash is drawn on its own layer above the bodies (a close hero never covers it).
var _cue_layer: Node2D


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


## The telegraph kind of the running windup (AttackDefinition.Telegraph), -1 when none: only during the startup.
func current_telegraph() -> int:
	var combat := enemy.combat
	if enemy.state != Enemy.State.TELEGRAPH or combat.current_attack == null:
		return -1
	return combat.current_attack.telegraph_kind()


## The cue check runs on the physics tick right after the enemy stepped (a child after its parent): once per attack,
## when its hit is ParryCue.lead() away - never for a moment already missed (> ParryCue.LATE ago), never twice.
func _physics_process(_delta: float) -> void:
	var combat := enemy.combat
	if enemy.state != Enemy.State.TELEGRAPH and enemy.state != Enemy.State.ATTACKING:
		_cue_age = -1.0   # stagger, death: the flash ends at once
		return
	if enemy.state != Enemy.State.TELEGRAPH or combat.attack_instance == cue_instance or not ParryCue.eligible(enemy.config, combat.current_attack):
		return
	var left := ParryCue.time_to_hit(combat)
	var lead := ParryCue.lead(ParryCue.window_of(enemy.target))
	if left < 0.0 or left > lead:
		return
	cue_instance = combat.attack_instance   # decided once for this attack, shown or (missed) not
	if left < lead - ParryCue.LATE:
		return
	cue_count += 1
	_cue_age = 0.0
	parry_cue.emit(cue_instance)


## The flash point: the attack side of the body, slightly in front of it (the procedural enemies have no weapon).
func cue_point() -> Vector2:
	var direction := enemy.combat.attack_direction if enemy.combat.attack_direction != Vector2.ZERO else Vector2.RIGHT
	return (Vector2(0, -4) + direction * (enemy.config.body_radius + 1.0)).round()


## A bright cross flash: "+" bursting out and a short "x" glint, ink-outlined, whole pixels; it shrinks away.
func _draw_cue() -> void:
	if not cue_visible():
		return
	var canvas := _cue_layer
	var t := clampf(_cue_age / CUE_FLASH, 0.0, 1.0)
	var at := cue_point()
	var arm := roundf(lerpf(5.0, 10.0, minf(1.0, t * 3.0)) * (1.0 - t * 0.5))
	var glint := roundf(arm * 0.55)
	var alpha := 1.0 - t * t
	for line: Array in [[Vector2(-arm, 0), Vector2(arm, 0)], [Vector2(0, -arm), Vector2(0, arm)]]:
		canvas.draw_line(at + line[0], at + line[1], Color(COLOR_INK, alpha), 4.0)
	for line: Array in [[Vector2(-glint, -glint), Vector2(glint, glint)], [Vector2(-glint, glint), Vector2(glint, -glint)]]:
		canvas.draw_line(at + line[0], at + line[1], Color(COLOR_CUE_GLOW, alpha * 0.9), 1.0)
	for line: Array in [[Vector2(-arm, 0), Vector2(arm, 0)], [Vector2(0, -arm), Vector2(0, arm)]]:
		canvas.draw_line(at + line[0], at + line[1], Color(COLOR_CUE, alpha), 2.0)
	canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(Color.WHITE, alpha))


## True while the flash is on screen (tests).
func cue_visible() -> bool:
	return _cue_age >= 0.0 and _cue_age < CUE_FLASH
