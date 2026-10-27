class_name CombatComponent
extends Node
## Action layer of a fighter: attack phases, hit scanning, modifiers and cancel
## rules. Two input models, chosen by the weapon family:
##  * Combat Flow 1.5 (families with combo_paths - the player): deterministic
##    combo-path state machine NEUTRAL -> WINDUP -> ACTIVE -> RECOVERY -> NEUTRAL,
##    instant heavies, one buffered input, transitions at a share of the recovery,
##    mastery-gated paths, defensive cancel windows, bow input (docs/WEAPON_MASTERY_COMBAT_FLOW.md).
##  * legacy tree (enemies): ComboController, 120 ms buffer, chain_delay, RMB charge.
## Movement and dash are separate systems; this component only reports how much
## movement the current action allows and whether a dash may cancel it.
## All attack behaviour comes from AttackDefinition data.

enum State { IDLE, CHARGING, ATTACKING }
enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

const BUFFER_LIGHT := &"light"
const BUFFER_HEAVY := &"heavy"
const PHASE_CANCEL_FLAGS := {
	Phase.STARTUP: AttackDefinition.CANCEL_STARTUP,
	Phase.ACTIVE: AttackDefinition.CANCEL_ACTIVE,
	Phase.RECOVERY: AttackDefinition.CANCEL_RECOVERY,
}
## Results of a Combat Flow input (flow_input signal; tests and debug overlay).
const INPUT_STARTED := &"started"
const INPUT_BUFFERED := &"buffered"
const INPUT_TRANSITION := &"transition"
const INPUT_TOO_EARLY := &"too_early"
const INPUT_LOCKED := &"locked"
const INPUT_BUFFER_FULL := &"buffer_full"
const INPUT_COMMITTED := &"committed"
const INPUT_WAITING := &"waiting"

signal attack_started(attack: AttackDefinition, charge_tier: int)
signal attack_phase_changed(attack: AttackDefinition, phase: Phase)
signal attack_finished(attack: AttackDefinition)
signal attack_cancelled(attack: AttackDefinition, reason: StringName)
signal charge_started(attack: AttackDefinition)
signal charge_tier_changed(tier: int)
signal charge_cancelled(reason: StringName)
signal hit_landed(hit: HitData)
signal weapon_changed(weapon: WeaponFamily)
## Combat Flow: what happened to one physical input ("L", "H", "P") - see INPUT_*.
signal flow_input(symbol: String, result: StringName)
## Combat Flow: a projectile left at the fire event (ranged attacks).
signal projectile_fired(attack: AttackDefinition, projectile: Node2D)

@export var weapon: WeaponFamily
@export var hitbox: AttackHitbox
@export var input_buffer_time: float = 0.12
@export var modifiers: Array[AttackModifier] = []
## Attack speed multiplier (1 = data timings). Set by the owner (player: resolved
## Attack Speed stat, clamped by ProgressionRules). Taken over when an attack
## starts and scaled per attack by AttackDefinition.attack_speed_scaling; it
## shortens startup/active/recovery and chain_delay and spreads the lunge over the
## shorter time. Heavy charge thresholds, combo windows and dashes never scale.
var attack_speed: float = 1.0
## Factor on the recovery phase only (Armor Mastery: burden lengthens it, Attack
## Recovery Speed shortens it). Set by the owner; 1 = data timings. Startup,
## active, chain delay, combo windows, charge and dash never use it. Taken over
## when an attack starts (burden snapshot).
var recovery_multiplier: float = 1.0
## Combat Flow: mastery level of the wielded family (set by the owner; 1 = only
## the base attacks). A chain keeps the level it started with.
var mastery_level: int = 1
## Combat Flow prototype values (transition, buffer, cancel shares, bow).
var flow_rules: CombatFlowRules = CombatFlowRules.get_default()

var state: State = State.IDLE
var phase: Phase = Phase.NONE
var current_attack: AttackDefinition
## Heavy attack being charged (already resolved from the combo tree).
var charging_attack: AttackDefinition
var charge_time: float = 0.0
## Charge tier of the current charge or the running heavy attack.
var charge_tier: int = 0
var attack_direction: Vector2 = Vector2.RIGHT
var phase_time: float = 0.0
## Increments for every started attack; identifies one swing.
var attack_instance: int = 0
var combo := ComboController.new()
var buffer := InputBuffer.new()

