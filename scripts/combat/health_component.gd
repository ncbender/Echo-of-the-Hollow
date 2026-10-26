class_name HealthComponent
extends Node
## Health and poise (Haltung). Poise breaks when it reaches zero, which staggers
## the entity for `stagger_duration`; poise then refills.

signal health_changed(current: float, maximum: float)
signal damaged(hit: HitData)
signal poise_broken
signal died

@export var max_health: float = 100.0
@export var max_poise: float = 40.0
@export var stagger_duration: float = 0.8
## Poise starts regenerating this long after the last poise damage.
@export var poise_regen_delay: float = 1.5
@export var poise_regen_rate: float = 25.0

var health: float = 0.0
var poise: float = 0.0
var stagger_left: float = 0.0
var _since_poise_damage: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	health = max_health
	poise = max_poise
	stagger_left = 0.0
	health_changed.emit(health, max_health)


## Changes max health (class/gear stats) keeping the current health ratio.
func set_max_health(value: float) -> void:
	value = maxf(1.0, value)
	if is_equal_approx(value, max_health):
		return
	var ratio := health / max_health if max_health > 0.0 else 1.0
	max_health = value
	if not is_dead():
		health = clampf(max_health * ratio, 1.0, max_health)
	health_changed.emit(health, max_health)


## Restores health (never above max, never revives).
func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func is_dead() -> bool:
	return health <= 0.0


func is_staggered() -> bool:
	return stagger_left > 0.0


func apply_hit(hit: HitData) -> void:
	if is_dead():
		return
	health = maxf(0.0, health - hit.damage)
	_since_poise_damage = 0.0
	if not is_staggered():
		poise -= hit.poise_damage
		if poise <= 0.0:
			poise = 0.0
			stagger_left = stagger_duration
			poise_broken.emit()
	damaged.emit(hit)
	health_changed.emit(health, max_health)
	if is_dead():
		died.emit()


func _physics_process(delta: float) -> void:
	if stagger_left > 0.0:
		stagger_left -= delta
		if stagger_left <= 0.0:
			stagger_left = 0.0
			poise = max_poise
		return
	_since_poise_damage += delta
	if _since_poise_damage >= poise_regen_delay and poise < max_poise:
		poise = minf(max_poise, poise + poise_regen_rate * delta)
