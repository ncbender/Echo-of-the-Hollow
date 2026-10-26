class_name TrainingDummy
extends StaticBody2D
## Stationary target. Takes hits through its Hurtbox, loses health and poise,
## and revives itself `revive_delay` seconds after being destroyed.

signal revived

@export var revive_delay: float = 1.5

var hits_taken: int = 0
var _revive_left: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox


func _ready() -> void:
	# Training targets give reduced, capped XP and no kill rewards.
	add_to_group(&"training_target")
	hurtbox.hit_received.connect(_on_hit_received)
	hurtbox.invulnerability_check = health.is_dead
	health.died.connect(_on_died)


func _on_hit_received(hit: HitData) -> void:
	hits_taken += 1
	health.apply_hit(hit)


func _on_died() -> void:
	_revive_left = revive_delay


func _physics_process(delta: float) -> void:
	if _revive_left <= 0.0:
		return
	_revive_left -= delta
	if _revive_left <= 0.0:
		health.reset()
		revived.emit()
