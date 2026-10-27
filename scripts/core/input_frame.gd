class_name InputFrame
extends RefCounted
## Player intent for one physics tick. Produced by PlayerInput from real devices,
## or built directly by tests and scripted playtests.

var move: Vector2 = Vector2.ZERO
## Normalized direction from the character towards the mouse cursor.
var aim_direction: Vector2 = Vector2.RIGHT
## Edge flags: true only on the tick the physical press/release happened.
var light_pressed: bool = false
var heavy_pressed: bool = false
var heavy_released: bool = false
var dash_pressed: bool = false
## Level flags: left / right mouse button currently held (the bow reads LMB for
## Flowing Draw and RMB for the Precision Stance).
var light_held: bool = false
var heavy_held: bool = false
## Level flag: G (interact) currently held - gathering continues only while held.
var interact_held: bool = false
## Active skill slot (Q/E/R/F = 0..3) pressed this tick, -1 = none.
var ability_slot: int = -1
## Shift (defensive): pressed this tick (edge) and currently held (level).
var defend_pressed: bool = false
var defend_held: bool = false
## Quick use (keys 1 / 2): Hearth Flask and the slotted special potion (edges).
var flask_pressed: bool = false
var potion_pressed: bool = false


## Clears one-shot flags after the frame was consumed; level state (move, aim, held) stays.
func clear_edges() -> void:
	light_pressed = false
	heavy_pressed = false
	heavy_released = false
	dash_pressed = false
	ability_slot = -1
	defend_pressed = false
	flask_pressed = false
	potion_pressed = false