## Combat Flow chain: inputs so far (incl. the running attack), the mastery level
## it started with, and the one buffered next sequence ("" = empty).
var chain: String = ""
var chain_level: int = 1
var buffered: String = ""
## Bow: Flowing Draw is running (LMB held past the threshold), shots fired in this cycle.
var flowing_draw: bool = false
var flowing_shot: int = 0
## The running attack closes its chain with a full recovery (last Flowing Draw shot).
var final_recovery: bool = false

## RMB went down and was not consumed yet; charging starts once free while still held.
var _heavy_hold_pending: bool = false
## Lunge distance the running attack may still cover (see take_lunge_velocity).
var _lunge_left: float = 0.0
## Effective speed factor of the running attack (fixed at attack start).
var _speed: float = 1.0
## Recovery factor of the running attack (burden snapshot at attack start).
var _recovery: float = 1.0
## Attack clock of the buffered input (it transitions at max(transition, press)).
var _buffered_at: float = 0.0
## Bow hold tracking: LMB held since the chain-starting press, seconds held.
var _hold_tracking: bool = false
var _hold_time: float = 0.0
## Bow Precision Stance: RMB currently held.
var _stance: bool = false
var _last_aim: Vector2 = Vector2.RIGHT


func _ready() -> void:
	buffer.window = input_buffer_time
	if weapon != null and combo.weapon != weapon:
		set_weapon(weapon)


## Equips a weapon family. Only allowed while idle; resets the combo.
func set_weapon(new_weapon: WeaponFamily) -> bool:
	if state != State.IDLE:
		return false
	for error in new_weapon.validate():
		push_error(error)
	weapon = new_weapon
	combo.set_weapon(new_weapon)
	clear_inputs()
	weapon_changed.emit(new_weapon)
	return true


func set_unlocked(requirement: StringName, unlocked: bool) -> void:
	if unlocked:
		combo.unlocks[requirement] = true
	else:
		combo.unlocks.erase(requirement)


func is_busy() -> bool:
	return state != State.IDLE


func uses_flow() -> bool:
	return weapon != null and weapon.uses_flow()


## Advances the action layer by one tick. While `blocked` (e.g. dashing) inputs are
## still buffered, but no new action starts.
func step(delta: float, input: InputFrame, aim: Vector2, blocked: bool = false) -> void:
	if aim != Vector2.ZERO:
		_last_aim = aim.normalized()
	if uses_flow():
		_step_flow(delta, input, aim, blocked)
		return
	buffer.step(delta)
	record_inputs(input)

	match state:
		State.IDLE:
			combo.step(delta)
		State.CHARGING:
			_step_charge(delta, input, aim)
		State.ATTACKING:
			_step_attack(delta)

	if blocked:
		return
	if state == State.IDLE or (state == State.ATTACKING and _can_chain()):
		_try_begin_action(input, aim)


## Buffers this tick's presses without advancing time (also used while the
## owner is frozen by hitstop, so clicks during a freeze are not lost; the
## Combat Flow attack clock stands still meanwhile).
func record_inputs(input: InputFrame) -> void:
	if uses_flow():
		_record_flow(input, true)
		return
	if input.light_pressed:
		buffer.push(BUFFER_LIGHT)
	if input.heavy_pressed:
		buffer.push(BUFFER_HEAVY)
		_heavy_hold_pending = true
	if not input.heavy_held:
		_heavy_hold_pending = false


## False while the running attack is in an uninterruptible (hyper armor) phase.
func is_interruptible() -> bool:
	if state != State.ATTACKING:
		return true
	return (current_attack.uninterruptible_phases & PHASE_CANCEL_FLAGS[phase]) == 0


## Whether a dash (and with the same rule parry / block) may cancel the running
## action now. Combat Flow: windup and active are committed (unless the attack
## declares special_cancel_phases); the recovery opens at the defensive share of
## its role (base quick 50 %, base heavy 65 %, combo step 55 %, quick finisher
## 65 %, heavy finisher 75 %) of the burden-lengthened recovery.
func can_dash_cancel() -> bool:
	if state != State.ATTACKING:
		return true
	if uses_flow() and current_attack.is_flow():
		if phase == Phase.RECOVERY:
			return phase_time >= _recovery_duration() * defense_cancel_ratio(current_attack) - 0.00001
		return (current_attack.special_cancel_phases & PHASE_CANCEL_FLAGS[phase]) != 0
	return (current_attack.dash_cancel_phases & PHASE_CANCEL_FLAGS[phase]) != 0


