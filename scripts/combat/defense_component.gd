class_name DefenseComponent
extends Node
## Block & Parry on Shift (docs/COMBAT_DESIGN.md "Block & Parry"). Generic: all
## values come from the active DefenseProfile (shield > weapon).
##
## States:  IDLE --press--> PARRY (parry_window)
##          PARRY --window over, Shift held, profile can block--> BLOCK
##          PARRY --window over, released--> RECOVERY (parry_recovery, a whiff)
##          BLOCK --release--> RECOVERY (block_recovery)
##          PARRY --successful parry--> IDLE + counter window (attack right away)
##          any --dash, interrupting hit reaction, death--> IDLE (cancel)
## Holding Shift never opens a new parry window; a new parry needs a new press
## and the anti-spam parry_cooldown. While defending, attacks and skills cannot
## start (the owner asks blocks_actions()) and movement is slowed.
## Starting a defense follows the dash-cancel rule of the running attack, so it
## never creates a cancel that was not possible before.
##
## Incoming hits are resolved in resolve() BEFORE damage (Hurtbox.hit_filter):
## only hits from the defended front sector count; unblockable hits ignore the
## defense; guard-breaking hits break a block; a hit that already landed can
## never be parried afterwards (resolution happens only at hit time).

enum State { IDLE, PARRY, BLOCK, RECOVERY }
enum Outcome { NONE, BLOCKED, PARRIED, GUARD_BROKEN }

signal parried(hit: HitData)
signal blocked(hit: HitData)
signal guard_broken(hit: HitData)
## Shift pressed and a parry window opened.
signal parry_started

## Profile of the equipped weapon family (set by the owner).
var weapon_profile: DefenseProfile
## Profile of an equipped shield; overrides the weapon's (set by the bridge).
var shield_profile: DefenseProfile
var state: State = State.IDLE
var state_left: float = 0.0
var cooldown_left: float = 0.0
## Remaining counter window after a successful parry.
var counter_left: float = 0.0
var last_outcome: Outcome = Outcome.NONE
var _press_buffer := InputBuffer.new(0.12)
var counter_modifier := CounterModifier.new()


func _init() -> void:
	counter_modifier.defense = weakref(self)


func profile() -> DefenseProfile:
	return shield_profile if shield_profile != null else weapon_profile


func is_defending() -> bool:
	return state == State.PARRY or state == State.BLOCK


func blocks_actions() -> bool:
	return state != State.IDLE


func move_multiplier() -> float:
	var active := profile()
	return active.move_multiplier if is_defending() and active != null else 1.0


## One tick. `can_start`: the owner allows starting a defense now (not dashing,
## not in a skill movement or lockout, attack cancellable like a dash).
func step(delta: float, pressed: bool, held: bool, can_start: bool) -> bool:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	counter_left = maxf(0.0, counter_left - delta)
	_press_buffer.step(delta)
	if pressed:
		_press_buffer.push(&"defend")
	var active := profile()
	match state:
		State.PARRY:
			state_left -= delta
			if state_left <= 0.00001:
				if held and active.can_block:
					_enter(State.BLOCK, 0.0)
				else:
					_enter(State.RECOVERY, active.parry_recovery)
		State.BLOCK:
			if not held:
				_enter(State.RECOVERY, active.block_recovery)
		State.RECOVERY:
			state_left -= delta
			if state_left <= 0.00001:
				_enter(State.IDLE, 0.0)
	if state == State.IDLE and active != null and can_start and cooldown_left <= 0.0 \
			and _press_buffer.has(&"defend"):
		_press_buffer.clear()
		cooldown_left = active.parry_cooldown
		_enter(State.PARRY, active.parry_window)
		parry_started.emit()
		return true
	return false


## Dash, interrupting reactions, death: defense ends at once (no recovery).
func cancel() -> void:
	_press_buffer.clear()
	_enter(State.IDLE, 0.0)


