class_name Player
extends CharacterBody2D
## Composition root of the player character. Wires input into the movement, dash
## and combat components and moves the body. Gameplay rules live in the components.

signal weapon_equipped(weapon: WeaponFamily)

const DASH_BUFFER_ACTION := &"dash"

@export var input_buffer_time: float = 0.12
## Weapon loadout; slot keys 1/2 switch between entries.
@export var weapons: Array[WeaponFamily] = []

## When true, physics ticks consume frames given via feed_input() instead of devices
## (used by tests and scripted playtests).
var use_external_input: bool = false
var aim_direction: Vector2 = Vector2.RIGHT

var _external_frame := InputFrame.new()
var _locomotion_velocity: Vector2 = Vector2.ZERO
var _dash_buffer: InputBuffer

@onready var input: PlayerInput = $PlayerInput
@onready var movement: MovementComponent = $MovementComponent
@onready var dash: DashComponent = $DashComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	_dash_buffer = InputBuffer.new(input_buffer_time)
	combat.input_buffer_time = input_buffer_time
	combat.buffer.window = input_buffer_time
	hurtbox.invulnerability_check = dash.is_invulnerable
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
	if slot < 0 or slot >= weapons.size() or weapons[slot] == combat.weapon:
		return false
	if not combat.set_weapon(weapons[slot]):
		return false
	weapon_equipped.emit(weapons[slot])
	return true


func physics_step(frame: InputFrame, delta: float) -> void:
	if frame.aim_direction.length_squared() > 0.0001:
		aim_direction = frame.aim_direction.normalized()
	if frame.weapon_slot >= 0 and not dash.is_dashing():
		equip_weapon(frame.weapon_slot)

	dash.step(delta)
	_dash_buffer.step(delta)
	if frame.dash_pressed:
		_dash_buffer.push(DASH_BUFFER_ACTION)
	if _dash_buffer.has(DASH_BUFFER_ACTION) and dash.can_dash() and combat.can_dash_cancel():
		_dash_buffer.clear()
		combat.cancel(&"dash")
		_start_dash(frame)

	combat.step(delta, frame, aim_direction, dash.is_dashing())

	if dash.is_dashing():
		velocity = dash.get_velocity()
		# Leave the dash at running speed instead of ramping up from zero.
		_locomotion_velocity = movement.full_speed_velocity(dash.direction)
	else:
		_locomotion_velocity = movement.compute_velocity(
				_locomotion_velocity, frame.move, combat.get_move_multiplier(), delta)
		velocity = _locomotion_velocity + combat.get_lunge_velocity()
	move_and_slide()


func _start_dash(frame: InputFrame) -> void:
	# No movement input: dash backwards relative to the aim direction.
	var direction := frame.move if frame.move.length_squared() > 0.01 else -aim_direction
	dash.try_start(direction.normalized())