## Whether another action (skill, drink) may start now. Combat Flow has no
## blanket skill or drink cancels: only in neutral. Legacy: the dash rule.
func allows_other_action() -> bool:
	if uses_flow():
		return state == State.IDLE
	return can_dash_cancel()


## Combat Flow: a dash / parry / block pressed while it may not cancel is
## refused instead of being stored for a later phantom cancel.
func refuses_defense_input() -> bool:
	return uses_flow() and state == State.ATTACKING and not can_dash_cancel()


## Aborts the running action. Pending hits of the attack are discarded, already
## dealt damage stays (and projectiles already in flight keep flying). Ends the
## combo (design rule: dash ends the combo) and clears every buffered input.
func cancel(reason: StringName) -> void:
	if state == State.ATTACKING:
		var attack := current_attack
		_clear_attack()
		attack_cancelled.emit(attack, reason)
	elif state == State.CHARGING:
		charging_attack = null
		charge_time = 0.0
		charge_tier = 0
		state = State.IDLE
		charge_cancelled.emit(reason)
	combo.reset()
	buffer.clear()
	_heavy_hold_pending = false
	_close_chain()
	clear_inputs()


## Clears every buffered input and hold state; a key still held needs a new
## press (UI opened, pause, stun, death, weapon or class change, load).
func clear_inputs() -> void:
	buffer.clear()
	buffered = ""
	_heavy_hold_pending = false
	_hold_tracking = false
	_hold_time = 0.0
	flowing_draw = false
	flowing_shot = 0


func get_move_multiplier() -> float:
	if uses_flow():
		return _flow_move_multiplier()
	match state:
		State.CHARGING:
			return charging_attack.charge_profile.move_multiplier
		State.ATTACKING:
			return current_attack.move_multiplier
	return 1.0


## Bow: RMB holds the Precision Stance (slower walking, LMB fires Precision Shots).
func in_precision_stance() -> bool:
	return uses_flow() and weapon.is_bow() and _stance


## Forward lunge velocity during startup + active of attacks with lunge_distance
## (query only; movement uses take_lunge_velocity).
func get_lunge_velocity() -> Vector2:
	if state != State.ATTACKING or current_attack.lunge_distance <= 0.0 or _lunge_left <= 0.0:
		return Vector2.ZERO
	if phase != Phase.STARTUP and phase != Phase.ACTIVE:
		return Vector2.ZERO
	var lunge_time := (current_attack.startup + current_attack.active) / _speed
	return lunge_direction() * current_attack.lunge_distance / lunge_time


## Direction of the attack movement: the attack direction turned by lunge_angle.
func lunge_direction() -> Vector2:
	if current_attack == null or is_zero_approx(current_attack.lunge_angle):
		return attack_direction
	return attack_direction.rotated(deg_to_rad(current_attack.lunge_angle))


## Lunge velocity for this movement tick. Consumes the attack's lunge budget, so a
## swing never covers more than lunge_distance even when the active phase ends
## mid-tick (blocked movement still consumes it - nothing is saved up).
func take_lunge_velocity(delta: float) -> Vector2:
	var velocity := get_lunge_velocity()
	if velocity == Vector2.ZERO or delta <= 0.0:
		return Vector2.ZERO
	var travel := minf(velocity.length() * delta, _lunge_left)
	_lunge_left -= travel
	return lunge_direction() * (travel / delta)


func get_charge_tier_preview() -> int:
	if state != State.CHARGING:
		return 0
	return charging_attack.charge_profile.get_tier(charge_time)


func get_reach(attack: AttackDefinition, tier: int) -> float:
	var profile := attack.charge_profile
	var reach := attack.reach * (profile.reach_multiplier(tier) if profile != null else 1.0)
	for modifier in modifiers:
		if modifier.applies_to(attack):
			reach = modifier.modify_reach(attack, reach)
	return reach


# --- Combat Flow 1.5 -------------------------------------------------------------

func _step_flow(delta: float, input: InputFrame, aim: Vector2, blocked: bool) -> void:
	buffer.step(delta)
	_record_flow(input, blocked)
	_step_hold(delta, input)
	if state == State.ATTACKING:
		_step_flow_attack(delta)
	if state == State.IDLE and not blocked:
		if flowing_draw:
			_start_flow_attack("L", weapon.node("L"), aim, 0.0)   # still held: the next three-shot cycle
		else:
			_try_flow_start(aim)


