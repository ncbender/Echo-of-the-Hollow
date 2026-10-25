class_name MovementConfig
extends Resource
## Base locomotion tuning. Action-specific speed multipliers live on the
## attack data (AttackDefinition.move_multiplier, ChargeProfile.move_multiplier).

@export var move_speed: float = 180.0
## px/s² towards the target velocity. High values keep movement immediate.
@export var acceleration: float = 4000.0
@export var deceleration: float = 5000.0
