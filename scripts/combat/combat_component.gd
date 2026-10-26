class_name CombatComponent
extends Node
## Action layer of a fighter: light/heavy input handling, heavy charging, attack
## phases, combo progression via ComboController and cancel rules.
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

signal attack_started(attack: AttackDefinition, charge_tier: int)
signal attack_phase_changed(attack: AttackDefinition, phase: Phase)
signal attack_finished(attack: AttackDefinition)
signal attack_cancelled(attack: AttackDefinition, reason: StringName)
signal charge_started(attack: AttackDefinition)
signal charge_tier_changed(tier: int)
signal charge_cancelled(reason: StringName)
signal hit_landed(hit: HitData)
signal weapon_changed(weapon: WeaponFamily)

@export var weapon: WeaponFamily
@export var hitbox: AttackHitbox
@export var input_buffer_time: float = 0.12
@export var modifiers: Array[AttackModifier] = []

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

## RMB went down and was not consumed yet; charging starts once free while still held.
var _heavy_hold_pending: bool = false
## Lunge distance the running attack may still cover (see take_lunge_velocity).
var _lunge_left: float = 0.0


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
	weapon_changed.emit(new_weapon)
	return true


func set_unlocked(requirement: StringName, unlocked: bool) -> void:
	if unlocked:
		combo.unlocks[requirement] = true
	else:
		combo.unlocks.erase(requirement)


func is_busy() -> bool:
	return state != State.IDLE


## Advances the action layer by one tick. While `blocked` (e.g. dashing) inputs are
## still buffered, but no new action starts.
func step(delta: float, input: InputFrame, aim: Vector2, blocked: bool = false) -> void:
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
## owner is frozen by hitstop, so clicks during a freeze are not lost).
func record_inputs(input: InputFrame) -> void:
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


func can_dash_cancel() -> bool:
	match state:
		State.ATTACKING:
			return (current_attack.dash_cancel_phases & PHASE_CANCEL_FLAGS[phase]) != 0
	return true


## Aborts the running action. Pending hits of the attack are discarded, already
## dealt damage stays. Ends the combo (design rule: dash ends the combo).
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


func get_move_multiplier() -> float:
	match state:
		State.CHARGING:
			return charging_attack.charge_profile.move_multiplier
		State.ATTACKING:
			return current_attack.move_multiplier
	return 1.0


## Forward lunge velocity during startup + active of attacks with lunge_distance
## (query only; movement uses take_lunge_velocity).
func get_lunge_velocity() -> Vector2:
	if state != State.ATTACKING or current_attack.lunge_distance <= 0.0 or _lunge_left <= 0.0:
		return Vector2.ZERO
	if phase != Phase.STARTUP and phase != Phase.ACTIVE:
		return Vector2.ZERO
	var lunge_time := current_attack.startup + current_attack.active
	return attack_direction * current_attack.lunge_distance / lunge_time


## Lunge velocity for this movement tick. Consumes the attack's lunge budget, so a
## swing never covers more than lunge_distance even when the active phase ends
## mid-tick (blocked movement still consumes it - nothing is saved up).
func take_lunge_velocity(delta: float) -> Vector2:
	var velocity := get_lunge_velocity()
	if velocity == Vector2.ZERO or delta <= 0.0:
		return Vector2.ZERO
	var travel := minf(velocity.length() * delta, _lunge_left)
	_lunge_left -= travel
	return attack_direction * (travel / delta)


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
	combo.commit(attack)
	attack_instance += 1
	current_attack = attack
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
		hitbox.armed = true
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
			combo.open_window(attack.combo_window)
			attack_finished.emit(attack)


func _phase_duration() -> float:
	match phase:
		Phase.STARTUP:
			return current_attack.startup
		Phase.ACTIVE:
			return current_attack.active
		Phase.RECOVERY:
			return current_attack.recovery
	return 0.0


func _can_chain() -> bool:
	return phase == Phase.RECOVERY and phase_time >= current_attack.chain_delay


func _clear_attack() -> void:
	if hitbox != null:
		hitbox.deactivate()
	current_attack = null
	_lunge_left = 0.0
	state = State.IDLE
	phase = Phase.NONE
	phase_time = 0.0


func _scan_hits() -> void:
	if hitbox == null:
		return
	for hurtbox in hitbox.scan():
		var hit := _build_hit(hurtbox)
		if hurtbox.receive_hit(hit):
			hitbox.mark_hit(hurtbox)
			hit_landed.emit(hit)
		if state != State.ATTACKING:
			return   # a hit listener cancelled the attack; no further hits


func _build_hit(hurtbox: Hurtbox) -> HitData:
	var attack := current_attack
	var profile := attack.charge_profile
	var hit := HitData.new()
	hit.attacker = get_parent()
	hit.target = hurtbox.get_entity()
	hit.attack = attack
	hit.attack_instance_id = attack_instance
	hit.charge_tier = charge_tier
	hit.damage = attack.damage * (profile.damage_multiplier(charge_tier) if profile else 1.0)
	hit.poise_damage = attack.poise_damage * (profile.poise_multiplier(charge_tier) if profile else 1.0)
	hit.damage_type = attack.damage_type
	hit.knockback = attack_direction * attack.knockback
	hit.hitstop = attack.hitstop * (profile.hitstop_multiplier(charge_tier) if profile else 1.0)
	hit.reaction = attack.hit_reaction
	hit.reaction_duration = attack.reaction_duration
	hit.position = hurtbox.global_position
	hit.tags = attack.effect_tags.duplicate()
	for modifier in modifiers:
		if modifier.applies_to(attack):
			modifier.modify_hit(hit)
	return hit