## One tick of physical inputs. Down edges only: a held key never repeats (the
## bow's Flowing Draw is driven by the hold timer, not by synthetic presses).
func _record_flow(input: InputFrame, blocked: bool) -> void:
	_stance = input.heavy_held
	if weapon.is_bow():
		if input.heavy_pressed and flowing_draw:
			_stop_flowing()   # switching to the Precision Stance ends the automatic sequence
		if input.light_pressed:
			_flow_press("P" if input.heavy_held else "L", blocked)
		return
	if input.light_pressed:
		_flow_press("L", blocked)
	if input.heavy_pressed:
		_flow_press("H", blocked)


func _flow_press(symbol: String, blocked: bool) -> void:
	if state == State.ATTACKING:
		_flow_continue(symbol)
		return
	# Neutral: a fresh chain. While another action blocks (dash, skill, drink),
	# the press waits the short start buffer; otherwise it starts this tick.
	if buffer.peek() != &"":
		flow_input.emit(symbol, INPUT_BUFFER_FULL)   # the first waiting press stays
		return
	buffer.push(StringName(symbol))
	if blocked:
		flow_input.emit(symbol, INPUT_WAITING)


## A combo input during an attack: it may only continue the chain when an
## unlocked path begins with chain + input. Rejected inputs are dropped - never
## kept as the start of a new chain, never reinterpreted as another combo.
func _flow_continue(symbol: String) -> void:
	var next := chain + symbol
	if flowing_draw:
		flow_input.emit(symbol, INPUT_COMMITTED)   # automatic sequence: no manual steps
		return
	if _must_finish() or not weapon.allows(next, chain_level):
		flow_input.emit(symbol, INPUT_LOCKED)
		return
	if buffered != "":
		flow_input.emit(symbol, INPUT_BUFFER_FULL)
		return
	var clock := attack_clock()
	if clock < accept_from() - 0.00001:
		flow_input.emit(symbol, INPUT_TOO_EARLY)
		return
	buffered = next
	_buffered_at = clock
	flow_input.emit(symbol, INPUT_BUFFERED if clock < transition_time() - 0.00001 else INPUT_TRANSITION)


func _try_flow_start(aim: Vector2) -> void:
	var symbol := String(buffer.peek())
	if symbol == "":
		return
	buffer.clear()
	var attack := weapon.node(symbol)
	if attack == null:
		flow_input.emit(symbol, INPUT_LOCKED)
		return
	chain = ""
	chain_level = mastery_level
	flowing_shot = 0
	# Bow: a chain-starting LMB press may become Flowing Draw while it stays held.
	_hold_tracking = weapon.is_bow() and symbol == "L"
	_hold_time = 0.0
	flow_input.emit(symbol, INPUT_STARTED)
	_start_flow_attack(symbol, attack, aim, 0.0)


func _start_flow_attack(sequence: String, attack: AttackDefinition, aim: Vector2, carried: float) -> void:
	if state == State.ATTACKING:
		_clear_attack()   # transition: the follow-up replaces the rest of the recovery
	chain = sequence
	buffered = ""
	combo.path.append(attack.id)
	if flowing_draw:
		flowing_shot += 1
		final_recovery = flowing_shot >= flow_rules.flowing_draw_shots
	_start_attack(attack, aim, 0)
	if carried > 0.0:
		_step_flow_attack(carried)   # keep the exact transition time at any frame rate


## Bow: hold timer of the chain-starting LMB press. Flowing Draw starts once the
## press is held past the threshold at mastery >= the Flowing Draw level, and
## only while RMB is not held.
func _step_hold(delta: float, input: InputFrame) -> void:
	if not weapon.is_bow():
		return
	if flowing_draw and (not input.light_held or input.heavy_held):
		_stop_flowing()
		return
	if not _hold_tracking:
		return
	if not input.light_held or input.heavy_held:
		_hold_tracking = false
		return
	_hold_time += delta
	var level := weapon.flowing_draw_level()
	if not flowing_draw and level > 0 and chain_level >= level and _hold_time >= flow_rules.flowing_draw_hold - 0.00001 \
			and state == State.ATTACKING and chain == "L":
		flowing_draw = true
		flowing_shot = 1   # the running first Quick Shot is shot 1 (never fired twice)
		buffered = ""


