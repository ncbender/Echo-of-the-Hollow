class_name Player
extends CharacterBody2D
## Composition root of the player character. Wires input into the movement, dash
## and combat components and moves the body. Gameplay rules live in the components.

signal weapon_equipped(weapon: WeaponFamily)
signal respawned
## A skill movement ended: completed = covered its distance, false = interrupted.
signal skill_motion_finished(completed: bool)
## A drink (Hearth Flask, potion) ended: completed = its effect happened, false = interrupted.
signal use_finished(completed: bool)

const DASH_BUFFER_ACTION := &"dash"

@export var input_buffer_time: float = 0.12
## Weapon loadout; slot keys 1/2 switch between entries (when no character
## progression controls the weapon, see weapon_slot_handler).
@export var weapons: Array[WeaponFamily] = []
## Prototype: seconds until the player stands up again at the spawn point after dying.
@export var respawn_delay: float = 1.5
## Deceleration (px/s²) of knockback received from enemy hits; distance comes from the hit.
@export var knockback_decay: float = 900.0

## When true, physics ticks consume frames given via feed_input() instead of devices
## (used by tests and scripted playtests).
var use_external_input: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
## Optional override for weapon slot keys (1/2). Receives the slot index.
var weapon_slot_handler: Callable
## Active skills (Q/E/R/F): receives the slot index, returns true when a skill
## was cast (set by the progression bridge; the player knows no skills itself).
var ability_handler: Callable
## Remaining skill cast lock: no attacks or other skills meanwhile (see begin_skill).
var skill_lock_left: float = 0.0
var skill_move_multiplier: float = 1.0
## Remaining local hitstop; while > 0 this character is frozen (others keep running).
var hitstop_left: float = 0.0
## Multiplier for incoming damage (armor etc.), set by the progression bridge.
var incoming_damage_multiplier: float = 1.0
## Normal walking speed factor from stats (Movement Speed %, armour burden) -
## never applied to the dash, skill motions or knockback.
var move_speed_multiplier: float = 1.0
## Quick use (keys 1 / 2): receives 0 = flask, 1 = potion; returns true when a
## drink started (set by the progression bridge; the player knows no items).
var consumable_handler: Callable
## Remaining drink time (begin_use); attacks, skills and blocking are locked meanwhile.
var use_left: float = 0.0
var use_move_multiplier: float = 1.0
var _use_done: Callable

var _external_frame := InputFrame.new()
var _locomotion_velocity: Vector2 = Vector2.ZERO
var _dash_buffer: InputBuffer
var _ability_buffer: InputBuffer
var _motion_velocity: Vector2 = Vector2.ZERO
var _motion_left: float = 0.0
var _motion_distance_left: float = 0.0
var _motion_arrived: bool = false
var knockback := KnockbackMotion.new()
var _spawn_position: Vector2
var _respawn_left: float = 0.0

@onready var input: PlayerInput = $PlayerInput
@onready var movement: MovementComponent = $MovementComponent
@onready var dash: DashComponent = $DashComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: HealthComponent = $HealthComponent
@onready var reaction: HitReactionComponent = $HitReactionComponent
## Block & parry on Shift (created in _ready; profile from weapon or shield).
var defense: DefenseComponent


func _ready() -> void:
	_dash_buffer = InputBuffer.new(input_buffer_time)
	_ability_buffer = InputBuffer.new(input_buffer_time)
	defense = DefenseComponent.new()
	defense.name = "DefenseComponent"
	add_child(defense)
	combat.modifiers.append(defense.counter_modifier)
	combat.hit_landed.connect(_on_hit_landed_sound)
	defense.parried.connect(_on_parried)
	defense.blocked.connect(_on_blocked)
	defense.guard_broken.connect(_on_guard_broken)
	knockback.deceleration = knockback_decay
	combat.input_buffer_time = input_buffer_time
	combat.buffer.window = input_buffer_time
	add_to_group(&"player")
	_spawn_position = global_position
	hurtbox.invulnerability_check = func() -> bool: return dash.is_invulnerable() or health.is_dead()
	hurtbox.hit_filter = _filter_incoming_hit
	hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	if not weapons.is_empty():
		equip_weapon(0)


func _physics_process(delta: float) -> void:
	var frame := _external_frame if use_external_input else input.poll(self)
	physics_step(frame, delta)
	if use_external_input:
		_external_frame.clear_edges()


