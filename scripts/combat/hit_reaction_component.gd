class_name HitReactionComponent
extends Node
## Applies the reaction requested by an incoming hit (HitData.reaction) to its
## owner. Decides interruption and lockouts; the owner asks blocks_actions() /
## blocks_movement() each tick. Hits during dash iFrames never reach this
## component (the Hurtbox rejects them).

signal reaction_started(type: HitReaction.Type, duration: float)

@export var config: HitReactionConfig

var current: HitReaction.Type = HitReaction.Type.NONE
var time_left: float = 0.0
## Extra resistance granted at runtime (abilities, gear); combined with config.resistance.
var bonus_resistance: int = 0


func _ready() -> void:
	if config == null:
		config = HitReactionConfig.new()


## Resolves and starts the reaction for `hit`. Returns the effective reaction.
## `combat` may be null; `dash` may be null.
func apply(hit: HitData, combat: CombatComponent, dash: DashComponent) -> HitReaction.Type:
	var type := effective_type(hit.reaction)
	if type == HitReaction.Type.NONE:
		return type
	var interrupts := type >= HitReaction.Type.INTERRUPT
	if interrupts and combat != null and not combat.is_interruptible():
		type = HitReaction.Type.FLINCH   # hyper armor: feedback only
		interrupts = false
	var duration := hit.reaction_duration if hit.reaction_duration > 0.0 else config.default_duration(type)
	if interrupts and combat != null:
		combat.cancel(&"hit_reaction")
	if type >= HitReaction.Type.KNOCKBACK and dash != null:
		dash.stop()
	# A weaker reaction never shortens or replaces a stronger running one.
	if type > current or time_left <= 0.0:
		current = type
		time_left = duration
	elif type == current:
		time_left = maxf(time_left, duration)
	reaction_started.emit(type, duration)
	return type


func effective_type(requested: HitReaction.Type) -> HitReaction.Type:
	var resistance := maxi(int(config.resistance), bonus_resistance)
	if requested != HitReaction.Type.NONE and int(requested) <= resistance:
		return HitReaction.Type.FLINCH
	return requested


func knockback_multiplier(type: HitReaction.Type) -> float:
	return config.knockback_multiplier if type == HitReaction.Type.KNOCKBACK else 1.0


func is_reacting() -> bool:
	return time_left > 0.0


func blocks_actions() -> bool:
	return time_left > 0.0 and current >= HitReaction.Type.INTERRUPT


func blocks_movement() -> bool:
	return time_left > 0.0 and current >= HitReaction.Type.KNOCKBACK


func blocks_dash() -> bool:
	return blocks_movement()


func step(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		current = HitReaction.Type.NONE