func _stop_flowing() -> void:
	flowing_draw = false
	_hold_tracking = false


func _step_flow_attack(delta: float) -> void:
	phase_time += delta
	while state == State.ATTACKING:
		if phase == Phase.RECOVERY and _flow_transition_due():
			var at := maxf(transition_time(), _buffered_at) - _startup_duration() - _active_duration()
			var carried := maxf(0.0, phase_time - at)
			phase_time = at
			_flow_transition(carried)
			return
		if phase_time < _phase_duration() - 0.00001:
			break
		phase_time -= _phase_duration()
		_enter_next_phase()
	if state == State.ATTACKING and phase == Phase.ACTIVE and not current_attack.is_projectile():
		_scan_hits()


func _flow_transition_due() -> bool:
	var clock := attack_clock()
	if flowing_draw:
		return flowing_shot < flow_rules.flowing_draw_shots and clock >= transition_time() - 0.00001
	return buffered != "" and clock >= maxf(transition_time(), _buffered_at) - 0.00001


func _flow_transition(carried: float) -> void:
	if flowing_draw:
		_start_flow_attack("L", weapon.node("L"), _last_aim, carried)
		return
	var next := buffered
	_start_flow_attack(next, weapon.node(next), _last_aim, carried)


## The running attack ends its chain with a full recovery (the last Flowing Draw
## shot, even when LMB was released meanwhile).
func _must_finish() -> bool:
	return final_recovery


func _close_chain() -> void:
	chain = ""
	buffered = ""
	_buffered_at = 0.0
	final_recovery = false
	# Still held after the closing recovery: the next three-shot cycle starts from shot 1.
	flowing_shot = 0


func _flow_move_multiplier() -> float:
	var stance := flow_rules.precision_stance_move if in_precision_stance() else 1.0
	if state != State.ATTACKING or not current_attack.is_flow():
		return stance
	var factor := 1.0
	match phase:
		Phase.STARTUP:
			factor = current_attack.windup_move
		Phase.ACTIVE:
			factor = current_attack.active_move
		Phase.RECOVERY:
			var progress := clampf(phase_time / maxf(_recovery_duration(), 0.0001), 0.0, 1.0)
			var hold := flow_rules.recovery_move_hold
			factor = current_attack.windup_move if progress <= hold \
					else lerpf(current_attack.windup_move, 1.0, (progress - hold) / maxf(1.0 - hold, 0.0001))
	return factor * stance


## Seconds since the running attack started (Combat Flow attack clock; pauses
## with hitstop because the owner does not step while frozen).
func attack_clock() -> float:
	match phase:
		Phase.STARTUP:
			return phase_time
		Phase.ACTIVE:
			return _startup_duration() + phase_time
		Phase.RECOVERY:
			return _startup_duration() + _active_duration() + phase_time
	return 0.0


## Attack clock of the combo transition: windup + active + ratio x recovery.
func transition_time() -> float:
	if current_attack == null:
		return 0.0
	var ratio := current_attack.transition_ratio if current_attack.transition_ratio >= 0.0 else flow_rules.transition_ratio
	return _startup_duration() + _active_duration() + _recovery_duration() * ratio


## Earliest attack clock at which a combo input is accepted: the later of the
## attack's window start (never before the windup ends) and transition - prebuffer.
func accept_from() -> float:
	if current_attack == null:
		return 0.0
	return maxf(_startup_duration() + current_attack.combo_open_at, transition_time() - flow_rules.prebuffer)


func defense_cancel_ratio(attack: AttackDefinition) -> float:
	return attack.defense_cancel_ratio if attack.defense_cancel_ratio >= 0.0 else flow_rules.cancel_ratio(attack.flow_role)


## Attack clock from which a defense may cancel the running attack.
func defense_cancel_time() -> float:
	if current_attack == null:
		return 0.0
	return _startup_duration() + _active_duration() + _recovery_duration() * defense_cancel_ratio(current_attack)


func _startup_duration() -> float:
	return current_attack.startup / _speed if current_attack != null else 0.0


func _active_duration() -> float:
	return current_attack.active / _speed if current_attack != null else 0.0


func _recovery_duration() -> float:
	return current_attack.recovery / _speed * _recovery if current_attack != null else 0.0


