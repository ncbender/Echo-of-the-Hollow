extends CanvasLayer
## Debug HUD: action state, combo path, charge tier, dash charges, weapon family,
## hit window. Read-only view of the player's components.

const STATE_NAMES := ["IDLE", "CHARGING", "ATTACKING"]
const PHASE_NAMES := ["-", "STARTUP", "ACTIVE", "RECOVERY"]

@export var player: Player

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
	lines.append("FPS      %d" % Engine.get_frames_per_second())
	return lines
