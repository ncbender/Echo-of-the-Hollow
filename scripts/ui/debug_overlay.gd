extends CanvasLayer
## Debug HUD: action state, combo path, charge tier, dash charges, weapon family,
## hit window. Read-only view of the player's components.

const STATE_NAMES := ["IDLE", "CHARGING", "ATTACKING"]
const PHASE_NAMES := ["-", "STARTUP", "ACTIVE", "RECOVERY"]

@export var player: Player

var _last_target: Enemy

@onready var _status: Label = $Status
@onready var _help: Label = $Help


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_status.text = "no player"
		return
	_status.text = "\n".join(_lines())


func _lines() -> PackedStringArray:
	var combat := player.combat
	var dash := player.dash
	var lines: PackedStringArray = []
	var weapon_name := combat.weapon.display_name if combat.weapon != null else "-"
	lines.append("Weapon   %s  [%d/%d]" % [weapon_name, player.weapons.find(combat.weapon) + 1, player.weapons.size()])
	lines.append("HP       %.0f / %.0f%s" % [player.health.health, player.health.max_health, "  (DOWN)" if player.health.is_dead() else ""])
	var reacting := player.reaction.is_reacting()
	lines.append("Reaction %s%s" % [HitReaction.name_of(player.reaction.current) if reacting else "-", "  (hitstop)" if player.hitstop_left > 0.0 else ""])

	var state := "%s" % STATE_NAMES[combat.state]
	if dash.is_dashing():
		state = "DASH" + (" (iFrames)" if dash.is_invulnerable() else "") + "  | action " + state
	if combat.state == CombatComponent.State.ATTACKING:
		state += " / %s  %s  %.2fs" % [PHASE_NAMES[combat.phase], combat.current_attack.id, combat.phase_time]
	lines.append("State    " + state)

	var path := " > ".join(PackedStringArray(combat.combo.path)) if not combat.combo.path.is_empty() else "-"
	var window := ""
	if combat.combo.paused:
		window = "  (timer paused)"
	elif combat.combo.window_open:
		window = "  (window %.2fs)" % combat.combo.window_left
	lines.append("Combo    " + path + window)

	var charge := "-"
	if combat.state == CombatComponent.State.CHARGING:
		var profile := combat.charging_attack.charge_profile
		charge = "%s  %.2fs -> %s" % [profile.tier_name(combat.get_charge_tier_preview()), combat.charge_time, combat.charging_attack.id]
	elif combat.state == CombatComponent.State.ATTACKING and combat.current_attack.charge_profile != null:
		charge = "released: " + combat.current_attack.charge_profile.tier_name(combat.charge_tier)
	lines.append("Heavy    " + charge)

	var pips := ""
	for i in dash.config.max_charges:
		pips += "#" if i < dash.charges else "."
	var recharge := "  recharge %d%%" % roundi(dash.get_recharge_progress() * 100.0) if dash.charges < dash.config.max_charges else ""
	lines.append("Dash     [%s]%s" % [pips, recharge])

	var hitbox_active := combat.hitbox != null and combat.hitbox.is_active()
	lines.append("Hitbox   %s" % ("ACTIVE" if hitbox_active else "off"))
	var unlocks: PackedStringArray = []
	for requirement: StringName in combat.combo.unlocks:
		unlocks.append(String(requirement).get_slice(".", 1))
	lines.append("Unlocks  %s" % (", ".join(unlocks) if not unlocks.is_empty() else "-"))
	lines.append("Lunge    " + _lunge_line(combat))
	lines.append("Knockbk  " + _knockback_line())
	lines.append("FPS      %d" % Engine.get_frames_per_second())
	return lines


func _lunge_line(combat: CombatComponent) -> String:
	if combat.state != CombatComponent.State.ATTACKING or combat.current_attack.lunge_distance <= 0.0:
		return "-"
	var direction := combat.attack_direction
	var running := combat.get_lunge_velocity() != Vector2.ZERO
	return "%.0f px  dir (%.2f, %.2f)  %s" % [combat.current_attack.lunge_distance, direction.x, direction.y, "MOVING" if running else "done"]


## Last enemy struck by the player: applied distance after resistance and the
## distance it really moved (less when a wall or another body stopped it).
func _knockback_line() -> String:
	if not player.combat.hit_landed.is_connected(_on_hit_landed):
		player.combat.hit_landed.connect(_on_hit_landed)
	var text := "-"
	if _last_target != null and is_instance_valid(_last_target):
		var motion := _last_target.knockback
		text = "dealt %.1f px (res %.2f) moved %.1f px  vec (%.1f, %.1f)" % [motion.last_offset.length(),
				_last_target.config.knockback_resistance, motion.last_traveled, motion.last_offset.x, motion.last_offset.y]
	if player.knockback.is_active():
		text += "  | taken %.1f px left" % player.knockback.remaining().length()
	return text


func _on_hit_landed(hit: HitData) -> void:
	if hit.target is Enemy:
		_last_target = hit.target