## Replaces the externally fed intent; edge flags are consumed by the next tick.
func feed_input(frame: InputFrame) -> void:
	use_external_input = true
	_external_frame = frame


## Switches to a loadout slot. Only possible while no action is running.
func equip_weapon(slot: int) -> bool:
	if slot < 0 or slot >= weapons.size():
		return false
	return set_weapon_family(weapons[slot])


## Sets the active combat weapon family. Only possible while no action is running.
func set_weapon_family(family: WeaponFamily) -> bool:
	if family == null or family == combat.weapon:
		return false
	if not combat.set_weapon(family):
		return false
	defense.weapon_profile = family.defense_profile
	weapon_equipped.emit(family)
	return true


## Local hitstop: freezes only this character. Overlapping requests never add up.
func apply_hitstop(duration: float) -> void:
	hitstop_left = maxf(hitstop_left, duration)


## Seconds until a downed player rises again (HUD death overlay).
func respawn_time_left() -> float:
	return _respawn_left if health.is_dead() else 0.0


func set_spawn_position(position_: Vector2) -> void:
	_spawn_position = position_


func physics_step(frame: InputFrame, delta: float) -> void:
	if health.is_dead():
		_step_down(delta)
		return
	if frame.aim_direction.length_squared() > 0.0001:
		aim_direction = frame.aim_direction.normalized()
	if hitstop_left > 0.0:
		_step_frozen(frame, delta)
		return
	if frame.weapon_slot >= 0 and not dash.is_dashing():
		if weapon_slot_handler.is_valid():
			weapon_slot_handler.call(frame.weapon_slot)
		else:
			equip_weapon(frame.weapon_slot)

	reaction.step(delta)
	dash.step(delta)
	_dash_buffer.step(delta)
	skill_lock_left = maxf(0.0, skill_lock_left - delta)
	if frame.dash_pressed:
		_dash_buffer.push(DASH_BUFFER_ACTION)
	if _dash_buffer.has(DASH_BUFFER_ACTION) and dash.can_dash() and combat.can_dash_cancel() \
			and not reaction.blocks_dash() and not is_in_skill_motion():
		_dash_buffer.clear()
		combat.cancel(&"dash")
		skill_lock_left = 0.0   # a dash ends the cast lock (the skill already happened)
		defense.cancel()        # and any block/parry (no iFrame overlap, no stacking)
		cancel_use()            # and a drink (nothing is consumed)
		_start_dash(frame.move)

	if defense.step(delta, frame.defend_pressed, frame.defend_held, can_start_defense()):
		combat.cancel(&"defend")   # same cancel rule as a dash (see can_start_defense)

	_step_use(frame, delta)
	_step_abilities(frame, delta)
	combat.step(delta, frame, aim_direction, dash.is_dashing() or reaction.blocks_actions() \
			or skill_lock_left > 0.0 or is_in_skill_motion() or defense.blocks_actions() or is_using())

	if dash.is_dashing():
		velocity = dash.get_velocity()
		# Leave the dash at running speed instead of ramping up from zero.
		_locomotion_velocity = movement.full_speed_velocity(dash.direction)
	elif is_in_skill_motion():
		# Exact distance like the attack lunge: never more than the skill asked for.
		var travel := minf(_motion_velocity.length() * delta, _motion_distance_left)
		_motion_distance_left -= travel
		if _motion_distance_left <= 0.001:
			_motion_left = 0.0
			_motion_arrived = true
		else:
			_motion_left = maxf(_motion_left - delta, 0.0001)
		velocity = _motion_velocity.normalized() * travel / delta if delta > 0.0 else Vector2.ZERO
		_locomotion_velocity = Vector2.ZERO
	else:
		var move_input := Vector2.ZERO if reaction.blocks_movement() else frame.move
		var multiplier := combat.get_move_multiplier()
		if skill_lock_left > 0.0:
			multiplier = minf(multiplier, skill_move_multiplier)
		multiplier = minf(multiplier, defense.move_multiplier())
		if is_using():
			multiplier = minf(multiplier, use_move_multiplier)
		multiplier *= move_speed_multiplier
		_locomotion_velocity = movement.compute_velocity(_locomotion_velocity, move_input, multiplier, delta)
		velocity = _locomotion_velocity + combat.take_lunge_velocity(delta)
	velocity += knockback.step(delta)
	velocity = BodyContact.strip_push(self, velocity, delta)
	move_and_slide()
	if _motion_arrived:
		_motion_arrived = false
		skill_motion_finished.emit(true)


