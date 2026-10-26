class_name KnockbackMotion
extends RefCounted
## The one knockback model shared by player and enemies (docs/COMBAT_DESIGN.md).
##
## A knockback is a *distance* in world pixels: HitData.knockback = attack direction
## * AttackDefinition.knockback, scaled once by the receiver (enemy resistance or
## player reaction multiplier) and handed to start(). The distance is covered with
## constant deceleration, so the body travels exactly that far - or less, because
## the owner moves it with move_and_slide: walls and other characters absorb the
## rest instead of storing it. There is no separate speed scale.

## px/s²; decides how quickly the distance is covered, never how far.
var deceleration: float = 1000.0

## Debug: offset of the last start() (after resistance) and the distance the body
## actually moved since then (record() feeds it).
var last_offset: Vector2 = Vector2.ZERO
var last_traveled: float = 0.0

## direction * distance still to cover.
var _remaining: Vector2 = Vector2.ZERO


func _init(deceleration_: float = 1000.0) -> void:
	deceleration = deceleration_


## Adds a knockback. Overlapping hits add their offsets (no speed multiplication).
func start(offset: Vector2) -> void:
	if offset.length_squared() < 0.0001:
		return
	_remaining += offset
	last_offset = _remaining
	last_traveled = 0.0


func is_active() -> bool:
	return _remaining.length_squared() > 0.0001


func remaining() -> Vector2:
	return _remaining


func stop() -> void:
	_remaining = Vector2.ZERO


## Velocity for this tick; consumes the planned step whether or not the body can
## move (a wall in the way swallows the knockback, nothing is kept for later).
func step(delta: float) -> Vector2:
	if not is_active() or delta <= 0.0:
		return Vector2.ZERO
	var distance := _remaining.length()
	var speed := sqrt(2.0 * deceleration * distance)
	var travel := minf(speed * delta, distance)
	var velocity := _remaining / distance * (travel / delta)
	_remaining = _remaining / distance * (distance - travel) if travel < distance else Vector2.ZERO
	return velocity


## Debug measurement: actual motion of the body during a knockback tick.
func record(motion: Vector2) -> void:
	last_traveled += motion.length()
