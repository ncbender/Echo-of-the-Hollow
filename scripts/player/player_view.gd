extends Node2D
## Placeholder visuals for the player. Reads state only, never changes gameplay.
## Swing visuals are derived from the running attack's data and phase, so every
## AttackDefinition gets readable feedback without per-attack art.

const BODY_RADIUS := 7.0
const COLOR_BODY := Color("6fc3c9")
const COLOR_DASH := Color("bff4ff")
const COLOR_IFRAME := Color(1.0, 1.0, 1.0, 0.45)
const COLOR_AIM := Color("f2e6c2")
const COLOR_BLADE := Color("e8e3d0")
const TIER_COLORS: Array[Color] = [Color("d9d4c7"), Color("ff9a3c"), Color("ffd84a")]

var _trail: Array[Vector2] = []
var _tier_flash: float = 0.0

@onready var player: Player = get_parent()
@onready var _fx: HitReactionFx = $"../HitReactionFx"


func _ready() -> void:
	# Sibling lookup: this view is ready before the Player's @onready vars are.
	var combat: CombatComponent = $"../CombatComponent"
	combat.charge_tier_changed.connect(func(_tier: int) -> void: _tier_flash = 1.0)


func _process(delta: float) -> void:
	_update_trail()
	_tier_flash = maxf(0.0, _tier_flash - delta * 5.0)
	queue_redraw()


func _update_trail() -> void:
	if player.dash.is_dashing():
		_trail.push_front(player.global_position)
		if _trail.size() > 6:
			_trail.pop_back()
	elif not _trail.is_empty():
		_trail.pop_back()


func _draw() -> void:
	for i in _trail.size():
		var alpha := 0.35 * (1.0 - float(i) / _trail.size())
		draw_circle(to_local(_trail[i]), BODY_RADIUS * 0.9, Color(COLOR_DASH, alpha))

	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, BODY_RADIUS + 1.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

	var combat := player.combat
	if combat.state == CombatComponent.State.CHARGING:
		_draw_charge(combat)

	var body_color := COLOR_BODY
	if player.dash.is_invulnerable():
		body_color = COLOR_IFRAME
	elif player.dash.is_dashing():
		body_color = COLOR_DASH
	if player.health.is_dead():
		body_color = Color(0.4, 0.4, 0.45, 0.6)
	body_color = body_color.lerp(Color(1.0, 0.4, 0.35), _fx.flash)
	draw_circle(Vector2(0, -2), BODY_RADIUS, body_color)
	draw_circle(Vector2(0, -2) + player.aim_direction * 3.0, 2.0, Color("1d1b26"))

	if combat.state == CombatComponent.State.ATTACKING:
		_draw_swing(combat)
	else:
		_draw_idle_blade()

	var aim := player.aim_direction
	var side := aim.orthogonal() * 3.0
	draw_colored_polygon(PackedVector2Array([aim * 18.0, aim * 13.0 + side, aim * 13.0 - side]), Color(COLOR_AIM, 0.8))
	if DebugView.show_hitboxes:
		_draw_debug_vectors()


## F1 debug: full lunge of the running attack (green) and remaining received knockback (red).
func _draw_debug_vectors() -> void:
	var combat := player.combat
	if combat.get_lunge_velocity() != Vector2.ZERO:
		DebugView.draw_vector(self, combat.attack_direction * combat.current_attack.lunge_distance, DebugView.COLOR_LUNGE)
	if player.knockback.is_active():
		DebugView.draw_vector(self, player.knockback.remaining(), DebugView.COLOR_KNOCKBACK)


func _weapon_color() -> Color:
	var weapon := player.combat.weapon
	return weapon.display_color if weapon != null else COLOR_BLADE


func _draw_idle_blade() -> void:
	var aim := player.aim_direction
	var hand := aim.orthogonal() * 6.0 + Vector2(0, -2)
	draw_line(hand, hand + aim.rotated(-0.6) * _blade_length() * 0.6, Color(_weapon_color(), 0.8), 2.0)


func _blade_length() -> float:
	var weapon := player.combat.weapon
	return weapon.visual_blade_length if weapon != null else 14.0


func _draw_charge(combat: CombatComponent) -> void:
	var tier := combat.get_charge_tier_preview()
	var profile := combat.charging_attack.charge_profile
	var full_time: float = profile.tier_thresholds[profile.tier_thresholds.size() - 1] if not profile.tier_thresholds.is_empty() else 1.0
	var progress := clampf(combat.charge_time / full_time, 0.0, 1.0)
	var color: Color = TIER_COLORS[mini(tier, TIER_COLORS.size() - 1)]
	var radius := 11.0 + 3.0 * tier
	draw_arc(Vector2(0, -2), radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, color, 2.0)
	if tier >= profile.max_tier():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		draw_arc(Vector2(0, -2), radius + 2.0, 0.0, TAU, 32, Color(color, 0.3 + 0.4 * pulse), 1.0)
	if _tier_flash > 0.0:
		draw_circle(Vector2(0, -2), radius + 4.0 * (1.0 - _tier_flash), Color(color, 0.35 * _tier_flash))
	# Wind-up blade pointing backwards.
	var aim := player.aim_direction
	draw_line(Vector2(0, -2), -aim.rotated(0.5) * _blade_length(), color, 2.0)


func _draw_swing(combat: CombatComponent) -> void:
	var attack := combat.current_attack
	var direction := combat.attack_direction
	var reach := combat.get_reach(attack, combat.charge_tier)
	var half := deg_to_rad(attack.arc_degrees) * 0.5
	var base_angle := direction.angle()
	# Alternate the swing side per combo step so chains read as left/right slashes.
	var side := 1.0 if combat.combo.path.size() % 2 == 1 else -1.0
	var from := base_angle - half * side
	var to := base_angle + half * side
	var color := _weapon_color() if attack.input_type == AttackDefinition.InputType.LIGHT \
			else TIER_COLORS[mini(combat.charge_tier, TIER_COLORS.size() - 1)]
	match combat.phase:
		CombatComponent.Phase.STARTUP:
			var windup := combat.phase_progress()
			var back := from - 0.5 * side * windup
			draw_line(Vector2.ZERO, Vector2.from_angle(back) * reach * 0.7, Color(color, 0.9), 2.0)
		CombatComponent.Phase.ACTIVE:
			var t := combat.phase_progress()
			var current := lerpf(from, to, ease(t, 0.6))
			_draw_wedge(from, current, reach, Color(color, 0.45))
			draw_line(Vector2.ZERO, Vector2.from_angle(current) * reach, Color.WHITE, 2.0)
		CombatComponent.Phase.RECOVERY:
			var fade := 1.0 - combat.phase_progress()
			_draw_wedge(from, to, reach, Color(color, 0.25 * fade))
			draw_line(Vector2.ZERO, Vector2.from_angle(to) * reach * 0.6, Color(color, 0.8), 2.0)


func _draw_wedge(from: float, to: float, radius: float, color: Color) -> void:
	if absf(to - from) < 0.01:
		return
	var points := PackedVector2Array([Vector2.ZERO])
	var segments := 12
	for i in segments + 1:
		points.append(Vector2.from_angle(lerpf(from, to, float(i) / segments)) * radius)
	draw_colored_polygon(points, color)
