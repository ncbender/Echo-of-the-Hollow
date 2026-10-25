class_name HitReactionConfig
extends Resource
## Default durations and strengths of hit reactions for one kind of character.
## An attack's own reaction_duration (if > 0) overrides these defaults.
## Values are conservative TEST values (see docs/COMBAT_DESIGN.md).

## FLINCH: feedback only, never interrupts.
@export var flinch_duration: float = 0.12
## INTERRUPT: cancels the current action, then no new attacks for this long (movement allowed).
@export var interrupt_lockout: float = 0.25
## KNOCKBACK: cancels, pushes harder, no movement/actions for this long.
@export var knockback_duration: float = 0.35
## Multiplier on the hit's knockback vector for KNOCKBACK reactions.
@export var knockback_multiplier: float = 1.8
## STUN: cancels, no movement/actions for this long.
@export var stun_duration: float = 0.6
## Reactions up to this severity are reduced to FLINCH (0 = none). Later abilities/gear raise it.
@export var resistance: HitReaction.Type = HitReaction.Type.NONE


func default_duration(type: HitReaction.Type) -> float:
	match type:
		HitReaction.Type.FLINCH:
			return flinch_duration
		HitReaction.Type.INTERRUPT:
			return interrupt_lockout
		HitReaction.Type.KNOCKBACK:
			return knockback_duration
		HitReaction.Type.STUN:
			return stun_duration
	return 0.0
