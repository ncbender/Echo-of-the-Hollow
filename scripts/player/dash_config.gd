class_name DashConfig
extends Resource

@export var max_charges: int = 2
## Seconds of dash movement.
@export var duration: float = 0.3
## Invulnerability window measured from dash start.
@export var iframe_duration: float = 0.18
## Seconds to regenerate one charge; charges regenerate one after another.
@export var recharge_time: float = 2.5
## Total distance covered by one dash in world pixels.
@export var distance: float = 110.0