func _step_frozen(frame: InputFrame, delta: float) -> void:
	hitstop_left = maxf(0.0, hitstop_left - delta)
	combat.record_inputs(frame)
	if frame.dash_pressed:
		_dash_buffer.push(DASH_BUFFER_ACTION)
	if frame.defend_pressed:
		defense.step(0.0, true, frame.defend_held, false)   # keep the press buffered
	if frame.ability_slot >= 0:
		_ability_buffer.push(StringName(str(frame.ability_slot)))
	velocity = Vector2.ZERO


## Skill inputs share the 120 ms buffer rule of attacks and dash. The handler
## (class runtime) decides whether the skill can be cast; the player only asks
## whether an action may start now.
func _step_abilities(frame: InputFrame, delta: float) -> void:
	_ability_buffer.step(delta)
	if frame.ability_slot >= 0:
		_ability_buffer.push(StringName(str(frame.ability_slot)))
	var buffered := _ability_buffer.peek()
	if buffered == &"" or not ability_handler.is_valid() or not can_start_skill():
		return
	if ability_handler.call(int(String(buffered))):
		_ability_buffer.clear()


## A skill may start when an attack could be dash-cancelled right now (same
## cancel rules), outside dashes, skill motions, cast locks, drinks and hit lockouts.
func can_start_skill() -> bool:
	return not health.is_dead() and not dash.is_dashing() and not is_in_skill_motion() \
			and skill_lock_left <= 0.0 and not reaction.blocks_actions() and combat.can_dash_cancel() \
			and not defense.blocks_actions() and not is_using()


# --- quick use: Hearth Flask and potions (Consumables 1.0) ------------------------

## Keys 1 / 2 ask the handler (progression bridge) whether a drink starts; the
## running drink completes after its time (then `_use_done` applies the effect).
func _step_use(frame: InputFrame, delta: float) -> void:
	if (frame.flask_pressed or frame.potion_pressed) and consumable_handler.is_valid() and can_start_skill():
		consumable_handler.call(0 if frame.flask_pressed else 1)
	if use_left <= 0.0:
		return
	use_left -= delta
	if use_left <= 0.0:
		use_left = 0.0
		var done := _use_done
		_use_done = Callable()
		if done.is_valid():
			done.call()
		use_finished.emit(true)


## Starts a drink: cancels the running attack and block, then for `duration`
## no attacks, skills or blocking and walking at `move_multiplier`. `on_done`
## runs when the drink completes - never when it is interrupted.
func begin_use(duration: float, move_multiplier: float, on_done: Callable) -> void:
	combat.cancel(&"use")
	defense.cancel()
	use_left = maxf(0.001, duration)
	use_move_multiplier = move_multiplier
	_use_done = on_done


## Interrupts a running drink (dash, stagger, death, scene change): no effect, nothing consumed.
func cancel_use() -> void:
	if use_left <= 0.0:
		return
	use_left = 0.0
	_use_done = Callable()
	use_finished.emit(false)


func is_using() -> bool:
	return use_left > 0.0


## Starts a skill action: cancels the running attack/charge (like a dash cancel)
## and locks attacks and skills for `lock` seconds at `move_multiplier` speed.
func begin_skill(lock: float, move_multiplier: float) -> void:
	combat.cancel(&"skill")
	skill_lock_left = maxf(0.0, lock)
	skill_move_multiplier = move_multiplier


## Skill movement (Blade Rush, Shadowstep ...): fixed velocity for `duration`,
## blocked by walls and bodies like walking. Separate from the dash: no dash
## charges, no dash iFrames, no dash cancel while it runs.
func start_skill_motion(motion_velocity: Vector2, duration: float) -> void:
	_motion_velocity = motion_velocity
	_motion_left = duration
	_motion_distance_left = motion_velocity.length() * duration


func stop_skill_motion() -> void:
	var was_moving := is_in_skill_motion()
	_motion_left = 0.0
	_motion_distance_left = 0.0
	_motion_arrived = false
	if was_moving:
		skill_motion_finished.emit(false)


func is_in_skill_motion() -> bool:
	return _motion_left > 0.0