## Decides what happens to `hit` before it deals damage and changes it
## accordingly (damage, knockback, reaction, tags). `facing` = owner's aim.
func resolve(hit: HitData, defender_position: Vector2, facing: Vector2) -> Outcome:
	last_outcome = Outcome.NONE
	var active := profile()
	if active == null or not is_defending() or hit.attack == null:
		return Outcome.NONE
	var flags := hit.attack.defense_flags
	if flags & (AttackDefinition.DEFENSE_BLOCKABLE | AttackDefinition.DEFENSE_PARRYABLE) == 0:
		hit.tags.append(&"unblockable")
		return Outcome.NONE
	var from := defender_position
	if hit.attacker is Node2D and is_instance_valid(hit.attacker):
		from = (hit.attacker as Node2D).global_position
	var to_attacker := from - defender_position
	var angle := absf(facing.angle_to(to_attacker)) if to_attacker.length() > 0.5 else 0.0
	if state == State.PARRY and flags & AttackDefinition.DEFENSE_PARRYABLE \
			and angle <= deg_to_rad(active.parry_arc_degrees) * 0.5:
		_parry(hit, active)
		return Outcome.PARRIED
	if not active.can_block or flags & AttackDefinition.DEFENSE_BLOCKABLE == 0 \
			or angle > deg_to_rad(active.block_arc_degrees) * 0.5:
		return Outcome.NONE
	if flags & AttackDefinition.DEFENSE_GUARD_BREAK:
		hit.tags.append(&"guard_break")
		_enter(State.RECOVERY, active.guard_break_recovery)
		last_outcome = Outcome.GUARD_BROKEN
		guard_broken.emit(hit)
		return Outcome.GUARD_BROKEN
	hit.damage *= 1.0 - active.block_reduction
	hit.knockback *= active.block_knockback_multiplier
	hit.reaction = mini(hit.reaction, HitReaction.Type.FLINCH) as HitReaction.Type
	hit.tags.append(&"blocked")
	last_outcome = Outcome.BLOCKED
	_answer(hit, active.block_poise_damage, &"blocked_by")
	blocked.emit(hit)
	return Outcome.BLOCKED


func _parry(hit: HitData, active: DefenseProfile) -> void:
	hit.damage = 0.0
	hit.knockback = Vector2.ZERO
	hit.reaction = HitReaction.Type.NONE
	hit.tags.append(&"parried")
	last_outcome = Outcome.PARRIED
	counter_left = active.counter_window
	_enter(State.IDLE, 0.0)   # free to counter-attack right away
	_answer(hit, active.parry_poise_damage, &"parried_by")
	if hit.attacker != null and is_instance_valid(hit.attacker) and hit.attacker.has_method(&"on_parried"):
		hit.attacker.call(&"on_parried")
	parried.emit(hit)


## Poise damage back to the attacker (its own resistance applies there).
func _answer(hit: HitData, poise: float, tag: StringName) -> void:
	if poise <= 0.0 or hit.attacker == null or not is_instance_valid(hit.attacker):
		return
	var hurtbox := hit.attacker.get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox == null:
		return
	var answer := HitData.new()
	answer.attacker = hit.target
	answer.source = HitData.Source.TRIGGERED
	answer.depth = 1
	answer.poise_damage = poise
	var config: Variant = hit.attacker.get(&"config")
	if config is EnemyConfig and tag == &"parried_by":
		answer.poise_damage *= (config as EnemyConfig).parry_poise_multiplier
	answer.tags.append(tag)
	answer.position = hurtbox.global_position
	hurtbox.receive_hit(answer)


func _enter(new_state: State, duration: float) -> void:
	state = new_state
	state_left = duration


## Weapon hits during the counter window after a parry deal extra damage once.
class CounterModifier:
	extends AttackModifier

	var defense: WeakRef

	func modify_hit(hit: HitData) -> void:
		var owner: DefenseComponent = defense.get_ref()
		if owner == null or owner.counter_left <= 0.0 or not hit.is_direct():
			return
		var active := owner.profile()
		hit.damage *= active.counter_damage_multiplier if active != null else 1.0
		hit.tags.append(&"counter")
		owner.counter_left = 0.0