## Fire event of a ranged attack: its projectiles leave now, each carrying a
## snapshot of the swing (a later cancel never takes back a fired arrow).
func _fire_projectiles() -> void:
	var attack := current_attack
	var world := CombatFx.world_of(self)
	var origin_node := get_parent() as Node2D
	if world == null or origin_node == null:
		return
	var count := maxi(1, attack.projectile_count)
	for index in count:
		var offset := 0.0 if count == 1 else lerpf(-attack.projectile_spread * 0.5, attack.projectile_spread * 0.5, float(index) / (count - 1))
		var projectile := SkillProjectile.new()
		projectile.velocity = attack_direction.rotated(deg_to_rad(offset)) * attack.projectile_speed
		projectile.max_distance = attack.projectile_range
		projectile.radius = attack.projectile_radius
		projectile.pierce = attack.projectile_pierce
		projectile.team = hitbox.team if hitbox != null else &"player"
		projectile.color = weapon.display_color
		projectile.shape = attack.projectile_shape
		projectile.on_hit = _on_projectile_hit.bind(attack, attack_instance, attack_direction)
		world.add_child(projectile)
		projectile.global_position = origin_node.global_position + attack_direction * 6.0
		projectile_fired.emit(attack, projectile)


func _on_projectile_hit(hurtbox: Hurtbox, attack: AttackDefinition, instance: int, direction: Vector2) -> bool:
	if not is_instance_valid(hurtbox):
		return false
	var hit := _make_hit(hurtbox, attack, instance, direction, 0)
	if not hurtbox.receive_hit(hit):
		return false
	hit_landed.emit(hit)
	return true


# --- legacy tree (enemies) ---------------------------------------------------------

func _try_begin_action(input: InputFrame, aim: Vector2) -> void:
	if buffer.has(BUFFER_LIGHT):
		var attack := combo.resolve(AttackDefinition.InputType.LIGHT)
		if attack != null:
			buffer.clear()
			_start_attack(attack, aim, 0)
	elif buffer.has(BUFFER_HEAVY) or (_heavy_hold_pending and input.heavy_held):
		var heavy := combo.resolve(AttackDefinition.InputType.HEAVY)
		if heavy != null:
			buffer.clear()
			_heavy_hold_pending = false
			_begin_charge(heavy, input, aim)


func _begin_charge(attack: AttackDefinition, input: InputFrame, aim: Vector2) -> void:
	if state == State.ATTACKING:
		_clear_attack()   # charging cancels the previous attack's recovery
	state = State.CHARGING
	charging_attack = attack
	charge_time = 0.0
	charge_tier = 0
	combo.paused = true
	charge_started.emit(attack)
	if not input.heavy_held:
		_release_charge(aim)   # tap: released before the charge could start


func _step_charge(delta: float, input: InputFrame, aim: Vector2) -> void:
	charge_time += delta
	var tier := charging_attack.charge_profile.get_tier(charge_time)
	if tier != charge_tier:
		charge_tier = tier
		charge_tier_changed.emit(tier)
	if not input.heavy_held:
		_release_charge(aim)


func _release_charge(aim: Vector2) -> void:
	var attack := charging_attack
	var tier := attack.charge_profile.get_tier(charge_time)
	charging_attack = null
	charge_time = 0.0
	combo.paused = false
	state = State.IDLE
	_start_attack(attack, aim, tier)


func _start_attack(attack: AttackDefinition, aim: Vector2, tier: int) -> void:
	if state == State.ATTACKING:
		_clear_attack()   # chain: the follow-up cancels the previous recovery
	if not attack.is_flow():
		combo.commit(attack)
	attack_instance += 1
	current_attack = attack
	_speed = effective_speed(attack)
	_recovery = recovery_multiplier
	_lunge_left = attack.lunge_distance
	charge_tier = tier
	state = State.ATTACKING
	phase = Phase.STARTUP
	phase_time = 0.0
	if aim != Vector2.ZERO:
		attack_direction = aim.normalized()
	if hitbox != null:
		hitbox.deactivate()
		hitbox.configure(get_reach(attack, tier), attack.arc_degrees, attack_direction)
		hitbox.configure_limits(attack.max_hits_per_target, attack.rehit_interval / _speed, attack.max_targets)
		hitbox.clock = 0.0
		hitbox.armed = not attack.is_projectile()
	attack_started.emit(attack, tier)
	attack_phase_changed.emit(attack, phase)