## Design rule (Combat Polish 0.2): the dash always goes where the character faces,
## i.e. towards the mouse; WASD is ignored. aim_direction is the last valid aim, so
## a cursor on top of the character keeps the previous facing. DashComponent keeps
## the direction fixed for the whole dash.
## Dash direction rule (docs/COMBAT_DESIGN.md): WASD movement first, else the
## facing towards the mouse - see DashComponent.direction_for.
func _start_dash(move: Vector2) -> void:
	dash.try_start(DashComponent.direction_for(move, aim_direction))


## Hits deal damage and knockback; the attack's reaction type decides whether the
## current action is interrupted (HitReactionComponent, docs/COMBAT_DESIGN.md).
func _on_hit_received(hit: HitData) -> void:
	hit.damage *= incoming_damage_multiplier
	health.apply_hit(hit)
	if health.is_dead():
		return
	var type := reaction.apply(hit, combat, dash)
	if type >= HitReaction.Type.INTERRUPT:
		skill_lock_left = 0.0
		stop_skill_motion()
		cancel_use()
		if defense.is_defending():
			defense.cancel()
	knockback.start(hit.knockback * reaction.knockback_multiplier(type))


func _on_died() -> void:
	combat.cancel(&"death")
	cancel_use()
	defense.cancel()
	stop_skill_motion()
	skill_lock_left = 0.0
	_respawn_left = respawn_delay


func _step_down(delta: float) -> void:
	velocity = Vector2.ZERO
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		global_position = _spawn_position
		knockback.stop()
		hitstop_left = 0.0
		health.reset()
		respawned.emit()


## Block/parry may start whenever a dash could cancel the current action (so it
## never adds a cancel the combo system did not allow), outside dashes, skill
## movements, cast locks and hit lockouts.
func can_start_defense() -> bool:
	return not health.is_dead() and not dash.is_dashing() and not is_in_skill_motion() \
			and skill_lock_left <= 0.0 and not reaction.blocks_actions() and combat.can_dash_cancel() and not is_using()


## Hurtbox.hit_filter: block/parry resolve the hit before damage, numbers and reactions.
func _filter_incoming_hit(hit: HitData) -> void:
	defense.resolve(hit, global_position, aim_direction)


# --- Defense and hit feedback (CombatFx visuals, CombatAudio sounds) --------------

func _defense_fx_point() -> Vector2:
	return global_position + aim_direction * 8.0 + Vector2(0, -3)


func _on_parried(_hit: HitData) -> void:
	CombatAudio.play(self, defense.profile().parry_sound if defense.profile() != null else &"parry")
	var world := CombatFx.world_of(self)
	CombatFx.spawn(world, _defense_fx_point(), CombatFx.Style.STAR, Color(1.0, 0.97, 0.8), 18.0, 0.35)
	CombatFx.spawn(world, _defense_fx_point(), CombatFx.Style.FLASH, Color(1.0, 1.0, 0.9), 10.0, 0.18)
	var label := CombatFx.spawn(world, global_position, CombatFx.Style.TEXT, Color(1.0, 0.95, 0.6), 0.0, 0.6)
	label.text = "PARRY"


func _on_blocked(_hit: HitData) -> void:
	var profile := defense.profile()
	CombatAudio.play(self, profile.block_sound if profile != null else &"block")
	CombatFx.spawn(CombatFx.world_of(self), _defense_fx_point(), CombatFx.Style.SPARKS,
			profile.color if profile != null else Color.WHITE, 10.0, 0.22)


func _on_guard_broken(_hit: HitData) -> void:
	CombatAudio.play(self, &"guard_break")
	var world := CombatFx.world_of(self)
	CombatFx.spawn(world, _defense_fx_point(), CombatFx.Style.SPARKS, Color(1.0, 0.45, 0.3), 14.0, 0.3)
	var label := CombatFx.spawn(world, global_position, CombatFx.Style.TEXT, Color(1.0, 0.5, 0.35), 0.0, 0.7)
	label.text = "GUARD BREAK"


## Weapon hits of the player (one sound per swing: CombatAudio throttles repeats).
func _on_hit_landed_sound(hit: HitData) -> void:
	var heavy := hit.attack != null and hit.attack.input_type == AttackDefinition.InputType.HEAVY
	CombatAudio.play(self, &"hit_heavy" if heavy else &"hit_light", hit.position)
