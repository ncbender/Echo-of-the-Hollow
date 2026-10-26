class_name Player
extends CharacterBody2D
## Composition root of the player character. Wires input into the movement, dash
## and combat components and moves the body. Gameplay rules live in the components.

signal weapon_equipped(weapon: WeaponFamily)
signal respawned

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
## Remaining local hitstop; while > 0 this character is frozen (others keep running).
var hitstop_left: float = 0.0
## Multiplier for incoming damage (armor etc.), set by the progression bridge.
var incoming_damage_multiplier: float = 1.0

var _external_frame := InputFrame.new()
var _locomotion_velocity: Vector2 = Vector2.ZERO
var _dash_buffer: InputBuffer
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


func _ready() -> void:
	_dash_buffer = InputBuffer.new(input_buffer_time)
	knockback.deceleration = knockback_decay
	combat.input_buffer_time = input_buffer_time
	combat.buffer.window = input_buffer_time
	add_to_group(&"player")
	_spawn_position = global_position
	hurtbox.invulnerability_check = func() -> bool: return dash.is_invulnerable() or health.is_dead()
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
	weapon_equipped.emit(family)
	return true


## Local hitstop: freezes only this character. Overlapping requests never add up.
func apply_hitstop(duration: float) -> void:
	hitstop_left = maxf(hitstop_left, duration)


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
	if frame.dash_pressed:
		_dash_buffer.push(DASH_BUFFER_ACTION)
	if _dash_buffer.has(DASH_BUFFER_ACTION) and dash.can_dash() and combat.can_dash_cancel() \
			and not reaction.blocks_dash():
		_dash_buffer.clear()
		combat.cancel(&"dash")
		_start_dash()

	combat.step(delta, frame, aim_direction, dash.is_dashing() or reaction.blocks_actions())

	if dash.is_dashing():
		velocity = dash.get_velocity()
		# Leave the dash at running speed instead of ramping up from zero.
		_locomotion_velocity = movement.full_speed_velocity(dash.direction)
	else:
		var move_input := Vector2.ZERO if reaction.blocks_movement() else frame.move
		_locomotion_velocity = movement.compute_velocity(
				_locomotion_velocity, move_input, combat.get_move_multiplier(), delta)
		velocity = _locomotion_velocity + combat.take_lunge_velocity(delta)
	velocity += knockback.step(delta)
	velocity = BodyContact.strip_push(self, velocity, delta)
	move_and_slide()


func _step_frozen(frame: InputFrame, delta: float) -> void:
	hitstop_left = maxf(0.0, hitstop_left - delta)
	combat.record_inputs(frame)
	if frame.dash_pressed:
		_dash_buffer.push(DASH_BUFFER_ACTION)
	velocity = Vector2.ZERO


## Design rule (Combat Polish 0.2): the dash always goes where the character faces,
## i.e. towards the mouse; WASD is ignored. aim_direction is the last valid aim, so
## a cursor on top of the character keeps the previous facing. DashComponent keeps
## the direction fixed for the whole dash.
func _start_dash() -> void:
	dash.try_start(aim_direction)


## Hits deal damage and knockback; the attack's reaction type decides whether the
## current action is interrupted (HitReactionComponent, docs/COMBAT_DESIGN.md).
func _on_hit_received(hit: HitData) -> void:
	hit.damage *= incoming_damage_multiplier
	health.apply_hit(hit)
	if health.is_dead():
		return
	var type := reaction.apply(hit, combat, dash)
	knockback.start(hit.knockback * reaction.knockback_multiplier(type))


func _on_died() -> void:
	combat.cancel(&"death")
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