func _step_attack(delta: float) -> void:
	phase_time += delta
	while state == State.ATTACKING and phase_time >= _phase_duration() - 0.00001:
		phase_time -= _phase_duration()
		_enter_next_phase()
	if state == State.ATTACKING and phase == Phase.ACTIVE:
		_scan_hits()


func _enter_next_phase() -> void:
	match phase:
		Phase.STARTUP:
			phase = Phase.ACTIVE
			if current_attack.is_projectile():
				attack_phase_changed.emit(current_attack, phase)
				_fire_projectiles()
				return
			if hitbox != null:
				hitbox.activate()
			attack_phase_changed.emit(current_attack, phase)
			# Scan on entry so even a window shorter than one tick can connect.
			_scan_hits()
		Phase.ACTIVE:
			phase = Phase.RECOVERY
			if hitbox != null:
				hitbox.deactivate()
			attack_phase_changed.emit(current_attack, phase)
		Phase.RECOVERY:
			var attack := current_attack
			_clear_attack()
			if attack.is_flow():
				# Recovery over: the chain closes, a buffered input is dropped.
				combo.path.clear()
				_close_chain()
			else:
				combo.open_window(attack.combo_window)
			attack_finished.emit(attack)


func _phase_duration() -> float:
	return phase_duration()


## Duration of the current phase of the running attack, attack speed applied.
func phase_duration() -> float:
	if current_attack == null:
		return 0.0
	match phase:
		Phase.STARTUP:
			return _startup_duration()
		Phase.ACTIVE:
			return _active_duration()
		Phase.RECOVERY:
			return _recovery_duration()
	return 0.0


## 0..1 progress through the current phase (views animate with it).
func phase_progress() -> float:
	return clampf(phase_time / maxf(phase_duration(), 0.001), 0.0, 1.0)


## Speed factor `attack` runs with: 1 + (attack_speed - 1) * attack_speed_scaling.
func effective_speed(attack: AttackDefinition) -> float:
	return maxf(0.1, 1.0 + (attack_speed - 1.0) * attack.attack_speed_scaling)


## Seconds the running attack takes in total (attack speed and recovery factor applied).
func current_total_duration() -> float:
	return _startup_duration() + _active_duration() + _recovery_duration() if current_attack != null else 0.0


func _can_chain() -> bool:
	return phase == Phase.RECOVERY and phase_time >= current_attack.chain_delay / _speed


func _clear_attack() -> void:
	if hitbox != null:
		hitbox.deactivate()
	current_attack = null
	_lunge_left = 0.0
	_speed = 1.0
	_recovery = 1.0
	state = State.IDLE
	phase = Phase.NONE
	phase_time = 0.0


func _scan_hits() -> void:
	if hitbox == null:
		return
	hitbox.clock = attack_clock()
	for hurtbox in hitbox.scan():
		var hit := _build_hit(hurtbox)
		if hurtbox.receive_hit(hit):
			hitbox.mark_hit(hurtbox)
			hit_landed.emit(hit)
		if state != State.ATTACKING:
			return   # a hit listener cancelled the attack; no further hits


func _build_hit(hurtbox: Hurtbox) -> HitData:
	return _make_hit(hurtbox, current_attack, attack_instance, attack_direction, charge_tier)


func _make_hit(hurtbox: Hurtbox, attack: AttackDefinition, instance: int, direction: Vector2, tier: int) -> HitData:
	var profile := attack.charge_profile
	var hit := HitData.new()
	hit.attacker = get_parent()
	hit.target = hurtbox.get_entity()
	hit.attack = attack
	hit.attack_instance_id = instance
	hit.charge_tier = tier
	hit.damage = attack.damage * (profile.damage_multiplier(tier) if profile else 1.0)
	hit.poise_damage = attack.poise_damage * (profile.poise_multiplier(tier) if profile else 1.0)
	hit.damage_type = attack.damage_type
	hit.knockback = direction * attack.knockback
	hit.hitstop = attack.hitstop * (profile.hitstop_multiplier(tier) if profile else 1.0)
	hit.reaction = attack.hit_reaction
	hit.reaction_duration = attack.reaction_duration
	hit.position = hurtbox.global_position
	hit.tags = attack.effect_tags.duplicate()
	for modifier in modifiers:
		if modifier.applies_to(attack):
			modifier.modify_hit(hit)
	return hit
